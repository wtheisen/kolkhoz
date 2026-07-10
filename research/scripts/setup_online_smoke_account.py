#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
import uuid

import psycopg


USER_ID = "00000000-0000-4000-8000-00000000c0de"
EMAIL = "codex-smoke@kolkhoz.local"
DISPLAY_NAME = "Codex Smoke Bot"


def main() -> int:
    database_url = os.environ.get("KOLKHOZ_ONLINE_DATABASE_URL", "").strip()
    password = sys.stdin.read().strip()
    if not database_url:
        raise SystemExit("KOLKHOZ_ONLINE_DATABASE_URL is required")
    if not password:
        raise SystemExit("read the test-account password from stdin")

    app_metadata = json.dumps({"provider": "email", "providers": ["email"]})
    user_metadata = json.dumps(
        {"display_name": DISPLAY_NAME, "test_account": True}
    )
    identity_data = json.dumps(
        {
            "sub": USER_ID,
            "email": EMAIL,
            "display_name": DISPLAY_NAME,
            "email_verified": True,
            "phone_verified": False,
        }
    )

    with psycopg.connect(database_url) as connection:
        connection.execute(
            """
            insert into auth.users (
                instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                confirmation_token, confirmation_sent_at, recovery_token,
                email_change_token_new, email_change, last_sign_in_at,
                raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                is_sso_user, is_anonymous
            ) values (
                '00000000-0000-0000-0000-000000000000', %s,
                'authenticated', 'authenticated', %s,
                crypt(%s, gen_salt('bf')), now(), '', now(), '', '', '', now(),
                %s::jsonb, %s::jsonb,
                now(), now(), false, false
            )
            on conflict (id) do update
                set email = excluded.email,
                    instance_id = excluded.instance_id,
                    encrypted_password = excluded.encrypted_password,
                    email_confirmed_at = now(),
                    confirmation_token = '',
                    confirmation_sent_at = now(),
                    recovery_token = '',
                    email_change_token_new = '',
                    email_change = '',
                    last_sign_in_at = now(),
                    raw_app_meta_data = excluded.raw_app_meta_data,
                    raw_user_meta_data = excluded.raw_user_meta_data,
                    updated_at = now()
            """,
            (USER_ID, EMAIL, password, app_metadata, user_metadata),
        )
        connection.execute(
            """
            insert into auth.identities (
                id, provider_id, user_id, identity_data, provider,
                last_sign_in_at, created_at, updated_at
            ) values (%s, %s, %s, %s::jsonb, 'email', now(), now(), now())
            on conflict (provider_id, provider) do update
                set identity_data = excluded.identity_data,
                    updated_at = now()
            """,
            (str(uuid.uuid4()), USER_ID, USER_ID, identity_data),
        )
        connection.execute(
            """
            insert into public.profiles (user_id, display_name, avatar_url)
            values (%s, %s, 'worker-mechanic')
            on conflict (user_id) do update
                set display_name = excluded.display_name,
                    avatar_url = excluded.avatar_url,
                    updated_at = now()
            """,
            (USER_ID, DISPLAY_NAME),
        )
    print(f"test-account-ready:{USER_ID}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
