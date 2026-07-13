from __future__ import annotations

import hashlib
import re
import secrets
import time
import uuid
from datetime import datetime, timezone
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
from .lobby import LobbyRepository, SeatRecord, SeatUnavailable
from .matchmaking import Matchmaker, MatchmakingSession, MatchRequest
from .model import JsonObject
from .routes import resolve_route
from .runtime import GameRuntime
from .social import SocialService
from .results import ResultsRepository


REACTION_IDS = frozenset(
    ("comrade", "medal", "protected", "warning", "wheat", "wrecker")
)


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
        lobby: LobbyRepository,
        *,
        auth: AuthVerifier | None = None,
        social: SocialService | None = None,
        results: ResultsRepository | None = None,
        session_ttl_seconds: float = 1800,
        presence_ttl_seconds: float = 60,
        lobby_countdown_seconds: float = 30,
    ) -> None:
        self.runtime = runtime
        self.lobby = lobby
        self.auth = auth
        self.social = social
        self.results = results
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
        if operation == "metrics":
            return Response(HTTPStatus.OK, {"service": self.metrics_state()})
        if operation == "presence.heartbeat":
            now = time.time()
            device_id = _header(request.headers, "X-Kolkhoz-Device-ID")
            current_session_id = str(request.body.get("sessionID") or "") or None
            if user_id is not None:
                self.lobby.mark_presence(user_id, now=now)
                if device_id and current_session_id:
                    if not self.lobby.acquire_device_lease(
                        user_id,
                        device_id,
                        current_session_id,
                        now=now,
                        ttl_seconds=self.presence_ttl_seconds,
                    ):
                        raise ServerError(
                            HTTPStatus.CONFLICT,
                            "active session is in use on another device",
                        )
            status = {"service": self.metrics_state()}
            status["activeSession"] = self._active_session_json(
                user_id, current_session_id
            )
            return Response(HTTPStatus.OK, status)
        if operation == "active_session.sync":
            return Response(
                HTTPStatus.OK,
                self._sync_active(
                    user_id, _header(request.headers, "X-Kolkhoz-Device-ID")
                ),
            )
        if operation.startswith("profiles.") or operation.startswith("comrades."):
            return Response(
                HTTPStatus.OK, self._social(operation, params, request.body, user_id)
            )
        if operation == "results.recent":
            user_id = self._require_user(user_id)
            if self.results is None:
                return Response(HTTPStatus.OK, {"games": []})
            return Response(
                HTTPStatus.OK,
                {"games": self.results.recent_games(user_id=user_id, limit=5)},
            )
        if operation == "results.replay":
            return Response(
                HTTPStatus.OK,
                self._replay(params["sessionID"], self._require_user(user_id)),
            )
        if operation == "results.rematch":
            return Response(
                HTTPStatus.OK,
                self._rematch(
                    params["sessionID"],
                    request.body,
                    self._require_user(user_id),
                    _header(request.headers, "X-Kolkhoz-Device-ID"),
                ),
            )
        if operation == "challenges.daily":
            return Response(
                HTTPStatus.OK, self._daily_challenge(self._require_user(user_id))
            )
        if operation == "challenges.daily.start":
            return Response(
                HTTPStatus.OK,
                self._start_daily_challenge(
                    self._require_user(user_id),
                    _header(request.headers, "X-Kolkhoz-Device-ID"),
                ),
            )
        if operation == "sessions.create":
            return Response(
                HTTPStatus.OK,
                self._create(
                    request.body,
                    user_id,
                    _header(request.headers, "X-Kolkhoz-Device-ID"),
                ),
            )
        if operation == "sessions.list":
            return Response(
                HTTPStatus.OK,
                [
                    self._listing(value, browser_listing=True)
                    for value in self.lobby.list_open(time.time())
                ],
            )
        if operation == "sessions.watchable":
            return Response(
                HTTPStatus.OK,
                [
                    self._listing(value)
                    for value in self.lobby.list_watchable(time.time())
                ],
            )
        if operation == "sessions.get":
            return Response(
                HTTPStatus.OK, self._listing(self.lobby.session(params["sessionID"]))
            )
        if operation == "sessions.spectate":
            record = self.lobby.session(params["sessionID"])
            if (
                record.status != "active"
                or record.ranked
                or not record.browser_joinable
            ):
                raise ServerError(HTTPStatus.FORBIDDEN, "session is not watchable")
            update = self._read_update(record.session_id, None)
            update["spectator"] = True
            update["legalActions"] = []
            return Response(HTTPStatus.OK, update)
        if operation == "sessions.join":
            return Response(
                HTTPStatus.OK,
                self._join(
                    params["sessionID"],
                    request.body,
                    user_id,
                    _header(request.headers, "X-Kolkhoz-Device-ID"),
                ),
            )
        if operation == "sessions.matchmake":
            return Response(
                HTTPStatus.OK,
                self._matchmake(
                    request.body,
                    user_id,
                    _header(request.headers, "X-Kolkhoz-Device-ID"),
                ),
            )
        if operation == "sessions.invites.pending":
            user_id = self._require_user(user_id)
            return Response(
                HTTPStatus.OK,
                [
                    self._invite_listing(value, user_id)
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
            self.lobby.decline_invite(session.session_id, user_id)
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

    def _replay(self, session_id: str, user_id: str) -> JsonObject:
        if self.results is None:
            raise ServerError(HTTPStatus.NOT_FOUND, "replay unavailable")
        results = self.results.session_results(session_id=session_id, user_id=user_id)
        if not results:
            raise ServerError(HTTPStatus.NOT_FOUND, "finished game not found")
        record = self.lobby.session(session_id)
        if record.status != "finished":
            raise ServerError(HTTPStatus.CONFLICT, "game is not finished")
        return {
            "sessionID": record.session_id,
            "seed": record.seed,
            "variants": record.variants,
            "controllers": record.controllers,
            "ranked": record.ranked,
            "results": results,
            "events": [
                {
                    "revision": event.revision,
                    "kind": event.kind,
                    "action": event.payload,
                    "createdAt": event.created_at,
                }
                for event in self.runtime.events(record.session_id)
            ],
        }

    def _rematch(
        self,
        session_id: str,
        body: JsonObject,
        user_id: str,
        device_id: str | None,
    ) -> JsonObject:
        if self.results is None:
            raise ServerError(HTTPStatus.NOT_FOUND, "result unavailable")
        players = self.results.session_results(session_id=session_id, user_id=user_id)
        if not players:
            raise ServerError(HTTPStatus.FORBIDDEN, "not a participant")
        source = self.lobby.session(session_id)
        if source.ranked:
            raise ServerError(HTTPStatus.CONFLICT, "ranked games cannot be rematched")
        if source.status != "finished":
            raise ServerError(HTTPStatus.CONFLICT, "game is not finished")
        series = self._series_status(source.session_id)
        if series is not None and bool(series.get("completed")):
            raise ServerError(HTTPStatus.CONFLICT, "series is complete")
        response = self._create(
            {
                "variants": body.get("variants", source.variants),
                "controllers": source.controllers,
                "browserJoinable": False,
            },
            user_id,
            device_id,
        )
        invitees = [
            str(player["userID"])
            for player in players
            if player.get("userID") and player["userID"] != user_id
        ]
        if invitees:
            self.lobby.invite(
                str(response["sessionID"]), set(invitees), now=time.time()
            )
        response["invitedUserIDs"] = invitees
        response["rematchOf"] = source.session_id
        if series is not None and hasattr(self.results, "continue_series"):
            try:
                continued = self.results.continue_series(
                    source_session_id=source.session_id,
                    session_id=str(response["sessionID"]),
                )
            except ValueError as error:
                raise ServerError(HTTPStatus.CONFLICT, str(error)) from error
            response["series"] = continued
            response["update"] = self._command_update(
                str(response["sessionID"]), int(response["playerID"])
            )
        return response

    def _daily_challenge(self, user_id: str) -> JsonObject:
        if self.results is None:
            raise ServerError(HTTPStatus.NOT_FOUND, "daily challenge unavailable")
        day = datetime.now(timezone.utc).date().isoformat()
        seed = int.from_bytes(
            hashlib.sha256(f"kolkhoz-daily:{day}".encode()).digest()[:8], "big"
        ) & ((1 << 63) - 1)
        status = self.results.daily_challenge(challenge_date=day, user_id=user_id)
        return {
            "date": day,
            "seed": seed,
            "variants": normalize_variants(None),
            **status,
        }

    def _start_daily_challenge(self, user_id: str, device_id: str | None) -> JsonObject:
        challenge = self._daily_challenge(user_id)
        response = self._create(
            {
                "seed": challenge["seed"],
                "variants": challenge["variants"],
                "controllers": ["human", "mediumAI", "mediumAI", "mediumAI"],
                "browserJoinable": False,
            },
            user_id,
            device_id,
        )
        assert self.results is not None
        if not self.results.claim_daily_attempt(
            challenge_date=str(challenge["date"]),
            user_id=user_id,
            session_id=str(response["sessionID"]),
        ):
            raise ServerError(
                HTTPStatus.CONFLICT, "daily challenge session already exists"
            )
        response["challengeDate"] = challenge["date"]
        return response

    def _create(
        self, body: JsonObject, user_id: str | None, device_id: str | None = None
    ) -> JsonObject:
        user_id = self._require_user(user_id)
        self._ensure_no_active(user_id)
        variants = normalize_variants(body.get("variants"))
        controllers = normalize_controllers(body.get("controllers"))
        seed = optional_int(body.get("seed")) or int(time.time_ns())
        best_of = optional_int(body.get("bestOf"), 1)
        if best_of not in (1, 3, 5):
            raise ServerError(HTTPStatus.BAD_REQUEST, "bestOf must be 1, 3, or 5")
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
            self.lobby.complete_lifecycle_intent(record.session_id, "provision")
            record = self._sync_lobby(record.session_id)
            self._register_device_lease(user_id, device_id, record.session_id)
        except Exception:
            self.lobby.delete_session(record.session_id)
            raise
        response = {
            "sessionID": record.session_id,
            "inviteCode": record.invite_code,
            "playerID": player_id,
            "seatToken": seat_token,
            "update": self._command_update(record.session_id, player_id),
        }
        if best_of > 1:
            if self.results is None or not hasattr(self.results, "create_series"):
                raise ServerError(HTTPStatus.SERVICE_UNAVAILABLE, "series unavailable")
            response["series"] = self.results.create_series(
                session_id=record.session_id, best_of=best_of
            )
            response["update"] = self._command_update(record.session_id, player_id)
        return response

    def _join(
        self,
        session_id_or_invite: str,
        body: JsonObject,
        user_id: str | None,
        device_id: str | None = None,
    ) -> JsonObject:
        user_id = self._require_user(user_id)
        record = self.lobby.session(session_id_or_invite)
        try:
            uuid.UUID(session_id_or_invite)
            joined_via_invite = False
        except ValueError:
            joined_via_invite = True
        if not joined_via_invite:
            self._ensure_not_banned(user_id)
            has_invites, invited = self.lobby.invite_access(record.session_id, user_id)
            if not record.browser_joinable and has_invites and not invited:
                raise ServerError(HTTPStatus.FORBIDDEN, "not invited")

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
            self.lobby.consume_invite(record.session_id, user_id)
            return player_id, token

        player_id, token = claim()
        self._register_device_lease(user_id, device_id, record.session_id)
        record = self._sync_lobby(record.session_id)
        return {
            "sessionID": record.session_id,
            "seed": record.seed,
            "inviteCode": record.invite_code,
            "playerID": player_id,
            "seatToken": token,
            "update": self._command_update(record.session_id, player_id),
        }

    def _sync_active(self, user_id: str | None, device_id: str | None) -> JsonObject:
        user_id = self._require_user(user_id)
        if not device_id:
            raise ServerError(HTTPStatus.BAD_REQUEST, "device ID is required")
        active = self.lobby.active_for_user(user_id)
        if active is None:
            raise ServerError(HTTPStatus.NOT_FOUND, "no active game")
        record, seat = active
        now = time.time()
        if not self.lobby.acquire_device_lease(
            user_id,
            device_id,
            record.session_id,
            now=now,
            ttl_seconds=self.presence_ttl_seconds,
        ):
            raise ServerError(
                HTTPStatus.CONFLICT, "active session is in use on another device"
            )
        token = secrets.token_urlsafe(24)
        self.lobby.replace_seat_token(
            record.session_id,
            seat.player_id,
            token_hash=_token_hash(token),
            now=now,
        )
        return {
            "sessionID": record.session_id,
            "seed": record.seed,
            "inviteCode": record.invite_code,
            "playerID": seat.player_id,
            "seatToken": token,
            "update": self._command_update(record.session_id, seat.player_id),
        }

    def _register_device_lease(
        self, user_id: str, device_id: str | None, session_id: str
    ) -> None:
        if not device_id:
            return
        if not self.lobby.acquire_device_lease(
            user_id,
            device_id,
            session_id,
            now=time.time(),
            ttl_seconds=self.presence_ttl_seconds,
        ):
            raise ServerError(
                HTTPStatus.CONFLICT, "active session is in use on another device"
            )

    def _active_session_json(
        self, user_id: str | None, current_session_id: str | None
    ) -> JsonObject | None:
        if user_id is None:
            return None
        active = self.lobby.active_for_user(user_id)
        if active is None:
            return None
        record, seat = active
        return {
            "sessionID": record.session_id,
            "inviteCode": record.invite_code,
            "playerID": seat.player_id,
            "started": record.status == "active",
            "requiresSync": current_session_id != record.session_id,
        }

    def metrics_state(self) -> JsonObject:
        service = self.runtime.metrics_state()
        now = time.time()
        service.update(
            self.lobby.metrics_state(
                now=now, presence_since=now - self.presence_ttl_seconds
            )
        )
        return service

    def finalize_runtime_state(
        self, session_id: str, state: Mapping[str, object]
    ) -> None:
        self._finalize_if_needed(self.lobby.session(session_id), state)

    def advance_automatic_session(self, session_id: str) -> None:
        self._command_update(session_id, None)

    def _matchmake(
        self, body: JsonObject, user_id: str | None, device_id: str | None = None
    ) -> JsonObject:
        user_id = self._require_user(user_id)
        self._ensure_no_active(user_id)
        self._ensure_not_banned(user_id)
        ranked_only = optional_bool(body.get("rankedOnly"), False)
        comrades_only = optional_bool(body.get("comradesOnly"), False)
        comrades = (
            self.social.comrade_user_ids(user_id)
            if comrades_only and self.social is not None
            else set()
        )
        if comrades_only and not comrades:
            raise ServerError(HTTPStatus.NOT_FOUND, "no open games")
        choice = Matchmaker(
            _ApplicationMatchmakingRepository(self.lobby, self.social)
        ).choose(
            MatchRequest(
                user_id,
                ranked_only=ranked_only,
                comrades_only=comrades_only,
                comrade_user_ids=frozenset(comrades),
            ),
            now=time.time(),
        )
        if choice is not None:
            try:
                return self._join(
                    choice.session_id,
                    {"preferredPlayerID": choice.player_id},
                    user_id,
                    device_id,
                )
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
            device_id,
        )
        session_id = str(created["sessionID"])
        record = self.lobby.session(session_id)
        # Ranked is a lobby/read-model attribute; the game rules remain identical.
        self.lobby.set_ranked(record.session_id, True, now=time.time())
        created["update"] = self._command_update(
            record.session_id, int(created["playerID"])
        )
        return created

    def _invite(
        self, session_id: str, body: JsonObject, user_id: str | None
    ) -> JsonObject:
        user_id = self._require_user(user_id)
        record = self.lobby.session(session_id)
        if record.created_by_user_id and record.created_by_user_id != user_id:
            raise ServerError(HTTPStatus.FORBIDDEN, "only the host can invite")
        if record.status != "open":
            raise ServerError(HTTPStatus.CONFLICT, "game has already started")
        values = body.get("userIDs", body.get("invitedUserIDs", []))
        invited = (
            {str(value) for value in values} if isinstance(values, list) else set()
        )
        invited.discard(user_id)
        if not invited:
            raise ServerError(HTTPStatus.BAD_REQUEST, "missing userIDs")
        if self.social is not None and not invited.issubset(
            self.social.comrade_user_ids(user_id)
        ):
            raise ServerError(HTTPStatus.FORBIDDEN, "can only invite comrades")
        seated = {
            seat.user_id
            for seat in self.lobby.seats(record.session_id)
            if seat.user_id is not None
        }
        invited.difference_update(seated)
        self.lobby.invite(record.session_id, invited, now=time.time())
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
            return self._read_update(record.session_id, viewer)
        if operation == "sessions.actions.legal":
            update = self._read_update(record.session_id, viewer)
            return update["legalActions"]
        if operation == "sessions.actions.since":
            after = int((query.get("afterRevision") or ["-1"])[0])
            current = self._read_update(record.session_id, viewer)
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
            return self._command_update(record.session_id, viewer)
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
        return self._read_update(record.session_id, viewer)

    def _leave(
        self,
        session_id: str,
        player_id: int,
        request: Request,
        user_id: str | None,
    ) -> JsonObject:
        record = self.lobby.session(session_id)
        penalty: dict[str, object] = {}
        self._authenticate(record.session_id, player_id, request, user_id)

        def leave() -> None:
            nonlocal penalty, deleted
            self._authenticate(record.session_id, player_id, request, user_id)
            now = time.time()
            if record.status == "active":
                self.lobby.abandon_seat(record.session_id, player_id, now=now)
                if self.results is not None:
                    value = self.results.record_abandonment(
                        session_id=record.session_id,
                        player_id=player_id,
                        user_id=user_id,
                        updated_at=now,
                        revision=self.runtime.store.game(record.session_id).revision,
                    )
                    penalty = value or {}
                return
            deleted = self.lobby.release_seat_and_delete_if_empty(
                record.session_id, player_id, now=now
            )

        deleted = False
        final_update = self._read_update(record.session_id, player_id)
        leave()
        if record.status == "active":
            self.runtime.set_autopilot(record.session_id, player_id)
        if deleted:
            self.runtime.delete_game(record.session_id)
            self.lobby.complete_lifecycle_intent(record.session_id, "delete")
        else:
            final_update = self._command_update(record.session_id, player_id)
        return {
            "sessionID": record.session_id,
            "inviteCode": record.invite_code,
            "playerID": player_id,
            "penalty": penalty,
            "update": final_update,
        }

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
                self.lobby.kick_seat(
                    record.session_id,
                    target_player_id,
                    host_user_id=str(host.user_id),
                    now=time.time(),
                )
            except SeatUnavailable as error:
                raise ServerError(HTTPStatus.CONFLICT, "seat unavailable") from error

        kick()
        return {
            "sessionID": record.session_id,
            "inviteCode": record.invite_code,
            "playerID": host_player_id,
            "update": self._command_update(record.session_id, host_player_id),
        }

    def _read_update(self, session_id: str, viewer_id: int | None) -> JsonObject:
        runtime_update = self.runtime.state(session_id, viewer_id)
        return self._build_update(
            session_id,
            viewer_id,
            runtime_update.state,
            runtime_update.revision,
        )

    def _command_update(self, session_id: str, viewer_id: int | None) -> JsonObject:
        record = self._sync_lobby(session_id)
        if record.status == "active":
            now = time.time()
            runtime_update = self.runtime.advance_and_state(
                record.session_id, viewer_id=viewer_id, now=now
            )
        else:
            runtime_update = self.runtime.state(record.session_id, viewer_id)
        self._finalize_if_needed(record, runtime_update.state)
        current = self.lobby.session(record.session_id)
        seats = self.lobby.seats(record.session_id)
        self._sync_turn_deadline(
            current, seats, runtime_update.state.get("waitingPlayer")
        )
        return self._build_update(
            record.session_id,
            viewer_id,
            runtime_update.state,
            runtime_update.revision,
        )

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
        actions = [
            event.payload
            for event in self.runtime.events(
                record.session_id, after_revision=max(0, revision - 64)
            )
        ]
        seats = self.lobby.seats(record.session_id)
        player_profiles = (
            self.social.player_profiles(seats, record.controllers)
            if self.social is not None
            else []
        )
        waiting = snapshot.get("waitingPlayer")
        turn_player_id, turn_deadline_at = self.lobby.turn_state(session_id)
        update = {
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
            "playerProfiles": player_profiles,
            "seatPresence": _seat_presence(seats),
            "turnPlayerID": turn_player_id,
            "turnDeadlineAt": turn_deadline_at,
            "snapshot": snapshot,
        }
        series = self._series_status(record.session_id)
        if series is not None:
            update["series"] = series
        return update

    def _series_status(self, session_id: str) -> JsonObject | None:
        if self.results is None or not hasattr(self.results, "series_status"):
            return None
        return self.results.series_status(session_id=session_id)

    def _finalize_if_needed(
        self, record: object, snapshot: Mapping[str, object]
    ) -> None:
        if int(snapshot.get("phase", -1)) != 5:
            return
        seats = self.lobby.seats(record.session_id)
        scores = [
            int(value.get("finalScore", 0))
            for value in snapshot.get("scores", [])
            if isinstance(value, Mapping)
        ]
        if len(scores) != 4:
            return
        ranks = _score_ranks(scores)
        winner_id = optional_int(snapshot.get("winnerID"), -1)
        players = snapshot.get("players", [])
        requisitions = snapshot.get("requisitionEvents", [])
        saboteur_exiled = any(
            isinstance(year, Mapping)
            and any(
                isinstance(card, Mapping) and optional_int(card.get("suit")) == 4
                for card in year.get("cards", [])
            )
            for year in snapshot.get("exiled", [])
            if isinstance(year, Mapping)
        )
        results = []
        for player_id in range(4):
            seat = next(
                (value for value in seats if value.player_id == player_id), None
            )
            player = (
                players[player_id]
                if isinstance(players, list) and len(players) > player_id
                else {}
            )
            results.append(
                {
                    "player_id": player_id,
                    "user_id": seat.user_id if seat else None,
                    "controller": record.controllers[player_id],
                    "score": scores[player_id],
                    "rank": ranks[player_id],
                    "won": player_id == winner_id,
                    "margin": scores[player_id]
                    - max(
                        score
                        for index, score in enumerate(scores)
                        if index != player_id
                    ),
                    "medals": int(player.get("medals", 0))
                    + int(player.get("bankedMedals", 0)),
                    "full_five_year_game": int(record.variants.get("maxYears", 5)) >= 5,
                    "saboteur_exiled": saboteur_exiled,
                    "exiled_plot_cards": sum(
                        1
                        for event in requisitions
                        if isinstance(event, Mapping)
                        and optional_int(event.get("playerID")) == player_id
                        and event.get("message") == "Card sent north."
                    ),
                }
            )
        now = time.time()
        if self.results is not None:
            self.results.record_session_results(
                session_id=record.session_id,
                results=results,
                ranked=record.ranked,
                updated_at=now,
                expires_at=record.expires_at,
            )
        self.lobby.finish_session(
            record.session_id, now=now, expires_at=record.expires_at
        )

    def _listing(self, record: object, *, browser_listing: bool = False) -> JsonObject:
        seats = self.lobby.seats(record.session_id)
        player_profiles = (
            self.social.player_profiles(seats, record.controllers)
            if self.social is not None
            else []
        )
        if browser_listing:
            action_count = 0
            turn_player_id, turn_deadline_at = None, None
        else:
            action_count = self.runtime.store.game(record.session_id).revision
            turn_player_id, turn_deadline_at = self.lobby.turn_state(record.session_id)
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
            player_profiles=player_profiles,
            seat_presence=_seat_presence(seats),
            turn_player_id=turn_player_id,
            turn_deadline_at=turn_deadline_at,
            action_log_count=action_count,
            started=record.status == "active",
            lobby_countdown_ends_at=record.lobby_countdown_ends_at,
            created_at=record.created_at,
            expires_at=record.expires_at,
        )

    def _invite_listing(self, record: object, user_id: str) -> JsonObject:
        listing = self._listing(record)
        listing.pop("inviteCode", None)
        profiles = listing.get("playerProfiles")
        host_profile: JsonObject | None = None
        if isinstance(profiles, list):
            for profile in profiles:
                if (
                    isinstance(profile, dict)
                    and profile.get("userID") == record.created_by_user_id
                ):
                    host_profile = profile
                    break
            if host_profile is None and profiles and isinstance(profiles[0], dict):
                host_profile = profiles[0]
        listing["hostProfile"] = host_profile or {}
        listing["invitedUserID"] = user_id
        return listing

    def _sync_lobby(self, session_id: str):
        return self._sync_lobby_unserialized(session_id)

    def population_seat_filled(self, session_id: str) -> None:
        """Start a population lobby once profile bots occupy every seat."""
        self.runtime.invalidate_session(session_id)

        def start_if_ready() -> bool:
            record = self.lobby.session(session_id)
            if record.status != "open":
                return False
            seats = self.lobby.seats(session_id)
            if not seats or any(
                not seat.occupied or seat.controller == "human" for seat in seats
            ):
                return False
            self.lobby.set_status(session_id, "active", now=time.time())
            return True

        started = start_if_ready()
        if started:
            previous_revision = -1
            for _ in range(64):
                update = self._command_update(session_id, None)
                snapshot = update.get("snapshot", {})
                if (
                    isinstance(snapshot, Mapping)
                    and optional_int(snapshot.get("phase"), -1) == 5
                ):
                    return
                revision = optional_int(update.get("actionLogCount"), -1)
                if revision <= previous_revision:
                    return
                previous_revision = revision

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

    def _sync_turn_deadline(
        self, record: object, seats: list[SeatRecord], waiting: object
    ) -> tuple[int | None, float | None]:
        current_player, current_deadline = self.lobby.turn_state(record.session_id)
        waiting_player = (
            waiting if isinstance(waiting, int) and 0 <= waiting < 4 else None
        )
        seat = next(
            (value for value in seats if value.player_id == waiting_player), None
        )
        eligible = bool(
            record.status == "active"
            and seat is not None
            and seat.controller == "human"
            and seat.occupied
            and not seat.autopilot
        )
        desired = waiting_player if eligible else None
        if desired == current_player and (
            desired is None or current_deadline is not None
        ):
            return current_player, current_deadline
        deadline = time.time() + 90 if desired is not None else None
        self.lobby.set_turn_deadline(
            record.session_id,
            desired,
            deadline_at=deadline,
            now=time.time(),
        )
        return desired, deadline

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
        self.lobby.touch_seat(
            session_id,
            player_id,
            now=time.time(),
            session_ttl_seconds=self.session_ttl_seconds,
        )

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
            return self.social.leaderboard(user_id=user_id)
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

    def _ensure_not_banned(self, user_id: str) -> None:
        if self.results is None:
            return
        penalty = self.results.online_ban_for_user(
            user_id=user_id, checked_at=time.time()
        )
        if penalty is not None:
            raise ServerError(
                HTTPStatus.FORBIDDEN, "online play temporarily restricted"
            )


