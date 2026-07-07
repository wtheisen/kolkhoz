alter table public.game_sessions
    add column if not exists turn_player_id integer,
    add column if not exists turn_deadline_at timestamptz;

alter table public.game_sessions
    drop constraint if exists game_sessions_turn_player_id_check;

alter table public.game_sessions
    add constraint game_sessions_turn_player_id_check
        check (turn_player_id is null or turn_player_id between 0 and 3);

alter table public.game_seats
    add column if not exists last_seen_at timestamptz,
    add column if not exists disconnected_at timestamptz,
    add column if not exists timeouts integer not null default 0,
    add column if not exists abandoned boolean not null default false,
    add column if not exists autopilot boolean not null default false;

alter table public.game_seats
    drop constraint if exists game_seats_presence_check;

alter table public.game_seats
    add constraint game_seats_presence_check
        check (timeouts >= 0);
