from __future__ import annotations

import copy
import ctypes
import hashlib
import json
import os
import queue
import secrets
import socket
import ssl
import sys
import threading
import time
import traceback
import uuid
from contextlib import contextmanager
from dataclasses import dataclass, field
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib import request as urlrequest
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlparse

from .c_engine import (
    CEngine,
    KCAction,
    KCCard,
    KCCardList,
    KCControllers,
    KCEngineSnapshot,
    KCPlayer,
    KCPlotStack,
    KCPolicyModelBuffer,
    KCVariants,
    MAX_YEARS,
    PLAYER_COUNT,
    REPO_ROOT,
    SUIT_COUNT,
)
from .model import PolicyArtifact
from .online_store import (
    SERVER_BOT_PROFILES,
    SERVER_BOT_PROFILES_BY_CONTROLLER,
    SERVER_BOT_PROFILES_BY_ID,
    seat_token_hash,
)

try:
    import certifi
except ImportError:  # pragma: no cover - depends on the local Python install
    certifi = None


WRECKER_SUIT = 4

PHASE_GAME_OVER = 5
DEFAULT_SESSION_TTL_SECONDS = 30 * 60
LOBBY_COUNTDOWN_SECONDS = 30
PERSISTED_TOUCH_INTERVAL_SECONDS = 60
DEFAULT_TURN_SECONDS = 90
PRESENCE_GRACE_SECONDS = 20
ONLINE_PRESENCE_SECONDS = 60
TIMEOUTS_BEFORE_AUTOPILOT = 2
DEFAULT_BACKGROUND_TICK_SECONDS = 1.0
BOT_LOBBY_SEED_INTERVAL_SECONDS = 15 * 60
BOT_OPEN_SEAT_FILL_INTERVAL_SECONDS = 30
BOT_OPEN_SEAT_MIN_AGE_SECONDS = 30
BOT_HUMAN_GAME_ACTION_DELAY_MIN_SECONDS = 1.5
BOT_HUMAN_GAME_ACTION_DELAY_MAX_SECONDS = 8.0
BOT_LOBBY_OPEN_SEAT_ROTATION = (3, 2, 1)
DEFAULT_MATCHMAKING_RATING = 1000
MATCHMAKING_IDEAL_RATING_DELTA = 300
MATCHMAKING_ACCEPTABLE_RATING_DELTA = 600
PROFILE_BOT_TARGET_WAIT_SECONDS = 90
POSTGRES_BIGINT_MAX = (1 << 63) - 1
DEFAULT_ONLINE_POLICY_PATH = (
    REPO_ROOT / "clients/flutter_app/assets/policies/hard_policy.json"
)
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
INVITE_CODE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
INVITE_CODE_LENGTH = 5
METRIC_SAMPLE_LIMIT = 2048
REACTION_IDS = (
    "comrade",
    "medal",
    "protected",
    "warning",
    "wheat",
    "wrecker",
)


class OnlineServerError(Exception):
    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


class OnlineMetricBucket:
    def __init__(self) -> None:
        self.count = 0
        self.total = 0.0
        self.minimum: float | None = None
        self.maximum: float | None = None
        self.samples: list[float] = []

    def record(self, value: float) -> None:
        self.count += 1
        self.total += value
        self.minimum = value if self.minimum is None else min(self.minimum, value)
        self.maximum = value if self.maximum is None else max(self.maximum, value)
        self.samples.append(value)
        if len(self.samples) > METRIC_SAMPLE_LIMIT:
            del self.samples[: len(self.samples) - METRIC_SAMPLE_LIMIT]

    def snapshot(self) -> dict[str, object]:
        samples = sorted(self.samples)
        return {
            "count": self.count,
            "meanMs": (self.total / self.count) * 1000 if self.count else 0.0,
            "minMs": (self.minimum or 0.0) * 1000,
            "maxMs": (self.maximum or 0.0) * 1000,
            "p50Ms": _percentile(samples, 0.50) * 1000,
            "p95Ms": _percentile(samples, 0.95) * 1000,
            "p99Ms": _percentile(samples, 0.99) * 1000,
        }


class OnlineServerMetrics:
    def __init__(self) -> None:
        self.started_at = time.time()
        self._lock = threading.RLock()
        self._routes: dict[str, OnlineMetricBucket] = {}
        self._route_statuses: dict[str, int] = {}
        self._lock_waits: dict[str, OnlineMetricBucket] = {}
        self._store_calls: dict[str, OnlineMetricBucket] = {}
        self._ticks = OnlineMetricBucket()

    def record_route(
        self,
        *,
        method: str,
        route: str,
        status: int,
        elapsed: float,
    ) -> None:
        key = f"{method} {route}"
        with self._lock:
            self._routes.setdefault(key, OnlineMetricBucket()).record(elapsed)
            status_key = f"{key} {status}"
            self._route_statuses[status_key] = (
                self._route_statuses.get(status_key, 0) + 1
            )

    def record_lock_wait(self, kind: str, elapsed: float) -> None:
        with self._lock:
            self._lock_waits.setdefault(kind, OnlineMetricBucket()).record(elapsed)

    def record_store_call(self, name: str, elapsed: float) -> None:
        with self._lock:
            self._store_calls.setdefault(name, OnlineMetricBucket()).record(elapsed)

    def record_background_tick(self, elapsed: float) -> None:
        with self._lock:
            self._ticks.record(elapsed)

    def snapshot(self, service: "KolkhozOnlineSessionService") -> dict[str, object]:
        with self._lock:
            return {
                "startedAt": self.started_at,
                "uptimeSeconds": time.time() - self.started_at,
                "process": {
                    "activeThreads": threading.active_count(),
                    "python": sys.version.split()[0],
                },
                "service": service.metrics_state(),
                "routes": {
                    key: bucket.snapshot()
                    for key, bucket in sorted(self._routes.items())
                },
                "routeStatuses": dict(sorted(self._route_statuses.items())),
                "sessionLockWaits": {
                    key: bucket.snapshot()
                    for key, bucket in sorted(self._lock_waits.items())
                },
                "storeCalls": {
                    key: bucket.snapshot()
                    for key, bucket in sorted(self._store_calls.items())
                },
                "backgroundTick": self._ticks.snapshot(),
            }


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


