#!/bin/sh
set -eu

for migration in /schema/supabase/migrations/*.sql; do
  psql -X -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -1 -f "$migration"
done

for schema in \
  postgres_schema.sql \
  lobby_schema.sql \
  distributed_schema.sql \
  command_schema.sql \
  population_schema.sql \
  notifications_schema.sql \
  commerce_schema.sql \
  tournament_schema.sql \
  identity_schema.sql
do
  psql -X -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -1 -f "/schema/server/$schema"
done

psql -X -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
insert into auth.users (id, email, created_at, updated_at) values
  ('10000000-0000-4000-8000-000000000001', 'host@staging.local', now(), now()),
  ('10000000-0000-4000-8000-000000000002', 'guest@staging.local', now(), now())
on conflict (id) do nothing;

insert into public.profiles (user_id, display_name) values
  ('10000000-0000-4000-8000-000000000001', 'Staging Host'),
  ('10000000-0000-4000-8000-000000000002', 'Staging Guest')
on conflict (user_id) do nothing;

insert into auth.users (id, email, created_at, updated_at)
select ('20000000-0000-4000-8000-' || lpad(value::text, 12, '0'))::uuid,
       'load-' || value || '@staging.local', now(), now()
  from generate_series(1, 1024) as identities(value)
on conflict (id) do nothing;

insert into public.profiles (user_id, display_name)
select ('20000000-0000-4000-8000-' || lpad(value::text, 12, '0'))::uuid,
       'Load Player ' || value
  from generate_series(1, 1024) as identities(value)
on conflict (user_id) do nothing;
SQL
