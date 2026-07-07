from __future__ import annotations

import ctypes
import hashlib
import json
import os
import secrets
import socket
import ssl
import threading
import time
import uuid
from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib import request as urlrequest
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlparse

from .c_engine import (
    CEngine,
    KCAction,
    KCCard,
    KCControllers,
    KCPolicyModelBuffer,
    KCVariants,
    REPO_ROOT,
)
from .model import PolicyArtifact
from .online_store import OnlineSessionStore

try:
    import certifi
except ImportError:  # pragma: no cover - depends on the local Python install
    certifi = None


PLAYER_COUNT = 4
SUIT_COUNT = 4
MAX_YEARS = 5
MAX_CARDS = 80
MAX_STACKS = 16

PHASE_GAME_OVER = 5
DEFAULT_SESSION_TTL_SECONDS = 6 * 60 * 60
PERSISTED_TOUCH_INTERVAL_SECONDS = 60
DEFAULT_TURN_SECONDS = 90
PRESENCE_GRACE_SECONDS = 20
TIMEOUTS_BEFORE_AUTOPILOT = 2
DEFAULT_BACKGROUND_TICK_SECONDS = 1.0
DEFAULT_ONLINE_POLICY_PATH = REPO_ROOT / "clients/flutter_app/assets/policies/hard_policy.json"
DEFAULT_ONLINE_POLICY_PATHS = {
    "mediumAI": REPO_ROOT / "clients/flutter_app/assets/policies/medium_policy.json",
    "neuralAI": DEFAULT_ONLINE_POLICY_PATH,
}
CONTROLLER_HUMAN = 0
CONTROLLER_HEURISTIC_AI = 1
CONTROLLER_POLICY_AI = 2

CONTROLLER_CODES = {
    "human": CONTROLLER_HUMAN,
    "heuristicAI": CONTROLLER_HEURISTIC_AI,
    "mediumAI": CONTROLLER_POLICY_AI,
    "neuralAI": CONTROLLER_POLICY_AI,
}
CONTROLLER_NAMES = {
    CONTROLLER_HUMAN: "human",
    CONTROLLER_HEURISTIC_AI: "heuristicAI",
    CONTROLLER_POLICY_AI: "neuralAI",
}


class OnlineServerError(Exception):
    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


class SupabaseAuthVerifier:
    def __init__(self, *, project_url: str, publishable_key: str) -> None:
        self.project_url = project_url.rstrip("/")
        self.publishable_key = publishable_key
        self.ssl_context = self._create_ssl_context()

    @classmethod
    def from_environment(cls) -> "SupabaseAuthVerifier | None":
        project_url = os.environ.get("KOLKHOZ_SUPABASE_URL")
        publishable_key = os.environ.get("KOLKHOZ_SUPABASE_PUBLISHABLE_KEY")
        if not project_url or not publishable_key:
            return None
        return cls(project_url=project_url, publishable_key=publishable_key)

    def user_id_from_authorization(self, authorization: str | None) -> str | None:
        if authorization is None or not authorization.startswith("Bearer "):
            return None
        token = authorization.removeprefix("Bearer ").strip()
        if not token:
            return None
        request = urlrequest.Request(
            f"{self.project_url}/auth/v1/user",
            headers={
                "Accept": "application/json",
                "Authorization": f"Bearer {token}",
                "apikey": self.publishable_key,
            },
        )
        try:
            with urlrequest.urlopen(
                request,
                timeout=5,
                context=self.ssl_context,
            ) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except HTTPError as error:
            if error.code in (HTTPStatus.UNAUTHORIZED, HTTPStatus.FORBIDDEN):
                raise OnlineServerError(HTTPStatus.UNAUTHORIZED, "invalid auth token")
            raise OnlineServerError(
                HTTPStatus.BAD_GATEWAY,
                f"Supabase auth failed with status {error.code}",
            ) from error
        except (OSError, URLError, json.JSONDecodeError) as error:
            raise OnlineServerError(
                HTTPStatus.BAD_GATEWAY,
                "Supabase auth verification failed",
            ) from error
        user_id = payload.get("id")
        if not isinstance(user_id, str) or not user_id:
            raise OnlineServerError(HTTPStatus.UNAUTHORIZED, "invalid auth token")
        return user_id

    @staticmethod
    def _create_ssl_context() -> ssl.SSLContext | None:
        if certifi is None:
            return None
        return ssl.create_default_context(cafile=certifi.where())


class KCCardList(ctypes.Structure):
    _fields_ = [
        ("cards", KCCard * MAX_CARDS),
        ("count", ctypes.c_int32),
    ]


class KCPlotStack(ctypes.Structure):
    _fields_ = [
        ("revealed", KCCard * MAX_CARDS),
        ("revealed_count", ctypes.c_int32),
        ("hidden", KCCard * MAX_CARDS),
        ("hidden_count", ctypes.c_int32),
    ]


class KCPlayer(ctypes.Structure):
    _fields_ = [
        ("id", ctypes.c_int32),
        ("is_human", ctypes.c_bool),
        ("hand", KCCardList),
        ("plot_revealed", KCCardList),
        ("plot_hidden", KCCardList),
        ("plot_medals", ctypes.c_int32),
        ("stacks", KCPlotStack * MAX_STACKS),
        ("stack_count", ctypes.c_int32),
        ("brigade_leader", ctypes.c_bool),
        ("has_won_trick_this_year", ctypes.c_bool),
        ("medals", ctypes.c_int32),
    ]


class KCTrickPlay(ctypes.Structure):
    _fields_ = [
        ("player_id", ctypes.c_int32),
        ("card", KCCard),
    ]


class KCRequisitionEvent(ctypes.Structure):
    _fields_ = [
        ("player_id", ctypes.c_int32),
        ("suit", ctypes.c_int32),
        ("card", KCCard),
        ("message_kind", ctypes.c_int32),
    ]


