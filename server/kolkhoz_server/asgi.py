"""Production ASGI transport for compatibility HTTP and realtime WebSockets."""

from __future__ import annotations

import asyncio
import json
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
    ) -> None:
        self.application = application
        self.realtime_bus = realtime_bus
        self.connection_buffer_size = connection_buffer_size
        self.max_message_bytes = max_message_bytes
        self.shutdown = shutdown

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
        if method == "OPTIONS":
            await self._http_response(send, HTTPStatus.NO_CONTENT, None)
            return
        try:
            payload = json.loads(body or b"{}")
            if not isinstance(payload, dict):
                payload = {}
            response = await asyncio.to_thread(
                self.application.dispatch,
                Request(method, _target(scope), _headers(scope), payload),
            )
            await self._http_response(send, response.status, response.body)
        except ServerError as error:
            await self._http_response(send, error.status, {"error": error.message})
        except RevisionConflict as error:
            await self._http_response(
                send,
                HTTPStatus.CONFLICT,
                {"error": str(error), "currentRevision": error.actual},
            )
        except GameNotFound:
            await self._http_response(
                send, HTTPStatus.NOT_FOUND, {"error": "game not found"}
            )
        except (json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
            await self._http_response(
                send, HTTPStatus.BAD_REQUEST, {"error": str(error)}
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
                    overflow.set()
                    stop.set()
                    return
                if message is None:
                    continue
                result = buffer.enqueue(message)
                if result in {EnqueueResult.FULL, EnqueueResult.OVERSIZED}:
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
