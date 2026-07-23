"""Independent, narrowly-scoped systemd restart control plane."""

from __future__ import annotations

import asyncio
import json
import logging
import os
import subprocess
import threading
import time
from http import HTTPStatus

from .auth import SupabaseAuthVerifier
from .asgi import RequestRateLimiter, _client_address
from .errors import ServerError


class AdminControlApplication:
    def __init__(
        self,
        *,
        auth: object,
        admin_user_ids: frozenset[str],
        restart: object,
        cooldown_seconds: float = 300,
        auth_timeout_seconds: float = 5.5,
        rate_limiter: RequestRateLimiter | None = None,
        clock: object = time.monotonic,
    ) -> None:
        self.auth, self.admin_user_ids, self.restart = auth, admin_user_ids, restart
        self.cooldown_seconds, self.clock = cooldown_seconds, clock
        self.auth_timeout_seconds = auth_timeout_seconds
        self.rate_limiter = rate_limiter or RequestRateLimiter(
            {"admin.restart": (5, 60.0)}, capacity=10_000
        )
        self._last_restart = float("-inf")
        self._lock = threading.Lock()

    async def __call__(
        self, scope: dict[str, object], receive: object, send: object
    ) -> None:
        if scope["type"] != "http":
            return
        method, path = str(scope["method"]), str(scope["path"])
        if method == "GET" and path == "/admin/control/health":
            await self._respond(send, HTTPStatus.OK, {"status": "ok"})
            return
        if method != "POST" or path != "/admin/control/restart":
            await self._respond(send, HTTPStatus.NOT_FOUND, {"error": "not found"})
            return
        headers = {
            bytes(k).decode().lower(): bytes(v).decode()
            for k, v in scope.get("headers", [])
        }
        try:
            retry_after = self.rate_limiter.retry_after_scope(
                "admin.restart", _client_address(scope, headers)
            )
            if retry_after is not None:
                raise ServerError(
                    HTTPStatus.TOO_MANY_REQUESTS,
                    f"restart rate limit exceeded; retry in {retry_after} seconds",
                )
            try:
                user_id = await asyncio.wait_for(
                    asyncio.to_thread(self.auth.user_id, headers.get("authorization")),
                    timeout=self.auth_timeout_seconds,
                )
            except TimeoutError as error:
                raise ServerError(
                    HTTPStatus.SERVICE_UNAVAILABLE, "admin authentication unavailable"
                ) from error
            if not user_id or user_id not in self.admin_user_ids:
                raise ServerError(HTTPStatus.FORBIDDEN, "admin access required")
            if headers.get("x-kolkhoz-restart-confirm") != "restart":
                raise ServerError(
                    HTTPStatus.BAD_REQUEST, "restart confirmation required"
                )
            with self._lock:
                now = self.clock()
                if now - self._last_restart < self.cooldown_seconds:
                    raise ServerError(
                        HTTPStatus.TOO_MANY_REQUESTS, "restart cooldown active"
                    )
                previous_restart = self._last_restart
                self._last_restart = now
            try:
                await asyncio.to_thread(self.restart)
            except Exception:
                with self._lock:
                    if self._last_restart == now:
                        self._last_restart = previous_restart
                raise
            logging.warning(
                "admin restarted kolkhoz-server.service",
                extra={"admin_user_id": user_id},
            )
            await self._respond(send, HTTPStatus.ACCEPTED, {"accepted": True})
        except ServerError as error:
            await self._respond(send, error.status, {"error": error.message})

    @staticmethod
    async def _respond(send: object, status: int, body: object) -> None:
        encoded = json.dumps(body, separators=(",", ":")).encode()
        await send(
            {
                "type": "http.response.start",
                "status": int(status),
                "headers": [
                    (b"content-type", b"application/json"),
                    (b"content-length", str(len(encoded)).encode()),
                ],
            }
        )
        await send({"type": "http.response.body", "body": encoded})


def _restart_service() -> None:
    subprocess.run(
        [
            "/usr/bin/sudo",
            "--non-interactive",
            "/bin/systemctl",
            "restart",
            "kolkhoz-server.service",
        ],
        check=True,
        timeout=30,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def create_admin_control_application() -> AdminControlApplication:
    auth = SupabaseAuthVerifier.from_environment()
    admins = frozenset(
        value.strip()
        for value in os.environ.get("KOLKHOZ_ADMIN_USER_IDS", "").split(",")
        if value.strip()
    )
    if auth is None or not admins:
        raise RuntimeError(
            "admin control requires Supabase auth and an admin allowlist"
        )
    return AdminControlApplication(
        auth=auth,
        admin_user_ids=admins,
        restart=_restart_service,
        cooldown_seconds=float(
            os.environ.get("KOLKHOZ_RESTART_COOLDOWN_SECONDS", "300")
        ),
        auth_timeout_seconds=float(
            os.environ.get("KOLKHOZ_ADMIN_AUTH_TIMEOUT_SECONDS", "5.5")
        ),
        rate_limiter=RequestRateLimiter(
            {
                "admin.restart": (
                    int(os.environ.get("KOLKHOZ_ADMIN_RATE_LIMIT", "5")),
                    float(os.environ.get("KOLKHOZ_ADMIN_RATE_WINDOW_SECONDS", "60")),
                )
            },
            capacity=int(os.environ.get("KOLKHOZ_ADMIN_RATE_CAPACITY", "10000")),
        ),
    )
