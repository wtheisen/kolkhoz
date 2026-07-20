-- Passwordless, server-owned player identity. The player UUID is the same UUID used
-- by existing profile, result, commerce, and lobby records.

create table if not exists server_players (
    id uuid primary key,
    guest_installation_hash text unique,
    status text not null default 'active' check (status in ('active', 'deleted')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

-- Adopt existing Supabase-authenticated profiles without changing their UUIDs,
-- then make the server player table the durable identity owner for new players.
insert into server_players (id, created_at, updated_at)
select user_id, created_at, updated_at
  from public.profiles
on conflict (id) do nothing;
alter table public.profiles drop constraint if exists profiles_user_id_fkey;
alter table public.profiles drop constraint if exists profiles_user_id_server_player_fkey;
alter table public.profiles add constraint profiles_user_id_server_player_fkey
    foreign key (user_id) references server_players(id) on delete cascade;

drop trigger if exists ensure_server_player_for_profile on public.profiles;
drop function if exists public.ensure_server_player_for_profile();

-- A profile is data owned by a player; inserting profile data must never create a
-- second kind of account implicitly. Identity flows create server_players first.
insert into public.profiles (user_id, display_name)
select players.id, 'Comrade'
  from server_players players
  left join public.profiles profiles on profiles.user_id = players.id
 where profiles.user_id is null;

alter table server_players
    drop constraint if exists server_players_status_deleted_check;
alter table server_players
    add constraint server_players_status_deleted_check check (
        (status = 'active' and deleted_at is null)
        or (status = 'deleted' and deleted_at is not null)
    );

create or replace function public.require_server_player_profile()
returns trigger language plpgsql set search_path = public as $$
begin
    if new.status = 'active'
       and not exists(select 1 from public.profiles where user_id = new.id) then
        raise exception 'active server player % requires exactly one profile', new.id;
    end if;
    return null;
end;
$$;
drop trigger if exists server_player_profile_required on server_players;
create constraint trigger server_player_profile_required
after insert or update on server_players
deferrable initially deferred
for each row execute function public.require_server_player_profile();

create or replace function public.prevent_orphan_server_player()
returns trigger language plpgsql set search_path = public as $$
begin
    if exists(select 1 from public.server_players where id = old.user_id and status = 'active')
       and not exists(select 1 from public.profiles where user_id = old.user_id) then
        raise exception 'profile removal would orphan active server player %', old.user_id;
    end if;
    return null;
end;
$$;
drop trigger if exists profile_server_player_required on public.profiles;
create constraint trigger profile_server_player_required
after delete or update of user_id on public.profiles
deferrable initially deferred
for each row execute function public.prevent_orphan_server_player();

alter table server_players drop column if exists display_name;

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

-- Device installations are credentials, not player types. A player may use several
-- Windows machines or platform devices, and any one installation can be moved when a
-- provisional guest links an established account.
create table if not exists server_device_credentials (
    id uuid primary key,
    player_id uuid not null references server_players(id) on delete cascade,
    installation_hash text not null unique,
    created_at timestamptz not null default now(),
    last_authenticated_at timestamptz not null default now()
);
create index if not exists server_device_credentials_player_idx
    on server_device_credentials(player_id);

alter table server_players
    add column if not exists guest_installation_hash text unique;
insert into server_device_credentials (id, player_id, installation_hash)
select gen_random_uuid(), id, guest_installation_hash
  from server_players
 where guest_installation_hash is not null
on conflict (installation_hash) do nothing;

alter table server_players drop column if exists guest_installation_hash;

create table if not exists server_recovery_emails (
    id uuid primary key,
    player_id uuid not null unique references server_players(id) on delete cascade,
    normalized_email text not null unique,
    verified_at timestamptz not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint server_recovery_emails_normalized_check
        check (normalized_email = lower(trim(normalized_email)))
);

-- Copy confirmed legacy recovery addresses before Supabase Auth is retired. Dynamic
-- SQL keeps this migration valid for fresh installations that have no auth schema.
do $$
begin
  if to_regclass('auth.users') is not null then
    if exists(
        select 1 from information_schema.columns
         where table_schema = 'auth' and table_name = 'users'
           and column_name = 'confirmed_at'
    ) then
      execute $legacy_email_backfill$
        insert into server_recovery_emails
            (id, player_id, normalized_email, verified_at)
        select gen_random_uuid(), players.id, lower(trim(users.email)),
               coalesce(users.email_confirmed_at, users.confirmed_at, now())
          from server_players players
          join auth.users users on users.id = players.id
         where users.email is not null
           and trim(users.email) <> ''
           and (users.email_confirmed_at is not null or users.confirmed_at is not null)
        on conflict do nothing
      $legacy_email_backfill$;
    else
      execute $legacy_email_backfill$
        insert into server_recovery_emails
            (id, player_id, normalized_email, verified_at)
        select gen_random_uuid(), players.id, lower(trim(users.email)),
               users.email_confirmed_at
          from server_players players
          join auth.users users on users.id = players.id
         where users.email is not null
           and trim(users.email) <> ''
           and users.email_confirmed_at is not null
        on conflict do nothing
      $legacy_email_backfill$;
    end if;
  end if;
end
$$;

create table if not exists server_email_login_codes (
    id uuid primary key,
    requested_by_player_id uuid not null references server_players(id) on delete cascade,
    normalized_email text not null,
    code_hash text not null,
    expires_at timestamptz not null,
    attempts integer not null default 0 check (attempts between 0 and 8),
    consumed_at timestamptz,
    created_at timestamptz not null default now()
);
create index if not exists server_email_login_codes_lookup_idx
    on server_email_login_codes(requested_by_player_id, normalized_email, created_at desc);

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
    target_device_credential_id uuid references server_device_credentials(id) on delete set null,
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

-- Local auth.users data was imported only to bootstrap legacy profiles and recovery
-- addresses. No public table may continue treating it as the player owner.
do $$
declare
    dependency record;
begin
    for dependency in
        select constraints.table_schema,
               constraints.table_name,
               constraints.constraint_name
          from information_schema.table_constraints constraints
          join information_schema.constraint_column_usage referenced
            on referenced.constraint_schema = constraints.constraint_schema
           and referenced.constraint_name = constraints.constraint_name
         where constraints.constraint_type = 'FOREIGN KEY'
           and constraints.table_schema = 'public'
           and referenced.table_schema = 'auth'
           and referenced.table_name = 'users'
    loop
        execute format(
            'alter table %I.%I drop constraint %I',
            dependency.table_schema,
            dependency.table_name,
            dependency.constraint_name
        );
    end loop;
end
$$;

-- Operational visibility without inventing account types. Every row is a player;
-- these booleans describe which recovery credentials that player has attached.
create or replace view server_player_credential_summary as
select players.id as player_id,
       players.status,
       exists(
           select 1 from server_linked_identities identities
            where identities.player_id = players.id
       ) as has_platform_identity,
       exists(
           select 1 from server_recovery_emails emails
            where emails.player_id = players.id
       ) as has_recovery_email,
       exists(
           select 1 from server_device_credentials devices
            where devices.player_id = players.id
       ) as has_device_credential,
       exists(
           select 1 from server_linked_identities identities
            where identities.player_id = players.id
       ) or exists(
           select 1 from server_recovery_emails emails
            where emails.player_id = players.id
       ) as recoverable
  from server_players players;
