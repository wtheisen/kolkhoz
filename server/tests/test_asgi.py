from __future__ import annotations

import asyncio
import json
import queue
import time
from dataclasses import dataclass
from typing import Any

from server.kolkhoz_server.api import Request, Response
from server.kolkhoz_server.asgi import ASGIApplication, _direct_committed_updates
from server.kolkhoz_server.distributed import RealtimeMessage
from server.kolkhoz_server.errors import ServerError


@dataclass
class _Subscription:
    messages: queue.Queue[RealtimeMessage]
    closed: bool = False

    def poll(self, timeout_seconds: float = 0.0) -> RealtimeMessage | None:
        try:
            return self.messages.get(timeout=timeout_seconds)
        except queue.Empty:
            return None

    def close(self) -> None:
        self.closed = True


class _Bus:
    def __init__(self) -> None:
        self.subscription = _Subscription(queue.Queue())
        self.topics: list[str] = []

    def subscribe(self, topic: str) -> _Subscription:
        self.topics.append(topic)
        return self.subscription

    def publish(self, message: RealtimeMessage) -> None:
        self.subscription.messages.put(message)


class _Application:
    def __init__(self) -> None:
        self.revision = 3
        self.requests: list[Request] = []

    def dispatch(self, request: Request) -> Response:
        self.requests.append(request)
        if request.target == "/health":
            return Response(200, {"status": "ok"})
        if request.target.startswith("/sessions/s1/state?viewerID=2"):
            self._authenticate(request)
            return Response(
                200,
                {
                    "sessionID": "s1",
                    "viewerID": 2,
                    "actionLogCount": self.revision,
                    "snapshot": {"private": "viewer-2"},
                },
            )
        if request.target.startswith("/sessions/s1/actions?viewerID=2"):
            self._authenticate(request)
            after = int(request.target.split("afterRevision=")[1])
            return Response(
                200,
                {
                    "sessionID": "s1",
                    "actionLogCount": self.revision,
                    "reactionLogCount": 0,
                    "updates": [
                        {"revision": value, "update": {"viewerID": 2}}
                        for value in range(after + 1, self.revision + 1)
                    ],
                    "reactions": [],
                    "resyncUpdate": None,
                },
            )
        raise ServerError(404, "route not found")

    def metrics_state(self):
        return {"activeSessions": 0}

    @staticmethod
    def _authenticate(request: Request) -> None:
        if request.headers.get("authorization") != "Bearer bearer":
            raise ServerError(401, "invalid auth token")
        if request.headers.get("x-kolkhoz-seat-token") != "seat":
            raise ServerError(401, "invalid seat token")


def _scope(query: bytes = b"viewerID=2") -> dict[str, Any]:
    return {
        "type": "websocket",
        "path": "/sessions/s1/realtime",
        "query_string": query,
        "headers": [
            (b"authorization", b"Bearer bearer"),
            (b"x-kolkhoz-seat-token", b"seat"),
        ],
    }


def _collector(sent: list[dict[str, Any]]):
    async def send(message: dict[str, Any]) -> None:
        sent.append(message)

    return send


def test_http_adapts_online_application_contract() -> None:
    application = _Application()
    app = ASGIApplication(application, _Bus())  # type: ignore[arg-type]
    incoming = asyncio.Queue()
    incoming.put_nowait({"type": "http.request", "body": b"", "more_body": False})
    sent: list[dict[str, Any]] = []
    scope = {
        "type": "http",
        "method": "GET",
        "path": "/health",
        "raw_path": b"/health",
        "query_string": b"",
        "headers": [],
    }
    asyncio.run(app(scope, incoming.get, _collector(sent)))
    assert sent[0]["status"] == 200
    assert json.loads(sent[1]["body"]) == {"status": "ok"}


def test_http_rejects_oversized_chunked_body_before_dispatch() -> None:
    application = _Application()
    app = ASGIApplication(
        application,
        _Bus(),
        max_request_body_bytes=4,  # type: ignore[arg-type]
    )
    incoming = asyncio.Queue()
    incoming.put_nowait({"type": "http.request", "body": b"123", "more_body": True})
    incoming.put_nowait({"type": "http.request", "body": b"45", "more_body": False})
    sent: list[dict[str, Any]] = []
    scope = {
        "type": "http",
        "method": "POST",
        "path": "/sessions",
        "raw_path": b"/sessions",
        "query_string": b"",
        "headers": [],
    }

    asyncio.run(app(scope, incoming.get, _collector(sent)))

    assert sent[0]["status"] == 413
    assert application.requests == []


def test_duplicate_gateway_catch_up_reads_are_coalesced() -> None:
    application = _Application()
    app = ASGIApplication(application, _Bus())  # type: ignore[arg-type]
    headers = {
        "authorization": "Bearer bearer",
        "x-kolkhoz-seat-token": "seat",
    }

    async def exercise():
        target = "/sessions/s1/actions?viewerID=2&afterRevision=1"
        return await asyncio.gather(
            app._coalesced_catch_up(target, headers),
            app._coalesced_catch_up(target, headers),
        )

    left, right = asyncio.run(exercise())

    assert left == right
    assert sum("/actions?" in request.target for request in application.requests) == 1


