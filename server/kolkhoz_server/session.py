from __future__ import annotations

import hashlib
import hmac
import secrets
from dataclasses import dataclass
from typing import Any, Iterable

from .errors import ServerError


PLAYER_COUNT = 4
PRESENCE_GRACE_SECONDS = 20.0
DEFAULT_TURN_SECONDS = 90.0
TIMEOUTS_BEFORE_AUTOPILOT = 2
REACTION_IDS = frozenset(
    ("comrade", "medal", "protected", "warning", "wheat", "wrecker")
)


@dataclass(frozen=True)
class DomainEvent:
    """A persistence-ready fact emitted by a shard-owned session aggregate."""

    kind: str
    payload: dict[str, Any]
    occurred_at: float


@dataclass
class Seat:
    player_id: int
    user_id: str | None
    token_hash: str
    last_seen_at: float
    timeouts: int = 0
    autopilot: bool = False
    abandoned: bool = False


class SessionAggregate:
    """Lock-free lifecycle state for one game.

    A worker shard must serialize calls for a given session. Commands mutate only by
    applying the domain events they return; the same events can rebuild the aggregate.
    Gameplay rules and actions remain owned by the C-engine aggregate.
    """

    def __init__(
        self,
        *,
        session_id: str,
        invite_code: str,
        seed: int,
        variants: dict[str, Any],
        controllers: Iterable[str],
        created_by_user_id: str | None,
        created_at: float,
        ranked: bool = False,
        browser_joinable: bool = True,
        lobby_countdown_seconds: float = 30.0,
        session_ttl_seconds: float = 1800.0,
    ) -> None:
        normalized_controllers = tuple(controllers)
        if len(normalized_controllers) != PLAYER_COUNT:
            raise ValueError("a session requires four controllers")
        self.session_id = session_id
        self.invite_code = invite_code
        self.seed = seed
        self.variants = dict(variants)
        self.controllers = normalized_controllers
        self.created_by_user_id = created_by_user_id
        self.created_at = created_at
        self.ranked = ranked
        self.browser_joinable = browser_joinable
        self.lobby_countdown_seconds = max(0.0, lobby_countdown_seconds)
        self.session_ttl_seconds = session_ttl_seconds
        self.last_seen_at = created_at
        self.seats: dict[int, Seat] = {}
        self.invited_user_ids: set[str] = set()
        self.declined_invite_user_ids: set[str] = set()
        self.started = False
        self.lobby_countdown_ends_at: float | None = None
        self.turn_player_id: int | None = None
        self.turn_deadline_at: float | None = None
        self.action_log_count = 0
        self.reactions: list[dict[str, Any]] = []

    @classmethod
    def replay(
        cls, *, events: Iterable[DomainEvent], **metadata: Any
    ) -> SessionAggregate:
        aggregate = cls(**metadata)
        for event in events:
            aggregate.apply(event)
        return aggregate

    def apply(self, event: DomainEvent) -> None:
        payload = event.payload
        if event.kind == "seat_joined":
            player_id = int(payload["playerID"])
            self.seats[player_id] = Seat(
                player_id=player_id,
                user_id=payload.get("userID"),
                token_hash=str(payload["tokenHash"]),
                last_seen_at=float(payload["lastSeenAt"]),
            )
        elif event.kind in ("seat_left", "seat_kicked"):
            self.seats.pop(int(payload["playerID"]), None)
        elif event.kind == "seat_seen":
            seat = self.seats[int(payload["playerID"])]
            seat.last_seen_at = float(payload["lastSeenAt"])
            if not seat.abandoned:
                seat.autopilot = False
        elif event.kind == "users_invited":
            users = set(payload["userIDs"])
            self.invited_user_ids.update(users)
            self.declined_invite_user_ids.difference_update(users)
        elif event.kind == "invite_declined":
            user_id = str(payload["userID"])
            self.invited_user_ids.discard(user_id)
            self.declined_invite_user_ids.add(user_id)
        elif event.kind == "invite_consumed":
            user_id = str(payload["userID"])
            self.invited_user_ids.discard(user_id)
            self.declined_invite_user_ids.discard(user_id)
        elif event.kind == "lobby_countdown_set":
            value = payload.get("endsAt")
            self.lobby_countdown_ends_at = None if value is None else float(value)
        elif event.kind == "session_started":
            self.started = True
            self.lobby_countdown_ends_at = None
        elif event.kind == "reaction_added":
            self.reactions.append(dict(payload))
        elif event.kind == "seat_timeout_recorded":
            seat = self.seats[int(payload["playerID"])]
            seat.timeouts = int(payload["timeouts"])
        elif event.kind == "seat_autopilot_set":
            seat = self.seats[int(payload["playerID"])]
            seat.autopilot = bool(payload["autopilot"])
        elif event.kind == "seat_abandoned":
            seat = self.seats[int(payload["playerID"])]
            seat.abandoned = True
            seat.autopilot = True
            seat.timeouts = max(TIMEOUTS_BEFORE_AUTOPILOT, seat.timeouts)
        elif event.kind == "turn_deadline_set":
            player = payload.get("playerID")
            deadline = payload.get("deadlineAt")
            self.turn_player_id = None if player is None else int(player)
            self.turn_deadline_at = None if deadline is None else float(deadline)
        elif event.kind == "action_revision_advanced":
            self.action_log_count = int(payload["actionLogCount"])
        elif event.kind != "session_touched":
            raise ValueError(f"unknown session event: {event.kind}")
        self.last_seen_at = max(self.last_seen_at, event.occurred_at)

    def _emit(self, kind: str, payload: dict[str, Any], now: float) -> DomainEvent:
        event = DomainEvent(kind, payload, now)
        self.apply(event)
        return event

    @staticmethod
    def _token_hash(token: str) -> str:
        return hashlib.sha256(token.encode()).hexdigest()

    def authenticate(
        self, player_id: int, token: str | None, user_id: str | None = None
    ) -> Seat:
        seat = self.seats.get(player_id)
        if (
            seat is None
            or token is None
            or not hmac.compare_digest(seat.token_hash, self._token_hash(token))
        ):
            raise ServerError(401, "invalid seat token")
        if user_id is not None and seat.user_id is not None and seat.user_id != user_id:
            raise ServerError(401, "invalid auth token")
        return seat

    def open_seats(self) -> list[int]:
        return [
            player_id
            for player_id, controller in enumerate(self.controllers)
            if not self.started
            and controller == "human"
            and player_id not in self.seats
        ]

    def can_join(self, user_id: str | None, *, via_invite_code: bool) -> bool:
        if self.started or not self.open_seats():
            return False
        if via_invite_code or self.browser_joinable:
            return True
        return user_id is not None and (
            user_id == self.created_by_user_id
            or user_id in self.invited_user_ids
            or any(seat.user_id == user_id for seat in self.seats.values())
        )

    def join(
        self,
        *,
        user_id: str | None,
        now: float,
        preferred_player_id: int | None = None,
        via_invite_code: bool = False,
        token: str | None = None,
    ) -> tuple[int, str, list[DomainEvent]]:
        if not self.can_join(user_id, via_invite_code=via_invite_code):
            raise ServerError(403, "not invited")
        open_seats = self.open_seats()
        if preferred_player_id is not None:
            if preferred_player_id not in open_seats:
                raise ServerError(409, "seat unavailable")
            player_id = preferred_player_id
        else:
            player_id = open_seats[0]
        token = token or secrets.token_urlsafe(32)
        events = [
            self._emit(
                "seat_joined",
                {
                    "playerID": player_id,
                    "userID": user_id,
                    "tokenHash": self._token_hash(token),
                    "lastSeenAt": now,
                },
                now,
            )
        ]
        if user_id is not None and (
            user_id in self.invited_user_ids or user_id in self.declined_invite_user_ids
        ):
            events.append(self._emit("invite_consumed", {"userID": user_id}, now))
        events.extend(self.sync_lobby(now))
        return player_id, token, events

    def invite(
        self,
        *,
        actor_user_id: str,
        user_ids: Iterable[str],
        comrade_user_ids: set[str],
        now: float,
    ) -> list[DomainEvent]:
        if (
            self.created_by_user_id is not None
            and actor_user_id != self.created_by_user_id
        ):
            raise ServerError(403, "only the host can invite")
        if self.started:
            raise ServerError(409, "game has already started")
        users = {user for user in user_ids if user and user != actor_user_id}
        if not users:
            raise ServerError(400, "missing userIDs")
        if not users.issubset(comrade_user_ids):
            raise ServerError(403, "can only invite comrades")
        seated = {seat.user_id for seat in self.seats.values()}
        pending = sorted(users - seated)
        if not pending:
            return []
        return [self._emit("users_invited", {"userIDs": pending}, now)]

    def decline_invite(self, *, user_id: str, now: float) -> list[DomainEvent]:
        if user_id not in self.invited_user_ids:
            raise ServerError(404, "invite not found")
        return [self._emit("invite_declined", {"userID": user_id}, now)]

    def pending_invite(self, user_id: str) -> bool:
        return (
            not self.started
            and user_id in self.invited_user_ids
            and user_id not in self.declined_invite_user_ids
            and all(seat.user_id != user_id for seat in self.seats.values())
            and bool(self.open_seats())
        )

    def leave(
        self, *, player_id: int, token: str, user_id: str | None, now: float
    ) -> list[DomainEvent]:
        self.authenticate(player_id, token, user_id)
        if self.started:
            return [self._emit("seat_abandoned", {"playerID": player_id}, now)]
        events = [self._emit("seat_left", {"playerID": player_id}, now)]
        events.extend(self.sync_lobby(now))
        return events

    def kick(
        self,
        *,
        host_player_id: int,
        target_player_id: int,
        token: str,
        user_id: str | None,
        now: float,
    ) -> list[DomainEvent]:
        host = self.authenticate(host_player_id, token, user_id)
        is_host = (
            host.user_id == self.created_by_user_id
            if self.created_by_user_id is not None
            else host_player_id == 0
        )
        if not is_host:
            raise ServerError(403, "only the host can kick")
        if target_player_id == host_player_id:
            raise ServerError(409, "cannot kick yourself")
        if self.started:
            raise ServerError(409, "cannot kick after the game starts")
        if (
            target_player_id not in self.seats
            or self.controllers[target_player_id] != "human"
        ):
            raise ServerError(409, "seat unavailable")
        events = [self._emit("seat_kicked", {"playerID": target_player_id}, now)]
        events.extend(self.sync_lobby(now))
        return events

    def sync_lobby(self, now: float) -> list[DomainEvent]:
        if self.started:
            return []
        if self.open_seats():
            if self.lobby_countdown_ends_at is None:
                return []
            return [self._emit("lobby_countdown_set", {"endsAt": None}, now)]
        if self.lobby_countdown_ends_at is None:
            return [
                self._emit(
                    "lobby_countdown_set",
                    {"endsAt": now + self.lobby_countdown_seconds},
                    now,
                )
            ]
        if now < self.lobby_countdown_ends_at:
            return []
        return [self._emit("session_started", {}, now)]

    def react(
        self,
        *,
        player_id: int,
        token: str,
        user_id: str | None,
        reaction_id: str,
        year: int,
        phase: int,
        now: float,
    ) -> list[DomainEvent]:
        self.authenticate(player_id, token, user_id)
        if not self.started:
            raise ServerError(409, "game has not started")
        if reaction_id not in REACTION_IDS:
            raise ServerError(400, "invalid reaction")
        return [
            self._emit(
                "reaction_added",
                {
                    "revision": len(self.reactions) + 1,
                    "playerID": player_id,
                    "reactionID": reaction_id,
                    "year": year,
                    "phase": phase,
                    "createdAt": now,
                },
                now,
            )
        ]

    def mark_seen(self, *, player_id: int, now: float) -> list[DomainEvent]:
        if player_id not in self.seats:
            raise ServerError(409, "seat unavailable")
        events = [
            self._emit("seat_seen", {"playerID": player_id, "lastSeenAt": now}, now)
        ]
        if self.turn_player_id == player_id and self.turn_deadline_at is None:
            events.extend(self.set_waiting_player(player_id, now=now))
        return events

    def set_waiting_player(
        self, player_id: int | None, *, now: float
    ) -> list[DomainEvent]:
        eligible = (
            self.started
            and player_id is not None
            and player_id in self.seats
            and self.controllers[player_id] == "human"
            and not self.seats[player_id].autopilot
        )
        next_player = player_id if eligible else None
        if next_player == self.turn_player_id and self.turn_deadline_at is not None:
            return []
        deadline = now + DEFAULT_TURN_SECONDS if next_player is not None else None
        if next_player == self.turn_player_id and deadline == self.turn_deadline_at:
            return []
        return [
            self._emit(
                "turn_deadline_set",
                {"playerID": next_player, "deadlineAt": deadline},
                now,
            )
        ]

    def record_timeout(self, *, player_id: int, now: float) -> list[DomainEvent]:
        seat = self.seats.get(player_id)
        if seat is None:
            raise ServerError(409, "seat unavailable")
        if self.turn_player_id != player_id or self.turn_deadline_at is None:
            raise ServerError(409, "player has no active deadline")
        if now < self.turn_deadline_at:
            raise ServerError(409, "turn deadline has not elapsed")
        events = [
            self._emit(
                "seat_timeout_recorded",
                {"playerID": player_id, "timeouts": seat.timeouts + 1},
                now,
            )
        ]
        if self.seats[player_id].timeouts >= TIMEOUTS_BEFORE_AUTOPILOT:
            events.append(self._emit("seat_abandoned", {"playerID": player_id}, now))
        events.append(
            self._emit(
                "turn_deadline_set",
                {"playerID": None, "deadlineAt": None},
                now,
            )
        )
        return events

    def advance_action_revision(
        self, *, expected: int, now: float
    ) -> list[DomainEvent]:
        if expected != self.action_log_count:
            raise ServerError(409, "stale action")
        return [
            self._emit(
                "action_revision_advanced",
                {"actionLogCount": expected + 1},
                now,
            )
        ]

    def seat_presence(self, now: float) -> list[dict[str, Any]]:
        return [
            {
                "playerID": player_id,
                "connected": seat is not None
                and (
                    self.controllers[player_id] != "human"
                    or now - seat.last_seen_at <= PRESENCE_GRACE_SECONDS
                ),
                "lastSeenAt": seat.last_seen_at if seat else None,
                "timeouts": seat.timeouts if seat else 0,
                "autopilot": seat.autopilot if seat else False,
                "abandoned": seat.abandoned if seat else False,
            }
            for player_id in range(PLAYER_COUNT)
            for seat in (self.seats.get(player_id),)
        ]

    def listing(self, now: float) -> dict[str, Any]:
        return {
            "sessionID": self.session_id,
            "inviteCode": self.invite_code,
            "openSeats": self.open_seats(),
            "occupiedSeats": sorted(self.seats),
            "controllers": list(self.controllers),
            "ranked": self.ranked,
            "browserJoinable": self.browser_joinable,
            "seatPresence": self.seat_presence(now),
            "turnPlayerID": self.turn_player_id,
            "turnDeadlineAt": self.turn_deadline_at,
            "actionLogCount": self.action_log_count,
            "started": self.started,
            "lobbyCountdownEndsAt": self.lobby_countdown_ends_at,
            "createdAt": self.created_at,
            "expiresAt": self.last_seen_at + self.session_ttl_seconds,
        }

    def update_input(self, *, viewer_id: int | None, now: float) -> dict[str, Any]:
        return {
            "sessionID": self.session_id,
            "seed": self.seed,
            "inviteCode": self.invite_code,
            "viewerID": viewer_id,
            "actionLogCount": self.action_log_count,
            "started": self.started,
            "lobbyCountdownEndsAt": self.lobby_countdown_ends_at,
            "reactions": [dict(reaction) for reaction in self.reactions],
            "isViewerTurn": self.started and viewer_id == self.turn_player_id,
            "variants": dict(self.variants),
            "controllers": list(self.controllers),
            "ranked": self.ranked,
            "browserJoinable": self.browser_joinable,
            "seatPresence": self.seat_presence(now),
            "turnPlayerID": self.turn_player_id,
            "turnDeadlineAt": self.turn_deadline_at,
        }
