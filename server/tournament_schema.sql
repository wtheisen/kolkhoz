-- Durable weekly multiplayer tournament state.

create table if not exists server_tournaments (
    tournament_id uuid primary key,
    starts_at timestamptz not null unique,
    join_opens_at timestamptz not null,
    join_closes_at timestamptz not null,
    status text not null check (
        status in ('enrollment', 'playing', 'completed', 'cancelled')
    ),
    current_round smallint not null default 0 check (current_round between 0 and 4),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint server_tournaments_window check (
        join_opens_at < join_closes_at and join_closes_at <= starts_at
    )
);

create index if not exists server_tournaments_current_idx
    on server_tournaments (status, starts_at);

create table if not exists server_tournament_entries (
    tournament_id uuid not null references server_tournaments(tournament_id) on delete cascade,
    user_id uuid not null references public.profiles(user_id) on delete cascade,
    controller text not null,
    is_bot boolean not null default false,
    status text not null default 'active' check (status in ('active', 'forfeited', 'withdrawn')),
    joined_at timestamptz not null default now(),
    tournament_points numeric(8, 2) not null default 0,
    wins smallint not null default 0,
    game_score integer not null default 0,
    final_placement integer check (final_placement > 0),
    primary key (tournament_id, user_id)
);

alter table server_tournament_entries
    add column if not exists final_placement integer;
drop index if exists server_tournament_active_human_idx;

create table if not exists server_tournament_tables (
    table_id uuid primary key,
    tournament_id uuid not null references server_tournaments(tournament_id) on delete cascade,
    round_number smallint not null check (round_number between 1 and 4),
    table_number integer not null check (table_number > 0),
    session_id uuid not null unique,
    status text not null default 'planned' check (status in ('planned', 'active', 'completed')),
    created_at timestamptz not null default now(),
    completed_at timestamptz,
    unique (tournament_id, round_number, table_number)
);

create index if not exists server_tournament_tables_round_idx
    on server_tournament_tables (tournament_id, round_number, status);

create table if not exists server_tournament_table_seats (
    table_id uuid not null references server_tournament_tables(table_id) on delete cascade,
    user_id uuid not null references public.profiles(user_id) on delete cascade,
    player_id smallint not null check (player_id between 0 and 3),
    score integer,
    medals integer,
    placement smallint check (placement between 1 and 4),
    tournament_points numeric(8, 2),
    primary key (table_id, user_id),
    unique (table_id, player_id)
);

create index if not exists server_tournament_seats_user_idx
    on server_tournament_table_seats (user_id, table_id);
