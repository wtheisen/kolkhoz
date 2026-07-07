create extension if not exists pgcrypto;

create table if not exists public.profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    display_name text not null,
    avatar_url text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint profiles_display_name_not_blank
        check (length(trim(display_name)) > 0)
);

create table if not exists public.profile_stats (
    user_id uuid primary key references public.profiles(user_id) on delete cascade,
    games_played integer not null default 0,
    wins_total integer not null default 0,
    offline_games integer not null default 0,
    offline_wins integer not null default 0,
    online_games integer not null default 0,
    online_wins integer not null default 0,
    rating integer not null default 1000,
    peak_rating integer not null default 1000,
    rating_games integer not null default 0,
    current_win_streak integer not null default 0,
    best_win_streak integer not null default 0,
    updated_at timestamptz not null default now(),
    constraint profile_stats_non_negative_check
        check (
            games_played >= 0
            and wins_total >= 0
            and offline_games >= 0
            and offline_wins >= 0
            and online_games >= 0
            and online_wins >= 0
            and rating_games >= 0
            and current_win_streak >= 0
            and best_win_streak >= 0
        ),
    constraint profile_stats_wins_bounds_check
        check (
            wins_total <= games_played
            and offline_wins <= offline_games
            and online_wins <= online_games
            and offline_games + online_games <= games_played
            and offline_wins + online_wins <= wins_total
        ),
    constraint profile_stats_peak_rating_check check (peak_rating >= rating)
);

create table if not exists public.game_sessions (
    session_id uuid primary key,
    invite_code text unique,
    seed bigint not null,
    variants jsonb not null,
    controllers text[] not null,
    status text not null default 'open',
    action_log_count integer not null default 0,
    policy_model_sha text,
    created_by uuid references auth.users(id) on delete set null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    expires_at timestamptz not null,
    constraint game_sessions_status_check
        check (status in ('open', 'active', 'finished', 'expired', 'abandoned'))
);

create index if not exists game_sessions_open_idx
    on public.game_sessions (status, expires_at)
    where status in ('open', 'active');

create table if not exists public.game_seats (
    session_id uuid not null references public.game_sessions(session_id) on delete cascade,
    player_id integer not null,
    controller text not null,
    occupied boolean not null default false,
    user_id uuid references auth.users(id) on delete set null,
    seat_token_hash text,
    joined_at timestamptz,
    primary key (session_id, player_id),
    constraint game_seats_player_id_check check (player_id between 0 and 3),
    constraint game_seats_controller_check
        check (controller in ('human', 'heuristicAI', 'neuralAI'))
);

create index if not exists game_seats_user_idx
    on public.game_seats (user_id)
    where user_id is not null;

create table if not exists public.game_actions (
    session_id uuid not null references public.game_sessions(session_id) on delete cascade,
    revision integer not null,
    player_id integer not null,
    action jsonb not null,
    created_at timestamptz not null default now(),
    primary key (session_id, revision),
    constraint game_actions_revision_check check (revision > 0),
    constraint game_actions_player_id_check check (player_id between 0 and 3)
);

create table if not exists public.game_snapshots (
    session_id uuid not null references public.game_sessions(session_id) on delete cascade,
    revision integer not null,
    viewer_id integer not null,
    snapshot jsonb not null,
    created_at timestamptz not null default now(),
    primary key (session_id, revision, viewer_id),
    constraint game_snapshots_viewer_id_check check (viewer_id between 0 and 3)
);

create table if not exists public.game_updates (
    id uuid primary key default gen_random_uuid(),
    session_id uuid not null references public.game_sessions(session_id) on delete cascade,
    revision integer,
    event_type text not null,
    payload jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists game_updates_session_created_idx
    on public.game_updates (session_id, created_at desc);

alter table public.game_sessions enable row level security;
alter table public.profiles enable row level security;
alter table public.profile_stats enable row level security;
alter table public.game_seats enable row level security;
alter table public.game_actions enable row level security;
alter table public.game_snapshots enable row level security;
alter table public.game_updates enable row level security;

grant select on public.profiles to authenticated;
grant insert, update on public.profiles to authenticated;
grant select on public.profile_stats to authenticated;

drop policy if exists "authenticated users can see profiles" on public.profiles;
create policy "authenticated users can see profiles"
    on public.profiles
    for select
    to authenticated
    using (true);

drop policy if exists "users can create their profile" on public.profiles;
create policy "users can create their profile"
    on public.profiles
    for insert
    to authenticated
    with check (auth.uid() = user_id);

drop policy if exists "users can update their profile" on public.profiles;
create policy "users can update their profile"
    on public.profiles
    for update
    to authenticated
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

drop policy if exists "authenticated users can see profile stats" on public.profile_stats;
create policy "authenticated users can see profile stats"
    on public.profile_stats
    for select
    to authenticated
    using (true);

create or replace function public.create_profile_stats()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profile_stats (user_id)
    values (new.user_id)
    on conflict (user_id) do nothing;
    return new;
end;
$$;

drop trigger if exists profiles_create_stats on public.profiles;
create trigger profiles_create_stats
    after insert on public.profiles
    for each row execute function public.create_profile_stats();

create or replace function public.is_game_session_player(target_session_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select exists (
        select 1
          from public.game_seats
         where game_seats.session_id = target_session_id
           and game_seats.user_id = auth.uid()
    );
$$;

drop policy if exists "open sessions are visible" on public.game_sessions;
create policy "open sessions are visible"
    on public.game_sessions
    for select
    using (status = 'open' and expires_at > now());

drop policy if exists "players can see their sessions" on public.game_sessions;
create policy "players can see their sessions"
    on public.game_sessions
    for select
    using (public.is_game_session_player(game_sessions.session_id));

drop policy if exists "players can see their update notifications" on public.game_updates;
create policy "players can see their update notifications"
    on public.game_updates
    for select
    using (public.is_game_session_player(game_updates.session_id));

do $$
begin
    execute 'alter publication supabase_realtime add table public.game_updates';
exception
    when duplicate_object then null;
    when undefined_object then null;
end $$;
