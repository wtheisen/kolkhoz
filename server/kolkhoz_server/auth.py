from __future__ import annotations

import json
import os
import ssl
import threading
import time
import uuid
from collections import OrderedDict
from collections.abc import Callable
from http import HTTPStatus
from urllib import request as urlrequest
from urllib.error import HTTPError, URLError

from .errors import ServerError

try:
    import certifi
except ImportError:
    certifi = None


class SupabaseAuthVerifier:
    def __init__(self, *, project_url: str, publishable_key: str) -> None:
        self.project_url = project_url.rstrip("/")
        self.publishable_key = publishable_key
        self.ssl_context = (
            ssl.create_default_context(cafile=certifi.where()) if certifi else None
        )

    @classmethod
    def from_environment(cls) -> "SupabaseAuthVerifier | None":
        project_url = os.environ.get("KOLKHOZ_SUPABASE_URL")
        publishable_key = os.environ.get("KOLKHOZ_SUPABASE_PUBLISHABLE_KEY")
        if not project_url or not publishable_key:
            return None
        return cls(project_url=project_url, publishable_key=publishable_key)

    def user_id(self, authorization: str | None) -> str | None:
        if authorization is None or not authorization.startswith("Bearer "):
            return None
        token = authorization.removeprefix("Bearer ").strip()
        if not token:
            return None
        request = urlrequest.Request(
            f"{self.project_url}/auth/v1/user",
            headers={
                "accept": "application/json",
                "authorization": f"Bearer {token}",
                "apikey": self.publishable_key,
            },
        )
        try:
            with urlrequest.urlopen(
                request, timeout=5, context=self.ssl_context
            ) as response:
                payload = json.loads(response.read())
        except HTTPError as error:
            try:
                if error.code in (HTTPStatus.UNAUTHORIZED, HTTPStatus.FORBIDDEN):
                    raise ServerError(HTTPStatus.UNAUTHORIZED, "invalid auth token")
                raise ServerError(
                    HTTPStatus.BAD_GATEWAY,
                    f"Supabase auth failed with status {error.code}",
                )
            finally:
                error.close()
        except (OSError, URLError, json.JSONDecodeError) as error:
            raise ServerError(
                HTTPStatus.BAD_GATEWAY, "Supabase auth verification failed"
            ) from error
        user_id = payload.get("id") if isinstance(payload, dict) else None
        if not isinstance(user_id, str) or not user_id:
            raise ServerError(HTTPStatus.UNAUTHORIZED, "invalid auth token")
        return user_id


class StaticAuthVerifier:
    """Deterministic auth seam for HTTP and load tests."""

    def __init__(self, tokens: dict[str, str]) -> None:
        self.tokens = dict(tokens)

    def user_id(self, authorization: str | None) -> str | None:
        if authorization is None or not authorization.startswith("Bearer "):
            return None
        token = authorization.removeprefix("Bearer ").strip()
        if token not in self.tokens:
            raise ServerError(HTTPStatus.UNAUTHORIZED, "invalid auth token")
        return self.tokens[token]


class StagingAuthVerifier(StaticAuthVerifier):
    """Static smoke tokens plus deterministic UUID identities for load tests."""

    def user_id(self, authorization: str | None) -> str | None:
        if authorization is not None and authorization.startswith("Bearer staging:"):
            value = authorization.removeprefix("Bearer staging:").strip()
            try:
                parsed = uuid.UUID(value)
            except ValueError as error:
                raise ServerError(
                    HTTPStatus.UNAUTHORIZED, "invalid auth token"
                ) from error
            if str(parsed) != value.lower():
                raise ServerError(HTTPStatus.UNAUTHORIZED, "invalid auth token")
            return str(parsed)
        return super().user_id(authorization)


class CachingAuthVerifier:
    """Bound repeated bearer verification without an unbounded token cache."""

    def __init__(
        self,
        verifier: SupabaseAuthVerifier,
        *,
        ttl_seconds: float = 30,
        capacity: int = 100_000,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        if ttl_seconds <= 0 or capacity <= 0:
            raise ValueError("auth cache TTL and capacity must be positive")
        self._verifier = verifier
        self._ttl = ttl_seconds
        self._capacity = capacity
        self._clock = clock
        self._entries: OrderedDict[str, tuple[str, float]] = OrderedDict()
        self._lock = threading.Lock()

    def user_id(self, authorization: str | None) -> str | None:
        if authorization is None:
            return None
        now = self._clock()
        with self._lock:
            cached = self._entries.get(authorization)
            if cached is not None and cached[1] > now:
                self._entries.move_to_end(authorization)
                return cached[0]
            self._entries.pop(authorization, None)
        user_id = self._verifier.user_id(authorization)
        if user_id is None:
            return None
        with self._lock:
            self._entries[authorization] = (user_id, now + self._ttl)
            self._entries.move_to_end(authorization)
            while len(self._entries) > self._capacity:
                self._entries.popitem(last=False)
        return user_id

    def invalidate_user(self, user_id: str) -> None:
        with self._lock:
            for authorization, cached in list(self._entries.items()):
                if cached[0] == user_id:
                    self._entries.pop(authorization, None)
