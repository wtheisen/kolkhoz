alter table public.profile_stats
    add column if not exists online_abandon_strikes integer not null default 0,
    add column if not exists online_banned_until timestamptz;

alter table public.profile_stats
    drop constraint if exists profile_stats_online_discipline_check;

alter table public.profile_stats
    add constraint profile_stats_online_discipline_check
        check (online_abandon_strikes >= 0);