class KCEngineSnapshot(ctypes.Structure):
    _fields_ = [
        ("rng_state", ctypes.c_uint64),
        ("variants", KCVariants),
        ("players", KCPlayer * PLAYER_COUNT),
        ("lead", ctypes.c_int32),
        ("year", ctypes.c_int32),
        ("trump", ctypes.c_int32),
        ("controllers", KCControllers),
        ("job_piles", KCCardList * SUIT_COUNT),
        ("revealed_jobs", KCCard * SUIT_COUNT),
        ("has_revealed_job", ctypes.c_bool * SUIT_COUNT),
        ("claimed_jobs", ctypes.c_bool * SUIT_COUNT),
        ("work_hours", ctypes.c_int32 * SUIT_COUNT),
        ("job_buckets", KCCardList * SUIT_COUNT),
        ("job_bucket_tricks", (ctypes.c_int32 * MAX_CARDS) * SUIT_COUNT),
        ("current_trick", KCTrickPlay * PLAYER_COUNT),
        ("current_trick_count", ctypes.c_int32),
        ("last_trick", KCTrickPlay * PLAYER_COUNT),
        ("last_trick_count", ctypes.c_int32),
        ("last_winner", ctypes.c_int32),
        ("trick_count", ctypes.c_int32),
        ("exiled", KCCardList * (MAX_YEARS + 1)),
        ("is_famine", ctypes.c_bool),
        ("phase", ctypes.c_int32),
        ("current_player", ctypes.c_int32),
        ("trump_selector", ctypes.c_int32),
        ("pending_assignment_targets", ctypes.c_int32 * PLAYER_COUNT),
        ("requisition_events", KCRequisitionEvent * MAX_CARDS),
        ("requisition_event_count", ctypes.c_int32),
        ("game_scores", ctypes.c_int32 * PLAYER_COUNT),
        ("winner_id", ctypes.c_int32),
        ("accumulated_job_cards", KCCardList * SUIT_COUNT),
        ("drunkard_replacements", KCCardList),
        ("swap_confirmed", ctypes.c_bool * PLAYER_COUNT),
        ("swap_count", ctypes.c_bool * PLAYER_COUNT),
        ("has_last_swap", ctypes.c_bool),
        ("last_swap_player_id", ctypes.c_int32),
        ("last_swap_plot_zone", ctypes.c_int32),
        ("last_swap_plot_index", ctypes.c_int32),
        ("last_swap_hand_index", ctypes.c_int32),
        ("last_swap_new_plot_card", KCCard),
    ]


def serve_online(
    *,
    host: str = "0.0.0.0",
    port: int = 8787,
    engine: CEngine | None = None,
    store: OnlineSessionStore | None = None,
    auth_verifier: SupabaseAuthVerifier | None = None,
) -> None:
    service = KolkhozOnlineSessionService(
        engine or CEngine(),
        store=store,
        auth_verifier=auth_verifier,
        background_tick_seconds=DEFAULT_BACKGROUND_TICK_SECONDS,
    )
    server = KolkhozOnlineHTTPServer((host, port), service)
    print(f"Kolkhoz online server: http://{host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        service.close()
        server.server_close()


class KolkhozOnlineHTTPServer(ThreadingHTTPServer):
    def __init__(
        self,
        server_address: tuple[str, int],
        service: "KolkhozOnlineSessionService",
    ) -> None:
        self.service = service
        if ":" in server_address[0]:
            self.address_family = socket.AF_INET6
        super().__init__(server_address, KolkhozOnlineRequestHandler)


class KolkhozOnlineRequestHandler(BaseHTTPRequestHandler):
    server: KolkhozOnlineHTTPServer
    protocol_version = "HTTP/1.1"

    def setup(self) -> None:
        super().setup()
        self.connection.settimeout(5)

    def parse_request(self) -> bool:
        print(f"Online request line: {self.raw_requestline!r}", flush=True)
        return super().parse_request()

    def do_OPTIONS(self) -> None:
        self._send_json({}, status=HTTPStatus.NO_CONTENT)

    def do_GET(self) -> None:
        self._handle()

    def do_POST(self) -> None:
        self._handle()

    def log_message(self, format: str, *args: object) -> None:
        print(f"Online server: {format % args}", flush=True)

    def _handle(self) -> None:
        try:
            parsed = urlparse(self.path)
            response = self._route(
                method=self.command,
                path=parsed.path,
                query=parse_qs(parsed.query),
                headers=self.headers,
                body=self._read_json_body(),
            )
            self._send_json(response)
        except OnlineServerError as error:
            self._send_json({"error": error.message}, status=error.status)
        except Exception as error:
            self._send_json({"error": str(error)}, status=HTTPStatus.BAD_REQUEST)

    def _route(
        self,
        *,
        method: str,
        path: str,
        query: dict[str, list[str]],
        headers: object,
        body: dict[str, object],
    ) -> object:
        parts = [part for part in path.split("/") if part]
        service = self.server.service
        if method == "GET" and parts == ["health"]:
            return {"status": "ok"}
        if method == "GET" and parts == ["sessions"]:
            return service.list_sessions()
        if method == "POST" and parts == ["sessions"]:
            return service.create_session(
                body,
                user_id=service.user_id_from_authorization(
                    _authorization_header(headers),
                ),
            )
        if len(parts) >= 2 and parts[0] == "sessions":
            session_id = parts[1]
            if method == "GET" and len(parts) == 2:
                return service.session_listing(session_id)
            if method == "POST" and len(parts) == 3 and parts[2] == "join":
                return service.join_session(
                    session_id,
                    body,
                    user_id=service.user_id_from_authorization(
                        _authorization_header(headers),
                    ),
                )
            if (
                method == "POST"
                and len(parts) == 5
                and parts[2] == "players"
                and parts[4] == "leave"
            ):
                return service.leave_session(
                    session_id,
                    _parse_int(parts[3], "playerID"),
                    _seat_token(headers, query, body),
                    user_id=service.user_id_from_authorization(
                        _authorization_header(headers),
                    ),
                )
            if method == "GET" and len(parts) == 3 and parts[2] == "state":
                return service.update(
                    session_id,
                    _optional_int_query(query, "viewerID"),
                    _seat_token(headers, query, body),
                    user_id=service.user_id_from_authorization(
                        _authorization_header(headers),
                    ),
                )
            if (
                method == "GET"
                and len(parts) == 5
                and parts[2] == "players"
                and parts[4] == "actions"
            ):
                return service.legal_actions(
                    session_id,
                    _parse_int(parts[3], "playerID"),
                    _seat_token(headers, query, body),
                    user_id=service.user_id_from_authorization(
                        _authorization_header(headers),
                    ),
                )
            if method == "POST" and len(parts) == 3 and parts[2] == "actions":
                return service.submit_action(
                    session_id,
                    body,
                    _seat_token(headers, query, body),
                    user_id=service.user_id_from_authorization(
                        _authorization_header(headers),
                    ),
                )
        raise OnlineServerError(HTTPStatus.NOT_FOUND, "route not found")

    def _read_json_body(self) -> dict[str, object]:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        decoded = json.loads(raw.decode("utf-8"))
        if not isinstance(decoded, dict):
            raise OnlineServerError(HTTPStatus.BAD_REQUEST, "expected JSON object")
        return decoded

    def _send_json(self, value: object, *, status: int = HTTPStatus.OK) -> None:
        body = (
            b""
            if status == HTTPStatus.NO_CONTENT
            else json.dumps(value).encode("utf-8")
        )
        self.send_response(int(status))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Content-Type, Accept, Authorization, X-Kolkhoz-Seat-Token",
        )
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)


@dataclass
class HostedSession:
    session_id: str
    engine_pointer: ctypes.c_void_p
    seed: int
    variants: dict[str, object]
    controllers: list[str]
    occupied_seats: set[int]
    seat_tokens: dict[int, str]
    seat_user_ids: dict[int, str]
    created_by_user_id: str | None
    action_log: list[dict[str, object]]
    created_at: float
    last_seen_at: float
    last_persisted_touch_at: float
    seat_last_seen_at: dict[int, float]
    seat_timeouts: dict[int, int]
    autopilot_seats: set[int]
    abandoned_seats: set[int]
    turn_player_id: int | None
    turn_deadline_at: float | None
    stats_recorded: bool = False