def test_prometheus_endpoint_preserves_plain_text_scrape_contract() -> None:
    app = ASGIApplication(_Application(), _Bus())  # type: ignore[arg-type]
    incoming = asyncio.Queue()
    incoming.put_nowait({"type": "http.request", "body": b"", "more_body": False})
    sent: list[dict[str, Any]] = []
    scope = {
        "type": "http",
        "method": "GET",
        "path": "/metrics/prometheus",
        "raw_path": b"/metrics/prometheus",
        "query_string": b"",
        "headers": [],
    }
    asyncio.run(app(scope, incoming.get, _collector(sent)))
    assert sent[0]["status"] == 200
    assert b"text/plain" in dict(sent[0]["headers"])[b"content-type"]
    assert b"kolkhoz_uptime_seconds" in sent[1]["body"]


def test_readiness_requires_all_dependencies_but_health_stays_live() -> None:
    app = ASGIApplication(
        _Application(),
        _Bus(),  # type: ignore[arg-type]
        readiness=lambda: {
            "postgres": True,
            "redisCommands": True,
            "redisRealtime": True,
        },
    )

    async def request(path: str):
        incoming = asyncio.Queue()
        incoming.put_nowait({"type": "http.request", "body": b"", "more_body": False})
        sent: list[dict[str, Any]] = []
        await app(
            {
                "type": "http",
                "method": "GET",
                "path": path,
                "raw_path": path.encode(),
                "query_string": b"",
                "headers": [],
            },
            incoming.get,
            _collector(sent),
        )
        return sent

    ready = asyncio.run(request("/ready"))
    health = asyncio.run(request("/health"))
    assert ready[0]["status"] == 200
    assert json.loads(ready[1]["body"])["status"] == "ready"
    assert health[0]["status"] == 200


def test_readiness_failure_and_timeout_return_503() -> None:
    def slow_check():
        time.sleep(0.05)
        return {"postgres": True}

    async def status(readiness, timeout=1.0):
        app = ASGIApplication(
            _Application(),
            _Bus(),  # type: ignore[arg-type]
            readiness=readiness,
            readiness_timeout_seconds=timeout,
        )
        incoming = asyncio.Queue()
        incoming.put_nowait({"type": "http.request", "body": b"", "more_body": False})
        sent: list[dict[str, Any]] = []
        await app(
            {
                "type": "http",
                "method": "GET",
                "path": "/ready",
                "raw_path": b"/ready",
                "query_string": b"",
                "headers": [],
            },
            incoming.get,
            _collector(sent),
        )
        return sent[0]["status"]

    assert asyncio.run(status(lambda: {"postgres": False})) == 503
    assert asyncio.run(status(slow_check, timeout=0.001)) == 503


def test_websocket_sends_state_and_revision_catch_up() -> None:
    application = _Application()
    bus = _Bus()
    app = ASGIApplication(application, bus)  # type: ignore[arg-type]
    incoming = asyncio.Queue()
    incoming.put_nowait({"type": "websocket.connect"})
    incoming.put_nowait({"type": "websocket.disconnect"})
    sent: list[dict[str, Any]] = []
    asyncio.run(
        app(_scope(b"viewerID=2&afterRevision=1"), incoming.get, _collector(sent))
    )
    assert bus.topics == ["session:s1"]
    assert sent[0] == {"type": "websocket.accept"}
    payloads = [json.loads(item["text"]) for item in sent if "text" in item]
    assert payloads[0]["type"] == "state"
    assert payloads[0]["update"]["actionLogCount"] == 3
    assert [item["revision"] for item in payloads[1]["updates"]["updates"]] == [2, 3]
    assert bus.subscription.closed


