alter table public.game_sessions
    add column if not exists ranked boolean not null default true,
    add column if not exists browser_joinable boolean not null default true;

update public.game_sessions
   set ranked = false
 where browser_joinable = false;