class KolkhozOnlineSessionService:
    def __init__(
        self,
        engine: CEngine,
        *,
        session_ttl_seconds: float = DEFAULT_SESSION_TTL_SECONDS,
        policy_path: Path | str | None = DEFAULT_ONLINE_POLICY_PATH,
        policy_paths: dict[str, Path | str | None] | None = None,
        policy_artifact: PolicyArtifact | None = None,
        store: OnlineSessionStore | None = None,
        auth_verifier: SupabaseAuthVerifier | None = None,
        background_tick_seconds: float = 0,
    ) -> None:
        self.engine = engine
        self._sessions: dict[str, HostedSession] = {}
        self.session_ttl_seconds = session_ttl_seconds
        self.policy_path = Path(policy_path) if policy_path is not None else None
        if policy_paths is None:
            self.policy_paths = {
                name: Path(path)
                for name, path in DEFAULT_ONLINE_POLICY_PATHS.items()
                if path is not None
            }
            if self.policy_path is not None:
                self.policy_paths["neuralAI"] = self.policy_path
        else:
            self.policy_paths = {
                name: Path(path)
                for name, path in policy_paths.items()
                if path is not None
            }
        self._policy_artifacts: dict[str, PolicyArtifact] = {}
        self._policy_models: dict[str, KCPolicyModelBuffer] = {}
        if policy_artifact is not None:
            self._policy_artifacts["neuralAI"] = policy_artifact
        self.store = store
        self.auth_verifier = auth_verifier
        self.background_tick_seconds = background_tick_seconds
        self._closed = threading.Event()
        self._background_thread: threading.Thread | None = None
        self._lock = threading.RLock()
        if self.store is not None:
            self.store.abandon_active_sessions(updated_at=time.time())
        if self.background_tick_seconds > 0:
            self._background_thread = threading.Thread(
                target=self._run_background_tick,
                name="kolkhoz-online-tick",
                daemon=True,
            )
            self._background_thread.start()

    def close(self) -> None:
        self._closed.set()
        background_thread = self._background_thread
        if background_thread is not None:
            background_thread.join(timeout=2)
        with self._lock:
            for hosted in self._sessions.values():
                self.engine.free_engine(hosted.engine_pointer)
            self._sessions.clear()
            if self.store is not None:
                self.store.close()

    def _run_background_tick(self) -> None:
        while not self._closed.wait(self.background_tick_seconds):
            try:
                self.tick()
            except Exception as error:
                print(f"Online background tick failed: {error}", flush=True)

    def tick(self) -> None:
        with self._lock:
            self._prune_expired_sessions()
            now = time.time()
            for hosted in list(self._sessions.values()):
                self._resolve_turn_timeouts(hosted, now)

    def create_session(
        self,
        request: dict[str, object],
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        with self._lock:
            self._ensure_not_online_banned(user_id)
            self._prune_expired_sessions()
            variants = _normalize_variants(request.get("variants"))
            controllers = _normalize_controllers(request.get("controllers"))
            seed = _optional_int(request.get("seed")) or int(time.time_ns())
            session_id = str(uuid.uuid4())
            now = time.time()
            pointer = self.engine.new_engine(
                seed,
                variants=_variants_native(variants),
                controllers=_controllers_native(controllers),
            )
            hosted = HostedSession(
                session_id=session_id,
                engine_pointer=pointer,
                seed=seed,
                variants=variants,
                controllers=controllers,
                occupied_seats=set(),
                seat_tokens={},
                seat_user_ids={},
                created_by_user_id=user_id,
                action_log=[],
                created_at=now,
                last_seen_at=now,
                last_persisted_touch_at=now,
                seat_last_seen_at={},
                seat_timeouts={},
                autopilot_seats=set(),
                abandoned_seats=set(),
                turn_player_id=None,
                turn_deadline_at=None,
            )
            player_id = self._first_available_seat(hosted)
            hosted.occupied_seats.add(player_id)
            seat_token = self._issue_seat_token(hosted, player_id)
            hosted.seat_last_seen_at[player_id] = now
            if user_id is not None:
                hosted.seat_user_ids[player_id] = user_id
            self._sessions[session_id] = hosted
            try:
                self._advance_automatic_turns(hosted)
                self._sync_turn_deadline(hosted, now, persist=False)
                self._persist_session_created(hosted)
                self._persist_turn_state(hosted, now)
                self._persist_finished_if_needed(hosted)
            except Exception:
                self._sessions.pop(session_id, None)
                self.engine.free_engine(pointer)
                raise
            print(f"Hosted online session {session_id} for player {player_id}", flush=True)
            return {
                "sessionID": session_id,
                "playerID": player_id,
                "seatToken": seat_token,
                "update": self._update(hosted, player_id),
            }

    def join_session(
        self,
        session_id: str,
        request: dict[str, object],
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        with self._lock:
            self._ensure_not_online_banned(user_id)
            hosted = self._session(session_id)
            preferred = _optional_int(request.get("preferredPlayerID"))
            if preferred is not None:
                if not self._seat_is_joinable(hosted, preferred):
                    raise OnlineServerError(HTTPStatus.CONFLICT, "seat unavailable")
                player_id = preferred
            else:
                player_id = self._first_available_seat(hosted)
            hosted.occupied_seats.add(player_id)
            seat_token = self._issue_seat_token(hosted, player_id)
            if user_id is not None:
                hosted.seat_user_ids[player_id] = user_id
            hosted.last_seen_at = time.time()
            self._mark_seat_seen(hosted, player_id, hosted.last_seen_at)
            self._advance_automatic_turns(hosted)
            self._sync_turn_deadline(hosted, hosted.last_seen_at)
            self._persist_seat_joined(hosted, player_id, seat_token)
            self._persist_finished_if_needed(hosted)
            print(
                f"Player {player_id} joined online session {hosted.session_id}",
                flush=True,
            )
            return {
                "sessionID": hosted.session_id,
                "playerID": player_id,
                "seatToken": seat_token,
                "update": self._update(hosted, player_id),
            }

    def leave_session(
        self,
        session_id: str,
        player_id: int,
        seat_token: str | None,
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        with self._lock:
            hosted = self._session(session_id)
            self._authenticate(hosted, player_id, seat_token, user_id=user_id)
            now = time.time()
            hosted.last_seen_at = now
            hosted.abandoned_seats.add(player_id)
            hosted.autopilot_seats.add(player_id)
            hosted.seat_timeouts[player_id] = max(
                TIMEOUTS_BEFORE_AUTOPILOT,
                hosted.seat_timeouts.get(player_id, 0),
            )
            penalty = self._persist_seat_abandoned(hosted, player_id, now)
            self._resolve_turn_timeouts(hosted, now)
            self._persist_finished_if_needed(hosted)
            return {
                "sessionID": hosted.session_id,
                "playerID": player_id,
                "penalty": penalty or {},
                "update": self._update(hosted, player_id),
            }

    def update(
        self,
        session_id: str,
        viewer_id: int | None,
        seat_token: str | None,
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        with self._lock:
            hosted = self._session(session_id)
            self._authenticate(hosted, viewer_id, seat_token, user_id=user_id)
            now = time.time()
            hosted.last_seen_at = now
            if viewer_id is not None:
                self._mark_seat_seen(hosted, viewer_id, now)
            self._resolve_turn_timeouts(hosted, now)
            self._persist_touch_if_needed(hosted)
            self._persist_finished_if_needed(hosted)
            return self._update(hosted, viewer_id)

    def user_id_from_authorization(self, authorization: str | None) -> str | None:
        if self.auth_verifier is None:
            return None
        return self.auth_verifier.user_id_from_authorization(authorization)

    def list_sessions(self) -> list[dict[str, object]]:
        with self._lock:
            self._prune_expired_sessions()
            now = time.time()
            for hosted in list(self._sessions.values()):
                self._resolve_turn_timeouts(hosted, now)
            return [
                self._listing(hosted)
                for hosted in self._sessions.values()
                if self._open_seats(hosted)
            ]

    def session_listing(self, session_id: str) -> dict[str, object]:
        with self._lock:
            self._prune_expired_sessions()
            hosted = self._session(session_id)
            self._resolve_turn_timeouts(hosted, time.time())
            return self._listing(hosted)

    def legal_actions(
        self,
        session_id: str,
        player_id: int,
        seat_token: str | None,
        *,
        user_id: str | None = None,
    ) -> list[dict[str, object]]:
        with self._lock:
            hosted = self._session(session_id)
            self._authenticate(hosted, player_id, seat_token, user_id=user_id)
            now = time.time()
            hosted.last_seen_at = now
            self._mark_seat_seen(hosted, player_id, now)
            self._resolve_turn_timeouts(hosted, now)
            self._persist_touch_if_needed(hosted)
            self._persist_finished_if_needed(hosted)
            return self._legal_action_json_for_player(hosted, player_id)

    def submit_action(
        self,
        session_id: str,
        request: dict[str, object],
        seat_token: str | None,
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        with self._lock:
            hosted = self._session(session_id)
            player_id = _required_int(request.get("playerID"), "playerID")
            self._authenticate(hosted, player_id, seat_token, user_id=user_id)
            now = time.time()
            hosted.last_seen_at = now
            self._mark_seat_seen(hosted, player_id, now)
            expected_revision = _required_int(
                request.get("actionLogCount"),
                "actionLogCount",
            )
            current_revision = len(hosted.action_log)
            if expected_revision != current_revision:
                raise OnlineServerError(HTTPStatus.CONFLICT, "stale action")
            action = _action_from_json(request.get("action"))
            if action.player_id != player_id:
                raise OnlineServerError(HTTPStatus.CONFLICT, "wrong player")
            if not _action_in(action, self._legal_actions_for_player(hosted, player_id)):
                raise OnlineServerError(HTTPStatus.CONFLICT, "illegal action")
            self.engine.apply_action(hosted.engine_pointer, action)
            hosted.action_log.append(_action_json(action))
            self._advance_automatic_turns(hosted)
            hosted.last_seen_at = time.time()
            self._sync_turn_deadline(hosted, hosted.last_seen_at)
            self._persist_action_appended(hosted, player_id, hosted.action_log[-1])
            self._persist_finished_if_needed(hosted)
            return self._update(hosted, player_id)

    def _session(self, session_id: str) -> HostedSession:
        self._prune_expired_sessions()
        try:
            uuid.UUID(session_id)
        except ValueError as error:
            raise OnlineServerError(HTTPStatus.NOT_FOUND, "session not found") from error
        hosted = self._sessions.get(session_id)
        if hosted is None:
            raise OnlineServerError(HTTPStatus.NOT_FOUND, "session not found")
        return hosted

    def _issue_seat_token(self, hosted: HostedSession, player_id: int) -> str:
        token = secrets.token_urlsafe(24)
        hosted.seat_tokens[player_id] = token
        return token

    def _authenticate(
        self,
        hosted: HostedSession,
        player_id: int | None,
        seat_token: str | None,
        *,
        user_id: str | None = None,
    ) -> None:
        if player_id is None:
            raise OnlineServerError(HTTPStatus.UNAUTHORIZED, "missing player")
        if player_id not in hosted.occupied_seats:
            raise OnlineServerError(HTTPStatus.CONFLICT, "seat not joined")
        expected = hosted.seat_tokens.get(player_id)
        if (
            expected is None
            or not seat_token
            or not secrets.compare_digest(expected, seat_token)
        ):
            raise OnlineServerError(HTTPStatus.UNAUTHORIZED, "invalid seat token")
        expected_user_id = hosted.seat_user_ids.get(player_id)
        if (
            self.auth_verifier is not None
            and expected_user_id is not None
            and user_id != expected_user_id
        ):
            raise OnlineServerError(HTTPStatus.UNAUTHORIZED, "invalid auth token")

    def _ensure_not_online_banned(self, user_id: str | None) -> None:
        if user_id is None or self.store is None:
            return
        penalty = self.store.online_ban_for_user(
            user_id=user_id,
            checked_at=time.time(),
        )
        if penalty is None:
            return
        banned_until = penalty.get("banned_until")
        raise OnlineServerError(
            HTTPStatus.FORBIDDEN,
            f"sent north until {_display_timestamp(banned_until)}",
        )

    def _prune_expired_sessions(self) -> None:
        if self.session_ttl_seconds <= 0:
            return
        now = time.time()
        expired = [
            session_id
            for session_id, hosted in self._sessions.items()
            if now - hosted.last_seen_at > self.session_ttl_seconds
        ]
        for session_id in expired:
            hosted = self._sessions.pop(session_id)
            self.engine.free_engine(hosted.engine_pointer)

    def _first_available_seat(self, hosted: HostedSession) -> int:
        for player_id in self._open_seats(hosted):
            return player_id
        raise OnlineServerError(HTTPStatus.CONFLICT, "seat unavailable")

    def _seat_is_joinable(self, hosted: HostedSession, player_id: int) -> bool:
        return (
            0 <= player_id < PLAYER_COUNT
            and hosted.controllers[player_id] == "human"
            and player_id not in hosted.occupied_seats
        )

    def _open_seats(self, hosted: HostedSession) -> list[int]:
        return [
            player_id
            for player_id in range(PLAYER_COUNT)
            if self._seat_is_joinable(hosted, player_id)
        ]

    def _listing(self, hosted: HostedSession) -> dict[str, object]:
        now = time.time()
        return {
            "sessionID": hosted.session_id,
            "openSeats": self._open_seats(hosted),
            "occupiedSeats": sorted(hosted.occupied_seats),
            "controllers": hosted.controllers,
            "playerProfiles": self._player_profiles(hosted),
            "seatPresence": self._seat_presence_json(hosted, now),
            "turnPlayerID": hosted.turn_player_id,
            "turnDeadlineAt": hosted.turn_deadline_at,
            "actionLogCount": len(hosted.action_log),
            "createdAt": hosted.created_at,
            "expiresAt": hosted.last_seen_at + self.session_ttl_seconds,
        }

    def _expires_at(self, hosted: HostedSession) -> float:
        return hosted.last_seen_at + self.session_ttl_seconds

    def _persist_session_created(self, hosted: HostedSession) -> None:
        if self.store is None:
            return
        try:
            self.store.create_session(
                session_id=hosted.session_id,
                seed=hosted.seed,
                variants=hosted.variants,
                controllers=hosted.controllers,
                occupied_seats=hosted.occupied_seats,
                seat_tokens=hosted.seat_tokens,
                seat_user_ids=hosted.seat_user_ids,
                action_log_count=len(hosted.action_log),
                created_at=hosted.created_at,
                expires_at=self._expires_at(hosted),
                policy_model_sha=self._policy_model_sha(),
                created_by_user_id=hosted.created_by_user_id,
            )
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online session persistence failed: {error}",
            ) from error

    def _persist_seat_joined(
        self,
        hosted: HostedSession,
        player_id: int,
        seat_token: str,
    ) -> None:
        if self.store is None:
            return
        try:
            self.store.join_seat(
                session_id=hosted.session_id,
                player_id=player_id,
                seat_token=seat_token,
                user_id=hosted.seat_user_ids.get(player_id),
                updated_at=hosted.last_seen_at,
                expires_at=self._expires_at(hosted),
            )
            hosted.last_persisted_touch_at = hosted.last_seen_at
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online seat persistence failed: {error}",
            ) from error

    def _persist_action_appended(
        self,
        hosted: HostedSession,
        player_id: int,
        action: dict[str, object],
    ) -> None:
        if self.store is None:
            return
        try:
            revision = len(hosted.action_log)
            self.store.append_action(
                session_id=hosted.session_id,
                revision=revision,
                player_id=player_id,
                action=action,
                updated_at=hosted.last_seen_at,
                expires_at=self._expires_at(hosted),
            )
            hosted.last_persisted_touch_at = hosted.last_seen_at
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online action persistence failed: {error}",
            ) from error

    def _persist_touch_if_needed(self, hosted: HostedSession) -> None:
        if self.store is None:
            return
        if (
            hosted.last_seen_at - hosted.last_persisted_touch_at
            < PERSISTED_TOUCH_INTERVAL_SECONDS
        ):
            return
        try:
            self.store.touch_session(
                session_id=hosted.session_id,
                updated_at=hosted.last_seen_at,
                expires_at=self._expires_at(hosted),
            )
            hosted.last_persisted_touch_at = hosted.last_seen_at
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online session touch persistence failed: {error}",
            ) from error

    def _persist_turn_state(self, hosted: HostedSession, now: float) -> None:
        if self.store is None:
            return
        try:
            self.store.update_turn_state(
                session_id=hosted.session_id,
                turn_player_id=hosted.turn_player_id,
                turn_deadline_at=hosted.turn_deadline_at,
                updated_at=now,
                expires_at=self._expires_at(hosted),
            )
            hosted.last_persisted_touch_at = now
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online turn state persistence failed: {error}",
            ) from error

    def _persist_seat_seen(
        self,
        hosted: HostedSession,
        player_id: int,
        now: float,
    ) -> None:
        if self.store is None:
            return
        try:
            self.store.touch_seat(
                session_id=hosted.session_id,
                player_id=player_id,
                updated_at=now,
                expires_at=self._expires_at(hosted),
            )
            hosted.last_persisted_touch_at = now
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online seat presence persistence failed: {error}",
            ) from error

    def _persist_seat_timeout(
        self,
        hosted: HostedSession,
        player_id: int,
        now: float,
    ) -> None:
        if self.store is None:
            return
        try:
            self.store.record_seat_timeout(
                session_id=hosted.session_id,
                player_id=player_id,
                timeouts=hosted.seat_timeouts.get(player_id, 0),
                autopilot=player_id in hosted.autopilot_seats,
                updated_at=now,
                expires_at=self._expires_at(hosted),
                revision=len(hosted.action_log),
            )
            hosted.last_persisted_touch_at = now
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online timeout persistence failed: {error}",
            ) from error

    def _persist_seat_abandoned(
        self,
        hosted: HostedSession,
        player_id: int,
        now: float,
    ) -> dict[str, object] | None:
        if self.store is None:
            return None
        try:
            penalty = self.store.abandon_seat(
                session_id=hosted.session_id,
                player_id=player_id,
                user_id=hosted.seat_user_ids.get(player_id),
                updated_at=now,
                expires_at=self._expires_at(hosted),
                revision=len(hosted.action_log),
            )
            hosted.last_persisted_touch_at = now
            return penalty
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online abandon persistence failed: {error}",
            ) from error

    def _mark_seat_seen(
        self,
        hosted: HostedSession,
        player_id: int,
        now: float,
    ) -> None:
        hosted.seat_last_seen_at[player_id] = now
        if player_id not in hosted.abandoned_seats:
            hosted.autopilot_seats.discard(player_id)
        if hosted.turn_player_id == player_id and hosted.turn_deadline_at is None:
            hosted.turn_deadline_at = now + DEFAULT_TURN_SECONDS
        self._persist_seat_seen(hosted, player_id, now)

    def _sync_turn_deadline(
        self,
        hosted: HostedSession,
        now: float,
        *,
        persist: bool = True,
    ) -> None:
        player_id = self.engine.waiting_player(hosted.engine_pointer)
        if (
            player_id < 0
            or player_id >= PLAYER_COUNT
            or hosted.controllers[player_id] != "human"
            or player_id in hosted.autopilot_seats
        ):
            next_player_id: int | None = None
            next_deadline: float | None = None
        else:
            next_player_id = player_id
            if hosted.turn_player_id == player_id and hosted.turn_deadline_at is not None:
                next_deadline = hosted.turn_deadline_at
            else:
                next_deadline = now + DEFAULT_TURN_SECONDS
        if (
            hosted.turn_player_id == next_player_id
            and hosted.turn_deadline_at == next_deadline
        ):
            return
        hosted.turn_player_id = next_player_id
        hosted.turn_deadline_at = next_deadline
        if persist:
            self._persist_turn_state(hosted, now)

    def _resolve_turn_timeouts(self, hosted: HostedSession, now: float) -> None:
        for _ in range(200):
            self._advance_automatic_turns(hosted)
            player_id = self.engine.waiting_player(hosted.engine_pointer)
            if player_id < 0 or player_id >= PLAYER_COUNT:
                self._sync_turn_deadline(hosted, now)
                return
            if hosted.controllers[player_id] != "human":
                continue
            if player_id in hosted.autopilot_seats:
                self._apply_autopilot_action(hosted, player_id, now)
                continue
            self._sync_turn_deadline(hosted, now)
            deadline = hosted.turn_deadline_at
            if deadline is None or now < deadline:
                return
            hosted.seat_timeouts[player_id] = hosted.seat_timeouts.get(player_id, 0) + 1
            forced_abandon = (
                hosted.seat_timeouts[player_id] >= TIMEOUTS_BEFORE_AUTOPILOT
                and player_id not in hosted.abandoned_seats
            )
            if forced_abandon:
                hosted.autopilot_seats.add(player_id)
                hosted.abandoned_seats.add(player_id)
            self._apply_autopilot_action(hosted, player_id, now)
            self._persist_seat_timeout(hosted, player_id, now)
            if forced_abandon:
                self._persist_seat_abandoned(hosted, player_id, now)
            self._sync_turn_deadline(hosted, now)
            self._persist_finished_if_needed(hosted)
            if int(_engine_state(hosted.engine_pointer).phase) == PHASE_GAME_OVER:
                return
        raise OnlineServerError(
            HTTPStatus.INTERNAL_SERVER_ERROR,
            "timeout controller loop exceeded guard limit",
        )

    def _apply_autopilot_action(
        self,
        hosted: HostedSession,
        player_id: int,
        now: float,
    ) -> None:
        try:
            action = self.engine.heuristic_action(hosted.engine_pointer)
            if action.player_id != player_id:
                actions = self._legal_actions_for_player(hosted, player_id)
                if not actions:
                    return
                action = actions[0]
            if hasattr(self.engine, "apply_policy_action"):
                self.engine.apply_policy_action(hosted.engine_pointer, action)
            else:
                self.engine.apply_action(hosted.engine_pointer, action)
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online autopilot action failed: {error}",
            ) from error
        hosted.action_log.append(_action_json(action))
        hosted.last_seen_at = now
        self._persist_action_appended(hosted, player_id, hosted.action_log[-1])
        self._advance_automatic_turns(hosted)

    def _persist_finished_if_needed(self, hosted: HostedSession) -> None:
        if hosted.stats_recorded:
            return
        if self.store is None:
            return
        state = _engine_state(hosted.engine_pointer)
        if int(state.phase) != PHASE_GAME_OVER:
            return
        hosted.stats_recorded = True
        winner_id = int(state.winner_id)
        scores = [int(state.game_scores[player_id]) for player_id in range(PLAYER_COUNT)]
        rating_scores = [
            score - 10000 if player_id in hosted.abandoned_seats else score
            for player_id, score in enumerate(scores)
        ]
        ranks = _score_ranks(rating_scores)
        results = [
            {
                "player_id": player_id,
                "user_id": hosted.seat_user_ids.get(player_id),
                "controller": hosted.controllers[player_id],
                "score": scores[player_id],
                "rank": ranks[player_id],
                "won": player_id == winner_id,
            }
            for player_id in range(PLAYER_COUNT)
        ]
        try:
            self.store.finish_session(
                session_id=hosted.session_id,
                results=results,
                updated_at=hosted.last_seen_at,
                expires_at=self._expires_at(hosted),
            )
            hosted.last_persisted_touch_at = hosted.last_seen_at
        except Exception as error:
            hosted.stats_recorded = False
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online result persistence failed: {error}",
            ) from error

    def _policy_model_sha(self) -> str | None:
        available_paths = {
            name: path for name, path in self.policy_paths.items() if path.exists()
        }
        if not available_paths:
            return None
        digest = hashlib.sha256()
        for name, path in sorted(available_paths.items()):
            digest.update(name.encode("utf-8"))
            with path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
        return digest.hexdigest()

    def _policy_model_buffer(self, controller: str) -> KCPolicyModelBuffer:
        if controller in self._policy_models:
            return self._policy_models[controller]
        artifact = self._policy_artifacts.get(controller)
        if artifact is None:
            policy_path = self.policy_paths.get(controller)
            if policy_path is None:
                raise OnlineServerError(
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                    f"online policy {controller!r} is not configured",
                )
            try:
                artifact = PolicyArtifact.load(policy_path)
            except Exception as error:
                raise OnlineServerError(
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                    f"online policy {controller!r} failed to load: {error}",
                ) from error
            self._policy_artifacts[controller] = artifact
        try:
            model = artifact.c_buffer()
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online policy {controller!r} failed to initialize: {error}",
            ) from error
        self._policy_models[controller] = model
        return model

    def _advance_automatic_turns(self, hosted: HostedSession) -> None:
        for _ in range(200):
            player_id = self.engine.waiting_player(hosted.engine_pointer)
            if player_id < 0 or player_id >= PLAYER_COUNT:
                return
            controller = CONTROLLER_CODES[hosted.controllers[player_id]]
            if controller == CONTROLLER_HUMAN:
                return
            if controller == CONTROLLER_HEURISTIC_AI:
                status = self.engine.step_automatic(hosted.engine_pointer)
            elif controller == CONTROLLER_POLICY_AI:
                status = self.engine.step_policy_automatic(
                    hosted.engine_pointer,
                    self._policy_model_buffer(hosted.controllers[player_id]),
                )
            else:
                return
            if status < 0:
                raise OnlineServerError(
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                    f"automatic controller failed with status {status}",
                )
            if status == 0:
                return
        raise OnlineServerError(
            HTTPStatus.INTERNAL_SERVER_ERROR,
            "automatic controller loop exceeded guard limit",
        )

    def _legal_actions_for_player(
        self,
        hosted: HostedSession,
        player_id: int,
    ) -> list[KCAction]:
        return [
            action
            for action in self.engine.legal_actions(hosted.engine_pointer)
            if action.player_id == player_id
        ]

    def _legal_action_json_for_player(
        self,
        hosted: HostedSession,
        player_id: int,
    ) -> list[dict[str, object]]:
        return [
            _action_json(action)
            for action in self._legal_actions_for_player(hosted, player_id)
        ]

    def _update(
        self,
        hosted: HostedSession,
        viewer_id: int | None,
    ) -> dict[str, object]:
        is_viewer_turn = (
            viewer_id is not None
            and self.engine.waiting_player(hosted.engine_pointer) == viewer_id
        )
        return {
            "sessionID": hosted.session_id,
            "viewerID": viewer_id,
            "actionLogCount": len(hosted.action_log),
            "isViewerTurn": is_viewer_turn,
            "legalActions": self._legal_action_json_for_player(hosted, viewer_id)
            if viewer_id is not None
            else [],
            "variants": hosted.variants,
            "controllers": hosted.controllers,
            "playerProfiles": self._player_profiles(hosted),
            "seatPresence": self._seat_presence_json(hosted, time.time()),
            "turnPlayerID": hosted.turn_player_id,
            "turnDeadlineAt": hosted.turn_deadline_at,
            "snapshot": self._snapshot_json(hosted, viewer_id),
        }

    def _seat_presence_json(
        self,
        hosted: HostedSession,
        now: float,
    ) -> list[dict[str, object]]:
        return [
            {
                "playerID": player_id,
                "connected": (
                    player_id in hosted.occupied_seats
                    and now - hosted.seat_last_seen_at.get(player_id, 0.0)
                    <= PRESENCE_GRACE_SECONDS
                ),
                "lastSeenAt": hosted.seat_last_seen_at.get(player_id),
                "timeouts": hosted.seat_timeouts.get(player_id, 0),
                "autopilot": player_id in hosted.autopilot_seats,
                "abandoned": player_id in hosted.abandoned_seats,
            }
            for player_id in range(PLAYER_COUNT)
        ]

    def _player_profiles(self, hosted: HostedSession) -> list[dict[str, object]]:
        user_ids = sorted(set(hosted.seat_user_ids.values()))
        profile_by_user_id: dict[str, dict[str, object]] = {}
        ai_profile_by_controller: dict[str, dict[str, object]] = {}
        if self.store is not None:
            try:
                profile_by_user_id = self.store.profiles_for_user_ids(user_ids)
            except Exception:
                profile_by_user_id = {}
            try:
                ai_profile_by_controller = self.store.profiles_for_ai_controllers(
                    hosted.controllers
                )
            except Exception:
                ai_profile_by_controller = {}
        profiles: list[dict[str, object]] = []
        for player_id, user_id in sorted(hosted.seat_user_ids.items()):
            profile = profile_by_user_id.get(user_id, {})
            display_name = profile.get("display_name")
            avatar_url = profile.get("avatar_url")
            stats = profile.get("stats")
            profiles.append(
                {
                    "playerID": player_id,
                    "userID": user_id,
                    "displayName": display_name
                    if isinstance(display_name, str)
                    else None,
                    "avatarURL": avatar_url if isinstance(avatar_url, str) else None,
                    "stats": stats if isinstance(stats, dict) else {},
                }
            )
        for player_id, controller in enumerate(hosted.controllers):
            if controller == "human" or player_id in hosted.seat_user_ids:
                continue
            profile = ai_profile_by_controller.get(controller, {})
            display_name = profile.get("display_name")
            avatar_url = profile.get("avatar_url")
            stats = profile.get("stats")
            rating = stats.get("rating") if isinstance(stats, dict) else None
            if isinstance(display_name, str) and isinstance(rating, int):
                display_name = f"{display_name} {rating}"
            profiles.append(
                {
                    "playerID": player_id,
                    "userID": None,
                    "displayName": display_name
                    if isinstance(display_name, str)
                    else None,
                    "avatarURL": avatar_url if isinstance(avatar_url, str) else None,
                    "stats": stats if isinstance(stats, dict) else {},
                }
            )
        return profiles

    def _snapshot_json(
        self,
        hosted: HostedSession,
        viewer_id: int | None,
    ) -> dict[str, object]:
        state = _engine_state(hosted.engine_pointer)
        game_over = int(state.phase) == PHASE_GAME_OVER
        return {
            "year": int(state.year),
            "phase": int(state.phase),
            "currentPlayer": int(state.current_player),
            "waitingPlayer": self.engine.waiting_player(hosted.engine_pointer),
            "waitingForExternalAction": self.engine.waiting_for_external_action(
                hosted.engine_pointer
            ),
            "lead": int(state.lead),
            "trumpSelector": int(state.trump_selector),
            "trump": int(state.trump),
            "trickCount": int(state.trick_count),
            "isFamine": bool(state.is_famine),
            "players": [
                _player_json(state.players[index], viewer_id)
                for index in range(PLAYER_COUNT)
            ],
            "jobPiles": _redacted_suit_cards(SUIT_COUNT),
            "revealedJobs": _revealed_jobs_json(state),
            "claimedJobs": [
                suit for suit in range(SUIT_COUNT) if bool(state.claimed_jobs[suit])
            ],
            "workHours": [
                {"suit": suit, "value": int(state.work_hours[suit])}
                for suit in range(SUIT_COUNT)
            ],
            "jobBuckets": _suit_card_lists_json(state.job_buckets, SUIT_COUNT),
            "accumulatedJobCards": _redacted_suit_cards(SUIT_COUNT),
            "currentTrick": _trick_json(state.current_trick, state.current_trick_count),
            "lastTrick": _trick_json(state.last_trick, state.last_trick_count),
            "lastWinner": int(state.last_winner),
            "exiled": _suit_card_lists_json(state.exiled, MAX_YEARS + 1),
            "pendingAssignments": _pending_assignments_json(state),
            "requisitionEvents": _requisition_events_json(state),
            "scores": [
                self._score_json(hosted.engine_pointer, player_id, viewer_id, game_over)
                for player_id in range(PLAYER_COUNT)
            ],
            "winnerID": int(state.winner_id),
            "swapConfirmed": [
                player_id
                for player_id in range(PLAYER_COUNT)
                if bool(state.swap_confirmed[player_id])
            ],
            "swapCount": [
                player_id
                for player_id in range(PLAYER_COUNT)
                if bool(state.swap_count[player_id])
            ],
        }

    def _score_json(
        self,
        pointer: ctypes.c_void_p,
        player_id: int,
        viewer_id: int | None,
        game_over: bool,
    ) -> dict[str, int]:
        visible = int(self.engine.lib.kc_visible_score(pointer, ctypes.c_int32(player_id)))
        final = int(self.engine.lib.kc_final_score(pointer, ctypes.c_int32(player_id)))
        if not game_over and viewer_id != player_id:
            final = visible
        return {
            "playerID": player_id,
            "visibleScore": visible,
            "finalScore": final,
        }


