from __future__ import annotations

import unittest
from datetime import datetime, timedelta, timezone
from io import BytesIO
from unittest.mock import patch

from server.tools.cleanup_unconfirmed_accounts import (
    SupabaseAuthUsers,
    cleanup_unconfirmed_accounts,
    is_stale_unconfirmed_email_user,
)


class UnconfirmedAccountCleanupTests(unittest.TestCase):
    def setUp(self) -> None:
        self.now = datetime(2026, 7, 18, tzinfo=timezone.utc)
        self.cutoff = self.now - timedelta(days=7)

    def test_selects_only_stale_completely_unconfirmed_email_users(self) -> None:
        old = "2026-07-10T23:59:59Z"
        recent = "2026-07-11T00:00:01Z"
        self.assertTrue(
            is_stale_unconfirmed_email_user(
                {"email": "old@example.com", "created_at": old},
                cutoff=self.cutoff,
            )
        )
        for user in (
            {"email": "recent@example.com", "created_at": recent},
            {
                "email": "email-confirmed@example.com",
                "created_at": old,
                "email_confirmed_at": "2026-07-12T00:00:00Z",
            },
            {
                "email": "phone-confirmed@example.com",
                "created_at": old,
                "confirmed_at": "2026-07-12T00:00:00Z",
            },
            {"created_at": old},
            {"email": "missing-date@example.com"},
            {"email": "bad-date@example.com", "created_at": "not-a-date"},
            {
                "email": "naive-date@example.com",
                "created_at": "2026-07-01T00:00:00",
            },
        ):
            self.assertFalse(is_stale_unconfirmed_email_user(user, cutoff=self.cutoff))

    def test_admin_listing_uses_secret_and_follows_pagination(self) -> None:
        class Response(BytesIO):
            def __enter__(self) -> "Response":
                return self

            def __exit__(self, *args: object) -> None:
                self.close()

        responses = [
            Response(b'{"users":[{"id":"one"}],"next_page":2}'),
            Response(b'{"users":[{"id":"two"}]}'),
        ]
        users = SupabaseAuthUsers(
            project_url="https://example.supabase.co/",
            secret_key="server-secret",
        )

        with patch(
            "server.tools.cleanup_unconfirmed_accounts.urlrequest.urlopen",
            side_effect=responses,
        ) as urlopen:
            listed = users.list_all()

        self.assertEqual([user["id"] for user in listed], ["one", "two"])
        first_request = urlopen.call_args_list[0].args[0]
        second_request = urlopen.call_args_list[1].args[0]
        self.assertIn("page=1&per_page=1000", first_request.full_url)
        self.assertIn("page=2&per_page=1000", second_request.full_url)
        self.assertEqual(
            first_request.headers["Authorization"],
            "Bearer server-secret",
        )
        self.assertEqual(first_request.headers["Apikey"], "server-secret")

    def test_dry_run_reports_without_deleting(self) -> None:
        class Users:
            def list_all(self) -> list[dict[str, object]]:
                return [
                    {
                        "id": "stale-user",
                        "email": "stale@example.com",
                        "created_at": "2026-07-01T00:00:00Z",
                    }
                ]

            def get(self, user_id: str) -> dict[str, object] | None:
                raise AssertionError(f"unexpected lookup: {user_id}")

        class Deleter:
            def delete(self, user_id: str) -> None:
                raise AssertionError(f"unexpected deletion: {user_id}")

        report = cleanup_unconfirmed_accounts(
            Users(),  # type: ignore[arg-type]
            Deleter(),  # type: ignore[arg-type]
            older_than=timedelta(days=7),
            delete=False,
            now=self.now,
        )
        self.assertEqual(report["candidateCount"], 1)
        self.assertEqual(report["deletedCount"], 0)
        self.assertEqual(report["mode"], "dry-run")

    def test_delete_mode_removes_only_selected_users(self) -> None:
        class Users:
            def list_all(self) -> list[dict[str, object]]:
                return [
                    {
                        "id": "stale-user",
                        "email": "stale@example.com",
                        "created_at": "2026-07-01T00:00:00Z",
                    },
                    {
                        "id": "confirmed-user",
                        "email": "confirmed@example.com",
                        "created_at": "2026-07-01T00:00:00Z",
                        "confirmed_at": "2026-07-02T00:00:00Z",
                    },
                ]

            def get(self, user_id: str) -> dict[str, object] | None:
                if user_id == "stale-user":
                    return {
                        "id": user_id,
                        "email": "stale@example.com",
                        "created_at": "2026-07-01T00:00:00Z",
                    }
                return None

        deleted: list[str] = []

        class Deleter:
            def delete(self, user_id: str) -> None:
                deleted.append(user_id)

        report = cleanup_unconfirmed_accounts(
            Users(),  # type: ignore[arg-type]
            Deleter(),  # type: ignore[arg-type]
            older_than=timedelta(days=7),
            delete=True,
            now=self.now,
        )
        self.assertEqual(deleted, ["stale-user"])
        self.assertEqual(report["deletedCount"], 1)
        self.assertEqual(report["mode"], "delete")

    def test_delete_mode_rechecks_confirmation_before_deleting(self) -> None:
        class Users:
            def list_all(self) -> list[dict[str, object]]:
                return [
                    {
                        "id": "just-confirmed",
                        "email": "confirmed@example.com",
                        "created_at": "2026-07-01T00:00:00Z",
                    }
                ]

            def get(self, user_id: str) -> dict[str, object] | None:
                return {
                    "id": user_id,
                    "email": "confirmed@example.com",
                    "created_at": "2026-07-01T00:00:00Z",
                    "confirmed_at": "2026-07-18T00:00:00Z",
                }

        deleted: list[str] = []

        class Deleter:
            def delete(self, user_id: str) -> None:
                deleted.append(user_id)

        report = cleanup_unconfirmed_accounts(
            Users(),  # type: ignore[arg-type]
            Deleter(),  # type: ignore[arg-type]
            older_than=timedelta(days=7),
            delete=True,
            now=self.now,
        )
        self.assertEqual(deleted, [])
        self.assertEqual(report["candidateCount"], 1)
        self.assertEqual(report["deletedCount"], 0)


if __name__ == "__main__":
    unittest.main()
