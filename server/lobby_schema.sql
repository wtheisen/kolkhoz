-- Production lobby, presence, invite, and reaction metadata.
--
-- All high-volume child tables lead with session_id in their primary key and
-- indexes. This keeps access shard-local and permits later hash partitioning by
-- session_id without changing repository queries.

create table if not exists server_sessions (
    session_id uuid primary key,
    invite_code text not null,
    seed bigint not null,
    variants jsonb not null default '{}'::jsonb,
    controllers jsonb not null,
    ranked boolean not null default false,
    browser_joinable boolean not null default false,
    status text not null check (status in ('open', 'active', 'finished', 'expired')),
    created_by_user_id text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    expires_at timestamptz not null,
    lobby_countdown_ends_at timestamptz,
    turn_player_id smallint check (turn_player_id between 0 and 3),
    turn_deadline_at timestamptz,
    scheduler_claim_owner text,
    scheduler_claim_until timestamptz,
    scheduler_fencing_token bigint not null default 0,
    reaction_revision bigint not null default 0,
    constraint server_sessions_turn_deadline_complete check (
        (turn_player_id is null) = (turn_deadline_at is null)
    ),
    constraint server_sessions_invite_code_upper check (invite_code = upper(invite_code))
);

create unique index if not exists server_sessions_invite_code_idx
    on server_sessions (invite_code);
create index if not exists server_sessions_browser_idx
    on server_sessions (updated_at desc, expires_at)
    where status = 'open' and browser_joinable;
create index if not exists server_sessions_expiry_idx
    on server_sessions (expires_at, session_id)
    where status in ('open', 'active');
create index if not exists server_sessions_countdown_idx
    on server_sessions (lobby_countdown_ends_at, session_id)
    where status = 'open' and lobby_countdown_ends_at is not null;
create index if not exists server_sessions_due_turn_idx
    on server_sessions (turn_deadline_at, session_id)
    where status = 'active' and turn_deadline_at is not null;

create table if not exists server_seats (
    session_id uuid not null references server_sessions(session_id) on delete cascade,
    player_id smallint not null check (player_id between 0 and 3),
    controller text not null,
    occupied boolean not null default false,
    user_id text,
    token_hash text,
    last_seen_at timestamptz,
    timeouts integer not null default 0,
    abandoned boolean not null default false,
    autopilot boolean not null default false,
    primary key (session_id, player_id),
    constraint server_seats_occupancy_consistent check (
        (occupied and user_id is not null and token_hash is not null)
        or (not occupied and user_id is null and token_hash is null)
    )
);

create unique index if not exists server_active_user_seat_idx
    on server_seats (user_id) where occupied and user_id is not null;
create index if not exists server_open_human_seat_idx
    on server_seats (session_id, player_id)
    where controller = 'human' and not occupied;

-- Result/progression idempotency belongs to the greenfield session authority.
-- Do not reuse public.profile_progression_events: its session foreign key points
-- at the retired legacy public.game_sessions table.
create table if not exists server_progression_events (
    session_id uuid not null references server_sessions(session_id) on delete cascade,
    user_id uuid not null references public.profiles(user_id) on delete cascade,
    recorded_at timestamptz not null default now(),
    primary key (session_id, user_id)
);
create index if not exists server_seat_heartbeat_idx
    on server_seats (last_seen_at, session_id)
    where occupied;

create table if not exists server_session_invites (
    session_id uuid not null references server_sessions(session_id) on delete cascade,
    user_id text not null,
    declined boolean not null default false,
    created_at timestamptz not null default now(),
    primary key (session_id, user_id)
);

create index if not exists server_invites_user_idx
    on server_session_invites (user_id, created_at desc, session_id)
    where not declined;

create table if not exists server_presence (
    user_id text primary key,
    last_seen_at timestamptz not null
);

create index if not exists server_presence_recent_idx
    on server_presence (last_seen_at desc, user_id);

create table if not exists server_device_leases (
    user_id text not null,
    device_id text not null,
    session_id uuid not null,
    last_seen_at timestamptz not null,
    primary key (user_id, device_id)
);

-- Acquisition is serialized per user with pg_advisory_xact_lock. A device may
-- replace another device only after its last_seen_at exceeds the configured TTL.

create index if not exists server_device_leases_session_idx
    on server_device_leases (session_id, last_seen_at desc);
create index if not exists server_device_leases_expiry_idx
    on server_device_leases (last_seen_at, user_id, device_id);

create table if not exists server_reactions (
    session_id uuid not null references server_sessions(session_id) on delete cascade,
    revision bigint not null,
    player_id smallint not null check (player_id between 0 and 3),
    reaction_id text not null,
    year smallint not null,
    phase smallint not null,
    created_at timestamptz not null default now(),
    primary key (session_id, revision)
);

create index if not exists server_reactions_created_idx
    on server_reactions (session_id, created_at desc);

create table if not exists server_session_updates (
    update_id bigserial primary key,
    session_id uuid not null references server_sessions(session_id) on delete cascade,
    revision bigint,
    kind text not null,
    created_at timestamptz not null default now()
);

create index if not exists server_session_updates_stream_idx
    on server_session_updates (session_id, update_id);