def _engine_state(pointer: ctypes.c_void_p) -> KCEngineSnapshot:
    return ctypes.cast(pointer, ctypes.POINTER(KCEngineSnapshot)).contents


def _score_ranks(scores: list[int]) -> list[int]:
    return [1 + sum(1 for other in scores if other > score) for score in scores]


def _display_timestamp(value: object) -> str:
    if isinstance(value, (int, float)):
        return time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime(float(value)))
    return "the discipline period ends"


def _normalize_variants(value: object) -> dict[str, object]:
    default = {
        "deckType": 52,
        "nomenclature": False,
        "allowSwap": True,
        "northernStyle": False,
        "miceVariant": False,
        "ordenNachalniku": False,
        "medalsCount": False,
        "accumulateJobs": False,
        "heroOfSovietUnion": True,
        "wrecker": True,
    }
    if value is None:
        return default
    if not isinstance(value, dict):
        raise OnlineServerError(HTTPStatus.BAD_REQUEST, "invalid variants")
    result = dict(default)
    for key in result:
        if key in value:
            result[key] = value[key]
    return result


def _variants_native(variants: dict[str, object]) -> KCVariants:
    return KCVariants(
        int(variants["deckType"]),
        bool(variants["nomenclature"]),
        bool(variants["allowSwap"]),
        bool(variants["northernStyle"]),
        bool(variants["miceVariant"]),
        bool(variants["ordenNachalniku"]),
        bool(variants["medalsCount"]),
        bool(variants["accumulateJobs"]),
        bool(variants["heroOfSovietUnion"]),
        bool(variants["wrecker"]),
    )


