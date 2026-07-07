revoke insert, update on public.profile_stats from authenticated, anon, public;

drop policy if exists "users can create their profile stats" on public.profile_stats;
drop policy if exists "users can update their profile stats" on public.profile_stats;
