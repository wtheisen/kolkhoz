from __future__ import annotations

import asyncio
import threading
import time
import unittest

from server.kolkhoz_server.admin_control import AdminControlApplication
from server.kolkhoz_server.asgi import RequestRateLimiter


class Auth:
    def user_id(self, authorization: str | None) -> str | None:
        return {"Bearer admin": "admin", "Bearer player": "player"}.get(authorization)


async def request(
    application: object, *, authorization: str | None, confirmation: bool = True
) -> int:
    messages: list[dict[str, object]] = []
    headers = []
    if authorization:
        headers.append((b"authorization", authorization.encode()))
    if confirmation:
        headers.append((b"x-kolkhoz-restart-confirm", b"restart"))

    async def receive() -> dict[str, object]:
        return {"type": "http.request", "body": b"", "more_body": False}

    async def send(message: dict[str, object]) -> None:
        messages.append(message)

    await application(
        {
            "type": "http",
            "method": "POST",
            "path": "/admin/control/restart",
            "headers": headers,
        },
        receive,
        send,
    )
    return int(messages[0]["status"])


class AdminControlTests(unittest.TestCase):
    def test_restart_requires_allowlist_confirmation_and_cooldown(self) -> None:
        restarts: list[bool] = []
        now = [100.0]
        application = AdminControlApplication(
            auth=Auth(),
            admin_user_ids=frozenset({"admin"}),
            restart=lambda: restarts.append(True),
            cooldown_seconds=60,
            rate_limiter=RequestRateLimiter({"admin.restart": (100, 60)}),
            clock=lambda: now[0],
        )
        self.assertEqual(asyncio.run(request(application, authorization=None)), 403)
        self.assertEqual(
            asyncio.run(request(application, authorization="Bearer player")), 403
        )
        self.assertEqual(
            asyncio.run(
                request(application, authorization="Bearer admin", confirmation=False)
            ),
            400,
        )
        self.assertEqual(
            asyncio.run(request(application, authorization="Bearer admin")), 202
        )
        self.assertEqual(
            asyncio.run(request(application, authorization="Bearer admin")), 429
        )
        self.assertEqual(restarts, [True])
        now[0] += 61
        self.assertEqual(
            asyncio.run(request(application, authorization="Bearer admin")), 202
        )
        self.assertEqual(restarts, [True, True])

    def test_restart_authentication_is_rate_limited_before_verification(self) -> None:
        calls: list[str | None] = []

        class CountingAuth:
            def user_id(self, authorization: str | None) -> str | None:
                calls.append(authorization)
                return None

        application = AdminControlApplication(
            auth=CountingAuth(),
            admin_user_ids=frozenset({"admin"}),
            restart=lambda: None,
            rate_limiter=RequestRateLimiter(
                {"admin.restart": (1, 60)}, clock=lambda: 100.0
            ),
        )

        self.assertEqual(asyncio.run(request(application, authorization="bad")), 403)
        self.assertEqual(asyncio.run(request(application, authorization="bad")), 429)
        self.assertEqual(calls, ["bad"])

    def test_remote_authentication_does_not_block_the_event_loop(self) -> None:
        started = threading.Event()
        release = threading.Event()

        class SlowAuth:
            def user_id(self, authorization: str | None) -> str | None:
                started.set()
                release.wait(1)
                return None

        application = AdminControlApplication(
            auth=SlowAuth(),
            admin_user_ids=frozenset({"admin"}),
            restart=lambda: None,
            rate_limiter=RequestRateLimiter({"admin.restart": (100, 60)}),
        )

        async def exercise() -> float:
            pending = asyncio.create_task(request(application, authorization="bad"))
            while not started.is_set():
                await asyncio.sleep(0)
            before = time.perf_counter()
            await asyncio.sleep(0)
            elapsed = time.perf_counter() - before
            release.set()
            self.assertEqual(await pending, 403)
            return elapsed

        self.assertLess(asyncio.run(exercise()), 0.05)


if __name__ == "__main__":
    unittest.main()