def _normalize_controllers(value: object) -> list[str]:
    if value is None:
        controllers = ["human", "human", "human", "human"]
    elif isinstance(value, list):
        controllers = [str(item) for item in value[:PLAYER_COUNT]]
    else:
        raise OnlineServerError(HTTPStatus.BAD_REQUEST, "invalid controllers")
    while len(controllers) < PLAYER_COUNT:
        controllers.append("human")
    for index, controller in enumerate(controllers):
        if controller not in CONTROLLER_CODES:
            raise OnlineServerError(
                HTTPStatus.BAD_REQUEST,
                f"unsupported online controller {controller!r}",
            )
    if "human" not in controllers:
        controllers[0] = "human"
    return controllers


def _controllers_native(controllers: list[str]) -> KCControllers:
    native = KCControllers()
    for index, controller in enumerate(controllers):
        native.seats[index] = CONTROLLER_CODES[controller]
    return native


def _player_json(player: KCPlayer, viewer_id: int | None) -> dict[str, object]:
    is_viewer = viewer_id == int(player.id)
    return {
        "id": int(player.id),
        "hand": _card_list_json(player.hand) if is_viewer else [],
        "revealedPlot": _card_list_json(player.plot_revealed),
        "hiddenPlot": _card_list_json(player.plot_hidden) if is_viewer else [],
        "medals": int(player.medals),
        "bankedMedals": int(player.plot_medals),
        "brigadeLeader": bool(player.brigade_leader),
        "wonTrickThisYear": bool(player.has_won_trick_this_year),
        "stacks": [
            _stack_json(player.stacks[index], is_viewer)
            for index in range(int(player.stack_count))
        ],
    }


