-- Passwordless, server-owned player identity. The player UUID is the same UUID used
-- by existing profile, result, commerce, and lobby records.

create table if not exists server_players (
    id uuid primary key,
    display_name text not null default 'Comrade',
    guest_installation_hash text unique,
    status text not null default 'active' check (status in ('active', 'deleted')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

-- Adopt existing Supabase-authenticated profiles without changing their UUIDs,
-- then make the server player table the durable identity owner for new players.
insert into server_players (id, display_name, created_at, updated_at)
select user_id, coalesce(nullif(display_name, ''), 'Comrade'), created_at, updated_at
  from public.profiles
on conflict (id) do nothing;
alter table public.profiles drop constraint if exists profiles_user_id_fkey;
alter table public.profiles drop constraint if exists profiles_user_id_server_player_fkey;
alter table public.profiles add constraint profiles_user_id_server_player_fkey
    foreign key (user_id) references server_players(id) on delete cascade;

create or replace function public.ensure_server_player_for_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    insert into public.server_players (id, display_name)
    values (new.user_id, coalesce(nullif(new.display_name, ''), 'Comrade'))
    on conflict (id) do nothing;
    return new;
end;
$$;
drop trigger if exists ensure_server_player_for_profile on public.profiles;
create trigger ensure_server_player_for_profile
before insert on public.profiles
for each row execute function public.ensure_server_player_for_profile();

create table if not exists server_linked_identities (
    id uuid primary key,
    player_id uuid not null references server_players(id) on delete cascade,
    provider text not null check (provider in ('game_center', 'play_games')),
    provider_subject text not null,
    created_at timestamptz not null default now(),
    last_authenticated_at timestamptz not null default now(),
    unique (provider, provider_subject)
);
create index if not exists server_linked_identities_player_idx
    on server_linked_identities(player_id);
create unique index if not exists server_linked_identities_player_provider_idx
    on server_linked_identities(player_id, provider);

create table if not exists server_identity_sessions (
    id uuid primary key,
    player_id uuid not null references server_players(id) on delete cascade,
    token_hash text not null unique,
    device_id text,
    created_at timestamptz not null default now(),
    last_used_at timestamptz not null default now(),
    expires_at timestamptz not null,
    revoked_at timestamptz
);
create index if not exists server_identity_sessions_player_idx
    on server_identity_sessions(player_id) where revoked_at is null;

create table if not exists server_platform_credential_replays (
    credential_hash text primary key,
    provider text not null,
    expires_at timestamptz not null,
    created_at timestamptz not null default now()
);

create table if not exists server_identity_rate_limits (
    player_id uuid not null references server_players(id) on delete cascade,
    action text not null,
    window_started_at timestamptz not null,
    attempts integer not null check (attempts between 1 and 1000),
    primary key (player_id, action)
);

create table if not exists server_device_link_requests (
    id uuid primary key,
    source_player_id uuid not null references server_players(id) on delete cascade,
    code_hash text not null unique,
    expires_at timestamptz not null,
    status text not null default 'pending'
        check (status in ('pending', 'target_confirmed', 'approved', 'cancelled', 'expired', 'conflict')),
    incorrect_attempts integer not null default 0 check (incorrect_attempts between 0 and 8),
    target_player_id uuid references server_players(id) on delete set null,
    target_identity_id uuid references server_linked_identities(id) on delete set null,
    target_confirmed_at timestamptz,
    approved_at timestamptz,
    redeemed_at timestamptz,
    cancelled_at timestamptz,
    conflict_reason text,
    target_session_issued_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index if not exists server_device_link_requests_source_idx
    on server_device_link_requests(source_player_id, created_at desc);

create table if not exists server_identity_audit (
    id bigserial primary key,
    player_id uuid,
    event_type text not null,
    provider text,
    other_player_id uuid,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);
