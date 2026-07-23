from __future__ import annotations

import json
import os
import ssl
from http import HTTPStatus
from urllib import request as urlrequest
from urllib.error import HTTPError, URLError
from urllib.parse import quote

from .store import ConnectionPool

try:
    import certifi
except ImportError:
    certifi = None


class AccountDeletionError(RuntimeError):
    pass


class SupabaseAccountDeleter:
    """Delete Auth users with a server-only Supabase secret key."""

    def __init__(self, *, project_url: str, secret_key: str) -> None:
        self.project_url = project_url.rstrip("/")
        self.secret_key = secret_key
        self.ssl_context = (
            ssl.create_default_context(cafile=certifi.where()) if certifi else None
        )

    @classmethod
    def from_environment(cls) -> "SupabaseAccountDeleter | None":
        project_url = os.environ.get("KOLKHOZ_SUPABASE_URL")
        secret_key = os.environ.get("KOLKHOZ_SUPABASE_SECRET_KEY") or os.environ.get(
            "KOLKHOZ_SUPABASE_SERVICE_ROLE_KEY"
        )
        if not project_url or not secret_key:
            return None
        return cls(project_url=project_url, secret_key=secret_key)

    def delete(self, user_id: str) -> None:
        request = urlrequest.Request(
            f"{self.project_url}/auth/v1/admin/users/{quote(user_id, safe='')}",
            method="DELETE",
            data=json.dumps({"should_soft_delete": False}).encode(),
            headers={
                "accept": "application/json",
                "content-type": "application/json",
                "authorization": f"Bearer {self.secret_key}",
                "apikey": self.secret_key,
            },
        )
        try:
            with urlrequest.urlopen(
                request, timeout=10, context=self.ssl_context
            ) as response:
                response.read()
        except HTTPError as error:
            try:
                if error.code == HTTPStatus.NOT_FOUND:
                    return
                raise AccountDeletionError(
                    f"Supabase account deletion failed with status {error.code}"
                )
            finally:
                error.close()
        except (OSError, URLError) as error:
            raise AccountDeletionError("Supabase account deletion failed") from error


class PostgresAccountCleaner:
    """Remove server-owned identifiers after Supabase cascades profile data."""

    def __init__(self, pool: ConnectionPool) -> None:
        self._pool = pool

    def delete(self, user_id: str) -> None:
        with self._pool.connection() as connection, connection.transaction():  # type: ignore[attr-defined]
            detach_player_from_sessions(connection, user_id)
            for table in (
                "server_session_invites",
                "server_presence",
                "server_device_leases",
                "server_notification_outbox",
                "server_push_installations",
            ):
                connection.execute(  # type: ignore[attr-defined]
                    f"delete from {table} where user_id = %s", (user_id,)
                )
            # identity_schema makes server_players the canonical owner and
            # public.profiles its cascading projection.
            connection.execute(  # type: ignore[attr-defined]
                "delete from server_players where id = %s", (user_id,)
            )


def detach_player_from_sessions(connection: object, user_id: str) -> None:
    """Remove a player identity from session-owned records before deletion or merge."""
    # Preserve active simulations with a non-personal, session-local marker. Seats
    # outside active games can be released immediately.
    connection.execute(  # type: ignore[attr-defined]
        """update server_seats seats
              set user_id = 'deleted:' || seats.session_id::text || ':' || seats.player_id::text,
                  token_hash = repeat('0', 64), abandoned = true,
                  autopilot = true, last_seen_at = null
             from server_sessions sessions
            where seats.session_id = sessions.session_id
              and seats.user_id = %s and sessions.status = 'active'""",
        (user_id,),
    )
    connection.execute(  # type: ignore[attr-defined]
        """update server_seats seats
              set occupied = false, user_id = null, token_hash = null,
                  last_seen_at = null, abandoned = false, autopilot = false
             from server_sessions sessions
            where seats.session_id = sessions.session_id
              and seats.user_id = %s and sessions.status <> 'active'""",
        (user_id,),
    )
    connection.execute(  # type: ignore[attr-defined]
        "update server_sessions set created_by_user_id = null where created_by_user_id = %s",
        (user_id,),
    )


class AccountDeletionService:
    def __init__(
        self,
        auth_deleter: SupabaseAccountDeleter,
        cleaner: PostgresAccountCleaner | None = None,
    ) -> None:
        self._auth_deleter = auth_deleter
        self._cleaner = cleaner

    def delete(self, user_id: str) -> None:
        self._auth_deleter.delete(user_id)
        if self._cleaner is not None:
            self._cleaner.delete(user_id)
