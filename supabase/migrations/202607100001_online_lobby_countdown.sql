alter table public.game_sessions
    add column if not exists lobby_countdown_ends_at timestamptz;

create table if not exists public.game_reactions (
    session_id uuid not null references public.game_sessions(session_id) on delete cascade,
    revision integer not null,
    player_id integer not null,
    reaction_id text not null,
    year integer not null check (year between 1 and 5),
    phase integer not null check (phase between 0 and 5),
    created_at timestamptz not null default now(),
    primary key (session_id, revision),
    constraint game_reactions_player_id_check check (player_id between 0 and 3)
);

alter table public.game_reactions enable row level security;

drop policy if exists "players can see game reactions" on public.game_reactions;
create policy "players can see game reactions"
    on public.game_reactions
    for select
    using (public.is_game_session_player(game_reactions.session_id));