def _stack_json(stack: KCPlotStack, is_viewer: bool) -> dict[str, object]:
    return {
        "revealed": _cards_json(stack.revealed, stack.revealed_count),
        "hidden": _cards_json(stack.hidden, stack.hidden_count) if is_viewer else [],
    }


def _card_json(card: KCCard) -> dict[str, int]:
    return {"suit": int(card.suit), "value": int(card.value)}


def _card_list_json(cards: KCCardList) -> list[dict[str, int]]:
    return _cards_json(cards.cards, cards.count)


def _cards_json(cards: object, count: int) -> list[dict[str, int]]:
    return [_card_json(cards[index]) for index in range(int(count))]


def _suit_card_lists_json(cards_by_suit: object, count: int) -> list[dict[str, object]]:
    return [
        {"suit": suit, "cards": _card_list_json(cards_by_suit[suit])}
        for suit in range(count)
    ]


def _redacted_suit_cards(count: int) -> list[dict[str, object]]:
    return [{"suit": suit, "cards": []} for suit in range(count)]


def _revealed_jobs_json(state: KCEngineSnapshot) -> list[dict[str, object]]:
    return [
        {
            "suit": suit,
            "cards": [_card_json(state.revealed_jobs[suit])]
            if bool(state.has_revealed_job[suit])
            else [],
        }
        for suit in range(SUIT_COUNT)
    ]


