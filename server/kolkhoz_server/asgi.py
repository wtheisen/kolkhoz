"""Production ASGI transport for compatibility HTTP and realtime WebSockets."""

from __future__ import annotations

import asyncio
import hashlib
import ipaddress
import json
import logging
import threading
import time
from collections import OrderedDict, deque
from http import HTTPStatus
from collections.abc import Callable
from typing import Any, Mapping
from urllib.parse import parse_qs

from .api import OnlineApplication, Request
from .contracts import merge_session_engine_projection, privacy_safe_action_log
from .distributed import (
    BoundedEventBuffer,
    BoundedIdempotencyWindow,
    EnqueueResult,
    RealtimeBus,
    RealtimeSubscriberOverflow,
)
from .errors import ServerError
from .metrics import ServerMetrics
from .store import GameNotFound, RevisionConflict


_ALLOWED_HEADERS = (
    "Content-Type, Accept, Authorization, X-Kolkhoz-Seat-Token, X-Kolkhoz-Device-ID"
)

DEFAULT_REQUEST_RATE_LIMITS: dict[str, tuple[int, float]] = {
    "identity.guest": (20, 600.0),
    "identity.platform": (30, 600.0),
    "identity.email": (10, 600.0),
    "identity.link_redeem.source": (20, 600.0),
    "identity.link_redeem.account": (8, 600.0),
    "sessions.create": (30, 600.0),
    "sessions.join.source": (30, 600.0),
    "sessions.join.account": (60, 600.0),
    "realtime.connect": (30, 60.0),
}