def _route_params(template: str, path: str) -> dict[str, str]:
    names = re.findall(r"\{([^}]+)\}", template)
    expression = re.sub(r"\{[^}]+\}", r"([^/]+)", template)
    match = re.fullmatch(expression + "/?", path)
    return dict(zip(names, match.groups(), strict=True)) if match else {}


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _header(headers: Mapping[str, str], name: str) -> str | None:
    lowered = name.lower()
    return next(
        (value for key, value in headers.items() if key.lower() == lowered), None
    )


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


def _score_ranks(scores: list[int]) -> list[int]:
    return [1 + sum(other > score for other in scores) for score in scores]


class _ApplicationMatchmakingRepository:
    def __init__(self, lobby: object, social: SocialService | None) -> None:
        self.lobby = lobby
        self.social = social

    def open_sessions(self, now: float) -> list[MatchmakingSession]:
        sessions: list[MatchmakingSession] = []
        for record in self.lobby.list_open(now):
            seats = self.lobby.seats(record.session_id)
            sessions.append(
                MatchmakingSession(
                    record.session_id,
                    record.created_at,
                    record.ranked,
                    record.browser_joinable,
                    tuple(
                        seat.player_id
                        for seat in seats
                        if seat.controller == "human" and not seat.occupied
                    ),
                    tuple(
                        seat.user_id
                        for seat in seats
                        if seat.occupied and seat.user_id is not None
                    ),
                )
            )
        return sessions

    def ratings(self, user_ids: set[str]) -> dict[str, int]:
        if self.social is None:
            return {}
        profiles = self.social.repository.profiles_for_user_ids(sorted(user_ids))
        return {
            user_id: int(profile.get("stats", {}).get("rating", 1000))
            for user_id, profile in profiles.items()
            if isinstance(profile.get("stats"), dict)
        }
