-- FCM installations and the durable notification outbox. Tokens are secrets:
-- never expose this table through health, metrics, logs, or admin responses.

create table if not exists server_push_installations (
    installation_id text primary key,
    user_id text not null,
    platform text not null check (platform in ('ios', 'android')),
    token text not null,
    preferences jsonb not null default '{"social":true,"invites":true,"turns":true,"results":true}'::jsonb,
    enabled boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists server_push_installations_user_idx
    on server_push_installations (user_id) where enabled;

create table if not exists server_notification_outbox (
    id bigserial primary key,
    user_id text not null,
    event_type text not null,
    dedupe_key text not null unique,
    payload jsonb not null,
    status text not null default 'pending'
        check (status in ('pending', 'sending', 'sent', 'failed')),
    attempts integer not null default 0,
    next_attempt_at timestamptz not null default now(),
    locked_until timestamptz,
    last_error_code text,
    created_at timestamptz not null default now(),
    sent_at timestamptz
);

create index if not exists server_notification_outbox_pending_idx
    on server_notification_outbox (next_attempt_at, id)
    where status in ('pending', 'sending');

create table if not exists server_notification_deliveries (
    outbox_id bigint not null references server_notification_outbox(id) on delete cascade,
    installation_id text not null references server_push_installations(installation_id) on delete cascade,
    status text not null check (status in ('delivered', 'invalid')),
    completed_at timestamptz not null default now(),
    primary key (outbox_id, installation_id)
);