class RequestRateLimiter:
    """Bound source- and credential-scoped controls for public entry points."""

    def __init__(
        self,
        rules: Mapping[str, tuple[int, float]] | None = None,
        *,
        capacity: int = 50_000,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self.rules = dict(rules or DEFAULT_REQUEST_RATE_LIMITS)
        if capacity <= 0 or any(
            limit <= 0 or window <= 0 for limit, window in self.rules.values()
        ):
            raise ValueError("rate limits and capacity must be positive")
        self.capacity = capacity
        self.clock = clock
        self._entries: OrderedDict[tuple[str, str], deque[float]] = OrderedDict()
        self._lock = threading.Lock()

    def retry_after(self, method: str, path: str, source: str) -> int | None:
        scope = _rate_limit_scope(method, path)
        if scope is None:
            return None
        return self.retry_after_scope(scope, source)

    def retry_after_scope(self, scope: str, key: str) -> int | None:
        rule = self.rules.get(scope)
        if rule is None:
            return None
        limit, window = rule
        now = self.clock()
        entry_key = (scope, key)
        with self._lock:
            attempts = self._entries.setdefault(entry_key, deque())
            while attempts and attempts[0] <= now - window:
                attempts.popleft()
            self._entries.move_to_end(entry_key)
            if len(attempts) >= limit:
                return max(1, int(window - (now - attempts[0])))
            attempts.append(now)
            while len(self._entries) > self.capacity:
                self._entries.popitem(last=False)
        return None


class ASGIApplication:
    """Async transport adapter; game execution remains in ``OnlineApplication``."""

    def __init__(
        self,
        application: OnlineApplication,
        realtime_bus: RealtimeBus,
        *,
        connection_buffer_size: int = 64,
        max_message_bytes: int = 1_048_576,
        max_request_body_bytes: int = 1_048_576,
        request_body_timeout_seconds: float = 15.0,
        shutdown: Callable[[], None] | None = None,
        metrics: ServerMetrics | None = None,
        readiness: Callable[[], Mapping[str, bool]] | None = None,
        readiness_timeout_seconds: float = 1.0,
        rate_limiter: RequestRateLimiter | None = None,
    ) -> None:
        self.application = application
        self.realtime_bus = realtime_bus
        self.connection_buffer_size = connection_buffer_size
        self.max_message_bytes = max_message_bytes
        self.max_request_body_bytes = max_request_body_bytes
        if request_body_timeout_seconds <= 0:
            raise ValueError("request body timeout must be positive")
        self.request_body_timeout_seconds = request_body_timeout_seconds
        self.shutdown = shutdown
        self.metrics = metrics or ServerMetrics()
        self.readiness = readiness
        self.readiness_timeout_seconds = readiness_timeout_seconds
        self.rate_limiter = rate_limiter or RequestRateLimiter()
        self._catch_up_tasks: dict[
            tuple[str, str, str], asyncio.Task[dict[str, Any]]
        ] = {}
        self._catch_up_lock = asyncio.Lock()

    async def __call__(self, scope: dict[str, Any], receive: Any, send: Any) -> None:
        if scope["type"] == "http":
            await self._http(scope, receive, send)
            return
        if scope["type"] == "websocket":
            await self._websocket(scope, receive, send)
            return
        if scope["type"] == "lifespan":
            await self._lifespan(receive, send)
            return
        raise RuntimeError(f"unsupported ASGI scope: {scope['type']}")

    async def _http(self, scope: dict[str, Any], receive: Any, send: Any) -> None:
        method = scope["method"].upper()
        route = _route_label(scope.get("path", "/"))
        started = time.perf_counter()
        status = int(HTTPStatus.INTERNAL_SERVER_ERROR)
        headers = _headers(scope)
        retry_after = self.rate_limiter.retry_after(
            method,
            scope.get("path", "/"),
            _client_address(scope, headers),
        )
        account_scope = _credential_rate_limit_scope(method, scope.get("path", "/"))
        if retry_after is None and account_scope is not None:
            authorization = headers.get("authorization")
            if authorization:
                account_key = hashlib.sha256(authorization.encode()).hexdigest()
                retry_after = self.rate_limiter.retry_after_scope(
                    account_scope, account_key
                )
        if retry_after is not None:
            status = int(HTTPStatus.TOO_MANY_REQUESTS)
            await self._http_response(
                send,
                HTTPStatus.TOO_MANY_REQUESTS,
                {"error": "request rate limit exceeded", "retryAfter": retry_after},
            )
            self.metrics.record_route(
                method, route, status, time.perf_counter() - started
            )
            return
        body = bytearray()
        body_deadline = (
            asyncio.get_running_loop().time() + self.request_body_timeout_seconds
        )
        while True:
            try:
                message = await asyncio.wait_for(
                    receive(),
                    timeout=max(0.0, body_deadline - asyncio.get_running_loop().time()),
                )
            except TimeoutError:
                status = int(HTTPStatus.REQUEST_TIMEOUT)
                await self._http_response(
                    send,
                    HTTPStatus.REQUEST_TIMEOUT,
                    {"error": "request body timed out"},
                )
                self.metrics.record_route(
                    method, route, status, time.perf_counter() - started
                )
                return
            if message["type"] == "http.disconnect":
                return
            body.extend(message.get("body", b""))
            if len(body) > self.max_request_body_bytes:
                status = int(HTTPStatus.REQUEST_ENTITY_TOO_LARGE)
                await self._http_response(
                    send,
                    HTTPStatus.REQUEST_ENTITY_TOO_LARGE,
                    {"error": "request body is too large"},
                )
                self.metrics.record_route(
                    method, route, status, time.perf_counter() - started
                )
                return
            if not message.get("more_body", False):
                break
        if method == "OPTIONS":
            await self._http_response(send, HTTPStatus.NO_CONTENT, None)
            self.metrics.record_route(
                method, route, HTTPStatus.NO_CONTENT, time.perf_counter() - started
            )
            return
        try:
            if scope.get("path") == "/metrics/prometheus":
                body = self.metrics.prometheus(self.application).encode()
                await self._raw_http_response(
                    send,
                    HTTPStatus.OK,
                    body,
                    b"text/plain; version=0.0.4; charset=utf-8",
                )
                status = int(HTTPStatus.OK)
                return
            if scope.get("path") == "/ready":
                if self.readiness is None:
                    raise ServerError(
                        HTTPStatus.SERVICE_UNAVAILABLE,
                        "readiness checks are not configured",
                    )
                try:
                    checks = await asyncio.wait_for(
                        asyncio.to_thread(self.readiness),
                        timeout=self.readiness_timeout_seconds,
                    )
                except Exception as error:
                    self.metrics.increment("readiness.failures")
                    self.metrics.gauge("readiness.ready", 0)
                    raise ServerError(
                        HTTPStatus.SERVICE_UNAVAILABLE, "dependencies are unavailable"
                    ) from error
                if not checks or not all(checks.values()):
                    self.metrics.increment("readiness.failures")
                    self.metrics.gauge("readiness.ready", 0)
                    raise ServerError(
                        HTTPStatus.SERVICE_UNAVAILABLE, "dependencies are unavailable"
                    )
                self.metrics.increment("readiness.successes")
                self.metrics.gauge("readiness.ready", 1)
                await self._http_response(
                    send, HTTPStatus.OK, {"status": "ready", "checks": checks}
                )
                status = int(HTTPStatus.OK)
                return
            payload = json.loads(body or b"{}")
            if not isinstance(payload, dict):
                payload = {}
            response = await asyncio.to_thread(
                self.application.dispatch,
                Request(method, _target(scope), headers, payload),
            )
            await self._http_response(send, response.status, response.body)
            status = int(response.status)
        except ServerError as error:
            status = int(error.status)
            await self._http_response(send, error.status, {"error": error.message})
        except RevisionConflict as error:
            status = int(HTTPStatus.CONFLICT)
            await self._http_response(
                send,
                HTTPStatus.CONFLICT,
                {"error": str(error), "currentRevision": error.actual},
            )
        except GameNotFound:
            status = int(HTTPStatus.NOT_FOUND)
            await self._http_response(
                send, HTTPStatus.NOT_FOUND, {"error": "game not found"}
            )
        except KeyError:
            logging.exception("request failed due to missing internal key")
            await self._http_response(
                send,
                HTTPStatus.INTERNAL_SERVER_ERROR,
                {"error": "internal server error"},
            )
        except (json.JSONDecodeError, TypeError, ValueError) as error:
            status = int(HTTPStatus.BAD_REQUEST)
            await self._http_response(
                send, HTTPStatus.BAD_REQUEST, {"error": str(error)}
            )
        finally:
            self.metrics.record_route(
                method, route, status, time.perf_counter() - started
            )

    async def _websocket(self, scope: dict[str, Any], receive: Any, send: Any) -> None:
        if (await receive())["type"] != "websocket.connect":
            return
        headers = _headers(scope)
        if (
            self.rate_limiter.retry_after(
                "WEBSOCKET",
                scope.get("path", "/"),
                _client_address(scope, headers),
            )
            is not None
        ):
            await send({"type": "websocket.close", "code": 1013})
            return
        match = _realtime_session_id(scope.get("path", ""))
        query = parse_qs(scope.get("query_string", b"").decode("ascii"))
        viewer_values = query.get("viewerID")
        if match is None or not viewer_values:
            await send({"type": "websocket.close", "code": 1008})
            return
        try:
            viewer_id = int(viewer_values[0])
            after_revision = int((query.get("afterRevision") or ["-1"])[0])
        except ValueError:
            await send({"type": "websocket.close", "code": 1008})
            return

        if not _header(headers, "authorization") or not _header(
            headers, "x-kolkhoz-seat-token"
        ):
            await send({"type": "websocket.close", "code": 1008})
            return

        try:
            authenticate = getattr(self.application, "authenticate_realtime", None)
            if authenticate is not None:
                await asyncio.to_thread(authenticate, match, viewer_id, headers)
            else:
                await self._dispatch_get(
                    f"/sessions/{match}/state?viewerID={viewer_id}", headers
                )
        except ServerError:
            await send({"type": "websocket.close", "code": 1008})
            return

        subscription = await asyncio.to_thread(
            self.realtime_bus.subscribe, f"session:{match}"
        )
        self.metrics.increment("realtime.connections")
        self.metrics.gauge(
            "realtime.subscribers",
            float(getattr(self.realtime_bus, "local_subscriber_count", 0)),
        )
        try:
            state = await self._dispatch_get(
                f"/sessions/{match}/state?viewerID={viewer_id}", headers
            )
            current_revision = int(state["actionLogCount"])
            if after_revision < -1 or after_revision > current_revision:
                raise ServerError(HTTPStatus.BAD_REQUEST, "invalid afterRevision")
            await send({"type": "websocket.accept"})
            await _send_json(send, {"type": "state", "update": state})
            if 0 <= after_revision < current_revision:
                catch_up = await self._coalesced_catch_up(
                    f"/sessions/{match}/actions?viewerID={viewer_id}"
                    f"&afterRevision={after_revision}",
                    headers,
                )
                await _send_json(send, {"type": "catchUp", "updates": catch_up})

            buffer = BoundedEventBuffer(
                self.connection_buffer_size,
                self.max_message_bytes,
                BoundedIdempotencyWindow(max(self.connection_buffer_size * 4, 64), 300),
            )
            await self._stream(
                receive,
                send,
                subscription,
                buffer,
                match,
                viewer_id,
                headers,
                current_revision,
                state,
            )
        except ServerError:
            await send({"type": "websocket.close", "code": 1008})
        finally:
            await asyncio.to_thread(subscription.close)
            self.metrics.gauge(
                "realtime.subscribers",
                float(getattr(self.realtime_bus, "local_subscriber_count", 0)),
            )

    async def _stream(
        self,
        receive: Any,
        send: Any,
        subscription: Any,
        buffer: BoundedEventBuffer,
        session_id: str,
        viewer_id: int,
        headers: Mapping[str, str],
        revision: int,
        current_update: Mapping[str, Any],
    ) -> None:
        stop = asyncio.Event()
        overflow = asyncio.Event()

        async def receive_client() -> None:
            while True:
                message = await receive()
                if message["type"] == "websocket.disconnect":
                    stop.set()
                    return

        async def produce() -> None:
            while not stop.is_set():
                try:
                    message = await asyncio.to_thread(subscription.poll, 0.25)
                except RealtimeSubscriberOverflow:
                    self.metrics.increment("realtime.overflow")
                    overflow.set()
                    stop.set()
                    return
                if message is None:
                    continue
                result = buffer.enqueue(message)
                if result in {EnqueueResult.FULL, EnqueueResult.OVERSIZED}:
                    self.metrics.increment("realtime.overflow")
                    overflow.set()
                    stop.set()
                    return

        receiver = asyncio.create_task(receive_client())
        producer = asyncio.create_task(produce())
        try:
            while not stop.is_set():
                messages = buffer.drain(16)
                if not messages:
                    await asyncio.sleep(0.01)
                    continue
                highest = max(int(item.payload.get("revision", 0)) for item in messages)
                if highest <= revision:
                    continue
                direct = _direct_committed_updates(
                    session_id,
                    viewer_id,
                    revision,
                    current_update,
                    messages,
                )
                if direct is not None:
                    updates, current_update, revision = direct
                    remember = getattr(
                        self.application, "remember_update_context", None
                    )
                    if remember is not None:
                        remember(current_update)
                    self.metrics.increment("realtime.direct_projection")
                    await _send_json(
                        send,
                        {"type": "committed", "revision": revision, "updates": updates},
                    )
                    continue
                self.metrics.increment("realtime.catch_up")
                updates = await self._coalesced_catch_up(
                    f"/sessions/{session_id}/actions?viewerID={viewer_id}"
                    f"&afterRevision={revision}",
                    headers,
                )
                revision = int(updates["actionLogCount"])
                current_update = _latest_update(current_update, updates)
                await _send_json(
                    send,
                    {"type": "committed", "revision": revision, "updates": updates},
                )
            if overflow.is_set():
                await send({"type": "websocket.close", "code": 1013})
        finally:
            receiver.cancel()
            producer.cancel()
            await asyncio.gather(receiver, producer, return_exceptions=True)

    async def _dispatch_get(
        self, target: str, headers: Mapping[str, str]
    ) -> dict[str, Any]:
        response = await asyncio.to_thread(
            self.application.dispatch, Request("GET", target, headers, {})
        )
        if not isinstance(response.body, dict):
            raise ServerError(HTTPStatus.INTERNAL_SERVER_ERROR, "invalid server state")
        return response.body

    async def _coalesced_catch_up(
        self, target: str, headers: Mapping[str, str]
    ) -> dict[str, Any]:
        key = (
            target,
            _header(headers, "authorization") or "",
            _header(headers, "x-kolkhoz-seat-token") or "",
        )
        async with self._catch_up_lock:
            task = self._catch_up_tasks.get(key)
            if task is None:
                task = asyncio.create_task(self._dispatch_get(target, headers))
                self._catch_up_tasks[key] = task
        try:
            return await asyncio.shield(task)
        finally:
            if task.done():
                async with self._catch_up_lock:
                    if self._catch_up_tasks.get(key) is task:
                        self._catch_up_tasks.pop(key, None)

    @staticmethod
    async def _http_response(send: Any, status: int, value: object) -> None:
        body = (
            b"" if value is None else json.dumps(value, separators=(",", ":")).encode()
        )
        await send(
            {
                "type": "http.response.start",
                "status": int(status),
                "headers": [
                    (b"content-type", b"application/json"),
                    (b"access-control-allow-origin", b"*"),
                    (b"access-control-allow-methods", b"GET, POST, OPTIONS"),
                    (b"access-control-allow-headers", _ALLOWED_HEADERS.encode()),
                    (b"content-length", str(len(body)).encode()),
                ],
            }
        )
        await send({"type": "http.response.body", "body": body})

    @staticmethod
    async def _raw_http_response(
        send: Any, status: int, body: bytes, content_type: bytes
    ) -> None:
        await send(
            {
                "type": "http.response.start",
                "status": int(status),
                "headers": [
                    (b"content-type", content_type),
                    (b"content-length", str(len(body)).encode()),
                ],
            }
        )
        await send({"type": "http.response.body", "body": body})

    async def _lifespan(self, receive: Any, send: Any) -> None:
        while True:
            message = await receive()
            if message["type"] == "lifespan.startup":
                await send({"type": "lifespan.startup.complete"})
            elif message["type"] == "lifespan.shutdown":
                if self.shutdown is not None:
                    await asyncio.to_thread(self.shutdown)
                await send({"type": "lifespan.shutdown.complete"})
                return


async def _send_json(send: Any, value: object) -> None:
    await send(
        {
            "type": "websocket.send",
            "text": json.dumps(value, separators=(",", ":")),
        }
    )


def _target(scope: Mapping[str, Any]) -> str:
    path = scope.get("raw_path") or scope.get("path", "/").encode()
    query = scope.get("query_string", b"")
    return path.decode("ascii") + ("?" + query.decode("ascii") if query else "")


def _headers(scope: Mapping[str, Any]) -> dict[str, str]:
    return {
        key.decode("latin-1"): value.decode("latin-1")
        for key, value in scope.get("headers", [])
    }


def _header(headers: Mapping[str, str], name: str) -> str | None:
    return headers.get(name) or headers.get(name.title())


def _client_address(scope: Mapping[str, Any], headers: Mapping[str, str]) -> str:
    client = scope.get("client")
    peer = str(client[0]) if isinstance(client, (tuple, list)) and client else "unknown"
    try:
        loopback = ipaddress.ip_address(peer).is_loopback
    except ValueError:
        loopback = False
    forwarded = _header(headers, "x-forwarded-for")
    if loopback and forwarded:
        candidate = forwarded.split(",", 1)[0].strip()
        try:
            return _normalized_source_ip(candidate)
        except ValueError:
            pass
    try:
        return _normalized_source_ip(peer)
    except ValueError:
        return peer


def _normalized_source_ip(value: str) -> str:
    address = ipaddress.ip_address(value)
    if address.version == 6:
        return str(ipaddress.ip_network(f"{address}/64", strict=False))
    return str(address)


def _rate_limit_scope(method: str, path: str) -> str | None:
    if method == "WEBSOCKET" and _realtime_session_id(path) is not None:
        return "realtime.connect"
    if method != "POST":
        return None
    if path == "/identity/guest":
        return "identity.guest"
    if path.startswith("/identity/platform/"):
        return "identity.platform"
    if path == "/identity/email/code":
        return "identity.email"
    if path == "/identity/device-links/redeem":
        return "identity.link_redeem.source"
    if path == "/sessions":
        return "sessions.create"
    if _session_join_code(path) is not None:
        return "sessions.join.source"
    return None


def _session_join_code(path: str) -> str | None:
    parts = [part for part in path.split("/") if part]
    if len(parts) == 3 and parts[0] == "sessions" and parts[2] == "join":
        return parts[1]
    return None


def _credential_rate_limit_scope(method: str, path: str) -> str | None:
    if method != "POST":
        return None
    if path == "/identity/device-links/redeem":
        return "identity.link_redeem.account"
    if _session_join_code(path) is not None:
        return "sessions.join.account"
    return None


def _realtime_session_id(path: str) -> str | None:
    parts = [part for part in path.split("/") if part]
    if len(parts) == 3 and parts[0] == "sessions" and parts[2] == "realtime":
        return parts[1]
    return None


def _direct_committed_updates(
    session_id: str,
    viewer_id: int,
    revision: int,
    current_update: Mapping[str, Any],
    messages: list[Any],
) -> tuple[dict[str, Any], dict[str, Any], int] | None:
    """Build normal action frames without another authenticated state request.

    The game owner publishes one privacy-scoped engine projection per player. The
    gateway selects only the authenticated viewer's projection and carries forward
    session metadata from the full state sent when the WebSocket connected. Missing
    projections, revision gaps, and terminal transitions use durable catch-up.
    """

    pending = sorted(
        (
            message
            for message in messages
            if int(message.payload.get("revision", 0)) > revision
        ),
        key=lambda message: int(message.payload.get("revision", 0)),
    )
    expected = revision + 1
    latest = dict(current_update)
    frames: list[dict[str, Any]] = []
    for message in pending:
        committed_revision = int(message.payload.get("revision", 0))
        if committed_revision != expected:
            return None
        states = message.payload.get("statesByViewer")
        if not isinstance(states, Mapping):
            return None
        raw_state = states.get(str(viewer_id), states.get(viewer_id))
        action_payload = message.payload.get("payload")
        if not isinstance(raw_state, Mapping) or not isinstance(
            action_payload, Mapping
        ):
            return None

        if int(raw_state.get("phase", -1)) == 5:
            return None
        safe_action = privacy_safe_action_log(
            [action_payload], viewer_id, game_over=False
        )[0]
        action_log = [
            dict(action)
            for action in latest.get("gameLogActions", [])
            if isinstance(action, Mapping)
        ]
        action_log.append(safe_action)

        waiting = raw_state.get("waitingPlayer")
        turn_player_id = (
            waiting
            if isinstance(waiting, int)
            and not isinstance(waiting, bool)
            and waiting >= 0
            else None
        )
        turn_deadline_at = (
            latest.get("turnDeadlineAt")
            if latest.get("turnPlayerID") == turn_player_id
            else None
        )
        latest = merge_session_engine_projection(
            {**latest, "sessionID": session_id},
            raw_state,
            viewer_id=viewer_id,
            revision=committed_revision,
            started=bool(latest.get("started", True)),
            game_log_actions=action_log,
            turn_player_id=turn_player_id,
            turn_deadline_at=turn_deadline_at,
        )
        frames.append(
            {
                "revision": committed_revision,
                "action": safe_action,
                "update": dict(latest),
            }
        )
        expected += 1

    if not frames:
        return None
    final_revision = expected - 1
    response = {
        "sessionID": session_id,
        "actionLogCount": final_revision,
        "reactionLogCount": len(latest.get("reactions", [])),
        "updates": frames,
        "reactions": [],
        "resyncUpdate": None,
    }
    return response, latest, final_revision


def _latest_update(
    current: Mapping[str, Any], updates: Mapping[str, Any]
) -> dict[str, Any]:
    resync = updates.get("resyncUpdate")
    if isinstance(resync, Mapping):
        return dict(resync)
    frames = updates.get("updates")
    if isinstance(frames, list) and frames:
        update = frames[-1].get("update") if isinstance(frames[-1], Mapping) else None
        if isinstance(update, Mapping):
            return dict(update)
    return dict(current)


def _route_label(path: str) -> str:
    parts = [part for part in path.split("/") if part]
    if parts and parts[0] in {"sessions", "profiles"} and len(parts) > 1:
        parts[1] = "{id}"
    return "/" + "/".join(parts)
