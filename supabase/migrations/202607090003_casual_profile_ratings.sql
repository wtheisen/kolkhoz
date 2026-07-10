alter table public.profile_stats
    add column if not exists casual_rating integer not null default 1000,
    add column if not exists casual_peak_rating integer not null default 1000,
    add column if not exists casual_rating_games integer not null default 0,
    add column if not exists casual_rating_mu double precision not null default 25.0,
    add column if not exists casual_rating_sigma double precision not null default 8.333333333333334,
    add column if not exists casual_rating_version integer not null default 2;

alter table public.profile_stats
    drop constraint if exists profile_stats_casual_rating_check;

alter table public.profile_stats
    add constraint profile_stats_casual_rating_check
        check (
            casual_rating >= 100
            and casual_rating <= 3000
            and casual_peak_rating >= casual_rating
            and casual_rating_games >= 0
            and casual_rating_games <= casual_games
            and casual_rating_mu > 0
            and casual_rating_sigma >= 2.0
            and casual_rating_sigma <= 8.333333333333334
            and casual_rating_version >= 2
        );

alter table public.ai_profile_stats
    add column if not exists casual_rating integer not null default 1000,
    add column if not exists casual_peak_rating integer not null default 1000,
    add column if not exists casual_rating_games integer not null default 0,
    add column if not exists casual_rating_mu double precision not null default 25.0,
    add column if not exists casual_rating_sigma double precision not null default 8.333333333333334,
    add column if not exists casual_rating_version integer not null default 2;

alter table public.ai_profile_stats
    drop constraint if exists ai_profile_stats_casual_rating_check;

alter table public.ai_profile_stats
    add constraint ai_profile_stats_casual_rating_check
        check (
            casual_rating >= 100
            and casual_rating <= 3000
            and casual_peak_rating >= casual_rating
            and casual_rating_games >= 0
            and casual_rating_games <= casual_games
            and casual_rating_mu > 0
            and casual_rating_sigma >= 2.0
            and casual_rating_sigma <= 8.333333333333334
            and casual_rating_version >= 2
        );
