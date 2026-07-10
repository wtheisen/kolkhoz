create table if not exists public.profile_progression (
    user_id uuid primary key references public.profiles(user_id) on delete cascade,
    progress jsonb not null default '{}'::jsonb,
    completed text[] not null default '{}',
    unlocks text[] not null default '{}',
    updated_at timestamptz not null default now()
);

create table if not exists public.profile_progression_events (
    session_id uuid not null references public.game_sessions(session_id) on delete cascade,
    user_id uuid not null references public.profiles(user_id) on delete cascade,
    recorded_at timestamptz not null default now(),
    primary key (session_id, user_id)
);

alter table public.profile_progression enable row level security;
alter table public.profile_progression_events enable row level security;

grant select on public.profile_progression to authenticated;
revoke insert, update, delete on public.profile_progression
    from authenticated, anon, public;
revoke all on public.profile_progression_events from authenticated, anon, public;

drop policy if exists "users can read their progression"
    on public.profile_progression;
create policy "users can read their progression"
    on public.profile_progression
    for select
    to authenticated
    using (auth.uid() = user_id);
