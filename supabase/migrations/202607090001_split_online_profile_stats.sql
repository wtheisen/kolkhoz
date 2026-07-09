alter table public.profile_stats
    add column if not exists casual_games integer not null default 0,
    add column if not exists casual_wins integer not null default 0,
    add column if not exists ranked_games integer not null default 0,
    add column if not exists ranked_wins integer not null default 0;

update public.profile_stats
   set ranked_games = greatest(rating_games, ranked_games),
       casual_games = greatest(online_games - rating_games, casual_games),
       ranked_wins = greatest(least(online_wins, rating_games), ranked_wins),
       casual_wins = greatest(
           online_wins - least(online_wins, rating_games),
           casual_wins
       );

alter table public.profile_stats
    drop constraint if exists profile_stats_split_online_non_negative_check;

alter table public.profile_stats
    add constraint profile_stats_split_online_non_negative_check
        check (
            casual_games >= 0
            and casual_wins >= 0
            and ranked_games >= 0
            and ranked_wins >= 0
        );

alter table public.profile_stats
    drop constraint if exists profile_stats_split_online_bounds_check;

alter table public.profile_stats
    add constraint profile_stats_split_online_bounds_check
        check (
            casual_wins <= casual_games
            and ranked_wins <= ranked_games
            and casual_games + ranked_games <= online_games
            and casual_wins + ranked_wins <= online_wins
        );

alter table public.ai_profile_stats
    add column if not exists casual_games integer not null default 0,
    add column if not exists casual_wins integer not null default 0,
    add column if not exists ranked_games integer not null default 0,
    add column if not exists ranked_wins integer not null default 0;

update public.ai_profile_stats
   set ranked_games = greatest(rating_games, ranked_games),
       casual_games = greatest(online_games - rating_games, casual_games),
       ranked_wins = greatest(least(online_wins, rating_games), ranked_wins),
       casual_wins = greatest(
           online_wins - least(online_wins, rating_games),
           casual_wins
       );

alter table public.ai_profile_stats
    drop constraint if exists ai_profile_stats_split_online_non_negative_check;

alter table public.ai_profile_stats
    add constraint ai_profile_stats_split_online_non_negative_check
        check (
            casual_games >= 0
            and casual_wins >= 0
            and ranked_games >= 0
            and ranked_wins >= 0
        );

alter table public.ai_profile_stats
    drop constraint if exists ai_profile_stats_split_online_bounds_check;

alter table public.ai_profile_stats
    add constraint ai_profile_stats_split_online_bounds_check
        check (
            casual_wins <= casual_games
            and ranked_wins <= ranked_games
            and casual_games + ranked_games <= online_games
            and casual_wins + ranked_wins <= online_wins
        );
