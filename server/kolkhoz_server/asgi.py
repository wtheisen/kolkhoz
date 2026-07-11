"""Production ASGI transport for compatibility HTTP and realtime WebSockets."""

from __future__ import annotations

import asyncio
import json
import logging
import time
from http import HTTPStatus
from collections.abc import Callable
from typing import Any, Mapping
from urllib.parse import parse_qs

from .api import OnlineApplication, Request
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


class ASGIApplication:
    """Async transport adapter; game execution remains in ``OnlineApplication``."""

    def __init__(
        self,
        application: OnlineApplication,
        realtime_bus: RealtimeBus,
        *,
        connection_buffer_size: int = 64,
        max_message_bytes: int = 1_048_576,
        shutdown: Callable[[], None] | None = None,
        metrics: ServerMetrics | None = None,
        readiness: Callable[[], Mapping[str, bool]] | None = None,
        readiness_timeout_seconds: float = 1.0,
    ) -> None:
        self.application = application
        self.realtime_bus = realtime_bus
        self.connection_buffer_size = connection_buffer_size
        self.max_message_bytes = max_message_bytes
        self.shutdown = shutdown
        self.metrics = metrics or ServerMetrics()
        self.readiness = readiness
        self.readiness_timeout_seconds = readiness_timeout_seconds

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
        body = bytearray()
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            body.extend(message.get("body", b""))
            if not message.get("more_body", False):
                break
        method = scope["method"].upper()
        route = _route_label(scope.get("path", "/"))
        started = time.perf_counter()
        status = int(HTTPStatus.INTERNAL_SERVER_ERROR)
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
                Request(method, _target(scope), _headers(scope), payload),
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

        headers = _headers(scope)
        if not _header(headers, "authorization") or not _header(
            headers, "x-kolkhoz-seat-token"
        ):
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
                catch_up = await self._dispatch_get(
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
                updates = await self._dispatch_get(
                    f"/sessions/{session_id}/actions?viewerID={viewer_id}"
                    f"&afterRevision={revision}",
                    headers,
                )
                revision = int(updates["actionLogCount"])
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


def _realtime_session_id(path: str) -> str | None:
    parts = [part for part in path.split("/") if part]
    if len(parts) == 3 and parts[0] == "sessions" and parts[2] == "realtime":
        return parts[1]
    return None


def _route_label(path: str) -> str:
    parts = [part for part in path.split("/") if part]
    if parts and parts[0] in {"sessions", "profiles"} and len(parts) > 1:
        parts[1] = "{id}"
    return "/" + "/".join(parts)