def _trick_json(plays: object, count: int) -> list[dict[str, object]]:
    return [
        {
            "playerID": int(plays[index].player_id),
            "card": _card_json(plays[index].card),
        }
        for index in range(int(count))
    ]


def _pending_assignments_json(state: KCEngineSnapshot) -> list[dict[str, object]]:
    assignments: list[dict[str, object]] = []
    for index in range(int(state.last_trick_count)):
        target_suit = int(state.pending_assignment_targets[index])
        if target_suit >= 0:
            assignments.append(
                {
                    "card": _card_json(state.last_trick[index].card),
                    "targetSuit": target_suit,
                }
            )
    return assignments


def _requisition_events_json(state: KCEngineSnapshot) -> list[dict[str, object]]:
    return [
        {
            "playerID": int(event.player_id),
            "suit": int(event.suit),
            "card": _card_json(event.card),
            "message": _requisition_message(int(event.message_kind)),
        }
        for event in (
            state.requisition_events[index]
            for index in range(int(state.requisition_event_count))
        )
    ]


def _requisition_message(kind: int) -> str:
    return {
        1: "Protected from requisition.",
        2: "Drunkard exiled.",
        3: "Card sent north.",
        4: "No matching card found.",
    }.get(kind, "Requisition resolved.")


def _action_json(action: KCAction) -> dict[str, object]:
    return {
        "kind": int(action.kind),
        "playerID": int(action.player_id),
        "suit": int(action.suit),
        "card": _card_json(action.card),
        "handCard": _card_json(action.hand_card),
        "plotCard": _card_json(action.plot_card),
        "plotZone": int(action.plot_zone),
        "targetSuit": int(action.target_suit),
    }