def test_websocket_delivers_committed_viewer_safe_update() -> None:
    application = _Application()
    application.revision = 0
    bus = _Bus()
    app = ASGIApplication(application, bus)  # type: ignore[arg-type]
    incoming = asyncio.Queue()
    incoming.put_nowait({"type": "websocket.connect"})
    sent: list[dict[str, Any]] = []

    async def send(message: dict[str, Any]) -> None:
        sent.append(message)
        if (
            message.get("type") == "websocket.send"
            and json.loads(message["text"])["type"] == "committed"
        ):
            incoming.put_nowait({"type": "websocket.disconnect"})

    async def scenario() -> None:
        task = asyncio.create_task(app(_scope(), incoming.get, send))
        while not any(item.get("type") == "websocket.accept" for item in sent):
            await asyncio.sleep(0)
        application.revision = 1
        bus.publish(
            RealtimeMessage(
                "session:s1",
                "s1:1",
                {
                    "sessionID": "s1",
                    "revision": 1,
                    "payload": {
                        "kind": 2,
                        "playerID": 1,
                        "handCard": {"suit": 2, "value": 10},
                        "plotCard": {"suit": 3, "value": 9},
                    },
                    "statesByViewer": {
                        "1": {"private": "viewer-1"},
                        "2": {
                            "private": "direct-viewer-2",
                            "phase": 2,
                            "waitingPlayer": 2,
                            "legalActions": [{"kind": 0, "playerID": 2}],
                        },
                    },
                },
            )
        )
        await asyncio.wait_for(task, 2)

    asyncio.run(scenario())
    payloads = [
        json.loads(item["text"])
        for item in sent
        if item.get("type") == "websocket.send"
    ]
    committed = next(item for item in payloads if item["type"] == "committed")
    assert committed["revision"] == 1
    assert committed["updates"]["updates"][0]["update"]["viewerID"] == 2
    projected = committed["updates"]["updates"][0]
    assert projected["update"]["snapshot"]["private"] == "direct-viewer-2"
    assert projected["update"]["isViewerTurn"] is True
    assert projected["action"]["handCard"] == {"suit": -1, "value": -1}
    assert "viewer-1" not in json.dumps(committed)
    assert not any("/actions?" in request.target for request in application.requests)


def test_websocket_rejects_missing_credentials() -> None:
    bus = _Bus()
    app = ASGIApplication(_Application(), bus)  # type: ignore[arg-type]
    sent: list[dict[str, Any]] = []
    scope = _scope()
    scope["headers"] = []
    incoming = asyncio.Queue()
    incoming.put_nowait({"type": "websocket.connect"})
    asyncio.run(app(scope, incoming.get, _collector(sent)))
    assert sent == [{"type": "websocket.close", "code": 1008}]
    assert bus.topics == []


def test_websocket_rejects_revision_ahead_of_durable_state() -> None:
    application = _Application()
    bus = _Bus()
    app = ASGIApplication(application, bus)  # type: ignore[arg-type]
    incoming = asyncio.Queue()
    incoming.put_nowait({"type": "websocket.connect"})
    sent: list[dict[str, Any]] = []
    asyncio.run(
        app(_scope(b"viewerID=2&afterRevision=4"), incoming.get, _collector(sent))
    )
    assert sent == [{"type": "websocket.close", "code": 1008}]
    assert bus.subscription.closed


def test_websocket_suppresses_duplicate_committed_notifications() -> None:
    application = _Application()
    application.revision = 0
    bus = _Bus()
    app = ASGIApplication(application, bus)  # type: ignore[arg-type]
    incoming = asyncio.Queue()
    incoming.put_nowait({"type": "websocket.connect"})
    sent: list[dict[str, Any]] = []

    async def send(message: dict[str, Any]) -> None:
        sent.append(message)
        committed = [
            item
            for item in sent
            if item.get("type") == "websocket.send"
            and json.loads(item["text"])["type"] == "committed"
        ]
        if committed:
            incoming.put_nowait({"type": "websocket.disconnect"})

    async def scenario() -> None:
        task = asyncio.create_task(
            app(_scope(b"viewerID=2&afterRevision=0"), incoming.get, send)
        )
        while not any(item.get("type") == "websocket.accept" for item in sent):
            await asyncio.sleep(0)
        application.revision = 1
        notification = RealtimeMessage(
            "session:s1", "s1:1", {"sessionID": "s1", "revision": 1}
        )
        bus.publish(notification)
        bus.publish(notification)
        await asyncio.wait_for(task, 2)

    asyncio.run(scenario())
    payloads = [
        json.loads(item["text"])
        for item in sent
        if item.get("type") == "websocket.send"
    ]
    assert [item["type"] for item in payloads].count("committed") == 1


def test_direct_projections_are_ordered_and_gaps_use_catch_up() -> None:
    current = {
        "sessionID": "s1",
        "viewerID": 2,
        "actionLogCount": 0,
        "gameLogActions": [],
        "reactions": [],
        "snapshot": {"phase": 2},
    }

    def message(revision: int, *, phase: int = 2) -> RealtimeMessage:
        return RealtimeMessage(
            "session:s1",
            f"s1:{revision}",
            {
                "revision": revision,
                "payload": {"kind": 0, "playerID": 2, "suit": revision},
                "statesByViewer": {
                    "2": {
                        "phase": phase,
                        "waitingPlayer": 2,
                        "legalActions": [{"kind": 0, "playerID": 2}],
                    }
                },
            },
        )

    direct = _direct_committed_updates(
        "s1", 2, 0, current, [message(2), message(1)]
    )
    assert direct is not None
    updates, latest, revision = direct
    assert revision == 2
    assert latest["actionLogCount"] == 2
    assert [item["revision"] for item in updates["updates"]] == [1, 2]
    assert _direct_committed_updates("s1", 2, 0, current, [message(2)]) is None
    assert _direct_committed_updates("s1", 2, 0, current, [message(1, phase=5)]) is None
