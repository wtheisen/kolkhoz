from __future__ import annotations

import threading
import time
from dataclasses import replace

from server.kolkhoz_server.lobby import (
    DueTurn,
    LifecycleIntent,
    SeatRecord,
    SeatUnavailable,
    SessionRecord,
    TimeoutResult,
    new_session_record,
)
from server.kolkhoz_server.model import JsonObject


class InMemoryLobbyRepository:
    """Thread-safe disposable lobby repository for unit tests."""

    def __init__(self, unused_path: object = None) -> None:
        self._lock = threading.RLock()
        self._sessions: dict[str, SessionRecord] = {}
        self._seats: dict[str, list[SeatRecord]] = {}
        self._invites: dict[tuple[str, str], tuple[bool, float]] = {}
        self._presence: dict[str, float] = {}
        self._device_leases: dict[tuple[str, str], tuple[str, float]] = {}
        self._reactions: dict[str, list[dict[str, object]]] = {}
        self._turns: dict[
            str, tuple[int | None, float | None, str | None, float | None, int]
        ] = {}
        self._timeouts: dict[tuple[str, int], TimeoutResult] = {}
        self._intents: dict[tuple[str, str], dict[str, object]] = {}

    @staticmethod
    def new_session(**values: object) -> SessionRecord:
        return new_session_record(**values)  # type: ignore[arg-type]

    def create(self, record: SessionRecord, seats: list[SeatRecord]) -> None:
        with self._lock:
            if record.session_id in self._sessions:
                raise KeyError(record.session_id)
            for seat in seats:
                if seat.user_id is not None:
                    self._release_finished_seats(seat.user_id)
                    self._require_available_user(seat.user_id)
            self._sessions[record.session_id] = record
            self._seats[record.session_id] = list(seats)
            self._turns[record.session_id] = (None, None, None, None, 0)
            self._set_intent(
                record.session_id,
                "provision",
                record.created_at,
                seed=record.seed,
                variants=record.variants,
                controllers=record.controllers,
            )

    def set_ranked(self, session_id: str, ranked: bool, *, now: float) -> None:
        with self._lock:
            record = self.session(session_id)
            self._sessions[session_id] = replace(record, ranked=ranked, updated_at=now)

    def session(self, session_id_or_invite: str) -> SessionRecord:
        with self._lock:
            direct = self._sessions.get(session_id_or_invite)
            if direct is not None:
                return direct
            normalized = session_id_or_invite.upper()
            for record in self._sessions.values():
                if record.invite_code.upper() == normalized:
                    return record
        raise KeyError(session_id_or_invite)

    def seats(self, session_id: str) -> list[SeatRecord]:
        with self._lock:
            return list(self._seats.get(session_id, ()))

    def list_open(self, now: float) -> list[SessionRecord]:
        with self._lock:
            records = [
                record
                for record in self._sessions.values()
                if record.status == "open"
                and record.browser_joinable
                and record.expires_at > now
                and any(
                    seat.controller == "human" and not seat.occupied
                    for seat in self._seats[record.session_id]
                )
            ]
            return sorted(records, key=lambda value: value.updated_at, reverse=True)

    def list_watchable(self, now: float) -> list[SessionRecord]:
        with self._lock:
            records = [
                record
                for record in self._sessions.values()
                if record.status == "active"
                and record.browser_joinable
                and not record.ranked
                and record.expires_at > now
            ]
            return sorted(records, key=lambda value: value.updated_at, reverse=True)

    def automatic_due_sessions(self, *, now: float, limit: int) -> list[str]:
        with self._lock:
            records = [
                record
                for record in self._sessions.values()
                if record.status == "active"
                and self._turns[record.session_id][0] is None
                and record.expires_at > now
                and record.updated_at <= now - 1
            ]
            return [
                value.session_id
                for value in sorted(
                    records, key=lambda item: (item.updated_at, item.session_id)
                )[:limit]
            ]

    def activate_ready_sessions(self, *, now: float) -> list[str]:
        with self._lock:
            activated = []
            for record in list(self._sessions.values()):
                ready = all(
                    seat.controller != "human" or seat.occupied
                    for seat in self._seats[record.session_id]
                )
                if (
                    record.status == "open"
                    and record.lobby_countdown_ends_at is not None
                    and record.lobby_countdown_ends_at <= now
                    and ready
                ):
                    self._sessions[record.session_id] = replace(
                        record,
                        status="active",
                        updated_at=now,
                        lobby_countdown_ends_at=None,
                    )
                    activated.append(record.session_id)
            return activated

    def finish_session(self, session_id: str, *, now: float, expires_at: float) -> bool:
        with self._lock:
            record = self.session(session_id)
            if record.status != "active":
                return False
            self._sessions[session_id] = replace(
                record, status="finished", updated_at=now, expires_at=expires_at
            )
            self._turns[session_id] = (
                None,
                None,
                None,
                None,
                self._turns[session_id][4],
            )
            self._set_intent(session_id, "invalidate", now)
            return True

    def expire_sessions(self, *, now: float, limit: int) -> list[str]:
        with self._lock:
            expired = sorted(
                (
                    record
                    for record in self._sessions.values()
                    if record.status in {"open", "active"} and record.expires_at <= now
                ),
                key=lambda value: (value.expires_at, value.session_id),
            )[:limit]
            for record in expired:
                self._sessions[record.session_id] = replace(
                    record, status="expired", updated_at=now
                )
                self._seats[record.session_id] = [
                    self._empty_seat(seat) for seat in self._seats[record.session_id]
                ]
                self._turns[record.session_id] = (
                    None,
                    None,
                    None,
                    None,
                    self._turns[record.session_id][4],
                )
                self._set_intent(record.session_id, "invalidate", now)
            return [record.session_id for record in expired]

    def occupy_seat(
        self,
        session_id: str,
        player_id: int,
        *,
        user_id: str,
        token_hash: str,
        now: float,
    ) -> None:
        with self._lock:
            self._release_finished_seats(user_id)
            self._require_available_user(user_id)
            seat = self._seat(session_id, player_id)
            if seat.controller != "human" or seat.occupied:
                raise SeatUnavailable(f"seat {player_id} is unavailable")
            self._replace_seat(
                session_id,
                replace(
                    seat,
                    occupied=True,
                    user_id=user_id,
                    token_hash=token_hash,
                    last_seen_at=now,
                    abandoned=False,
                    autopilot=False,
                ),
            )
            self._touch_session(session_id, now)

    def _release_seat(self, session_id: str, player_id: int, *, now: float) -> None:
        seat = self._seat(session_id, player_id)
        if not seat.occupied:
            raise SeatUnavailable(f"seat {player_id} is unavailable")
        self._replace_seat(session_id, self._empty_seat(seat))
        self._touch_session(session_id, now)

    def release_seat_and_delete_if_empty(
        self, session_id: str, player_id: int, *, now: float
    ) -> bool:
        with self._lock:
            self._release_seat(session_id, player_id, now=now)
            if any(seat.occupied for seat in self._seats[session_id]):
                return False
            if self._sessions[session_id].status != "open":
                return False
            self._set_intent(session_id, "delete", now)
            self._sessions.pop(session_id)
            self._seats.pop(session_id)
            self._turns.pop(session_id, None)
            return True

    def kick_seat(
        self,
        session_id: str,
        target_player_id: int,
        *,
        host_user_id: str,
        now: float,
    ) -> None:
        with self._lock:
            record = self.session(session_id)
            if record.status != "open" or record.created_by_user_id != host_user_id:
                raise SeatUnavailable(f"seat {target_player_id} is unavailable")
            self._release_seat(session_id, target_player_id, now=now)

    def abandon_seat(self, session_id: str, player_id: int, *, now: float) -> None:
        with self._lock:
            seat = self._seat(session_id, player_id)
            if not seat.occupied:
                raise SeatUnavailable(f"seat {player_id} is unavailable")
            self._replace_seat(
                session_id,
                replace(
                    seat,
                    abandoned=True,
                    autopilot=True,
                    timeouts=max(2, seat.timeouts),
                    last_seen_at=now,
                ),
            )

    def set_status(
        self,
        session_id: str,
        status: str,
        *,
        now: float,
        countdown_ends_at: float | None = None,
    ) -> None:
        with self._lock:
            record = self.session(session_id)
            self._sessions[session_id] = replace(
                record,
                status=status,
                updated_at=now,
                lobby_countdown_ends_at=countdown_ends_at,
            )

    def delete_session(self, session_id: str) -> None:
        with self._lock:
            self._set_intent(session_id, "delete", time.time())
            self._sessions.pop(session_id, None)
            self._seats.pop(session_id, None)
            self._turns.pop(session_id, None)

    def append_reaction(
        self,
        session_id: str,
        *,
        player_id: int,
        reaction_id: str,
        year: int,
        phase: int,
        now: float,
    ) -> dict[str, object]:
        with self._lock:
            values = self._reactions.setdefault(session_id, [])
            reaction = {
                "revision": len(values) + 1,
                "playerID": player_id,
                "reactionID": reaction_id,
                "year": year,
                "phase": phase,
                "createdAt": now,
            }
            values.append(reaction)
            return dict(reaction)

    def reactions(self, session_id: str) -> list[dict[str, object]]:
        with self._lock:
            return [dict(value) for value in self._reactions.get(session_id, ())]

    def invite(self, session_id: str, user_ids: set[str], *, now: float) -> None:
        with self._lock:
            for user_id in user_ids:
                self._invites[(session_id, user_id)] = (False, now)

    def invites_for_user(self, user_id: str) -> list[SessionRecord]:
        with self._lock:
            values = [
                (created_at, self._sessions[session_id])
                for (session_id, invited_user), (
                    declined,
                    created_at,
                ) in self._invites.items()
                if invited_user == user_id
                and not declined
                and session_id in self._sessions
                and self._sessions[session_id].status == "open"
                and self._sessions[session_id].expires_at > time.time()
            ]
            return [record for _, record in sorted(values, reverse=True)]

    def decline_invite(self, session_id: str, user_id: str) -> None:
        with self._lock:
            key = (session_id, user_id)
            current = self._invites.get(key)
            if current is None or current[0]:
                raise KeyError("session invite not found")
            self._invites[key] = (True, current[1])

    def invite_access(self, session_id: str, user_id: str) -> tuple[bool, bool]:
        with self._lock:
            values = {
                invited_user: declined
                for (value_session, invited_user), (
                    declined,
                    _,
                ) in self._invites.items()
                if value_session == session_id
            }
            return bool(values), user_id in values and not values[user_id]

    def consume_invite(self, session_id: str, user_id: str) -> None:
        with self._lock:
            self._invites.pop((session_id, user_id), None)

    def mark_presence(self, user_id: str, *, now: float) -> None:
        with self._lock:
            self._presence[user_id] = now

    def acquire_device_lease(
        self,
        user_id: str,
        device_id: str,
        session_id: str,
        *,
        now: float,
        ttl_seconds: float,
    ) -> bool:
        with self._lock:
            cutoff = now - max(0.0, ttl_seconds)
            for (lease_user, lease_device), (
                lease_session,
                seen_at,
            ) in self._device_leases.items():
                if (
                    lease_user == user_id
                    and lease_device != device_id
                    and lease_session == session_id
                    and seen_at >= cutoff
                ):
                    return False
            self._device_leases[(user_id, device_id)] = (session_id, now)
            return True

    def online_user_ids(self, *, since: float) -> set[str]:
        with self._lock:
            return {
                user_id
                for user_id, seen_at in self._presence.items()
                if seen_at >= since
            }

    def metrics_state(self, *, now: float, presence_since: float) -> JsonObject:
        with self._lock:
            active = [
                record
                for record in self._sessions.values()
                if record.status in {"open", "active"} and record.expires_at > now
            ]
            active_ids = {record.session_id for record in active}
            seats = [
                seat for session_id in active_ids for seat in self._seats[session_id]
            ]
            people = self.online_user_ids(since=presence_since)
            people.update(
                seat.user_id
                for seat in seats
                if seat.occupied
                and seat.controller != "human"
                and seat.user_id is not None
            )
            return {
                "activeSessions": len(active),
                "activeSeats": sum(seat.occupied for seat in seats),
                "connectedSeatedHumanSeats": sum(
                    seat.occupied
                    and not seat.abandoned
                    and seat.controller == "human"
                    and (seat.last_seen_at or 0) >= presence_since
                    for seat in seats
                ),
                "citizensOnline": len(people),
            }

    def active_for_user(self, user_id: str) -> tuple[SessionRecord, SeatRecord] | None:
        with self._lock:
            matches = []
            now = time.time()
            for record in self._sessions.values():
                if record.status not in {"open", "active"} or record.expires_at <= now:
                    continue
                for seat in self._seats[record.session_id]:
                    if seat.occupied and not seat.abandoned and seat.user_id == user_id:
                        matches.append((record, seat))
            return (
                max(matches, key=lambda value: value[0].updated_at) if matches else None
            )

    def replace_seat_token(
        self, session_id: str, player_id: int, *, token_hash: str, now: float
    ) -> None:
        with self._lock:
            seat = self._seat(session_id, player_id)
            if not seat.occupied:
                raise SeatUnavailable(f"seat {player_id} is unavailable")
            self._replace_seat(
                session_id, replace(seat, token_hash=token_hash, last_seen_at=now)
            )

    def touch_seat(
        self,
        session_id: str,
        player_id: int,
        *,
        now: float,
        session_ttl_seconds: float | None = None,
    ) -> None:
        with self._lock:
            seat = self._seat(session_id, player_id)
            if not seat.occupied:
                raise SeatUnavailable(f"seat {player_id} is unavailable")
            self._replace_seat(
                session_id,
                replace(
                    seat,
                    last_seen_at=now,
                    autopilot=seat.autopilot if seat.abandoned else False,
                ),
            )
            if session_ttl_seconds is not None:
                record = self.session(session_id)
                if record.status in {"open", "active"}:
                    self._sessions[session_id] = replace(
                        record,
                        expires_at=max(record.expires_at, now + session_ttl_seconds),
                    )

    def set_turn_deadline(
        self,
        session_id: str,
        player_id: int | None,
        *,
        deadline_at: float | None,
        now: float,
    ) -> None:
        if (player_id is None) != (deadline_at is None):
            raise ValueError(
                "player_id and deadline_at must both be set or both be null"
            )
        with self._lock:
            token = self._turns[session_id][4]
            self._turns[session_id] = (player_id, deadline_at, None, None, token)
            self._touch_session(session_id, now)

    def turn_state(self, session_id: str) -> tuple[int | None, float | None]:
        with self._lock:
            turn = self._turns.get(session_id)
            if turn is None:
                raise KeyError(session_id)
            return turn[0], turn[1]

    def claim_due_turns(
        self, *, owner: str, now: float, lease_seconds: float, limit: int
    ) -> list[DueTurn]:
        if not owner or lease_seconds <= 0 or limit <= 0:
            raise ValueError("owner, lease_seconds, and limit must be positive")
        with self._lock:
            due = []
            for session_id, turn in self._turns.items():
                player_id, deadline, _, claim_until, _ = turn
                record = self._sessions.get(session_id)
                if (
                    record is not None
                    and record.status == "active"
                    and player_id is not None
                    and deadline is not None
                    and deadline <= now
                    and (claim_until is None or claim_until <= now)
                ):
                    due.append((deadline, session_id))
            claims = []
            for deadline, session_id in sorted(due)[:limit]:
                player_id, _, _, _, token = self._turns[session_id]
                token += 1
                self._turns[session_id] = (
                    player_id,
                    deadline,
                    owner,
                    now + lease_seconds,
                    token,
                )
                claims.append(DueTurn(session_id, player_id, deadline, owner, token))  # type: ignore[arg-type]
            return claims

    def consume_timeout(self, claim: DueTurn, *, now: float) -> TimeoutResult:
        with self._lock:
            key = (claim.session_id, claim.fencing_token)
            existing = self._timeouts.get(key)
            if existing is not None:
                return existing
            turn = self._turns.get(claim.session_id)
            if (
                turn is None
                or turn[0] != claim.player_id
                or turn[1] is None
                or turn[1] > now
                or turn[2] != claim.claim_owner
                or turn[4] != claim.fencing_token
            ):
                raise SeatUnavailable("stale timeout claim")
            seat = self._seat(claim.session_id, claim.player_id)
            if not seat.occupied:
                raise SeatUnavailable("timeout seat unavailable")
            timeouts = seat.timeouts + 1
            forced = timeouts >= 2 or seat.autopilot
            self._replace_seat(
                claim.session_id,
                replace(
                    seat,
                    timeouts=timeouts,
                    autopilot=forced,
                    abandoned=timeouts >= 2 or seat.abandoned,
                ),
            )
            self._turns[claim.session_id] = (None, None, None, None, turn[4])
            result = TimeoutResult(timeouts, forced)
            self._timeouts[key] = result
            return result

    def complete_timeout(self, claim: DueTurn) -> None:
        with self._lock:
            key = (claim.session_id, claim.fencing_token)
            current = self._timeouts.get(key)
            if current is None:
                raise SeatUnavailable("timeout transition unavailable")
            self._timeouts[key] = replace(current, completed=True)

    def complete_lifecycle_intent(
        self, session_id: str, operation: str, *, fencing_token: int | None = None
    ) -> None:
        with self._lock:
            key = (session_id, operation)
            current = self._intents.get(key)
            if current is not None and (
                fencing_token is None or current["fencing_token"] == fencing_token
            ):
                self._intents.pop(key)

    def claim_lifecycle_intents(
        self, *, owner: str, now: float, lease_seconds: float, limit: int
    ) -> list[LifecycleIntent]:
        with self._lock:
            due = [
                (key, value)
                for key, value in self._intents.items()
                if value["next_attempt_at"] <= now
                and (value["claim_until"] is None or value["claim_until"] <= now)
            ]
            results = []
            for (session_id, operation), value in sorted(due)[:limit]:
                value["claim_owner"] = owner
                value["claim_until"] = now + lease_seconds
                value["fencing_token"] = int(value["fencing_token"]) + 1
                results.append(
                    LifecycleIntent(
                        session_id,
                        operation,
                        value["seed"],  # type: ignore[arg-type]
                        value["variants"],  # type: ignore[arg-type]
                        value["controllers"],  # type: ignore[arg-type]
                        int(value["fencing_token"]),
                    )
                )
            return results

    def retry_lifecycle_intent(
        self, intent: LifecycleIntent, *, now: float, delay_seconds: float
    ) -> None:
        with self._lock:
            current = self._intents.get((intent.session_id, intent.operation))
            if current is not None and current["fencing_token"] == intent.fencing_token:
                current["next_attempt_at"] = now + delay_seconds
                current["claim_owner"] = None
                current["claim_until"] = None

    def _set_intent(
        self,
        session_id: str,
        operation: str,
        now: float,
        *,
        seed: int | None = None,
        variants: JsonObject | None = None,
        controllers: list[str] | None = None,
    ) -> None:
        self._intents[(session_id, operation)] = {
            "seed": seed,
            "variants": None if variants is None else dict(variants),
            "controllers": None if controllers is None else list(controllers),
            "next_attempt_at": now,
            "claim_owner": None,
            "claim_until": None,
            "fencing_token": 0,
        }

    def _seat(self, session_id: str, player_id: int) -> SeatRecord:
        for seat in self._seats.get(session_id, ()):
            if seat.player_id == player_id:
                return seat
        raise SeatUnavailable(f"seat {player_id} is unavailable")

    def _replace_seat(self, session_id: str, updated: SeatRecord) -> None:
        self._seats[session_id] = [
            updated if seat.player_id == updated.player_id else seat
            for seat in self._seats[session_id]
        ]

    @staticmethod
    def _empty_seat(seat: SeatRecord) -> SeatRecord:
        return replace(
            seat,
            occupied=False,
            user_id=None,
            token_hash=None,
            last_seen_at=None,
            abandoned=False,
            autopilot=False,
        )

    def _touch_session(self, session_id: str, now: float) -> None:
        record = self.session(session_id)
        self._sessions[session_id] = replace(record, updated_at=now)

    def _release_finished_seats(self, user_id: str) -> None:
        for session_id, record in self._sessions.items():
            if record.status not in {"finished", "expired"}:
                continue
            self._seats[session_id] = [
                self._empty_seat(seat) if seat.user_id == user_id else seat
                for seat in self._seats[session_id]
            ]

    def _require_available_user(self, user_id: str) -> None:
        for session_id, seats in self._seats.items():
            if any(
                seat.occupied and not seat.abandoned and seat.user_id == user_id
                for seat in seats
            ):
                raise SeatUnavailable("user already has an active seat")
