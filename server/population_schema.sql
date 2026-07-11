-- Horizontally replicated population scheduler coordination.
create table if not exists population_intervals (
    job_kind text not null,
    interval_epoch bigint not null,
    owner_id text not null,
    fencing_token bigint not null check (fencing_token > 0),
    expires_at timestamptz not null,
    primary key (job_kind)
);
create index if not exists population_intervals_expiry_idx
    on population_intervals (expires_at, job_kind);

-- Durable balancing replaces per-process counters and survives scheduler failover.
alter table public.server_bot_profiles
    add column if not exists use_count bigint not null default 0,
    add column if not exists last_used_at timestamptz;
create index if not exists server_bot_profiles_population_idx
    on public.server_bot_profiles (use_count, user_id) where active;

-- Supports bounded oldest-first candidate selection without scanning active games.
create index if not exists server_sessions_population_fill_idx
    on server_sessions (created_at, session_id)
    where status = 'open' and browser_joinable;
