from __future__ import annotations

import json
import os
import ssl
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
