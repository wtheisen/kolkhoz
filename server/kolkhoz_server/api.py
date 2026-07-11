from __future__ import annotations

import hashlib
import re
import secrets
import time
from dataclasses import dataclass
from http import HTTPStatus
from typing import Mapping
from urllib.parse import parse_qs, urlsplit

from .contracts import (
    listing_json,
    normalize_controllers,
    normalize_variants,
    optional_bool,
    optional_int,
)
from .errors import ServerError
from .lobby import SeatRecord, SeatUnavailable, SQLiteLobbyRepository
from .model import JsonObject
from .routes import resolve_route
from .runtime import GameRuntime
from .session import REACTION_IDS
from .social import SocialService


@dataclass(frozen=True)
class Request:
    method: str
    target: str
    headers: Mapping[str, str]
    body: JsonObject


@dataclass(frozen=True)
class Response:
    status: int
    body: object


class AuthVerifier:
    def user_id(self, authorization: str | None) -> str | None: ...


class OnlineApplication:
    """Transport-neutral compatibility API composed from independent services."""

    def __init__(
        self,
        runtime: GameRuntime,
        lobby: SQLiteLobbyRepository,
        *,
        auth: AuthVerifier | None = None,
        social: SocialService | None = None,
        session_ttl_seconds: float = 1800,
        presence_ttl_seconds: float = 60,
        lobby_countdown_seconds: float = 30,
    ) -> None:
        self.runtime = runtime
        self.lobby = lobby
        self.auth = auth
        self.social = social
        self.session_ttl_seconds = session_ttl_seconds
        self.presence_ttl_seconds = presence_ttl_seconds
        self.lobby_countdown_seconds = max(0.0, lobby_countdown_seconds)

    def dispatch(self, request: Request) -> Response:
        parsed = urlsplit(request.target)
        route = resolve_route(request.method, parsed.path)
        if route is None:
            raise ServerError(HTTPStatus.NOT_FOUND, "route not found")
        params = _route_params(route.path, parsed.path)
        query = parse_qs(parsed.query)
        user_id = self._user_id(request.headers)
        operation = route.operation

        if operation == "health":
            return Response(HTTPStatus.OK, self.runtime.health_state())
        if operation == "presence.heartbeat":
            if user_id is not None:
                self.lobby.mark_presence(user_id, now=time.time())
            return Response(
                HTTPStatus.OK,
                {
                    "citizensOnline": len(
                        self.lobby.online_user_ids(
                            since=time.time() - self.presence_ttl_seconds
                        )
                    )
                },
            )
        if operation == "active_session.sync":
            return Response(HTTPStatus.OK, self._sync_active(user_id))
        if operation.startswith("profiles.") or operation.startswith("comrades."):
            return Response(
                HTTPStatus.OK, self._social(operation, params, request.body, user_id)
            )
        if operation == "sessions.create":
            return Response(HTTPStatus.OK, self._create(request.body, user_id))
        if operation == "sessions.list":
            return Response(
                HTTPStatus.OK,
                [self._listing(value) for value in self.lobby.list_open(time.time())],
            )
        if operation == "sessions.get":
            return Response(
                HTTPStatus.OK, self._listing(self.lobby.session(params["sessionID"]))
            )
        if operation == "sessions.join":
            return Response(
                HTTPStatus.OK,
                self._join(params["sessionID"], request.body, user_id),
            )
        if operation == "sessions.matchmake":
            return Response(HTTPStatus.OK, self._matchmake(request.body, user_id))
        if operation == "sessions.invites.pending":
            user_id = self._require_user(user_id)
            return Response(
                HTTPStatus.OK,
                [
                    self._listing(value)
                    for value in self.lobby.invites_for_user(user_id)
                ],
            )
        if operation == "sessions.invites.send":
            return Response(
                HTTPStatus.OK,
                self._invite(params["sessionID"], request.body, user_id),
            )
        if operation == "sessions.invites.decline":
            user_id = self._require_user(user_id)
            session = self.lobby.session(params["sessionID"])
            self.runtime.serialize(
                session.session_id,
                lambda: self.lobby.decline_invite(session.session_id, user_id),
            )
            return Response(HTTPStatus.OK, {"declined": True})
        if operation in {
            "sessions.state",
            "sessions.actions.legal",
            "sessions.actions.since",
            "sessions.actions.submit",
            "sessions.reactions.submit",
        }:
            return Response(
                HTTPStatus.OK,
                self._game_operation(operation, params, query, request, user_id),
            )
        if operation == "sessions.players.leave":
            return Response(
                HTTPStatus.OK,
                self._leave(
                    params["sessionID"], int(params["playerID"]), request, user_id
                ),
            )
        if operation == "sessions.players.kick":
            return Response(
                HTTPStatus.OK,
                self._kick(
                    params["sessionID"],
                    int(params["playerID"]),
                    request,
                    user_id,
                ),
            )
        raise ServerError(HTTPStatus.NOT_IMPLEMENTED, f"{operation} is not implemented")

    def _create(self, body: JsonObject, user_id: str | None) -> JsonObject:
        user_id = self._require_user(user_id)
        self._ensure_no_active(user_id)
        variants = normalize_variants(body.get("variants"))
        controllers = normalize_controllers(body.get("controllers"))
        seed = optional_int(body.get("seed")) or int(time.time_ns())
        record = self.lobby.new_session(
            seed=seed,
            variants=variants,
            controllers=controllers,
            ranked=False,
            browser_joinable=optional_bool(body.get("browserJoinable"), True),
            created_by_user_id=user_id,
            ttl_seconds=self.session_ttl_seconds,
        )
        player_id = controllers.index("human")
        seat_token = secrets.token_urlsafe(24)
        seats = [
            SeatRecord(
                index,
                controller,
                index == player_id,
                user_id if index == player_id else None,
                _token_hash(seat_token) if index == player_id else None,
                record.created_at if index == player_id else None,
                0,
                False,
                False,
            )
            for index, controller in enumerate(controllers)
        ]
        self.lobby.create(record, seats)
        try:
            self.runtime.create_game(
                seed=seed,
                variants={"variants": variants, "controllers": controllers},
                session_id=record.session_id,
            )
            record = self._sync_lobby(record.session_id)
        except Exception:
            self.lobby.delete_session(record.session_id)
            raise
        return {
            "sessionID": record.session_id,
            "inviteCode": record.invite_code,
            "playerID": player_id,
            "seatToken": seat_token,
            "update": self._update(record.session_id, player_id),
        }

    def _join(
        self, session_id_or_invite: str, body: JsonObject, user_id: str | None
    ) -> JsonObject:
        user_id = self._require_user(user_id)
        record = self.lobby.session(session_id_or_invite)

        def claim() -> tuple[int, str]:
            seats = self.lobby.seats(record.session_id)
            preferred = optional_int(body.get("preferredPlayerID"))
            available = [
                seat.player_id
                for seat in seats
                if seat.controller == "human" and not seat.occupied
            ]
            if preferred is not None:
                if preferred not in available:
                    raise ServerError(HTTPStatus.CONFLICT, "seat unavailable")
                player_id = preferred
            elif available:
                player_id = available[0]
            else:
                raise ServerError(HTTPStatus.CONFLICT, "session is full")
            token = secrets.token_urlsafe(24)
            try:
                self.lobby.occupy_seat(
                    record.session_id,
                    player_id,
                    user_id=user_id,
                    token_hash=_token_hash(token),
                    now=time.time(),
                )
            except SeatUnavailable as error:
                raise ServerError(HTTPStatus.CONFLICT, str(error)) from error
            return player_id, token

        player_id, token = self.runtime.serialize(record.session_id, claim)
        record = self._sync_lobby(record.session_id)
        return {
            "sessionID": record.session_id,
            "seed": record.seed,
            "inviteCode": record.invite_code,
            "playerID": player_id,
            "seatToken": token,
            "update": self._update(record.session_id, player_id),
        }

    def _sync_active(self, user_id: str | None) -> JsonObject:
        user_id = self._require_user(user_id)
        active = self.lobby.active_for_user(user_id)
        if active is None:
            raise ServerError(HTTPStatus.NOT_FOUND, "no active game")
        record, seat = active
        token = secrets.token_urlsafe(24)
        self.lobby.replace_seat_token(
            record.session_id,
            seat.player_id,
            token_hash=_token_hash(token),
            now=time.time(),
        )
        return {
            "sessionID": record.session_id,
            "seed": record.seed,
            "inviteCode": record.invite_code,
            "playerID": seat.player_id,
            "seatToken": token,
            "update": self._update(record.session_id, seat.player_id),
        }

    def _matchmake(self, body: JsonObject, user_id: str | None) -> JsonObject:
        user_id = self._require_user(user_id)
        self._ensure_no_active(user_id)
        ranked_only = optional_bool(body.get("rankedOnly"), False)
        for record in self.lobby.list_open(time.time()):
            if ranked_only and not record.ranked:
                continue
            if any(
                seat.user_id == user_id for seat in self.lobby.seats(record.session_id)
            ):
                continue
            try:
                return self._join(record.session_id, {}, user_id)
            except ServerError as error:
                if error.status != HTTPStatus.CONFLICT:
                    raise
        if not ranked_only:
            raise ServerError(HTTPStatus.NOT_FOUND, "no open games")
        created = self._create(
            {
                "controllers": ["human"] * 4,
                "browserJoinable": True,
            },
            user_id,
        )
        session_id = str(created["sessionID"])
        record = self.lobby.session(session_id)
        # Ranked is a lobby/read-model attribute; the game rules remain identical.
        self.lobby.set_ranked(record.session_id, True, now=time.time())
        created["update"] = self._update(record.session_id, int(created["playerID"]))
        return created

    def _invite(
        self, session_id: str, body: JsonObject, user_id: str | None
    ) -> JsonObject:
        user_id = self._require_user(user_id)
        record = self.lobby.session(session_id)
        if record.created_by_user_id and record.created_by_user_id != user_id:
            raise ServerError(HTTPStatus.FORBIDDEN, "only the host can invite")
        values = body.get("userIDs", body.get("invitedUserIDs", []))
        invited = (
            {str(value) for value in values} if isinstance(values, list) else set()
        )
        invited.discard(user_id)
        if not invited:
            raise ServerError(HTTPStatus.BAD_REQUEST, "missing userIDs")
        self.runtime.serialize(
            record.session_id,
            lambda: self.lobby.invite(record.session_id, invited, now=time.time()),
        )
        return {"sessionID": record.session_id, "invitedUserIDs": sorted(invited)}

    def _game_operation(
        self,
        operation: str,
        params: dict[str, str],
        query: dict[str, list[str]],
        request: Request,
        user_id: str | None,
    ) -> object:
        record = self.lobby.session(params["sessionID"])
        body = request.body
        viewer = optional_int(
            body.get("playerID")
            if operation in {"sessions.actions.submit", "sessions.reactions.submit"}
            else (query.get("viewerID") or [params.get("playerID")])[0]
        )
        self._authenticate(record.session_id, viewer, request, user_id)
        if operation == "sessions.state":
            return self._update(record.session_id, viewer)
        if operation == "sessions.actions.legal":
            update = self._update(record.session_id, viewer)
            return update["legalActions"]
        if operation == "sessions.actions.since":
            after = int((query.get("afterRevision") or ["-1"])[0])
            current = self._update(record.session_id, viewer)
            after_reaction = optional_int(
                (query.get("afterReactionRevision") or [None])[0]
            )
            return self.runtime.updates_since(
                record.session_id,
                after_revision=after,
                viewer_id=viewer,
                resync_update=lambda: current,
                after_reaction_revision=after_reaction,
                durable_reactions=self.lobby.reactions(record.session_id),
            )
        if operation == "sessions.actions.submit":
            action = body.get("action")
            if not isinstance(action, dict):
                raise ServerError(HTTPStatus.BAD_REQUEST, "invalid action")
            expected = optional_int(body.get("actionLogCount"))
            if expected is None:
                raise ServerError(HTTPStatus.BAD_REQUEST, "missing actionLogCount")

            def authorize_action() -> None:
                current = self.lobby.session(record.session_id)
                if current.status != "active":
                    raise ServerError(HTTPStatus.CONFLICT, "game has not started")
                if optional_int(action.get("playerID")) != viewer:
                    raise ServerError(HTTPStatus.CONFLICT, "wrong player")
                self._authenticate(record.session_id, viewer, request, user_id)

            self.runtime.submit_action(
                record.session_id,
                expected_revision=expected,
                action=action,
                viewer_id=viewer,
                authorize=authorize_action,
            )
            return self._update(record.session_id, viewer)
        reaction_id = str(body.get("reactionID") or "")
        if record.status != "active":
            raise ServerError(HTTPStatus.CONFLICT, "game has not started")
        if reaction_id not in REACTION_IDS:
            raise ServerError(HTTPStatus.BAD_REQUEST, "invalid reaction")
        state = self.runtime.state(record.session_id, viewer).state
        self.runtime.record_reaction(
            record.session_id,
            lambda: self.lobby.append_reaction(
                record.session_id,
                player_id=int(viewer),
                reaction_id=reaction_id,
                year=int(state["year"]),
                phase=int(state["phase"]),
                now=time.time(),
            ),
        )
        return self._update(record.session_id, viewer)

    def _leave(
        self,
        session_id: str,
        player_id: int,
        request: Request,
        user_id: str | None,
    ) -> JsonObject:
        record = self.lobby.session(session_id)

        def leave() -> None:
            self._authenticate(record.session_id, player_id, request, user_id)
            self.lobby.release_seat(record.session_id, player_id, now=time.time())

        self.runtime.serialize(record.session_id, leave)
        return {"sessionID": record.session_id, "left": True, "playerID": player_id}

    def _kick(
        self,
        session_id: str,
        target_player_id: int,
        request: Request,
        user_id: str | None,
    ) -> JsonObject:
        record = self.lobby.session(session_id)
        host_player_id = optional_int(request.body.get("hostPlayerID"))
        if host_player_id is None:
            raise ServerError(HTTPStatus.BAD_REQUEST, "missing hostPlayerID")

        def kick() -> None:
            self._authenticate(record.session_id, host_player_id, request, user_id)
            seats = self.lobby.seats(record.session_id)
            host = next(value for value in seats if value.player_id == host_player_id)
            if record.created_by_user_id and host.user_id != record.created_by_user_id:
                raise ServerError(HTTPStatus.FORBIDDEN, "only the host can kick")
            if target_player_id == host_player_id:
                raise ServerError(HTTPStatus.CONFLICT, "cannot kick yourself")
            if record.status == "active":
                raise ServerError(
                    HTTPStatus.CONFLICT, "cannot kick after the game starts"
                )
            try:
                self.lobby.release_seat(
                    record.session_id, target_player_id, now=time.time()
                )
            except SeatUnavailable as error:
                raise ServerError(HTTPStatus.CONFLICT, "seat unavailable") from error

        self.runtime.serialize(record.session_id, kick)
        return {
            "sessionID": record.session_id,
            "inviteCode": record.invite_code,
            "playerID": host_player_id,
            "update": self._update(record.session_id, host_player_id),
        }

    def _update(self, session_id: str, viewer_id: int | None) -> JsonObject:
        record = self._sync_lobby(session_id)
        self._ensure_projector(record.session_id)
        if record.status == "active":
            self.runtime.advance_automatic(record.session_id)
        runtime_update = self.runtime.state(record.session_id, viewer_id)
        return self._build_update(
            record.session_id,
            viewer_id,
            runtime_update.state,
            runtime_update.revision,
        )

    def _ensure_projector(self, session_id: str) -> None:
        def project(engine: object) -> dict[int | None, JsonObject]:
            revision = self.runtime.store.game(session_id).revision
            return {
                viewer: self._build_update(
                    session_id,
                    viewer,
                    engine.view(viewer),  # type: ignore[attr-defined]
                    revision,
                )
                for viewer in (None, 0, 1, 2, 3)
            }

        self.runtime.register_projector(session_id, project)

    def _build_update(
        self,
        session_id: str,
        viewer_id: int | None,
        state: Mapping[str, object],
        revision: int,
    ) -> JsonObject:
        record = self.lobby.session(session_id)
        snapshot = dict(state)
        legal_actions = snapshot.pop("legalActions", [])
        actions = [event.payload for event in self.runtime.events(record.session_id)]
        seats = self.lobby.seats(record.session_id)
        waiting = snapshot.get("waitingPlayer")
        return {
            "sessionID": record.session_id,
            "seed": record.seed,
            "inviteCode": record.invite_code,
            "viewerID": viewer_id,
            "actionLogCount": revision,
            "started": record.status == "active",
            "lobbyCountdownEndsAt": record.lobby_countdown_ends_at,
            "gameLogActions": actions,
            "reactions": self.lobby.reactions(record.session_id),
            "isViewerTurn": record.status == "active" and waiting == viewer_id,
            "legalActions": [
                action
                for action in legal_actions
                if viewer_id is not None and action.get("playerID") == viewer_id
            ],
            "variants": record.variants,
            "controllers": record.controllers,
            "ranked": record.ranked,
            "browserJoinable": record.browser_joinable,
            "playerProfiles": [],
            "seatPresence": _seat_presence(seats),
            "turnPlayerID": int(waiting)
            if isinstance(waiting, int) and waiting >= 0
            else None,
            "turnDeadlineAt": None,
            "snapshot": snapshot,
        }

    def _listing(self, record: object) -> JsonObject:
        record = self._sync_lobby(record.session_id)
        seats = self.lobby.seats(record.session_id)
        action_count = self.runtime.store.game(record.session_id).revision
        return listing_json(
            session_id=record.session_id,
            invite_code=record.invite_code,
            open_seats=[
                seat.player_id
                for seat in seats
                if seat.controller == "human" and not seat.occupied
            ],
            occupied_seats=[seat.player_id for seat in seats if seat.occupied],
            controllers=record.controllers,
            ranked=record.ranked,
            browser_joinable=record.browser_joinable,
            player_profiles=[],
            seat_presence=_seat_presence(seats),
            turn_player_id=None,
            turn_deadline_at=None,
            action_log_count=action_count,
            started=record.status == "active",
            lobby_countdown_ends_at=record.lobby_countdown_ends_at,
            created_at=record.created_at,
            expires_at=record.expires_at,
        )

    def _sync_lobby(self, session_id: str):
        return self.runtime.serialize(
            session_id, lambda: self._sync_lobby_unserialized(session_id)
        )

    def _sync_lobby_unserialized(self, session_id: str):
        record = self.lobby.session(session_id)
        if record.status != "open":
            return record
        seats = self.lobby.seats(record.session_id)
        ready = all(seat.controller != "human" or seat.occupied for seat in seats)
        now = time.time()
        if not ready and record.lobby_countdown_ends_at is not None:
            self.lobby.set_status(record.session_id, "open", now=now)
        elif ready and record.lobby_countdown_ends_at is None:
            countdown = now + self.lobby_countdown_seconds
            self.lobby.set_status(
                record.session_id,
                "active" if self.lobby_countdown_seconds == 0 else "open",
                now=now,
                countdown_ends_at=countdown,
            )
        elif ready and record.lobby_countdown_ends_at <= now:
            self.lobby.set_status(record.session_id, "active", now=now)
        return self.lobby.session(record.session_id)

    def _authenticate(
        self,
        session_id: str,
        player_id: int | None,
        request: Request,
        user_id: str | None,
    ) -> None:
        if player_id is None:
            raise ServerError(HTTPStatus.UNAUTHORIZED, "missing player")
        seats = self.lobby.seats(session_id)
        seat = next((value for value in seats if value.player_id == player_id), None)
        if seat is None or not seat.occupied:
            raise ServerError(HTTPStatus.CONFLICT, "seat not joined")
        token = (
            request.headers.get("X-Kolkhoz-Seat-Token")
            or request.headers.get("x-kolkhoz-seat-token")
            or str(request.body.get("seatToken") or "")
        )
        if (
            not token
            or seat.token_hash is None
            or not secrets.compare_digest(seat.token_hash, _token_hash(token))
        ):
            raise ServerError(HTTPStatus.UNAUTHORIZED, "invalid seat token")
        if self.auth is not None and user_id is None:
            raise ServerError(HTTPStatus.UNAUTHORIZED, "missing auth token")
        if seat.user_id is not None and user_id != seat.user_id:
            raise ServerError(HTTPStatus.UNAUTHORIZED, "invalid auth token")

    def _social(
        self,
        operation: str,
        params: dict[str, str],
        body: JsonObject,
        user_id: str | None,
    ) -> object:
        if self.social is None:
            raise ServerError(
                HTTPStatus.SERVICE_UNAVAILABLE, "profiles are not configured"
            )
        if operation == "profiles.leaderboard":
            return self.social.leaderboard()
        if operation == "profiles.get_public":
            return self.social.public_profile(params["userID"])
        user_id = self._require_user(user_id)
        if operation == "comrades.list":
            return self.social.comrades(user_id=user_id)
        if operation == "comrades.request":
            return self.social.send_request(body, user_id=user_id)
        if operation == "comrades.respond":
            return self.social.respond(body, user_id=user_id)
        return self.social.remove(body, user_id=user_id)

    def _user_id(self, headers: Mapping[str, str]) -> str | None:
        if self.auth is None:
            return None
        return self.auth.user_id(
            headers.get("Authorization") or headers.get("authorization")
        )

    def _require_user(self, user_id: str | None) -> str:
        if self.auth is not None and user_id is None:
            raise ServerError(HTTPStatus.UNAUTHORIZED, "missing auth token")
        return user_id or "anonymous"

    def _ensure_no_active(self, user_id: str) -> None:
        if self.lobby.active_for_user(user_id) is not None:
            raise ServerError(HTTPStatus.CONFLICT, "user already has an active game")


def _route_params(template: str, path: str) -> dict[str, str]:
    names = re.findall(r"\{([^}]+)\}", template)
    expression = re.sub(r"\{[^}]+\}", r"([^/]+)", template)
    match = re.fullmatch(expression + "/?", path)
    return dict(zip(names, match.groups(), strict=True)) if match else {}


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _seat_presence(seats: list[SeatRecord]) -> list[JsonObject]:
    return [
        {
            "playerID": seat.player_id,
            "connected": seat.occupied and not seat.abandoned,
            "autopilot": seat.autopilot,
            "timeouts": seat.timeouts,
            "abandoned": seat.abandoned,
        }
        for seat in seats
    ]