def serve_online(
    *,
    host: str = "0.0.0.0",
    port: int = 8787,
    engine: CEngine | None = None,
    store: Any | None = None,
    auth_verifier: SupabaseAuthVerifier | None = None,
) -> None:
    service = KolkhozOnlineSessionService(
        engine or CEngine(),
        store=store,
        auth_verifier=auth_verifier,
        background_tick_seconds=DEFAULT_BACKGROUND_TICK_SECONDS,
        population_enabled=True,
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
        started = time.perf_counter()
        parsed = urlparse(self.path)
        status = int(HTTPStatus.INTERNAL_SERVER_ERROR)
        route = _route_label(parsed.path)
        try:
            response = self._route(
                method=self.command,
                path=parsed.path,
                query=parse_qs(parsed.query),
                headers=self.headers,
                body=self._read_json_body(),
            )
            status = int(HTTPStatus.OK)
            self._send_json(response)
        except OnlineServerError as error:
            status = int(error.status)
            if error.status >= HTTPStatus.INTERNAL_SERVER_ERROR:
                print(
                    f"Online server error {error.status}: {error.message}",
                    flush=True,
                )
            self._send_json({"error": error.message}, status=error.status)
        except Exception as error:
            status = int(HTTPStatus.BAD_REQUEST)
            print(f"Online server unexpected error: {error!r}", flush=True)
            traceback.print_exc()
            self._send_json({"error": str(error)}, status=HTTPStatus.BAD_REQUEST)
        finally:
            self.server.service.metrics.record_route(
                method=self.command,
                route=route,
                status=status,
                elapsed=time.perf_counter() - started,
            )

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
            return service.health_snapshot()
        if method == "POST" and parts == ["presence"]:
            authorization = _authorization_header(headers)
            user_id = (
                service.user_id_from_authorization(authorization)
                if authorization is not None
                else None
            )
            service.mark_online_presence(user_id=user_id)
            return service.metrics_snapshot()
        if method == "GET" and parts == ["metrics"]:
            return service.metrics_snapshot()
        authorization = _authorization_header(headers)
        user_id = (
            service.user_id_from_authorization(authorization)
            if authorization is not None
            else None
        )
        if len(parts) >= 1 and parts[0] == "comrades":
            if method == "GET" and len(parts) == 1:
                return service.comrades(user_id=user_id)
            if method == "POST" and len(parts) == 1:
                return service.send_comrade_request(body, user_id=user_id)
            if method == "POST" and len(parts) == 2 and parts[1] == "respond":
                return service.respond_to_comrade_request(body, user_id=user_id)
            if method == "POST" and len(parts) == 2 and parts[1] == "remove":
                return service.remove_comrade(body, user_id=user_id)
        if method == "GET" and parts == ["sessions"]:
            return service.list_sessions(user_id=user_id)
        if method == "POST" and parts == ["sessions"]:
            return service.create_session(body, user_id=user_id)
        if method == "GET" and parts == ["sessions", "invites"]:
            return service.pending_session_invites(user_id=user_id)
        if method == "POST" and parts == ["sessions", "matchmake"]:
            return service.matchmake_session(body, user_id=user_id)
        if len(parts) >= 2 and parts[0] == "sessions":
            session_id = parts[1]
            if method == "GET" and len(parts) == 2:
                return service.session_listing(session_id)
            if method == "POST" and len(parts) == 3 and parts[2] == "invites":
                return service.invite_session_comrades(
                    session_id,
                    body,
                    user_id=user_id,
                )
            if (
                method == "POST"
                and len(parts) == 4
                and parts[2] == "invites"
                and parts[3] == "decline"
            ):
                return service.decline_session_invite(session_id, user_id=user_id)
            if method == "POST" and len(parts) == 3 and parts[2] == "join":
                return service.join_session(
                    session_id,
                    body,
                    user_id=user_id,
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
                    user_id=user_id,
                )
            if (
                method == "POST"
                and len(parts) == 5
                and parts[2] == "players"
                and parts[4] == "kick"
            ):
                return service.kick_session_player(
                    session_id,
                    _parse_int(parts[3], "playerID"),
                    body,
                    _seat_token(headers, query, body),
                    user_id=user_id,
                )
            if method == "GET" and len(parts) == 3 and parts[2] == "state":
                return service.update(
                    session_id,
                    _optional_int_query(query, "viewerID"),
                    _seat_token(headers, query, body),
                    user_id=user_id,
                )
            if method == "GET" and len(parts) == 3 and parts[2] == "actions":
                return service.action_updates(
                    session_id,
                    _optional_int_query(query, "viewerID"),
                    _required_int_query(query, "afterRevision"),
                    _seat_token(headers, query, body),
                    user_id=user_id,
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
                    user_id=user_id,
                )
            if method == "POST" and len(parts) == 3 and parts[2] == "actions":
                return service.submit_action(
                    session_id,
                    body,
                    _seat_token(headers, query, body),
                    user_id=user_id,
                )
            if method == "POST" and len(parts) == 3 and parts[2] == "reactions":
                return service.submit_reaction(
                    session_id,
                    body,
                    _seat_token(headers, query, body),
                    user_id=user_id,
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
    invite_code: str
    engine_pointer: ctypes.c_void_p
    seed: int
    variants: dict[str, object]
    controllers: list[str]
    ranked: bool
    browser_joinable: bool
    population_kind: str | None
    occupied_seats: set[int]
    seat_tokens: dict[int, str]
    seat_token_hashes: dict[int, str]
    seat_user_ids: dict[int, str]
    server_bot_controllers: dict[int, str]
    bot_action_ready_at: dict[int, float]
    created_by_user_id: str | None
    action_log: list[dict[str, object]]
    action_update_cache: list[dict[str, object]]
    created_at: float
    last_seen_at: float
    last_persisted_touch_at: float
    seat_last_seen_at: dict[int, float]
    seat_timeouts: dict[int, int]
    autopilot_seats: set[int]
    abandoned_seats: set[int]
    turn_player_id: int | None
    turn_deadline_at: float | None
    invited_user_ids: set[str] = field(default_factory=set)
    declined_invite_user_ids: set[str] = field(default_factory=set)
    started: bool = False
    lobby_countdown_ends_at: float | None = None
    reaction_log: list[dict[str, object]] = field(default_factory=list)
    stats_recorded: bool = False
    lock: threading.RLock = field(default_factory=threading.RLock, repr=False)


@dataclass(frozen=True)
class PersistenceJob:
    name: str
    func: object
    kwargs: dict[str, object]


class ProfileBotFactory:
    def create_profiles(
        self,
        *,
        count: int,
        now: float,
        exclude_user_ids: set[str],
        target_wait_seconds: float,
        target_rating: int,
    ) -> list[dict[str, object]]:
        return []


class StoreBackedProfileBotFactory(ProfileBotFactory):
    def __init__(self, store: Any) -> None:
        self.store = store

    def create_profiles(
        self,
        *,
        count: int,
        now: float,
        exclude_user_ids: set[str],
        target_wait_seconds: float,
        target_rating: int,
    ) -> list[dict[str, object]]:
        return self.store.create_profile_bot_profiles(
            count=count,
            exclude_user_ids=set(exclude_user_ids),
            target_rating=target_rating,
            updated_at=now,
        )


class OnlinePopulationHandler:
    def __init__(self, service: KolkhozOnlineSessionService) -> None:
        self.service = service
        now = time.time()
        self.next_lobby_seed_at = now
        self.next_open_seat_fill_at = now + BOT_OPEN_SEAT_FILL_INTERVAL_SECONDS
        self.bot_use_counts = {
            str(profile["user_id"]): 0 for profile in SERVER_BOT_PROFILES
        }
        self.lobby_seed_count = 0

    def tick(self, now: float) -> None:
        if now >= self.next_lobby_seed_at:
            self._seed_open_lobbies(now)
            self.next_lobby_seed_at = _next_interval_after(
                self.next_lobby_seed_at,
                now,
                BOT_LOBBY_SEED_INTERVAL_SECONDS,
            )
        if now >= self.next_open_seat_fill_at:
            filled_profiles = self.service.fill_open_seats_with_server_bots(
                now=now,
                profiles=self._choose_bot_profiles(len(SERVER_BOT_PROFILES), now),
            )
            self._mark_used(filled_profiles)
            self.next_open_seat_fill_at = _next_interval_after(
                self.next_open_seat_fill_at,
                now,
                BOT_OPEN_SEAT_FILL_INTERVAL_SECONDS,
            )

    def _seed_open_lobbies(self, now: float) -> None:
        open_seat_choices = self._choose_lobby_open_seats(now)
        self.lobby_seed_count += 1
        for ranked, open_human_seats in zip((True, False), open_seat_choices):
            profiles = self._choose_bot_profiles(
                PLAYER_COUNT - open_human_seats,
                now,
            )
            try:
                session_id = self.service.create_population_session(
                    bot_profiles=profiles,
                    open_human_seats=open_human_seats,
                    ranked=ranked,
                    now=now,
                    population_kind="open_lobby_seed",
                )
            except ValueError:
                continue
            seated_profile_user_ids = {
                str(profile["userID"])
                for profile in self.service.session_listing(session_id)[
                    "playerProfiles"
                ]
                if str(profile.get("userID")) in SERVER_BOT_PROFILES_BY_ID
            }
            self._mark_used(
                [
                    profile
                    for profile in profiles
                    if str(profile["user_id"]) in seated_profile_user_ids
                ]
            )

    def _choose_lobby_open_seats(self, now: float) -> list[int]:
        epoch = int(now // BOT_LOBBY_SEED_INTERVAL_SECONDS)
        options = list(BOT_LOBBY_OPEN_SEAT_ROTATION)
        options.sort(
            key=lambda open_human_seats: hashlib.sha256(
                (f"{epoch}:{self.lobby_seed_count}:{open_human_seats}").encode("utf-8")
            ).hexdigest()
        )
        return options[:2]

    def _choose_bot_profiles(
        self,
        count: int,
        now: float,
        *,
        exclude_user_ids: set[str] | None = None,
    ) -> list[dict[str, object]]:
        excluded = exclude_user_ids or set()
        epoch = int(now // BOT_OPEN_SEAT_FILL_INTERVAL_SECONDS)
        profiles = [
            profile
            for profile in SERVER_BOT_PROFILES
            if str(profile["user_id"]) not in excluded
        ]
        profiles.sort(
            key=lambda profile: (
                self.bot_use_counts.get(str(profile["user_id"]), 0),
                hashlib.sha256(
                    f"{epoch}:{profile['user_id']}".encode("utf-8")
                ).hexdigest(),
            )
        )
        return profiles[:count]

    def _mark_used(self, profiles: list[dict[str, object]]) -> None:
        for profile in profiles:
            user_id = str(profile["user_id"])
            self.bot_use_counts[user_id] = self.bot_use_counts.get(user_id, 0) + 1


class KolkhozOnlineSessionService:
    def __init__(
        self,
        engine: CEngine,
        *,
        session_ttl_seconds: float = DEFAULT_SESSION_TTL_SECONDS,
        policy_path: Path | str | None = DEFAULT_ONLINE_POLICY_PATH,
        policy_paths: dict[str, Path | str | None] | None = None,
        policy_artifact: PolicyArtifact | None = None,
        store: Any | None = None,
        auth_verifier: SupabaseAuthVerifier | None = None,
        profile_bot_factory: ProfileBotFactory | None = None,
        background_tick_seconds: float = 0,
        population_enabled: bool = False,
        lobby_countdown_seconds: float = LOBBY_COUNTDOWN_SECONDS,
    ) -> None:
        self.engine = engine
        self.engine_provenance = (
            engine.provenance() if hasattr(engine, "provenance") else None
        )
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
        self.profile_bot_factory = (
            profile_bot_factory
            or (StoreBackedProfileBotFactory(store) if store is not None else None)
            or ProfileBotFactory()
        )
        self.background_tick_seconds = background_tick_seconds
        self.lobby_countdown_seconds = max(0.0, lobby_countdown_seconds)
        self._closed = threading.Event()
        self._background_thread: threading.Thread | None = None
        self._persistence_queue: queue.Queue[PersistenceJob | None] = queue.Queue(
            maxsize=4096,
        )
        self._persistence_thread: threading.Thread | None = None
        self._persistence_error: str | None = None
        self._lock = threading.RLock()
        self._policy_lock = threading.RLock()
        self._online_presence: dict[str, float] = {}
        self.metrics = OnlineServerMetrics()
        self.population_handler = (
            OnlinePopulationHandler(self) if population_enabled else None
        )
        if self.store is not None:
            self._persistence_thread = threading.Thread(
                target=self._run_persistence,
                name="kolkhoz-online-persistence",
                daemon=True,
            )
            self._persistence_thread.start()
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
        persistence_thread = self._persistence_thread
        if persistence_thread is not None:
            self._persistence_queue.put(None)
            self._persistence_queue.join()
            persistence_thread.join(timeout=2)
        with self._lock:
            for hosted in self._sessions.values():
                self.engine.free_engine(hosted.engine_pointer)
            self._sessions.clear()
            if self.store is not None:
                self.store.close()

    def _run_persistence(self) -> None:
        while True:
            job = self._persistence_queue.get()
            if job is None:
                self._persistence_queue.task_done()
                return
            try:
                while True:
                    try:
                        self._store_call(job.name, job.func, **job.kwargs)
                        self._persistence_error = None
                        break
                    except Exception as error:
                        self._persistence_error = f"{job.name}: {error}"
                        print(
                            f"Online persistence failed; retrying: {self._persistence_error}",
                            flush=True,
                        )
                        if self._closed.wait(1):
                            break
            finally:
                self._persistence_queue.task_done()

    def _enqueue_store_call(
        self,
        name: str,
        func: object,
        **kwargs: object,
    ) -> None:
        try:
            self._persistence_queue.put_nowait(
                PersistenceJob(name, func, copy.deepcopy(kwargs)),
            )
        except queue.Full as error:
            self._persistence_error = "persistence queue is full"
            raise OnlineServerError(
                HTTPStatus.SERVICE_UNAVAILABLE,
                self._persistence_error,
            ) from error

    def wait_for_persistence(self) -> None:
        self._persistence_queue.join()

    def _run_background_tick(self) -> None:
        while not self._closed.wait(self.background_tick_seconds):
            started = time.perf_counter()
            try:
                self.tick()
            except Exception as error:
                print(f"Online background tick failed: {error}", flush=True)
            finally:
                self.metrics.record_background_tick(time.perf_counter() - started)

    def tick(self) -> None:
        with self._lock:
            self._prune_expired_sessions()
            now = time.time()
            if self.population_handler is not None:
                self.population_handler.tick(now)
            sessions = list(self._sessions.values())
        for hosted in sessions:
            with self._session_lock(hosted, "background_tick"):
                if not self._session_is_registered(hosted):
                    continue
                self._sync_lobby_state(hosted, now)
                self._resolve_turn_timeouts(hosted, now)

    @contextmanager
    def _locked_session(self, session_id: str):
        hosted = self._get_or_load_session_locked(session_id)
        try:
            yield hosted
        finally:
            hosted.lock.release()

    @contextmanager
    def _session_lock(self, hosted: HostedSession, kind: str):
        self._acquire_session_lock(hosted, kind)
        try:
            yield hosted
        finally:
            hosted.lock.release()

    def _acquire_session_lock(self, hosted: HostedSession, kind: str) -> None:
        started = time.perf_counter()
        hosted.lock.acquire()
        self.metrics.record_lock_wait(kind, time.perf_counter() - started)

    def _get_or_load_session_locked(self, session_id: str) -> HostedSession:
        with self._lock:
            self._prune_expired_sessions()
            hosted = self._session_from_memory(session_id)
            if hosted is not None:
                self._acquire_session_lock(hosted, "request")
                return hosted
        loaded = self._load_persisted_session(session_id)
        with self._lock:
            existing = self._session_from_memory(str(loaded.session_id))
            if existing is None:
                existing = self._session_from_memory(str(loaded.invite_code))
            if existing is not None:
                self.engine.free_engine(loaded.engine_pointer)
                self._acquire_session_lock(existing, "request")
                return existing
            self._sessions[loaded.session_id] = loaded
            self._acquire_session_lock(loaded, "request")
            return loaded

    def _session_is_registered(self, hosted: HostedSession) -> bool:
        with self._lock:
            return self._sessions.get(hosted.session_id) is hosted

    def _store_call(self, name: str, func: object, *args: object, **kwargs: object):
        started = time.perf_counter()
        try:
            return func(*args, **kwargs)  # type: ignore[misc]
        finally:
            self.metrics.record_store_call(name, time.perf_counter() - started)

    def metrics_snapshot(self) -> dict[str, object]:
        return self.metrics.snapshot(self)

    def health_snapshot(self) -> dict[str, object]:
        return {
            "status": "ok",
            "gitSHA": self.engine_provenance.git_sha
            if self.engine_provenance is not None
            else "unknown",
            "engineSHA256": self.engine_provenance.c_sha256
            if self.engine_provenance is not None
            else "unknown",
        }

    def mark_online_presence(
        self,
        *,
        user_id: str | None,
    ) -> None:
        key = _online_presence_key(user_id)
        if key is None:
            return
        with self._lock:
            self._online_presence[key] = time.time()

    def metrics_state(self) -> dict[str, object]:
        with self._lock:
            sessions = list(self._sessions.values())
            self._prune_online_presence_locked()
            connected_online_clients = len(self._online_presence)
        now = time.time()
        active_sessions = len(sessions)
        active_seats = sum(len(hosted.occupied_seats) for hosted in sessions)
        connected_seated_human_seats = sum(
            1
            for hosted in sessions
            for player_id in hosted.occupied_seats
            if self._effective_controller(hosted, player_id) == "human"
            and now - hosted.seat_last_seen_at.get(player_id, 0.0)
            <= PRESENCE_GRACE_SECONDS
        )
        action_cache_entries = sum(
            len(hosted.action_update_cache) for hosted in sessions
        )
        action_cache_viewer_snapshots = sum(
            len(entry.get("updatesByViewer", {}))
            for hosted in sessions
            for entry in hosted.action_update_cache
            if isinstance(entry, dict)
        )
        return {
            "activeSessions": active_sessions,
            "activeSeats": active_seats,
            "connectedHumanSeats": connected_online_clients,
            "connectedSeatedHumanSeats": connected_seated_human_seats,
            "profiledBotSeats": len(SERVER_BOT_PROFILES),
            "citizensOnline": connected_online_clients + len(SERVER_BOT_PROFILES),
            "persistenceQueueDepth": self._persistence_queue.qsize(),
            "persistenceError": self._persistence_error,
            "actionCacheEntries": action_cache_entries,
            "actionCacheViewerSnapshots": action_cache_viewer_snapshots,
            "populationEnabled": self.population_handler is not None,
            "storeConfigured": self.store is not None,
        }

    def _prune_online_presence_locked(self) -> None:
        cutoff = time.time() - ONLINE_PRESENCE_SECONDS
        expired = [
            key
            for key, last_seen in self._online_presence.items()
            if last_seen < cutoff
        ]
        for key in expired:
            del self._online_presence[key]

    def create_session(
        self,
        request: dict[str, object],
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        with self._lock:
            self._require_authenticated_user(user_id)
            self._prune_expired_sessions()
            variants = _normalize_variants(request.get("variants"))
            controllers = _normalize_controllers(request.get("controllers"))
            browser_joinable = _optional_bool(request.get("browserJoinable"), True)
            ranked = False
            seed = _optional_int(request.get("seed")) or int(time.time_ns())
            session_id = str(uuid.uuid4())
            invite_code = self._generate_invite_code()
            now = time.time()
            pointer = self.engine.new_engine(
                seed,
                variants=_variants_native(variants),
                controllers=_controllers_native(controllers),
            )
            hosted = HostedSession(
                session_id=session_id,
                invite_code=invite_code,
                engine_pointer=pointer,
                seed=seed,
                variants=variants,
                controllers=controllers,
                ranked=ranked,
                browser_joinable=browser_joinable,
                population_kind=None,
                occupied_seats=set(),
                seat_tokens={},
                seat_token_hashes={},
                seat_user_ids={},
                server_bot_controllers={},
                bot_action_ready_at={},
                created_by_user_id=user_id,
                action_log=[],
                action_update_cache=[],
                created_at=now,
                last_seen_at=now,
                last_persisted_touch_at=now,
                seat_last_seen_at={},
                seat_timeouts={},
                autopilot_seats=set(),
                abandoned_seats=set(),
                turn_player_id=None,
                turn_deadline_at=None,
                started=False,
            )
            player_id = self._first_available_seat(hosted)
            hosted.occupied_seats.add(player_id)
            seat_token = self._issue_seat_token(hosted, player_id)
            hosted.seat_last_seen_at[player_id] = now
            if user_id is not None:
                hosted.seat_user_ids[player_id] = user_id
            self._assign_server_bot_profiles(hosted)
            self._sessions[session_id] = hosted
            try:
                self._sync_lobby_state(hosted, now, persist=False)
                self._persist_session_created(hosted)
                self._persist_lobby_state(hosted, now)
                self._persist_finished_if_needed(hosted)
            except Exception:
                self._sessions.pop(session_id, None)
                self.engine.free_engine(pointer)
                raise
            print(
                f"Hosted online session {session_id} for player {player_id}", flush=True
            )
            return {
                "sessionID": session_id,
                "inviteCode": hosted.invite_code,
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
        with self._locked_session(session_id) as hosted:
            self._require_authenticated_user(user_id)
            lookup_is_invite_code = _session_lookup_is_invite_code(session_id)
            if not lookup_is_invite_code:
                self._ensure_not_online_banned(user_id)
            if (
                not lookup_is_invite_code
                and not hosted.browser_joinable
                and (hosted.invited_user_ids or hosted.declined_invite_user_ids)
                and not self._user_can_join_invited_session(hosted, user_id)
            ):
                raise OnlineServerError(HTTPStatus.FORBIDDEN, "not invited")
            preferred = _optional_int(request.get("preferredPlayerID"))
            if preferred is not None:
                if not self._seat_is_joinable(hosted, preferred):
                    raise OnlineServerError(HTTPStatus.CONFLICT, "seat unavailable")
                player_id = preferred
            else:
                player_id = self._first_available_seat(hosted)
            response = self._join_hosted_seat(hosted, player_id, user_id=user_id)
            if user_id is not None:
                hosted.invited_user_ids.discard(user_id)
                hosted.declined_invite_user_ids.discard(user_id)
            return response

    def invite_session_comrades(
        self,
        session_id: str,
        request: dict[str, object],
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        with self._locked_session(session_id) as hosted:
            self._require_authenticated_user(user_id)
            if (
                hosted.created_by_user_id is not None
                and user_id != hosted.created_by_user_id
            ):
                raise OnlineServerError(
                    HTTPStatus.FORBIDDEN, "only the host can invite"
                )
            if hosted.started:
                raise OnlineServerError(HTTPStatus.CONFLICT, "game has already started")
            user_ids = set(_string_list(request.get("userIDs")))
            if not user_ids:
                user_ids = set(_string_list(request.get("invitedUserIDs")))
            if not user_ids:
                raise OnlineServerError(HTTPStatus.BAD_REQUEST, "missing userIDs")
            if user_id is not None:
                user_ids.discard(user_id)
            if not user_ids:
                raise OnlineServerError(HTTPStatus.BAD_REQUEST, "missing userIDs")
            if self.store is not None and user_id is not None:
                allowed_user_ids = self._comrade_user_ids(user_id)
                if not user_ids.issubset(allowed_user_ids):
                    raise OnlineServerError(
                        HTTPStatus.FORBIDDEN,
                        "can only invite comrades",
                    )
            seated_user_ids = set(hosted.seat_user_ids.values())
            pending_user_ids = user_ids - seated_user_ids
            hosted.invited_user_ids.update(pending_user_ids)
            hosted.declined_invite_user_ids.difference_update(pending_user_ids)
            hosted.last_seen_at = time.time()
            return {
                "sessionID": hosted.session_id,
                "invitedUserIDs": sorted(hosted.invited_user_ids),
            }

    def pending_session_invites(
        self,
        *,
        user_id: str | None = None,
    ) -> list[dict[str, object]]:
        self._require_authenticated_user(user_id)
        self._ensure_not_online_banned(user_id)
        if user_id is None:
            return []
        with self._lock:
            self._prune_expired_sessions()
            sessions = list(self._sessions.values())
        invites: list[dict[str, object]] = []
        for hosted in sessions:
            with self._session_lock(hosted, "session_invites"):
                if not self._session_is_registered(hosted):
                    continue
                if not self._pending_invite_for_user(hosted, user_id):
                    continue
                self._sync_lobby_state(hosted, time.time())
                if not self._open_seats(hosted):
                    continue
                invites.append(self._invite_listing(hosted, user_id))
        return invites

    def decline_session_invite(
        self,
        session_id: str,
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        with self._locked_session(session_id) as hosted:
            self._require_authenticated_user(user_id)
            if user_id is None or user_id not in hosted.invited_user_ids:
                raise OnlineServerError(HTTPStatus.NOT_FOUND, "invite not found")
            hosted.invited_user_ids.discard(user_id)
            hosted.declined_invite_user_ids.add(user_id)
            hosted.last_seen_at = time.time()
            return {"declined": True, "sessionID": hosted.session_id}

    def matchmake_session(
        self,
        request: dict[str, object],
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        self._require_authenticated_user(user_id)
        self._ensure_not_online_banned(user_id)
        ranked_only = _optional_bool(request.get("rankedOnly"), False)
        comrades_only = _optional_bool(request.get("comradesOnly"), False)
        comrade_user_ids: set[str] = set()
        if comrades_only:
            if user_id is None or self.store is None:
                raise OnlineServerError(HTTPStatus.NOT_FOUND, "no open games")
            comrade_summary = self.store.comrades_for_user(user_id=user_id)
            comrade_user_ids = {
                str(comrade.get("user_id") or comrade.get("userID"))
                for comrade in comrade_summary.get("comrades", [])
                if comrade.get("user_id") or comrade.get("userID")
            }
            if not comrade_user_ids:
                raise OnlineServerError(HTTPStatus.NOT_FOUND, "no open games")
        with self._lock:
            self._prune_expired_sessions()
            candidates = [
                hosted
                for hosted in self._sessions.values()
                if hosted.browser_joinable
                and (not ranked_only or hosted.ranked)
                and (
                    not comrades_only
                    or any(
                        seat_user_id in comrade_user_ids
                        for seat_user_id in hosted.seat_user_ids.values()
                    )
                )
                and self._open_seats(hosted)
            ]
            rating_user_ids = {
                seat_user_id
                for hosted in candidates
                for seat_user_id in hosted.seat_user_ids.values()
            }
        if user_id is not None:
            rating_user_ids.add(user_id)
        ratings = self._matchmaking_ratings(rating_user_ids)
        player_rating = (
            ratings.get(user_id, DEFAULT_MATCHMAKING_RATING)
            if user_id is not None
            else DEFAULT_MATCHMAKING_RATING
        )
        scored_candidates = [
            (
                self._matchmaking_rating_key(hosted, player_rating, ratings),
                len(self._open_seats(hosted)),
                hosted.created_at,
                hosted.session_id,
                hosted,
            )
            for hosted in candidates
        ]
        if any(score[0][0] < 2 for score in scored_candidates):
            scored_candidates = [
                score for score in scored_candidates if score[0][0] < 2
            ]
        candidates = [
            hosted
            for _, _, _, _, hosted in sorted(
                scored_candidates,
                key=lambda score: (score[0], score[1], score[2], score[3]),
            )
        ]
        for hosted in candidates:
            with self._session_lock(hosted, "matchmake"):
                if not self._session_is_registered(hosted):
                    continue
                self._resolve_turn_timeouts(hosted, time.time())
                open_seats = self._open_seats(hosted)
                if (
                    not hosted.browser_joinable
                    or not open_seats
                    or (ranked_only and not hosted.ranked)
                    or (
                        comrades_only
                        and not any(
                            seat_user_id in comrade_user_ids
                            for seat_user_id in hosted.seat_user_ids.values()
                        )
                    )
                    or (
                        user_id is not None and user_id in hosted.seat_user_ids.values()
                    )
                ):
                    continue
                return self._join_hosted_seat(
                    hosted,
                    open_seats[0],
                    user_id=user_id,
                )
        if ranked_only and not comrades_only:
            return self._join_new_ranked_matchmaking_seed(user_id=user_id)
        raise OnlineServerError(HTTPStatus.NOT_FOUND, "no open games")

    def _join_new_ranked_matchmaking_seed(
        self,
        *,
        user_id: str | None,
    ) -> dict[str, object]:
        now = time.time()
        try:
            session_id = self.create_population_session(
                bot_profiles=[],
                open_human_seats=PLAYER_COUNT,
                ranked=True,
                now=now,
                population_kind="rating_seed",
            )
        except ValueError as error:
            raise OnlineServerError(HTTPStatus.NOT_FOUND, "no open games") from error
        with self._locked_session(session_id) as hosted:
            return self._join_hosted_seat(
                hosted,
                self._first_available_seat(hosted),
                user_id=user_id,
            )

    def _bot_profiles_by_rating_match(
        self,
        profiles: list[dict[str, object]],
        target_rating: int,
        ratings: dict[str, int],
    ) -> list[dict[str, object]]:
        return [
            profile
            for _, profile in sorted(
                enumerate(profiles),
                key=lambda entry: (
                    abs(self._profile_rating(entry[1], ratings) - target_rating),
                    entry[0],
                ),
            )
        ]

    def _profile_rating(
        self,
        profile: dict[str, object],
        ratings: dict[str, int],
    ) -> int:
        stats = profile.get("stats")
        rating = stats.get("rating") if isinstance(stats, dict) else None
        if isinstance(rating, (int, float)):
            return int(rating)
        return ratings.get(str(profile["user_id"]), DEFAULT_MATCHMAKING_RATING)

    def _matchmaking_ratings(self, user_ids: set[str]) -> dict[str, int]:
        ratings = {
            user_id: DEFAULT_MATCHMAKING_RATING for user_id in user_ids if user_id
        }
        if not ratings or self.store is None:
            return ratings
        try:
            profiles = self.store.profiles_for_user_ids(sorted(ratings))
        except Exception:
            return ratings
        for profile_user_id, profile in profiles.items():
            stats = profile.get("stats") if isinstance(profile, dict) else None
            rating = stats.get("rating") if isinstance(stats, dict) else None
            if isinstance(rating, (int, float)):
                ratings[str(profile_user_id)] = int(rating)
        return ratings

    def _matchmaking_rating_key(
        self,
        hosted: HostedSession,
        player_rating: int,
        ratings: dict[str, int],
    ) -> tuple[int, int, int]:
        seat_ratings = [
            ratings.get(seat_user_id, DEFAULT_MATCHMAKING_RATING)
            for seat_user_id in hosted.seat_user_ids.values()
            if seat_user_id
        ]
        if not seat_ratings:
            return (0, 0, 0)
        max_delta = max(abs(rating - player_rating) for rating in seat_ratings)
        average_rating = sum(seat_ratings) / len(seat_ratings)
        average_delta = int(abs(average_rating - player_rating))
        if max_delta <= MATCHMAKING_IDEAL_RATING_DELTA:
            band = 0
        elif max_delta <= MATCHMAKING_ACCEPTABLE_RATING_DELTA:
            band = 1
        else:
            band = 2
        return (band, max_delta, average_delta)

    def _join_hosted_seat(
        self,
        hosted: HostedSession,
        player_id: int,
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        previous_occupied_seats = set(hosted.occupied_seats)
        previous_seat_tokens = dict(hosted.seat_tokens)
        previous_seat_token_hashes = dict(hosted.seat_token_hashes)
        previous_seat_user_ids = dict(hosted.seat_user_ids)
        previous_last_seen_at = hosted.last_seen_at
        previous_seat_last_seen_at = dict(hosted.seat_last_seen_at)
        previous_autopilot_seats = set(hosted.autopilot_seats)
        previous_turn_deadline_at = hosted.turn_deadline_at
        previous_lobby_countdown_ends_at = hosted.lobby_countdown_ends_at
        hosted.occupied_seats.add(player_id)
        seat_token = self._issue_seat_token(hosted, player_id)
        if user_id is not None:
            hosted.seat_user_ids[player_id] = user_id
        hosted.last_seen_at = time.time()
        try:
            self._mark_seat_seen(hosted, player_id, hosted.last_seen_at)
            self._persist_seat_joined(hosted, player_id, seat_token)
            self._sync_lobby_state(hosted, hosted.last_seen_at)
            self._persist_finished_if_needed(hosted)
        except Exception:
            hosted.occupied_seats = previous_occupied_seats
            hosted.seat_tokens = previous_seat_tokens
            hosted.seat_token_hashes = previous_seat_token_hashes
            hosted.seat_user_ids = previous_seat_user_ids
            hosted.last_seen_at = previous_last_seen_at
            hosted.seat_last_seen_at = previous_seat_last_seen_at
            hosted.autopilot_seats = previous_autopilot_seats
            hosted.turn_deadline_at = previous_turn_deadline_at
            hosted.lobby_countdown_ends_at = previous_lobby_countdown_ends_at
            raise
        print(
            f"Player {player_id} joined online session {hosted.session_id}",
            flush=True,
        )
        return {
            "sessionID": hosted.session_id,
            "seed": hosted.seed,
            "inviteCode": hosted.invite_code,
            "playerID": player_id,
            "seatToken": seat_token,
            "update": self._update(hosted, player_id),
        }

    def create_population_session(
        self,
        *,
        bot_profiles: list[dict[str, object]],
        open_human_seats: int,
        ranked: bool,
        now: float,
        population_kind: str,
    ) -> str:
        bot_count = PLAYER_COUNT - open_human_seats
        if bot_count < 0 or bot_count > PLAYER_COUNT:
            raise ValueError("population session needs between 0 and 4 bots")
        with self._lock:
            self._prune_expired_sessions()
            selected_profiles = self._available_profile_bots_locked(
                bot_profiles,
            )[:bot_count]
            if len(selected_profiles) < bot_count:
                selected_profiles = self._available_profile_bots_locked(
                    [
                        *selected_profiles,
                        *self._create_profile_bot_profiles_locked(
                            count=bot_count - len(selected_profiles),
                            now=now,
                            exclude_user_ids={
                                str(profile["user_id"]) for profile in selected_profiles
                            },
                            target_rating=DEFAULT_MATCHMAKING_RATING,
                        ),
                    ],
                )[:bot_count]
            if len(selected_profiles) < bot_count:
                raise ValueError("not enough available bot profiles")
            controllers = [
                str(profile["controller"]) for profile in selected_profiles
            ] + ["human"] * open_human_seats
            seed = int(now * 1_000_000_000) ^ int(
                hashlib.sha256(
                    f"{population_kind}:{now}:{controllers}".encode("utf-8")
                ).hexdigest()[:16],
                16,
            )
            seed &= POSTGRES_BIGINT_MAX
            session_id = str(uuid.uuid4())
            invite_code = self._generate_invite_code()
            variants = _normalize_variants(None)
            pointer = self.engine.new_engine(
                seed,
                variants=_variants_native(variants),
                controllers=_controllers_native(controllers),
            )
            hosted = HostedSession(
                session_id=session_id,
                invite_code=invite_code,
                engine_pointer=pointer,
                seed=seed,
                variants=variants,
                controllers=controllers,
                ranked=ranked,
                browser_joinable=True,
                population_kind=population_kind,
                occupied_seats=set(),
                seat_tokens={},
                seat_token_hashes={},
                seat_user_ids={},
                server_bot_controllers={},
                bot_action_ready_at={},
                created_by_user_id=str(selected_profiles[0]["user_id"])
                if selected_profiles
                else None,
                action_log=[],
                action_update_cache=[],
                created_at=now,
                last_seen_at=now,
                last_persisted_touch_at=now,
                seat_last_seen_at={},
                seat_timeouts={},
                autopilot_seats=set(),
                abandoned_seats=set(),
                turn_player_id=None,
                turn_deadline_at=None,
                started=False,
            )
            for player_id, profile in enumerate(selected_profiles):
                self._seat_server_bot(hosted, player_id, profile, now)
            self._sessions[session_id] = hosted
            try:
                self._sync_lobby_state(hosted, now, persist=False)
                self._persist_session_created(hosted)
                self._persist_lobby_state(hosted, now)
                self._persist_finished_if_needed(hosted)
            except Exception:
                self._sessions.pop(session_id, None)
                self.engine.free_engine(pointer)
                raise
            print(
                f"Seeded {population_kind} online session {session_id}",
                flush=True,
            )
            return session_id

    def fill_open_seats_with_server_bots(
        self,
        *,
        now: float,
        profiles: list[dict[str, object]],
    ) -> list[dict[str, object]]:
        with self._lock:
            self._prune_expired_sessions()
            profiles = self._available_profile_bots_locked(profiles)
            hosted_candidates = [
                hosted
                for hosted in self._sessions.values()
                if hosted.browser_joinable and self._open_seats(hosted)
            ]
            seated_user_ids = {
                seat_user_id
                for hosted in hosted_candidates
                for seat_user_id in hosted.seat_user_ids.values()
            }
            seated_ratings = self._matchmaking_ratings(seated_user_ids)
            target_rating = self._profile_bot_target_rating(
                hosted_candidates,
                seated_ratings,
            )
            if len(profiles) < len(hosted_candidates):
                profiles = self._available_profile_bots_locked(
                    [
                        *profiles,
                        *self._create_profile_bot_profiles_locked(
                            count=len(hosted_candidates) - len(profiles),
                            now=now,
                            exclude_user_ids={
                                str(profile["user_id"]) for profile in profiles
                            },
                            target_rating=target_rating,
                        ),
                    ],
                )
            profile_by_user_id = {
                str(profile["user_id"]): profile for profile in profiles
            }
            rating_user_ids = {
                seat_user_id
                for hosted in hosted_candidates
                for seat_user_id in hosted.seat_user_ids.values()
            } | set(profile_by_user_id)
        ratings = self._matchmaking_ratings(rating_user_ids)
        scored_candidates = []
        for hosted in hosted_candidates:
            used_user_ids = set(hosted.seat_user_ids.values())
            for profile_index, profile in enumerate(profiles):
                profile_user_id = str(profile["user_id"])
                if profile_user_id in used_user_ids:
                    continue
                profile_rating = self._profile_rating(profile, ratings)
                scored_candidates.append(
                    (
                        self._matchmaking_rating_key(
                            hosted,
                            profile_rating,
                            ratings,
                        ),
                        len(self._open_seats(hosted)),
                        hosted.created_at,
                        hosted.session_id,
                        profile_index,
                        hosted,
                        profile,
                    )
                )
        if any(score[0][0] < 2 for score in scored_candidates):
            scored_candidates = [
                score for score in scored_candidates if score[0][0] < 2
            ]
        scored_candidates.sort(
            key=lambda score: (score[0], score[1], score[2], score[3], score[4])
        )
        filled_profiles: list[dict[str, object]] = []
        filled_session_ids: set[str] = set()
        filled_profile_user_ids: set[str] = set()
        for _, _, _, _, _, hosted, profile in scored_candidates:
            profile_user_id = str(profile["user_id"])
            if (
                hosted.session_id in filled_session_ids
                or profile_user_id in filled_profile_user_ids
            ):
                continue
            with self._session_lock(hosted, "population_fill"):
                if not self._session_is_registered(hosted):
                    continue
                self._resolve_turn_timeouts(hosted, now)
                open_seats = self._open_seats(hosted)
                if (
                    not hosted.browser_joinable
                    or not open_seats
                    or profile_user_id in hosted.seat_user_ids.values()
                ):
                    continue
                self._join_server_bot_seat(hosted, open_seats[0], profile, now)
                filled_profiles.append(profile)
                filled_session_ids.add(hosted.session_id)
                filled_profile_user_ids.add(profile_user_id)
        return filled_profiles

    def fill_open_seat_with_server_bot(
        self,
        *,
        now: float,
        profiles: list[dict[str, object]],
    ) -> dict[str, object] | None:
        filled_profiles = self.fill_open_seats_with_server_bots(
            now=now,
            profiles=profiles,
        )
        return filled_profiles[0] if filled_profiles else None

    def _available_profile_bots_locked(
        self,
        profiles: list[dict[str, object]],
    ) -> list[dict[str, object]]:
        active_user_ids = self._active_profile_bot_user_ids_locked()
        available: list[dict[str, object]] = []
        seen_user_ids: set[str] = set()
        for profile in profiles:
            user_id = str(profile["user_id"])
            if user_id in active_user_ids or user_id in seen_user_ids:
                continue
            available.append(profile)
            seen_user_ids.add(user_id)
        return available

    def _create_profile_bot_profiles_locked(
        self,
        *,
        count: int,
        now: float,
        exclude_user_ids: set[str],
        target_rating: int,
    ) -> list[dict[str, object]]:
        if count <= 0:
            return []
        excluded = set(exclude_user_ids) | self._active_profile_bot_user_ids_locked()
        try:
            created = self.profile_bot_factory.create_profiles(
                count=count,
                now=now,
                exclude_user_ids=excluded,
                target_wait_seconds=PROFILE_BOT_TARGET_WAIT_SECONDS,
                target_rating=target_rating,
            )
        except Exception:
            return []
        profiles: list[dict[str, object]] = []
        seen_user_ids = set(excluded)
        for profile in created:
            normalized = self._normalized_profile_bot(profile)
            if normalized is None:
                continue
            user_id = str(normalized["user_id"])
            if user_id in seen_user_ids:
                continue
            profiles.append(normalized)
            seen_user_ids.add(user_id)
        return profiles[:count]

    def _profile_bot_target_rating(
        self,
        hosted_candidates: list[HostedSession],
        ratings: dict[str, int],
    ) -> int:
        table_ratings: list[int] = []
        for hosted in hosted_candidates:
            seat_ratings = [
                ratings.get(seat_user_id, DEFAULT_MATCHMAKING_RATING)
                for seat_user_id in hosted.seat_user_ids.values()
                if seat_user_id
            ]
            if seat_ratings:
                table_ratings.append(round(sum(seat_ratings) / len(seat_ratings)))
        if not table_ratings:
            return DEFAULT_MATCHMAKING_RATING
        return round(sum(table_ratings) / len(table_ratings))

    def _normalized_profile_bot(
        self,
        profile: dict[str, object],
    ) -> dict[str, object] | None:
        user_id = str(profile.get("user_id") or "").strip()
        controller = str(profile.get("controller") or "").strip()
        if not user_id or controller not in CONTROLLER_CODES or controller == "human":
            return None
        return {
            "user_id": user_id,
            "controller": controller,
            "slot": profile.get("slot", 0),
            "display_name": profile.get("display_name"),
            "avatar_url": profile.get("avatar_url"),
            "stats": profile.get("stats")
            if isinstance(profile.get("stats"), dict)
            else {},
        }

    def _active_profile_bot_user_ids_locked(self) -> set[str]:
        active_user_ids: set[str] = set()
        for hosted in self._sessions.values():
            if int(CEngine.snapshot(hosted.engine_pointer).phase) == PHASE_GAME_OVER:
                continue
            for player_id, user_id in hosted.seat_user_ids.items():
                if (
                    user_id in SERVER_BOT_PROFILES_BY_ID
                    or player_id in hosted.server_bot_controllers
                ):
                    active_user_ids.add(user_id)
        return active_user_ids

    def _player_created_lobby_is_empty(self, hosted: HostedSession) -> bool:
        if hosted.population_kind is not None:
            return False
        return not any(
            player_id in hosted.occupied_seats
            and self._effective_controller(hosted, player_id) == "human"
            for player_id in range(PLAYER_COUNT)
        )

    def leave_session(
        self,
        session_id: str,
        player_id: int,
        seat_token: str | None,
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        with self._locked_session(session_id) as hosted:
            self._authenticate(hosted, player_id, seat_token, user_id=user_id)
            now = time.time()
            if not hosted.started:
                hosted.last_seen_at = now
                hosted.occupied_seats.discard(player_id)
                hosted.seat_tokens.pop(player_id, None)
                hosted.seat_token_hashes.pop(player_id, None)
                hosted.seat_user_ids.pop(player_id, None)
                hosted.seat_last_seen_at.pop(player_id, None)
                hosted.seat_timeouts.pop(player_id, None)
                hosted.abandoned_seats.discard(player_id)
                hosted.autopilot_seats.discard(player_id)
                if hosted.turn_player_id == player_id:
                    hosted.turn_player_id = None
                    hosted.turn_deadline_at = None
                self._sync_lobby_state(hosted, now, persist=False)
                update = self._update(hosted, player_id)
                if self._player_created_lobby_is_empty(hosted):
                    self._expire_empty_lobby(hosted, now)
                else:
                    self._persist_lobby_seat_left(hosted, player_id, now)
                    self._persist_lobby_state(hosted, now)
                return {
                    "sessionID": hosted.session_id,
                    "inviteCode": hosted.invite_code,
                    "playerID": player_id,
                    "penalty": {},
                    "update": update,
                }
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
                "inviteCode": hosted.invite_code,
                "playerID": player_id,
                "penalty": penalty or {},
                "update": self._update(hosted, player_id),
            }

    def kick_session_player(
        self,
        session_id: str,
        target_player_id: int,
        request: dict[str, object],
        seat_token: str | None,
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        with self._locked_session(session_id) as hosted:
            host_player_id = _required_int(request.get("hostPlayerID"), "hostPlayerID")
            self._authenticate(hosted, host_player_id, seat_token, user_id=user_id)
            if not self._seat_can_kick_players(hosted, host_player_id):
                raise OnlineServerError(HTTPStatus.FORBIDDEN, "only the host can kick")
            if target_player_id == host_player_id:
                raise OnlineServerError(HTTPStatus.CONFLICT, "cannot kick yourself")
            if hosted.started:
                raise OnlineServerError(
                    HTTPStatus.CONFLICT,
                    "cannot kick after the game starts",
                )
            if (
                target_player_id < 0
                or target_player_id >= len(hosted.controllers)
                or target_player_id not in hosted.occupied_seats
                or hosted.controllers[target_player_id] != "human"
            ):
                raise OnlineServerError(HTTPStatus.CONFLICT, "seat unavailable")
            previous_occupied_seats = set(hosted.occupied_seats)
            previous_seat_tokens = dict(hosted.seat_tokens)
            previous_seat_token_hashes = dict(hosted.seat_token_hashes)
            previous_seat_user_ids = dict(hosted.seat_user_ids)
            previous_last_seen_at = hosted.last_seen_at
            previous_seat_last_seen_at = dict(hosted.seat_last_seen_at)
            previous_seat_timeouts = dict(hosted.seat_timeouts)
            previous_autopilot_seats = set(hosted.autopilot_seats)
            previous_abandoned_seats = set(hosted.abandoned_seats)
            previous_turn_player_id = hosted.turn_player_id
            previous_turn_deadline_at = hosted.turn_deadline_at
            previous_lobby_countdown_ends_at = hosted.lobby_countdown_ends_at
            now = time.time()
            hosted.occupied_seats.discard(target_player_id)
            hosted.seat_tokens.pop(target_player_id, None)
            hosted.seat_token_hashes.pop(target_player_id, None)
            hosted.seat_user_ids.pop(target_player_id, None)
            hosted.seat_last_seen_at.pop(target_player_id, None)
            hosted.seat_timeouts.pop(target_player_id, None)
            hosted.autopilot_seats.discard(target_player_id)
            hosted.abandoned_seats.discard(target_player_id)
            if hosted.turn_player_id == target_player_id:
                hosted.turn_player_id = None
                hosted.turn_deadline_at = None
            hosted.last_seen_at = now
            try:
                self._persist_seat_kicked(hosted, target_player_id, now)
                self._sync_lobby_state(hosted, now)
                self._persist_finished_if_needed(hosted)
            except Exception:
                hosted.occupied_seats = previous_occupied_seats
                hosted.seat_tokens = previous_seat_tokens
                hosted.seat_token_hashes = previous_seat_token_hashes
                hosted.seat_user_ids = previous_seat_user_ids
                hosted.last_seen_at = previous_last_seen_at
                hosted.seat_last_seen_at = previous_seat_last_seen_at
                hosted.seat_timeouts = previous_seat_timeouts
                hosted.autopilot_seats = previous_autopilot_seats
                hosted.abandoned_seats = previous_abandoned_seats
                hosted.turn_player_id = previous_turn_player_id
                hosted.turn_deadline_at = previous_turn_deadline_at
                hosted.lobby_countdown_ends_at = previous_lobby_countdown_ends_at
                raise
            return {
                "sessionID": hosted.session_id,
                "inviteCode": hosted.invite_code,
                "playerID": host_player_id,
                "update": self._update(hosted, host_player_id),
            }

    def update(
        self,
        session_id: str,
        viewer_id: int | None,
        seat_token: str | None,
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        with self._locked_session(session_id) as hosted:
            self._authenticate(hosted, viewer_id, seat_token, user_id=user_id)
            now = time.time()
            hosted.last_seen_at = now
            if viewer_id is not None:
                self._mark_seat_seen(hosted, viewer_id, now)
            self._sync_lobby_state(hosted, now)
            self._resolve_turn_timeouts(hosted, now)
            self._persist_touch_if_needed(hosted)
            self._persist_finished_if_needed(hosted)
            return self._update(hosted, viewer_id)

    def user_id_from_authorization(self, authorization: str | None) -> str | None:
        if self.auth_verifier is None:
            return None
        started = time.perf_counter()
        try:
            return self.auth_verifier.user_id_from_authorization(authorization)
        finally:
            self.metrics.record_store_call(
                "supabase_auth",
                time.perf_counter() - started,
            )

    def comrades(self, *, user_id: str | None = None) -> dict[str, object]:
        self._require_authenticated_user(user_id)
        if user_id is None or self.store is None:
            return {"userID": user_id, "comradeCode": None, "comrades": []}
        self.store.ensure_comrade_code(
            user_id=user_id,
            display_name="Player",
            updated_at=time.time(),
        )
        return _comrades_response(
            self._comrades_with_presence(
                self.store.comrades_for_user(user_id=user_id),
            ),
        )

    def _comrades_with_presence(self, value: dict[str, object]) -> dict[str, object]:
        user_ids: set[str] = set()
        for key in ("comrades", "incoming_requests", "outgoing_requests"):
            profiles = value.get(key)
            if not isinstance(profiles, list):
                continue
            for profile in profiles:
                if not isinstance(profile, dict):
                    continue
                profile_user_id = profile.get("user_id") or profile.get("userID")
                if profile_user_id:
                    user_ids.add(str(profile_user_id))

        if not user_ids:
            return value

        statuses = {
            profile_user_id: {
                "isOnline": False,
                "inGame": False,
                "inLobby": False,
            }
            for profile_user_id in user_ids
        }
        with self._lock:
            self._prune_expired_sessions()
            self._prune_online_presence_locked()
            for profile_user_id in user_ids:
                key = _online_presence_key(profile_user_id)
                statuses[profile_user_id]["isOnline"] = (
                    key is not None and key in self._online_presence
                )
            for hosted in self._sessions.values():
                for seat_user_id in hosted.seat_user_ids.values():
                    status = statuses.get(seat_user_id)
                    if status is None:
                        continue
                    if hosted.started:
                        status["inGame"] = True
                    else:
                        status["inLobby"] = True

        for key in ("comrades", "incoming_requests", "outgoing_requests"):
            profiles = value.get(key)
            if not isinstance(profiles, list):
                continue
            for profile in profiles:
                if not isinstance(profile, dict):
                    continue
                profile_user_id = profile.get("user_id") or profile.get("userID")
                if profile_user_id:
                    profile.update(statuses.get(str(profile_user_id), {}))
        return value

    def send_comrade_request(
        self,
        request: dict[str, object],
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        self._require_authenticated_user(user_id)
        if user_id is None or self.store is None:
            raise OnlineServerError(
                HTTPStatus.SERVICE_UNAVAILABLE,
                "comrade profiles are not configured",
            )
        try:
            comrade_user_id = str(request.get("userID") or "").strip()
            if comrade_user_id:
                profile = self.store.send_comrade_request_to_user(
                    user_id=user_id,
                    comrade_user_id=comrade_user_id,
                    updated_at=time.time(),
                )
            else:
                code = str(request.get("comradeCode") or "").strip()
                if not code:
                    raise OnlineServerError(
                        HTTPStatus.BAD_REQUEST,
                        "missing comrade code",
                    )
                profile = self.store.send_comrade_request_by_code(
                    user_id=user_id,
                    comrade_code=code,
                    updated_at=time.time(),
                )
        except ValueError as error:
            raise OnlineServerError(HTTPStatus.NOT_FOUND, str(error)) from error
        key = "comrade" if profile.get("accepted") is True else "request"
        return {key: _comrade_profile_response(profile)}

    def respond_to_comrade_request(
        self,
        request: dict[str, object],
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        self._require_authenticated_user(user_id)
        if user_id is None or self.store is None:
            raise OnlineServerError(
                HTTPStatus.SERVICE_UNAVAILABLE,
                "comrade profiles are not configured",
            )
        requester_user_id = str(request.get("userID") or "").strip()
        if not requester_user_id:
            raise OnlineServerError(HTTPStatus.BAD_REQUEST, "missing userID")
        accept = bool(request.get("accept"))
        try:
            profile = self.store.respond_to_comrade_request(
                user_id=user_id,
                requester_user_id=requester_user_id,
                accept=accept,
                updated_at=time.time(),
            )
        except ValueError as error:
            raise OnlineServerError(HTTPStatus.NOT_FOUND, str(error)) from error
        if profile is None:
            return {"accepted": False}
        return {"accepted": True, "comrade": _comrade_profile_response(profile)}

    def remove_comrade(
        self,
        request: dict[str, object],
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        self._require_authenticated_user(user_id)
        if user_id is None or self.store is None:
            raise OnlineServerError(
                HTTPStatus.SERVICE_UNAVAILABLE,
                "comrade profiles are not configured",
            )
        comrade_user_id = str(request.get("userID") or "").strip()
        if not comrade_user_id:
            raise OnlineServerError(HTTPStatus.BAD_REQUEST, "missing userID")
        self.store.remove_comrade(
            user_id=user_id,
            comrade_user_id=comrade_user_id,
        )
        return {"removed": True}

    def list_sessions(self, *, user_id: str | None = None) -> list[dict[str, object]]:
        self._ensure_not_online_banned(user_id)
        with self._lock:
            self._prune_expired_sessions()
            sessions = list(self._sessions.values())
        listings: list[dict[str, object]] = []
        for hosted in sessions:
            with self._session_lock(hosted, "list_sessions"):
                if not self._session_is_registered(hosted):
                    continue
                if hosted.browser_joinable and self._open_seats(hosted):
                    listings.append(self._listing(hosted))
        return listings

    def session_listing(self, session_id: str) -> dict[str, object]:
        with self._locked_session(session_id) as hosted:
            self._sync_lobby_state(hosted, time.time())
            return self._listing(hosted)

    def legal_actions(
        self,
        session_id: str,
        player_id: int,
        seat_token: str | None,
        *,
        user_id: str | None = None,
    ) -> list[dict[str, object]]:
        with self._locked_session(session_id) as hosted:
            self._authenticate(hosted, player_id, seat_token, user_id=user_id)
            now = time.time()
            hosted.last_seen_at = now
            self._mark_seat_seen(hosted, player_id, now)
            self._sync_lobby_state(hosted, now)
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
        with self._locked_session(session_id) as hosted:
            player_id = _required_int(request.get("playerID"), "playerID")
            self._authenticate(hosted, player_id, seat_token, user_id=user_id)
            now = time.time()
            hosted.last_seen_at = now
            self._mark_seat_seen(hosted, player_id, now)
            self._sync_lobby_state(hosted, now)
            if not hosted.started:
                raise OnlineServerError(
                    HTTPStatus.CONFLICT,
                    "game has not started",
                )
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
            if not _action_in(
                action, self._legal_actions_for_player(hosted, player_id)
            ):
                raise OnlineServerError(HTTPStatus.CONFLICT, "illegal action")
            self.engine.apply_action(hosted.engine_pointer, action)
            action_json = self._append_action(hosted, action, source="manual")
            hosted.last_seen_at = time.time()
            self._persist_action_appended(hosted, player_id, action_json)
            self._advance_automatic_turns(hosted)
            hosted.last_seen_at = time.time()
            self._sync_turn_deadline(hosted, hosted.last_seen_at)
            self._persist_finished_if_needed(hosted)
            return self._update(hosted, player_id)

    def submit_reaction(
        self,
        session_id: str,
        request: dict[str, object],
        seat_token: str | None,
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        with self._locked_session(session_id) as hosted:
            player_id = _required_int(request.get("playerID"), "playerID")
            self._authenticate(hosted, player_id, seat_token, user_id=user_id)
            now = time.time()
            self._sync_lobby_state(hosted, now)
            if not hosted.started:
                raise OnlineServerError(HTTPStatus.CONFLICT, "game has not started")
            reaction_id = str(request.get("reactionID") or "").strip()
            if reaction_id not in REACTION_IDS:
                raise OnlineServerError(HTTPStatus.BAD_REQUEST, "invalid reaction")
            state = CEngine.snapshot(hosted.engine_pointer)
            entry = {
                "revision": len(hosted.reaction_log) + 1,
                "playerID": player_id,
                "reactionID": reaction_id,
                "year": int(state.year),
                "phase": int(state.phase),
                "createdAt": now,
            }
            hosted.reaction_log.append(entry)
            hosted.last_seen_at = now
            self._persist_reaction(hosted, entry, now)
            return self._update(hosted, player_id)

    def action_updates(
        self,
        session_id: str,
        viewer_id: int | None,
        after_revision: int,
        seat_token: str | None,
        *,
        user_id: str | None = None,
    ) -> dict[str, object]:
        with self._locked_session(session_id) as hosted:
            self._authenticate(hosted, viewer_id, seat_token, user_id=user_id)
            now = time.time()
            hosted.last_seen_at = now
            if viewer_id is not None:
                self._mark_seat_seen(hosted, viewer_id, now)
            self._sync_lobby_state(hosted, now)
            self._resolve_turn_timeouts(hosted, now)
            current_revision = len(hosted.action_log)
            if after_revision < 0 or after_revision > current_revision:
                raise OnlineServerError(HTTPStatus.CONFLICT, "unknown revision")
            self._persist_touch_if_needed(hosted)
            self._persist_finished_if_needed(hosted)
            return {
                "sessionID": hosted.session_id,
                "actionLogCount": current_revision,
                "updates": self._action_updates_since(
                    hosted,
                    viewer_id,
                    after_revision,
                ),
            }

    def _session(self, session_id: str) -> HostedSession:
        hosted = self._session_from_memory(session_id)
        if hosted is None:
            raise OnlineServerError(HTTPStatus.NOT_FOUND, "session not found")
        return hosted

    def _session_from_memory(self, session_id: str) -> HostedSession | None:
        normalized_invite = session_id.strip().upper()
        for hosted in self._sessions.values():
            if hosted.invite_code == normalized_invite:
                return hosted
        try:
            uuid.UUID(session_id)
        except ValueError:
            return None
        return self._sessions.get(session_id)

    def _load_persisted_session(self, session_id: str) -> HostedSession:
        if self.store is None:
            raise OnlineServerError(HTTPStatus.NOT_FOUND, "session not found")
        try:
            record = self._store_call(
                "load_session", self.store.load_session, session_id
            )
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online session recovery failed: {error}",
            ) from error
        if record is None:
            raise OnlineServerError(HTTPStatus.NOT_FOUND, "session not found")
        return self._hosted_from_persisted_record(record)

    def _hosted_from_persisted_record(
        self,
        record: dict[str, object],
    ) -> HostedSession:
        variants = _normalize_variants(record.get("variants"))
        controllers = _normalize_controllers(record.get("controllers"))
        seed = _required_int(record.get("seed"), "seed")
        pointer = self.engine.new_engine(
            seed,
            variants=_variants_native(variants),
            controllers=_controllers_native(controllers),
        )
        try:
            seats = [seat for seat in record.get("seats", []) if isinstance(seat, dict)]
            occupied_seats = {
                int(seat["player_id"])
                for seat in seats
                if bool(seat.get("occupied")) and "player_id" in seat
            }
            seat_user_ids = {
                int(seat["player_id"]): str(seat["user_id"])
                for seat in seats
                if "player_id" in seat and isinstance(seat.get("user_id"), str)
            }
            seat_token_hashes = {
                int(seat["player_id"]): str(seat["seat_token_hash"])
                for seat in seats
                if "player_id" in seat and isinstance(seat.get("seat_token_hash"), str)
            }
            seat_last_seen_at = {
                int(seat["player_id"]): float(seat["last_seen_at"])
                for seat in seats
                if "player_id" in seat
                and isinstance(seat.get("last_seen_at"), (int, float))
            }
            seat_timeouts = {
                int(seat["player_id"]): int(seat.get("timeouts") or 0)
                for seat in seats
                if "player_id" in seat
            }
            autopilot_seats = {
                int(seat["player_id"])
                for seat in seats
                if "player_id" in seat and bool(seat.get("autopilot"))
            }
            abandoned_seats = {
                int(seat["player_id"])
                for seat in seats
                if "player_id" in seat and bool(seat.get("abandoned"))
            }
            now = time.time()
            hosted = HostedSession(
                session_id=str(record["session_id"]),
                invite_code=str(record.get("invite_code") or ""),
                engine_pointer=pointer,
                seed=seed,
                variants=variants,
                controllers=controllers,
                ranked=_optional_bool(record.get("ranked"), True),
                browser_joinable=_optional_bool(record.get("browser_joinable"), True),
                population_kind=None,
                occupied_seats=occupied_seats,
                seat_tokens={},
                seat_token_hashes=seat_token_hashes,
                seat_user_ids=seat_user_ids,
                server_bot_controllers={},
                bot_action_ready_at={},
                created_by_user_id=str(record["created_by_user_id"])
                if isinstance(record.get("created_by_user_id"), str)
                else None,
                action_log=[],
                action_update_cache=[],
                created_at=float(record.get("created_at") or now),
                last_seen_at=float(record.get("last_seen_at") or now),
                last_persisted_touch_at=float(record.get("last_seen_at") or now),
                seat_last_seen_at=seat_last_seen_at,
                seat_timeouts=seat_timeouts,
                autopilot_seats=autopilot_seats,
                abandoned_seats=abandoned_seats,
                turn_player_id=_optional_int(record.get("turn_player_id")),
                turn_deadline_at=float(record["turn_deadline_at"])
                if isinstance(record.get("turn_deadline_at"), (int, float))
                else None,
                started=record.get("status") == "active",
                lobby_countdown_ends_at=float(record["lobby_countdown_ends_at"])
                if isinstance(record.get("lobby_countdown_ends_at"), (int, float))
                else None,
                reaction_log=[
                    dict(entry)
                    for entry in record.get("reactions", [])
                    if isinstance(entry, dict)
                ],
            )
            self._assign_server_bot_profiles(hosted)
            self._restore_server_bot_controllers(hosted)
            for entry in record.get("actions", []):
                if not isinstance(entry, dict):
                    continue
                action_json = entry.get("action")
                action = _action_from_json(action_json)
                source = (
                    action_json.get("source") if isinstance(action_json, dict) else None
                )
                if source in ("automatic", "autopilot"):
                    self.engine.apply_ai_action(pointer, action)
                else:
                    self.engine.apply_action(pointer, action)
                self._append_action_json(
                    hosted,
                    action_json
                    if isinstance(action_json, dict)
                    else _action_json(action),
                )
            print(
                f"Recovered online session {hosted.session_id} from persistence",
                flush=True,
            )
            return hosted
        except Exception:
            self.engine.free_engine(pointer)
            raise

    def _generate_invite_code(self) -> str:
        for _ in range(100):
            code = "".join(
                secrets.choice(INVITE_CODE_ALPHABET) for _ in range(INVITE_CODE_LENGTH)
            )
            if all(hosted.invite_code != code for hosted in self._sessions.values()):
                return code
        raise OnlineServerError(
            HTTPStatus.INTERNAL_SERVER_ERROR,
            "could not allocate invite code",
        )

    def _issue_seat_token(self, hosted: HostedSession, player_id: int) -> str:
        token = secrets.token_urlsafe(24)
        hosted.seat_tokens[player_id] = token
        hosted.seat_token_hashes[player_id] = seat_token_hash(token)
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
        expected_hash = hosted.seat_token_hashes.get(player_id)
        if not seat_token:
            raise OnlineServerError(HTTPStatus.UNAUTHORIZED, "invalid seat token")
        if expected is not None:
            if not secrets.compare_digest(expected, seat_token):
                raise OnlineServerError(HTTPStatus.UNAUTHORIZED, "invalid seat token")
        elif expected_hash is not None:
            if not secrets.compare_digest(expected_hash, seat_token_hash(seat_token)):
                raise OnlineServerError(HTTPStatus.UNAUTHORIZED, "invalid seat token")
        else:
            raise OnlineServerError(HTTPStatus.UNAUTHORIZED, "invalid seat token")
        expected_user_id = hosted.seat_user_ids.get(player_id)
        if self.auth_verifier is not None and user_id is None:
            raise OnlineServerError(HTTPStatus.UNAUTHORIZED, "missing auth token")
        if (
            self.auth_verifier is not None
            and expected_user_id is not None
            and user_id != expected_user_id
        ):
            raise OnlineServerError(HTTPStatus.UNAUTHORIZED, "invalid auth token")

    def _require_authenticated_user(self, user_id: str | None) -> None:
        if self.auth_verifier is not None and user_id is None:
            raise OnlineServerError(HTTPStatus.UNAUTHORIZED, "missing auth token")

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
            hosted = self._sessions.get(session_id)
            if hosted is None:
                continue
            if not hosted.lock.acquire(blocking=False):
                continue
            try:
                if (
                    self._sessions.get(session_id) is hosted
                    and now - hosted.last_seen_at > self.session_ttl_seconds
                ):
                    self._sessions.pop(session_id, None)
                    self.engine.free_engine(hosted.engine_pointer)
            finally:
                hosted.lock.release()

    def _first_available_seat(self, hosted: HostedSession) -> int:
        for player_id in self._open_seats(hosted):
            return player_id
        raise OnlineServerError(HTTPStatus.CONFLICT, "seat unavailable")

    def _seat_is_joinable(self, hosted: HostedSession, player_id: int) -> bool:
        return (
            not hosted.started
            and 0 <= player_id < PLAYER_COUNT
            and hosted.controllers[player_id] == "human"
            and player_id not in hosted.occupied_seats
        )

    def _seat_can_kick_players(
        self,
        hosted: HostedSession,
        player_id: int,
    ) -> bool:
        seat_user_id = hosted.seat_user_ids.get(player_id)
        if hosted.created_by_user_id is not None:
            return seat_user_id == hosted.created_by_user_id
        return player_id == 0

    def _open_seats(self, hosted: HostedSession) -> list[int]:
        return [
            player_id
            for player_id in range(PLAYER_COUNT)
            if self._seat_is_joinable(hosted, player_id)
        ]

    def _comrade_user_ids(self, user_id: str) -> set[str]:
        if self.store is None:
            return set()
        summary = self.store.comrades_for_user(user_id=user_id)
        return {
            str(comrade.get("user_id") or comrade.get("userID"))
            for comrade in summary.get("comrades", [])
            if comrade.get("user_id") or comrade.get("userID")
        }

    def _user_can_join_invited_session(
        self,
        hosted: HostedSession,
        user_id: str | None,
    ) -> bool:
        if user_id is None:
            return False
        if user_id in hosted.invited_user_ids:
            return True
        if user_id == hosted.created_by_user_id:
            return True
        return user_id in hosted.seat_user_ids.values()

    def _pending_invite_for_user(
        self,
        hosted: HostedSession,
        user_id: str,
    ) -> bool:
        if hosted.started or user_id in hosted.declined_invite_user_ids:
            return False
        if user_id not in hosted.invited_user_ids:
            return False
        if user_id in hosted.seat_user_ids.values():
            return False
        return bool(self._open_seats(hosted))

    def _invite_listing(
        self,
        hosted: HostedSession,
        user_id: str,
    ) -> dict[str, object]:
        listing = self._listing(hosted)
        listing.pop("inviteCode", None)
        profiles = listing.get("playerProfiles")
        host_profile: dict[str, object] | None = None
        if isinstance(profiles, list):
            for profile in profiles:
                if not isinstance(profile, dict):
                    continue
                if profile.get("userID") == hosted.created_by_user_id:
                    host_profile = profile
                    break
            if host_profile is None and profiles and isinstance(profiles[0], dict):
                host_profile = profiles[0]
        listing["hostProfile"] = host_profile or {}
        listing["invitedUserID"] = user_id
        return listing

    def _sync_lobby_state(
        self,
        hosted: HostedSession,
        now: float,
        *,
        persist: bool = True,
    ) -> None:
        if hosted.started:
            return
        if self._open_seats(hosted):
            if hosted.lobby_countdown_ends_at is not None:
                hosted.lobby_countdown_ends_at = None
                if persist:
                    self._persist_lobby_state(hosted, now)
            return
        if hosted.lobby_countdown_ends_at is None:
            hosted.lobby_countdown_ends_at = now + self.lobby_countdown_seconds
            if persist:
                self._persist_lobby_state(hosted, now)
            return
        if now < hosted.lobby_countdown_ends_at:
            return
        hosted.started = True
        hosted.lobby_countdown_ends_at = None
        if persist:
            self._persist_lobby_state(hosted, now)
        self._advance_automatic_turns(hosted, persist=persist, now=now)
        self._sync_turn_deadline(hosted, now, persist=persist)

    def _seat_server_bot(
        self,
        hosted: HostedSession,
        player_id: int,
        profile: dict[str, object],
        now: float,
    ) -> str:
        hosted.occupied_seats.add(player_id)
        seat_token = self._issue_seat_token(hosted, player_id)
        hosted.seat_user_ids[player_id] = str(profile["user_id"])
        hosted.server_bot_controllers[player_id] = str(profile["controller"])
        hosted.seat_last_seen_at[player_id] = now
        return seat_token

    def _join_server_bot_seat(
        self,
        hosted: HostedSession,
        player_id: int,
        profile: dict[str, object],
        now: float,
    ) -> None:
        previous_occupied_seats = set(hosted.occupied_seats)
        previous_seat_tokens = dict(hosted.seat_tokens)
        previous_seat_token_hashes = dict(hosted.seat_token_hashes)
        previous_seat_user_ids = dict(hosted.seat_user_ids)
        previous_server_bot_controllers = dict(hosted.server_bot_controllers)
        previous_last_seen_at = hosted.last_seen_at
        previous_seat_last_seen_at = dict(hosted.seat_last_seen_at)
        previous_autopilot_seats = set(hosted.autopilot_seats)
        previous_turn_deadline_at = hosted.turn_deadline_at
        previous_lobby_countdown_ends_at = hosted.lobby_countdown_ends_at
        seat_token = self._seat_server_bot(hosted, player_id, profile, now)
        hosted.last_seen_at = now
        try:
            self._persist_seat_joined(hosted, player_id, seat_token)
            self._sync_lobby_state(hosted, now)
            self._persist_finished_if_needed(hosted)
        except Exception:
            hosted.occupied_seats = previous_occupied_seats
            hosted.seat_tokens = previous_seat_tokens
            hosted.seat_token_hashes = previous_seat_token_hashes
            hosted.seat_user_ids = previous_seat_user_ids
            hosted.server_bot_controllers = previous_server_bot_controllers
            hosted.last_seen_at = previous_last_seen_at
            hosted.seat_last_seen_at = previous_seat_last_seen_at
            hosted.autopilot_seats = previous_autopilot_seats
            hosted.turn_deadline_at = previous_turn_deadline_at
            hosted.lobby_countdown_ends_at = previous_lobby_countdown_ends_at
            raise
        print(
            f"Server bot {profile['user_id']} joined online session "
            f"{hosted.session_id} as player {player_id}",
            flush=True,
        )

    def _restore_server_bot_controllers(self, hosted: HostedSession) -> None:
        for player_id, user_id in hosted.seat_user_ids.items():
            profile = SERVER_BOT_PROFILES_BY_ID.get(user_id)
            if profile is not None:
                hosted.server_bot_controllers[player_id] = str(profile["controller"])

    def _assign_server_bot_profiles(self, hosted: HostedSession) -> None:
        controller_counts: dict[str, int] = {}
        for player_id, controller in enumerate(hosted.controllers):
            profiles = SERVER_BOT_PROFILES_BY_CONTROLLER.get(controller)
            if not profiles or player_id in hosted.seat_user_ids:
                continue
            count = controller_counts.get(controller, 0)
            controller_counts[controller] = count + 1
            offset = int(
                hashlib.sha256(
                    f"{hosted.session_id}:{controller}".encode("utf-8")
                ).hexdigest()[:8],
                16,
            )
            profile = profiles[(offset + count) % len(profiles)]
            self._seat_server_bot(hosted, player_id, profile, hosted.created_at)

    def _listing(self, hosted: HostedSession) -> dict[str, object]:
        now = time.time()
        return {
            "sessionID": hosted.session_id,
            "inviteCode": hosted.invite_code,
            "openSeats": self._open_seats(hosted),
            "occupiedSeats": sorted(hosted.occupied_seats),
            "controllers": hosted.controllers,
            "ranked": hosted.ranked,
            "browserJoinable": hosted.browser_joinable,
            "playerProfiles": self._player_profiles(hosted),
            "seatPresence": self._seat_presence_json(hosted, now),
            "turnPlayerID": hosted.turn_player_id,
            "turnDeadlineAt": hosted.turn_deadline_at,
            "actionLogCount": len(hosted.action_log),
            "started": hosted.started,
            "lobbyCountdownEndsAt": hosted.lobby_countdown_ends_at,
            "createdAt": hosted.created_at,
            "expiresAt": hosted.last_seen_at + self.session_ttl_seconds,
        }

    def _expires_at(self, hosted: HostedSession) -> float:
        return hosted.last_seen_at + self.session_ttl_seconds

    def _persist_session_created(self, hosted: HostedSession) -> None:
        if self.store is None:
            return
        try:
            self._store_call(
                "create_session",
                self.store.create_session,
                session_id=hosted.session_id,
                invite_code=hosted.invite_code,
                seed=hosted.seed,
                variants=hosted.variants,
                controllers=hosted.controllers,
                ranked=hosted.ranked,
                browser_joinable=hosted.browser_joinable,
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
            self._store_call(
                "join_seat",
                self.store.join_seat,
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
        revision = len(hosted.action_log)
        self._enqueue_store_call(
            "append_action",
            self.store.append_action,
            session_id=hosted.session_id,
            revision=revision,
            player_id=player_id,
            action=action,
            updated_at=hosted.last_seen_at,
            expires_at=self._expires_at(hosted),
        )
        hosted.last_persisted_touch_at = hosted.last_seen_at

    def _persist_reaction(
        self,
        hosted: HostedSession,
        reaction: dict[str, object],
        now: float,
    ) -> None:
        if self.store is None:
            return
        self._enqueue_store_call(
            "append_reaction",
            self.store.append_reaction,
            session_id=hosted.session_id,
            revision=int(reaction["revision"]),
            player_id=int(reaction["playerID"]),
            reaction_id=str(reaction["reactionID"]),
            year=int(reaction["year"]),
            phase=int(reaction["phase"]),
            created_at=now,
            expires_at=self._expires_at(hosted),
        )
        hosted.last_persisted_touch_at = now

    def _persist_touch_if_needed(self, hosted: HostedSession) -> None:
        if self.store is None:
            return
        if (
            hosted.last_seen_at - hosted.last_persisted_touch_at
            < PERSISTED_TOUCH_INTERVAL_SECONDS
        ):
            return
        self._enqueue_store_call(
            "touch_session",
            self.store.touch_session,
            session_id=hosted.session_id,
            updated_at=hosted.last_seen_at,
            expires_at=self._expires_at(hosted),
        )
        hosted.last_persisted_touch_at = hosted.last_seen_at

    def _persist_turn_state(self, hosted: HostedSession, now: float) -> None:
        if self.store is None:
            return
        self._enqueue_store_call(
            "update_turn_state",
            self.store.update_turn_state,
            session_id=hosted.session_id,
            turn_player_id=hosted.turn_player_id,
            turn_deadline_at=hosted.turn_deadline_at,
            updated_at=now,
            expires_at=self._expires_at(hosted),
        )
        hosted.last_persisted_touch_at = now

    def _persist_lobby_state(self, hosted: HostedSession, now: float) -> None:
        if self.store is None:
            return
        self._enqueue_store_call(
            "update_lobby_state",
            self.store.update_lobby_state,
            session_id=hosted.session_id,
            started=hosted.started,
            lobby_countdown_ends_at=hosted.lobby_countdown_ends_at,
            updated_at=now,
            expires_at=self._expires_at(hosted),
        )
        hosted.last_persisted_touch_at = now

    def _persist_seat_seen(
        self,
        hosted: HostedSession,
        player_id: int,
        now: float,
    ) -> None:
        if self.store is None:
            return
        self._enqueue_store_call(
            "touch_seat",
            self.store.touch_seat,
            session_id=hosted.session_id,
            player_id=player_id,
            updated_at=now,
            expires_at=self._expires_at(hosted),
        )
        hosted.last_persisted_touch_at = now

    def _persist_seat_timeout(
        self,
        hosted: HostedSession,
        player_id: int,
        now: float,
    ) -> None:
        if self.store is None:
            return
        self._enqueue_store_call(
            "record_seat_timeout",
            self.store.record_seat_timeout,
            session_id=hosted.session_id,
            player_id=player_id,
            timeouts=hosted.seat_timeouts.get(player_id, 0),
            autopilot=player_id in hosted.autopilot_seats,
            updated_at=now,
            expires_at=self._expires_at(hosted),
            revision=len(hosted.action_log),
        )
        hosted.last_persisted_touch_at = now

    def _persist_seat_abandoned(
        self,
        hosted: HostedSession,
        player_id: int,
        now: float,
    ) -> dict[str, object] | None:
        if self.store is None:
            return None
        try:
            penalty = self._store_call(
                "abandon_seat",
                self.store.abandon_seat,
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

    def _persist_lobby_seat_left(
        self,
        hosted: HostedSession,
        player_id: int,
        now: float,
    ) -> None:
        if self.store is None:
            return
        try:
            self._store_call(
                "leave_lobby_seat",
                self.store.leave_lobby_seat,
                session_id=hosted.session_id,
                player_id=player_id,
                updated_at=now,
                expires_at=self._expires_at(hosted),
                revision=len(hosted.action_log),
            )
            hosted.last_persisted_touch_at = now
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online lobby leave persistence failed: {error}",
            ) from error

    def _expire_empty_lobby(self, hosted: HostedSession, now: float) -> None:
        if self.store is not None:
            try:
                self._store_call(
                    "expire_session",
                    self.store.expire_session,
                    session_id=hosted.session_id,
                    updated_at=now,
                    expires_at=now,
                )
                hosted.last_persisted_touch_at = now
            except Exception as error:
                raise OnlineServerError(
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                    f"online lobby expiration failed: {error}",
                ) from error
        with self._lock:
            if self._sessions.get(hosted.session_id) is hosted:
                self._sessions.pop(hosted.session_id, None)
                self.engine.free_engine(hosted.engine_pointer)

    def _persist_seat_kicked(
        self,
        hosted: HostedSession,
        player_id: int,
        now: float,
    ) -> None:
        if self.store is None:
            return
        try:
            self._store_call(
                "kick_seat",
                self.store.kick_seat,
                session_id=hosted.session_id,
                player_id=player_id,
                updated_at=now,
                expires_at=self._expires_at(hosted),
                revision=len(hosted.action_log),
            )
            hosted.last_persisted_touch_at = now
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online kick persistence failed: {error}",
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

    def _effective_controller(self, hosted: HostedSession, player_id: int) -> str:
        return hosted.server_bot_controllers.get(
            player_id,
            hosted.controllers[player_id],
        )

    def _should_delay_bot_action(self, hosted: HostedSession, player_id: int) -> bool:
        return (
            hosted.population_kind != "rating_seed"
            and hosted.browser_joinable
            and "human" in hosted.controllers
            and self._effective_controller(hosted, player_id) != "human"
        )

    def _bot_action_is_ready(
        self,
        hosted: HostedSession,
        player_id: int,
        now: float,
    ) -> bool:
        if not self._should_delay_bot_action(hosted, player_id):
            hosted.bot_action_ready_at.pop(player_id, None)
            return True
        ready_at = hosted.bot_action_ready_at.get(player_id)
        if ready_at is None:
            hosted.bot_action_ready_at[player_id] = now + self._bot_action_delay(
                hosted,
                player_id,
            )
            return False
        return now >= ready_at

    def _bot_action_delay(self, hosted: HostedSession, player_id: int) -> float:
        digest = hashlib.sha256(
            (
                f"{hosted.session_id}:{player_id}:"
                f"{len(hosted.action_log)}:{hosted.seat_user_ids.get(player_id, '')}"
            ).encode("utf-8")
        ).digest()
        jitter = int.from_bytes(digest[:4], "big") / 0xFFFFFFFF
        return (
            BOT_HUMAN_GAME_ACTION_DELAY_MIN_SECONDS
            + (
                BOT_HUMAN_GAME_ACTION_DELAY_MAX_SECONDS
                - BOT_HUMAN_GAME_ACTION_DELAY_MIN_SECONDS
            )
            * jitter
        )

    def _sync_turn_deadline(
        self,
        hosted: HostedSession,
        now: float,
        *,
        persist: bool = True,
    ) -> None:
        if not hosted.started:
            if hosted.turn_player_id is None and hosted.turn_deadline_at is None:
                return
            hosted.turn_player_id = None
            hosted.turn_deadline_at = None
            if persist:
                self._persist_turn_state(hosted, now)
            return
        player_id = self.engine.waiting_player(hosted.engine_pointer)
        if (
            player_id < 0
            or player_id >= PLAYER_COUNT
            or self._effective_controller(hosted, player_id) != "human"
            or player_id in hosted.autopilot_seats
        ):
            next_player_id: int | None = None
            next_deadline: float | None = None
        else:
            next_player_id = player_id
            if (
                hosted.turn_player_id == player_id
                and hosted.turn_deadline_at is not None
            ):
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
        if not hosted.started:
            return
        for _ in range(200):
            previous_action_count = len(hosted.action_log)
            previous_player_id = self.engine.waiting_player(hosted.engine_pointer)
            self._advance_automatic_turns(hosted)
            player_id = self.engine.waiting_player(hosted.engine_pointer)
            if player_id < 0 or player_id >= PLAYER_COUNT:
                self._sync_turn_deadline(hosted, now)
                return
            if self._effective_controller(hosted, player_id) != "human":
                if (
                    player_id == previous_player_id
                    and len(hosted.action_log) == previous_action_count
                ):
                    return
                continue
            if player_id in hosted.autopilot_seats:
                if not self._apply_autopilot_action(hosted, player_id, now):
                    self._sync_turn_deadline(hosted, now)
                    return
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
            applied = self._apply_autopilot_action(hosted, player_id, now)
            self._persist_seat_timeout(hosted, player_id, now)
            if forced_abandon:
                self._persist_seat_abandoned(hosted, player_id, now)
            self._sync_turn_deadline(hosted, now)
            self._persist_finished_if_needed(hosted)
            if not applied:
                return
            if int(CEngine.snapshot(hosted.engine_pointer).phase) == PHASE_GAME_OVER:
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
    ) -> bool:
        try:
            action = self.engine.heuristic_action(hosted.engine_pointer)
            if action.player_id != player_id:
                actions = self._legal_actions_for_player(hosted, player_id)
                if not actions:
                    return False
                action = actions[0]
            if hasattr(self.engine, "apply_ai_action"):
                self.engine.apply_ai_action(hosted.engine_pointer, action)
            elif hasattr(self.engine, "apply_policy_action"):
                self.engine.apply_policy_action(hosted.engine_pointer, action)
            else:
                self.engine.apply_action(hosted.engine_pointer, action)
        except Exception as error:
            raise OnlineServerError(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                f"online autopilot action failed: {error}",
            ) from error
        action_json = self._append_action(hosted, action, source="autopilot")
        hosted.last_seen_at = now
        self._persist_action_appended(hosted, player_id, action_json)
        self._advance_automatic_turns(hosted)
        return True

    def _persist_finished_if_needed(self, hosted: HostedSession) -> None:
        if hosted.stats_recorded:
            return
        if self.store is None:
            return
        state = CEngine.snapshot(hosted.engine_pointer)
        if int(state.phase) != PHASE_GAME_OVER:
            return
        hosted.stats_recorded = True
        winner_id = int(state.winner_id)
        scores = [
            int(state.game_scores[player_id]) for player_id in range(PLAYER_COUNT)
        ]
        rating_scores = [
            score - 10000 if player_id in hosted.abandoned_seats else score
            for player_id, score in enumerate(scores)
        ]
        ranks = _score_ranks(rating_scores)
        saboteur_exiled = any(
            int(state.exiled[year].cards[index].suit) == WRECKER_SUIT
            for year in range(MAX_YEARS + 1)
            for index in range(int(state.exiled[year].count))
        )
        results = [
            {
                "player_id": player_id,
                "user_id": hosted.seat_user_ids.get(player_id),
                "controller": self._effective_controller(hosted, player_id),
                "score": scores[player_id],
                "rank": ranks[player_id],
                "won": player_id == winner_id,
                "margin": scores[player_id]
                - max(
                    score
                    for other_player_id, score in enumerate(scores)
                    if other_player_id != player_id
                ),
                "medals": int(state.players[player_id].plot_medals)
                + int(state.players[player_id].medals),
                "full_five_year_game": int(state.variants.max_years) >= 5,
                "saboteur_exiled": saboteur_exiled,
                "exiled_plot_cards": sum(
                    1
                    for index in range(int(state.requisition_event_count))
                    if int(state.requisition_events[index].player_id) == player_id
                    and int(state.requisition_events[index].message_kind) == 1
                ),
            }
            for player_id in range(PLAYER_COUNT)
        ]
        self._enqueue_store_call(
            "finish_session",
            self.store.finish_session,
            session_id=hosted.session_id,
            results=results,
            ranked=hosted.ranked,
            updated_at=hosted.last_seen_at,
            expires_at=self._expires_at(hosted),
        )
        hosted.last_persisted_touch_at = hosted.last_seen_at

    def _append_action(
        self,
        hosted: HostedSession,
        action: KCAction,
        *,
        source: str,
    ) -> dict[str, object]:
        return self._append_action_json(hosted, _action_json(action, source=source))

    def _append_action_json(
        self,
        hosted: HostedSession,
        action_json: dict[str, object],
    ) -> dict[str, object]:
        action_json.setdefault("createdAt", time.time())
        hosted.action_log.append(dict(action_json))
        self._cache_action_update(hosted, hosted.action_log[-1])
        return hosted.action_log[-1]

    def _cache_action_update(
        self,
        hosted: HostedSession,
        action_json: dict[str, object],
        *,
        revision: int | None = None,
    ) -> None:
        revision = revision or len(hosted.action_log)
        updates_by_viewer = {
            str(player_id): self._update(hosted, player_id)
            for player_id in range(PLAYER_COUNT)
        }
        hosted.action_update_cache.append(
            {
                "revision": revision,
                "action": dict(action_json),
                "updatesByViewer": updates_by_viewer,
            }
        )

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
        with self._policy_lock:
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

    def _policy_action_for_controller(
        self,
        hosted: HostedSession,
        player_id: int,
        controller_name: str,
    ) -> KCAction | None:
        if not hasattr(self.engine, "policy_action"):
            return None
        state = CEngine.snapshot(hosted.engine_pointer)
        original_controller = int(state.controllers.seats[player_id])
        effective_controller = CONTROLLER_CODES[controller_name]
        state.controllers.seats[player_id] = effective_controller
        try:
            return self.engine.policy_action(
                hosted.engine_pointer,
                self._policy_model_buffer(controller_name),
            )
        finally:
            state.controllers.seats[player_id] = original_controller

    def _advance_automatic_turns(
        self,
        hosted: HostedSession,
        *,
        persist: bool = True,
        now: float | None = None,
    ) -> None:
        if not hosted.started:
            return
        for _ in range(200):
            action_now = time.time() if now is None else now
            player_id = self.engine.waiting_player(hosted.engine_pointer)
            if player_id < 0 or player_id >= PLAYER_COUNT:
                return
            controller_name = self._effective_controller(hosted, player_id)
            controller = CONTROLLER_CODES[controller_name]
            if controller == CONTROLLER_HUMAN:
                return
            if not self._bot_action_is_ready(hosted, player_id, action_now):
                return
            if controller == CONTROLLER_HEURISTIC_AI:
                if not hasattr(self.engine, "heuristic_action"):
                    status = self.engine.step_automatic(hosted.engine_pointer)
                    if status < 0:
                        raise OnlineServerError(
                            HTTPStatus.INTERNAL_SERVER_ERROR,
                            f"automatic controller failed with status {status}",
                        )
                    if status == 0:
                        return
                    continue
                action = self.engine.heuristic_action(hosted.engine_pointer)
            elif controller == CONTROLLER_POLICY_AI:
                if not hasattr(self.engine, "policy_action"):
                    if hosted.controllers[player_id] != controller_name:
                        if not hasattr(self.engine, "heuristic_action"):
                            return
                        action = self.engine.heuristic_action(hosted.engine_pointer)
                        if action.player_id != player_id:
                            actions = self._legal_actions_for_player(hosted, player_id)
                            if not actions:
                                return
                            action = actions[0]
                        try:
                            self.engine.apply_ai_action(hosted.engine_pointer, action)
                        except Exception as error:
                            raise OnlineServerError(
                                HTTPStatus.INTERNAL_SERVER_ERROR,
                                f"automatic controller failed: {error}",
                            ) from error
                        hosted.bot_action_ready_at.pop(player_id, None)
                        action_json = self._append_action(
                            hosted,
                            action,
                            source="automatic",
                        )
                        hosted.last_seen_at = action_now
                        if persist:
                            self._persist_action_appended(
                                hosted,
                                player_id,
                                action_json,
                            )
                        continue
                    status = self.engine.step_policy_automatic(
                        hosted.engine_pointer,
                        self._policy_model_buffer(controller_name),
                    )
                    if status < 0:
                        raise OnlineServerError(
                            HTTPStatus.INTERNAL_SERVER_ERROR,
                            f"automatic controller failed with status {status}",
                        )
                    if status == 0:
                        return
                    continue
                action = self._policy_action_for_controller(
                    hosted,
                    player_id,
                    controller_name,
                )
                if action is None:
                    actions = self._legal_actions_for_player(hosted, player_id)
                    if not actions:
                        return
                    action = actions[0]
            else:
                return
            if action.player_id != player_id:
                actions = self._legal_actions_for_player(hosted, player_id)
                if not actions:
                    return
                action = actions[0]
            try:
                self.engine.apply_ai_action(hosted.engine_pointer, action)
            except Exception as error:
                raise OnlineServerError(
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                    f"automatic controller failed: {error}",
                ) from error
            hosted.bot_action_ready_at.pop(player_id, None)
            action_json = self._append_action(hosted, action, source="automatic")
            hosted.last_seen_at = action_now
            if persist:
                self._persist_action_appended(hosted, player_id, action_json)
        raise OnlineServerError(
            HTTPStatus.INTERNAL_SERVER_ERROR,
            "automatic controller loop exceeded guard limit",
        )

    def _action_updates_since(
        self,
        hosted: HostedSession,
        viewer_id: int | None,
        after_revision: int,
    ) -> list[dict[str, object]]:
        updates: list[dict[str, object]] = []
        for index, action_json in enumerate(
            hosted.action_log[len(hosted.action_update_cache) :],
            start=len(hosted.action_update_cache) + 1,
        ):
            self._cache_action_update(hosted, action_json, revision=index)
        viewer_key = str(viewer_id) if viewer_id is not None else None
        for entry in hosted.action_update_cache:
            revision = int(entry.get("revision") or 0)
            if revision <= after_revision:
                continue
            updates_by_viewer = entry.get("updatesByViewer")
            cached_update = None
            if isinstance(updates_by_viewer, dict) and viewer_key is not None:
                cached_update = updates_by_viewer.get(viewer_key)
            updates.append(
                {
                    "revision": revision,
                    "action": entry.get("action", {}),
                    "update": cached_update
                    if isinstance(cached_update, dict)
                    else self._update(hosted, viewer_id),
                }
            )
        return updates

    def _legal_actions_for_player(
        self,
        hosted: HostedSession,
        player_id: int,
    ) -> list[KCAction]:
        if not hosted.started:
            return []
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
            hosted.started
            and viewer_id is not None
            and self.engine.waiting_player(hosted.engine_pointer) == viewer_id
        )
        return {
            "sessionID": hosted.session_id,
            "seed": hosted.seed,
            "inviteCode": hosted.invite_code,
            "viewerID": viewer_id,
            "actionLogCount": len(hosted.action_log),
            "started": hosted.started,
            "lobbyCountdownEndsAt": hosted.lobby_countdown_ends_at,
            "gameLogActions": self._game_log_actions(hosted, viewer_id),
            "reactions": [dict(entry) for entry in hosted.reaction_log],
            "isViewerTurn": is_viewer_turn,
            "legalActions": self._legal_action_json_for_player(hosted, viewer_id)
            if viewer_id is not None
            else [],
            "variants": hosted.variants,
            "controllers": hosted.controllers,
            "ranked": hosted.ranked,
            "browserJoinable": hosted.browser_joinable,
            "playerProfiles": self._player_profiles(hosted),
            "seatPresence": self._seat_presence_json(hosted, time.time()),
            "turnPlayerID": hosted.turn_player_id,
            "turnDeadlineAt": hosted.turn_deadline_at,
            "snapshot": self._snapshot_json(hosted, viewer_id),
        }

    def _game_log_actions(
        self,
        hosted: HostedSession,
        viewer_id: int | None,
    ) -> list[dict[str, object]]:
        game_over = (
            int(CEngine.snapshot(hosted.engine_pointer).phase) == PHASE_GAME_OVER
        )
        actions: list[dict[str, object]] = []
        for action in hosted.action_log:
            value = dict(action)
            player_id = _optional_int(value.get("playerID"))
            if not game_over and player_id != viewer_id and value.get("kind") in (2, 8):
                value["handCard"] = {"suit": -1, "value": -1}
                value["plotCard"] = {"suit": -1, "value": -1}
            actions.append(value)
        return actions

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
                    and (
                        self._effective_controller(hosted, player_id) != "human"
                        or now - hosted.seat_last_seen_at.get(player_id, 0.0)
                        <= PRESENCE_GRACE_SECONDS
                    )
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
            if not profile:
                profile = SERVER_BOT_PROFILES_BY_ID.get(user_id, {})
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
        state = CEngine.snapshot(hosted.engine_pointer)
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
            "jobBuckets": _job_buckets_json(state),
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
        visible = int(
            self.engine.lib.kc_visible_score(pointer, ctypes.c_int32(player_id))
        )
        final = int(self.engine.lib.kc_final_score(pointer, ctypes.c_int32(player_id)))
        if not game_over and viewer_id != player_id:
            final = visible
        return {
            "playerID": player_id,
            "visibleScore": visible,
            "finalScore": final,
        }


def _score_ranks(scores: list[int]) -> list[int]:
    return [1 + sum(1 for other in scores if other > score) for score in scores]


def _display_timestamp(value: object) -> str:
    if isinstance(value, (int, float)):
        return time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime(float(value)))
    return "the discipline period ends"


def _comrades_response(value: dict[str, object]) -> dict[str, object]:
    comrades = value.get("comrades")
    return {
        "userID": value.get("user_id") or value.get("userID"),
        "comradeCode": value.get("comrade_code") or value.get("comradeCode"),
        "comrades": [
            _comrade_profile_response(profile)
            for profile in comrades
            if isinstance(profile, dict)
        ]
        if isinstance(comrades, list)
        else [],
        "incomingRequests": [
            _comrade_profile_response(profile)
            for profile in value.get(
                "incoming_requests", value.get("incomingRequests", [])
            )
            if isinstance(profile, dict)
        ],
        "outgoingRequests": [
            _comrade_profile_response(profile)
            for profile in value.get(
                "outgoing_requests", value.get("outgoingRequests", [])
            )
            if isinstance(profile, dict)
        ],
    }


def _comrade_profile_response(profile: dict[str, object]) -> dict[str, object]:
    return {
        "userID": profile.get("user_id") or profile.get("userID"),
        "displayName": profile.get("display_name") or profile.get("displayName"),
        "avatarURL": profile.get("avatar_url") or profile.get("avatarURL"),
        "comradeCode": profile.get("comrade_code") or profile.get("comradeCode"),
        "requestedAt": profile.get("requested_at") or profile.get("requestedAt"),
        "isOnline": bool(profile.get("isOnline")),
        "inGame": bool(profile.get("inGame")),
        "inLobby": bool(profile.get("inLobby")),
        "stats": profile.get("stats") if isinstance(profile.get("stats"), dict) else {},
    }


def _next_interval_after(previous: float, now: float, interval: float) -> float:
    next_at = previous + interval
    while next_at <= now:
        next_at += interval
    return next_at


def _normalize_variants(value: object) -> dict[str, object]:
    default = {
        "deckType": 52,
        "maxYears": 5,
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
        int(variants["maxYears"]),
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


def _job_buckets_json(state: KCEngineSnapshot) -> list[dict[str, object]]:
    return [
        {
            "suit": suit,
            "cards": [
                {
                    **_card_json(state.job_buckets[suit].cards[index]),
                    "assignmentRound": int(state.job_bucket_tricks[suit][index]),
                }
                for index in range(int(state.job_buckets[suit].count))
            ],
        }
        for suit in range(SUIT_COUNT)
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
        1: "Card sent north.",
        2: "No matching card found.",
        3: "Drunkard exiled.",
        4: "Protected from requisition.",
    }.get(kind, "Requisition resolved.")


def _action_json(action: KCAction, *, source: str | None = None) -> dict[str, object]:
    value: dict[str, object] = {
        "kind": int(action.kind),
        "playerID": int(action.player_id),
        "suit": int(action.suit),
        "card": _card_json(action.card),
        "handCard": _card_json(action.hand_card),
        "plotCard": _card_json(action.plot_card),
        "plotZone": int(action.plot_zone),
        "targetSuit": int(action.target_suit),
    }
    if source is not None:
        value["source"] = source
    return value


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


def _optional_bool(value: object, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "1", "yes"}:
            return True
        if lowered in {"false", "0", "no"}:
            return False
    raise OnlineServerError(HTTPStatus.BAD_REQUEST, "expected boolean")


def _string_list(value: object) -> list[str]:
    if value is None:
        return []
    values = value if isinstance(value, list) else [value]
    result: list[str] = []
    for item in values:
        text = str(item).strip()
        if text:
            result.append(text)
    return result


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


def _required_int_query(query: dict[str, list[str]], key: str) -> int:
    value = _optional_int_query(query, key)
    if value is None:
        raise OnlineServerError(HTTPStatus.BAD_REQUEST, f"missing {key}")
    return value


def _authorization_header(headers: object) -> str | None:
    header_get = getattr(headers, "get", None)
    if not callable(header_get):
        return None
    value = header_get("Authorization")
    return str(value) if value else None


def _online_presence_key(user_id: str | None) -> str | None:
    if user_id:
        return f"user:{user_id}"
    return None


def _session_lookup_is_invite_code(value: str) -> bool:
    try:
        uuid.UUID(value)
    except ValueError:
        return True
    return False


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


def _percentile(samples: list[float], percentile: float) -> float:
    if not samples:
        return 0.0
    if len(samples) == 1:
        return samples[0]
    index = int(round((len(samples) - 1) * percentile))
    return samples[max(0, min(index, len(samples) - 1))]


def _route_label(path: str) -> str:
    parts = [part for part in path.split("/") if part]
    if not parts:
        return "/"
    if parts == ["health"]:
        return "/health"
    if parts == ["metrics"]:
        return "/metrics"
    if parts == ["sessions"]:
        return "/sessions"
    if parts == ["sessions", "invites"]:
        return "/sessions/invites"
    if parts == ["sessions", "matchmake"]:
        return "/sessions/matchmake"
    if parts[0] == "comrades":
        if len(parts) == 1:
            return "/comrades"
        return f"/comrades/{parts[1]}"
    if parts[0] != "sessions":
        return "/" + "/".join(parts)
    if len(parts) == 2:
        return "/sessions/{session}"
    if len(parts) == 3:
        return f"/sessions/{{session}}/{parts[2]}"
    if len(parts) == 5 and parts[2] == "players":
        return f"/sessions/{{session}}/players/{{player}}/{parts[4]}"
    return "/sessions/{session}/" + "/".join(parts[2:])
