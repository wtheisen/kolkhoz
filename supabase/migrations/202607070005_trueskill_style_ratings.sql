alter table public.profile_stats
    add column if not exists rating_mu double precision not null default 25.0,
    add column if not exists rating_sigma double precision not null default 8.333333333333334,
    add column if not exists rating_version integer not null default 1;

update public.profile_stats
   set rating_mu = 25.0 + ((rating - 1000)::double precision / 32.0),
       rating_sigma = 8.333333333333334,
       rating_version = 2
 where rating_version < 2;

alter table public.profile_stats
    alter column rating_version set default 2;

alter table public.profile_stats
    drop constraint if exists profile_stats_rating_distribution_check;

alter table public.profile_stats
    add constraint profile_stats_rating_distribution_check
        check (
            rating >= 100
            and rating <= 3000
            and peak_rating >= rating
            and rating_mu > 0
            and rating_sigma >= 2.0
            and rating_sigma <= 8.333333333333334
            and rating_version >= 2
        );

alter table public.game_seats
    drop constraint if exists game_seats_controller_check;

alter table public.game_seats
    add constraint game_seats_controller_check
        check (controller in ('human', 'heuristicAI', 'mediumAI', 'neuralAI'));

create table if not exists public.ai_profile_stats (
    ai_key text primary key,
    display_name text not null,
    games_played integer not null default 0,
    wins_total integer not null default 0,
    online_games integer not null default 0,
    online_wins integer not null default 0,
    rating integer not null default 1000,
    peak_rating integer not null default 1000,
    rating_games integer not null default 0,
    rating_mu double precision not null default 25.0,
    rating_sigma double precision not null default 8.333333333333334,
    rating_version integer not null default 2,
    updated_at timestamptz not null default now(),
    constraint ai_profile_stats_non_negative_check
        check (
            games_played >= 0
            and wins_total >= 0
            and online_games >= 0
            and online_wins >= 0
            and rating_games >= 0
        ),
    constraint ai_profile_stats_wins_bounds_check
        check (
            wins_total <= games_played
            and online_wins <= online_games
        ),
    constraint ai_profile_stats_rating_check
        check (
            rating >= 100
            and rating <= 3000
            and peak_rating >= rating
            and rating_mu > 0
            and rating_sigma >= 2.0
            and rating_sigma <= 8.333333333333334
            and rating_version >= 2
        )
);

insert into public.ai_profile_stats (ai_key, display_name)
values
    ('heuristicAI', 'Easy AI'),
    ('mediumAI', 'Medium AI'),
    ('neuralAI', 'Hard AI')
on conflict (ai_key) do update
    set display_name = excluded.display_name;

alter table public.ai_profile_stats enable row level security;

grant select on public.ai_profile_stats to authenticated;
revoke insert, update, delete on public.ai_profile_stats from authenticated, anon, public;

drop policy if exists "authenticated users can see ai profile stats" on public.ai_profile_stats;
create policy "authenticated users can see ai profile stats"
    on public.ai_profile_stats
    for select
    to authenticated
    using (true);
