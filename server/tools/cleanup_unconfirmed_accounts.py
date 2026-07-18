from __future__ import annotations

import argparse
import json
import os
import ssl
from datetime import datetime, timedelta, timezone
from http import HTTPStatus
from urllib import parse, request as urlrequest
from urllib.error import HTTPError

from server.kolkhoz_server.accounts import SupabaseAccountDeleter

try:
    import certifi
except ImportError:
    certifi = None


class SupabaseAuthUsers:
    def __init__(self, *, project_url: str, secret_key: str) -> None:
        self.project_url = project_url.rstrip("/")
        self.secret_key = secret_key
        self.ssl_context = (
            ssl.create_default_context(cafile=certifi.where()) if certifi else None
        )

    def list_all(self) -> list[dict[str, object]]:
        users: list[dict[str, object]] = []
        page = 1
        per_page = 1000
        while True:
            query = parse.urlencode({"page": page, "per_page": per_page})
            request = urlrequest.Request(
                f"{self.project_url}/auth/v1/admin/users?{query}",
                headers={
                    "accept": "application/json",
                    "authorization": f"Bearer {self.secret_key}",
                    "apikey": self.secret_key,
                },
            )
            with urlrequest.urlopen(
                request, timeout=15, context=self.ssl_context
            ) as response:
                body = json.load(response)
            page_users = body.get("users") or []
            users.extend(page_users)
            next_page = body.get("next_page")
            if isinstance(next_page, int) and next_page > page:
                page = next_page
            elif len(page_users) == per_page:
                page += 1
            else:
                break
        return users

    def get(self, user_id: str) -> dict[str, object] | None:
        request = urlrequest.Request(
            f"{self.project_url}/auth/v1/admin/users/{parse.quote(user_id, safe='')}",
            headers={
                "accept": "application/json",
                "authorization": f"Bearer {self.secret_key}",
                "apikey": self.secret_key,
            },
        )
        try:
            with urlrequest.urlopen(
                request, timeout=15, context=self.ssl_context
            ) as response:
                return json.load(response)
        except HTTPError as error:
            try:
                if error.code == HTTPStatus.NOT_FOUND:
                    return None
                raise
            finally:
                error.close()


def is_stale_unconfirmed_email_user(
    user: dict[str, object],
    *,
    cutoff: datetime,
) -> bool:
    if not user.get("email"):
        return False
    if user.get("email_confirmed_at") or user.get("confirmed_at"):
        return False
    created_at = user.get("created_at")
    if not isinstance(created_at, str):
        return False
    try:
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    except ValueError:
        return False
    if created.tzinfo is None:
        return False
    return created <= cutoff


def cleanup_unconfirmed_accounts(
    users: SupabaseAuthUsers,
    deleter: SupabaseAccountDeleter,
    *,
    older_than: timedelta,
    delete: bool,
    now: datetime | None = None,
) -> dict[str, object]:
    current_time = now or datetime.now(timezone.utc)
    cutoff = current_time - older_than
    candidates = [
        user
        for user in users.list_all()
        if is_stale_unconfirmed_email_user(user, cutoff=cutoff)
    ]
    deleted = 0
    if delete:
        for user in candidates:
            user_id = user.get("id")
            if not isinstance(user_id, str) or not user_id:
                continue
            current_user = users.get(user_id)
            if current_user is None or not is_stale_unconfirmed_email_user(
                current_user,
                cutoff=cutoff,
            ):
                continue
            deleter.delete(user_id)
            deleted += 1
    return {
        "status": "ok",
        "mode": "delete" if delete else "dry-run",
        "olderThanDays": older_than.days,
        "candidateCount": len(candidates),
        "deletedCount": deleted,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Delete Supabase email users left unconfirmed past retention."
    )
    parser.add_argument("--older-than-days", type=int, default=7)
    parser.add_argument("--delete", action="store_true")
    args = parser.parse_args()
    if args.older_than_days < 1:
        parser.error("--older-than-days must be at least 1")

    project_url = os.environ.get("KOLKHOZ_SUPABASE_URL")
    secret_key = os.environ.get("KOLKHOZ_SUPABASE_SECRET_KEY") or os.environ.get(
        "KOLKHOZ_SUPABASE_SERVICE_ROLE_KEY"
    )
    if not project_url or not secret_key:
        parser.error("Supabase URL and server secret are required")

    users = SupabaseAuthUsers(project_url=project_url, secret_key=secret_key)
    deleter = SupabaseAccountDeleter(
        project_url=project_url,
        secret_key=secret_key,
    )
    report = cleanup_unconfirmed_accounts(
        users,
        deleter,
        older_than=timedelta(days=args.older_than_days),
        delete=args.delete,
    )
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