def _action_from_json(value: object) -> KCAction:
    if not isinstance(value, dict):
        raise OnlineServerError(HTTPStatus.BAD_REQUEST, "invalid action")
    return KCAction(
        _required_int(value.get("kind"), "kind"),
        _required_int(value.get("playerID"), "playerID"),
        _optional_int(value.get("suit"), -1),
        _card_from_json(value.get("card")),
        _card_from_json(value.get("handCard")),
        _card_from_json(value.get("plotCard")),
        _optional_int(value.get("plotZone"), -1),
        _optional_int(value.get("targetSuit"), -1),
    )


def _card_from_json(value: object) -> KCCard:
    if not isinstance(value, dict):
        return KCCard(-1, 0)
    return KCCard(
        _optional_int(value.get("suit"), -1),
        _optional_int(value.get("value"), 0),
    )


def _action_in(action: KCAction, actions: list[KCAction]) -> bool:
    return any(_actions_equal(action, candidate) for candidate in actions)


def _actions_equal(left: KCAction, right: KCAction) -> bool:
    return _action_json(left) == _action_json(right)


def _optional_int(value: object, default: int | None = None) -> int | None:
    if value is None:
        return default
    if isinstance(value, bool):
        raise OnlineServerError(HTTPStatus.BAD_REQUEST, "expected integer")
    try:
        return int(value)
    except (TypeError, ValueError) as error:
        raise OnlineServerError(HTTPStatus.BAD_REQUEST, "expected integer") from error


def _required_int(value: object, field: str) -> int:
    result = _optional_int(value)
    if result is None:
        raise OnlineServerError(HTTPStatus.BAD_REQUEST, f"missing {field}")
    return result


def _parse_int(value: str, field: str) -> int:
    try:
        return int(value)
    except ValueError as error:
        raise OnlineServerError(HTTPStatus.BAD_REQUEST, f"invalid {field}") from error


def _optional_int_query(query: dict[str, list[str]], key: str) -> int | None:
    values = query.get(key)
    if not values:
        return None
    return _parse_int(values[0], key)


def _authorization_header(headers: object) -> str | None:
    header_get = getattr(headers, "get", None)
    if not callable(header_get):
        return None
    value = header_get("Authorization")
    return str(value) if value else None


def _seat_token(
    headers: object,
    query: dict[str, list[str]],
    body: dict[str, object],
) -> str | None:
    header_get = getattr(headers, "get", None)
    if callable(header_get):
        value = header_get("X-Kolkhoz-Seat-Token")
        if value:
            return str(value)
    query_values = query.get("seatToken")
    if query_values:
        return query_values[0]
    body_value = body.get("seatToken")
    if body_value is None:
        return None
    return str(body_value)
