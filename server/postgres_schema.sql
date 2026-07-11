-- Production schema for the EventStore contract. PostgreSQL is the authority;
-- game workers hold only replayable C-engine caches.

create table if not exists server_games (
    session_id uuid primary key,
    seed bigint not null,
    variants jsonb not null default '{}'::jsonb,
    revision bigint not null default 0,
    fencing_token bigint not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists server_game_events (
    session_id uuid not null references server_games(session_id) on delete cascade,
    revision bigint not null,
    kind text not null,
    payload jsonb not null,
    created_at timestamptz not null default now(),
    primary key (session_id, revision)
);

create index if not exists server_game_events_created_at_idx
    on server_game_events (created_at);

-- A production adapter performs this comparison and event insert in one
-- transaction. Exactly one process may advance a given revision.
--
-- update server_games
--    set revision = revision + 1, updated_at = now()
--  where session_id = $1 and revision = $2
-- returning revision;
