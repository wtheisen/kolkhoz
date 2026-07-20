-- Production-only retirement of the imported Supabase database objects.
-- identity_schema.sql must run first so verified email addresses and canonical
-- player UUIDs are preserved before this legacy storage is removed.
begin;

drop table if exists public.game_reactions;
drop table if exists public.game_updates;
drop table if exists public.game_actions;
drop table if exists public.profile_progression_events;
drop table if exists public.game_seats;
drop table if exists public.game_sessions;

drop function if exists public.is_game_session_player(uuid);
drop function if exists public.record_offline_result(boolean);

-- Token verification still talks to the remote Supabase Auth service during the
-- migration window. The local imported auth schema is not part of that bridge.
drop schema if exists auth cascade;

commit;
