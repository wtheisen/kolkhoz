from __future__ import annotations

import json
import os
import unittest
from unittest.mock import MagicMock, patch

from server.kolkhoz_server.accounts import (
    AccountDeletionService,
    SupabaseAccountDeleter,
)
from server.kolkhoz_server.auth import CachingAuthVerifier


class AccountDeletionTests(unittest.TestCase):
    def test_auth_cache_can_evict_every_token_for_deleted_user(self) -> None:
        class Verifier:
            def user_id(self, authorization: str | None) -> str | None:
                return "user-1" if authorization else None

        cache = CachingAuthVerifier(Verifier())  # type: ignore[arg-type]
        self.assertEqual(cache.user_id("Bearer one"), "user-1")
        self.assertEqual(cache.user_id("Bearer two"), "user-1")
        cache.invalidate_user("user-1")
        self.assertEqual(cache._entries, {})

    def test_supabase_deletion_uses_server_secret_and_hard_delete(self) -> None:
        response = MagicMock()
        response.__enter__.return_value.read.return_value = b"{}"
        deleter = SupabaseAccountDeleter(
            project_url="https://example.supabase.co/",
            secret_key="server-secret",
        )

        with patch(
            "server.kolkhoz_server.accounts.urlrequest.urlopen",
            return_value=response,
        ) as urlopen:
            deleter.delete("user/one")

        request = urlopen.call_args.args[0]
        self.assertEqual(
            request.full_url,
            "https://example.supabase.co/auth/v1/admin/users/user%2Fone",
        )
        self.assertEqual(request.method, "DELETE")
        self.assertEqual(json.loads(request.data), {"should_soft_delete": False})
        self.assertEqual(request.headers["Authorization"], "Bearer server-secret")
        self.assertEqual(request.headers["Apikey"], "server-secret")

    def test_environment_requires_server_secret(self) -> None:
        with patch.dict(
            os.environ,
            {"KOLKHOZ_SUPABASE_URL": "https://example.supabase.co"},
            clear=True,
        ):
            self.assertIsNone(SupabaseAccountDeleter.from_environment())

    def test_service_deletes_auth_before_server_identifiers(self) -> None:
        calls: list[tuple[str, str]] = []

        class Deleter:
            def delete(self, user_id: str) -> None:
                calls.append(("auth", user_id))

        class Cleaner:
            def delete(self, user_id: str) -> None:
                calls.append(("server", user_id))

        service = AccountDeletionService(Deleter(), Cleaner())  # type: ignore[arg-type]
        service.delete("user-1")
        self.assertEqual(calls, [("auth", "user-1"), ("server", "user-1")])


if __name__ == "__main__":
    unittest.main()
