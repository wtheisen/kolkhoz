#!/usr/bin/env python3
"""Seed private deterministic benchmark identities into a dedicated database."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from urllib.parse import urlparse


def identity(number: int) -> str:
    return f"20000000-0000-4000-8000-{number:012d}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--database-url", required=True)
    parser.add_argument("--confirm-database", required=True)
    parser.add_argument("--count", type=int, default=10_000)
    parser.add_argument(
        "--output", type=Path, default=Path("benchmark-identities.json")
    )
    args = parser.parse_args()
    database_name = urlparse(args.database_url).path.lstrip("/")
    if (
        database_name != args.confirm_database
        or "benchmark" not in database_name.lower()
    ):
        raise SystemExit(
            "refusing seed: exact dedicated benchmark database confirmation required"
        )
    if not 1 <= args.count <= 10_000:
        raise SystemExit("count must be between 1 and 10000")
    try:
        import psycopg
    except ImportError as error:
        raise SystemExit(
            "psycopg is required; install server/deploy/requirements.txt"
        ) from error
    rows = [
        (identity(n), f"benchmark-{n}@invalid.local", f"Load Player {n}")
        for n in range(1, args.count + 1)
    ]
    with psycopg.connect(args.database_url) as connection:
        with connection.cursor() as cursor:
            cursor.executemany(
                """insert into auth.users
                       (id, aud, role, email, email_confirmed_at, raw_app_meta_data,
                        raw_user_meta_data, created_at, updated_at, is_sso_user, is_anonymous)
                     values (%s::uuid, 'authenticated', 'authenticated', %s, now(),
                             '{"provider":"benchmark","providers":["benchmark"]}'::jsonb,
                             '{"benchmark":true}'::jsonb, now(), now(), false, false)
                     on conflict (id) do nothing""",
                [(user_id, email) for user_id, email, _ in rows],
            )
            cursor.executemany(
                """insert into public.server_players (id) values (%s::uuid)
                     on conflict (id) do nothing""",
                [(user_id,) for user_id, _, _ in rows],
            )
            cursor.executemany(
                """insert into public.profiles (user_id, display_name)
                     values (%s::uuid, %s)
                     on conflict (user_id) do update set display_name = excluded.display_name""",
                [(user_id, name) for user_id, _, name in rows],
            )
            cursor.executemany(
                """insert into public.profile_stats (user_id) values (%s::uuid)
                     on conflict (user_id) do nothing""",
                [(user_id,) for user_id, _, _ in rows],
            )
    args.output.write_text(
        json.dumps(
            [
                {"token": f"staging:{user_id}", "deviceID": f"benchmark-{n}"}
                for n, (user_id, _, _) in enumerate(rows, 1)
            ]
        )
        + "\n"
    )
    args.output.chmod(0o600)
    print(
        f"seeded {args.count} private identities in {database_name}; wrote {args.output}"
    )


if __name__ == "__main__":
    main()
