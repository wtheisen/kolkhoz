#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE="${KOLKHOZ_POSTGRES_SMOKE_IMAGE:-postgres:17-alpine}"
CONTAINER="kolkhoz-postgres-smoke-${$}"

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker run --name "$CONTAINER" \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=kolkhoz \
  -d "$IMAGE" >/dev/null

for _ in $(seq 1 150); do
  # The image briefly starts a bootstrap postmaster before restarting the final
  # server, so require an actual query rather than trusting transient readiness.
  if docker exec "$CONTAINER" psql -X -U postgres -d kolkhoz -Atqc \
      'select 1' >/dev/null 2>&1; then
    sleep 0.5
    if docker exec "$CONTAINER" psql -X -U postgres -d kolkhoz -Atqc \
        'select 1' >/dev/null 2>&1; then
      break
    fi
  fi
  sleep 0.2
done
docker exec "$CONTAINER" psql -X -U postgres -d kolkhoz -Atqc 'select 1' >/dev/null

psql_stdin() {
  docker exec -i "$CONTAINER" psql -X -U postgres -d kolkhoz \
    -v ON_ERROR_STOP=1 "$@"
}

# Vanilla PostgreSQL does not provide the small auth surface referenced by the
# existing Supabase migrations. This is deliberately only a disposable test shim.
psql_stdin <<'SQL'
create schema auth;
create role anon nologin;
create role authenticated nologin;
create table auth.users (
    id uuid primary key,
    aud varchar(255),
    role varchar(255),
    email varchar(255),
    email_confirmed_at timestamptz,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    created_at timestamptz,
    updated_at timestamptz,
    is_sso_user boolean default false,
    is_anonymous boolean default false
);
create function auth.uid() returns uuid language sql stable
as $$ select null::uuid $$;
create publication supabase_realtime;
SQL

# Apply the deployed Supabase history first. -1 is important because the bot
# seed migration intentionally uses an ON COMMIT DROP temporary table.
while IFS= read -r migration; do
  psql_stdin -1 < "$migration" >/dev/null
done < <(find "$ROOT/supabase/migrations" -name '*.sql' -type f | sort)

schemas=(
  server/postgres_schema.sql
  server/lobby_schema.sql
  server/distributed_schema.sql
  server/command_schema.sql
  server/population_schema.sql
  server/notifications_schema.sql
  server/commerce_schema.sql
  server/tournament_schema.sql
)

# New server schemas are rerunnable deployment inputs. Applying them twice
# catches missing IF NOT EXISTS clauses and ordering dependencies.
for pass in 1 2; do
  for schema in "${schemas[@]}"; do
    psql_stdin -1 < "$ROOT/$schema" >/dev/null
  done
  echo "schema pass $pass: ok"
done

# Exercise the core production relationships and write patterns in one concise
# database-side smoke: game/event CAS, lobby/seat query, ownership fencing,
# population coordination, command receipts, and exactly-once result metadata.
psql_stdin <<'SQL'
insert into auth.users (id, email, created_at, updated_at)
values ('10000000-0000-4000-8000-000000000001', 'smoke@kolkhoz.local', now(), now());
insert into public.profiles (user_id, display_name)
values ('10000000-0000-4000-8000-000000000001', 'Smoke Player');

insert into server_games (session_id, seed, variants)
values ('20000000-0000-4000-8000-000000000001', 42, '{"controllers":["human","heuristicAI","heuristicAI","heuristicAI"]}');
insert into server_sessions (
    session_id, invite_code, seed, variants, controllers, ranked,
    browser_joinable, status, created_by_user_id, expires_at
) values (
    '20000000-0000-4000-8000-000000000001', 'SMOKE1', 42, '{}',
    '["human","heuristicAI","heuristicAI","heuristicAI"]', false,
    true, 'open', '10000000-0000-4000-8000-000000000001', now() + interval '1 hour'
);
insert into server_seats (
    session_id, player_id, controller, occupied, user_id, token_hash, last_seen_at
) values
    ('20000000-0000-4000-8000-000000000001', 0, 'human', true,
     '10000000-0000-4000-8000-000000000001', 'smoke-token', now()),
    ('20000000-0000-4000-8000-000000000001', 1, 'human', false, null, null, null),
    ('20000000-0000-4000-8000-000000000001', 2, 'human', false, null, null, null),
    ('20000000-0000-4000-8000-000000000001', 3, 'human', false, null, null, null);

with advanced as (
    update server_games set revision = revision + 1, fencing_token = 1, updated_at = now()
     where session_id = '20000000-0000-4000-8000-000000000001' and revision = 0
     returning revision
)
insert into server_game_events (session_id, revision, kind, payload)
select '20000000-0000-4000-8000-000000000001', revision, 'action', '{"type":"smoke"}'
from advanced;

insert into game_session_leases (session_id, owner_id, fencing_token, expires_at)
values ('20000000-0000-4000-8000-000000000001', 'worker-a', 1, now() + interval '30 seconds')
on conflict (session_id) do update set
    owner_id = excluded.owner_id,
    fencing_token = game_session_leases.fencing_token + 1,
    expires_at = excluded.expires_at;
insert into population_intervals (job_kind, interval_epoch, owner_id, fencing_token, expires_at)
values ('fill', 1, 'scheduler-a', 1, now() + interval '30 seconds');
update public.server_bot_profiles set use_count = use_count + 1, last_used_at = now()
where user_id = '00000000-0000-4000-8000-000000000101';
insert into game_command_receipts (
    command_id, session_id, fencing_token, result_json
) values (
    'smoke-command', '20000000-0000-4000-8000-000000000001', 1, '{"ok":true}'
);

insert into server_progression_events (session_id, user_id)
values ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001')
on conflict (session_id, user_id) do nothing;
update public.profile_stats
   set games_played = games_played + 1,
       online_games = online_games + 1,
       wins_total = wins_total + 1,
       online_wins = online_wins + 1,
       updated_at = now()
 where user_id = '10000000-0000-4000-8000-000000000001';
update server_sessions set status = 'finished', updated_at = now()
where session_id = '20000000-0000-4000-8000-000000000001' and status <> 'finished';

do $$
declare
    lobby_rows integer;
begin
    select count(*) into lobby_rows
      from server_sessions s
     where s.invite_code = 'SMOKE1' and s.browser_joinable;
    if lobby_rows <> 1 then raise exception 'lobby smoke failed'; end if;
    if (select revision from server_games where session_id = '20000000-0000-4000-8000-000000000001') <> 1
       then raise exception 'event revision smoke failed'; end if;
    if (select count(*) from server_game_events where session_id = '20000000-0000-4000-8000-000000000001') <> 1
       then raise exception 'event append smoke failed'; end if;
    if (select fencing_token from game_session_leases where session_id = '20000000-0000-4000-8000-000000000001') <> 1
       then raise exception 'lease smoke failed'; end if;
    if (select use_count from public.server_bot_profiles where user_id = '00000000-0000-4000-8000-000000000101') <> 1
       then raise exception 'population smoke failed'; end if;
    if (select online_games from public.profile_stats where user_id = '10000000-0000-4000-8000-000000000001') <> 1
       then raise exception 'result smoke failed'; end if;
end $$;
SQL

echo "postgres smoke: ok"
