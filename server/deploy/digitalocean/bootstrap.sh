#!/bin/sh
set -eu

ROOT=/opt/kolkhoz-greenfield
SERVER_ENV=/etc/kolkhoz-greenfield.env
PORT=18787
REDIS_PORT=16379
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
apply=false
repo=
ref=

usage() { echo "usage: $0 --repo URL --ref COMMIT_OR_TAG [--apply]" >&2; exit 64; }
git_server() { git -c safe.directory="$ROOT" -C "$ROOT" "$@"; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) [ "$#" -ge 2 ] || usage; repo=$2; shift 2 ;;
    --ref) [ "$#" -ge 2 ] || usage; ref=$2; shift 2 ;;
    --apply) apply=true; shift ;;
    *) usage ;;
  esac
done
[ -n "$repo" ] && [ -n "$ref" ] || usage
[ -r "$SERVER_ENV" ] || { echo "missing $SERVER_ENV" >&2; exit 1; }
grep -q '^DATABASE_URL=' "$SERVER_ENV" || { echo "server database key missing" >&2; exit 1; }
if ss -H -ltn "sport = :$PORT" | grep -q . && ! systemctl is-active --quiet kolkhoz-greenfield.service; then
  echo "refusing: 127.0.0.1:$PORT is already in use" >&2; exit 1
fi
if ss -H -ltn "sport = :$REDIS_PORT" | grep -q . && ! systemctl is-active --quiet kolkhoz-greenfield-redis; then
  echo "refusing: Redis port $REDIS_PORT belongs to another process" >&2; exit 1
fi
if [ -e "$ROOT" ]; then
  [ -d "$ROOT/.git" ] || { echo "refusing non-git path $ROOT" >&2; exit 1; }
  [ -z "$(git_server status --porcelain)" ] || { echo "refusing dirty server checkout" >&2; exit 1; }
  actual=$(git_server remote get-url origin)
  [ "$actual" = "$repo" ] || { echo "server remote mismatch" >&2; exit 1; }
fi

if ! $apply; then
  echo "DRY RUN: would install redis-server, PostgreSQL client, Python venv, clang, and git"
  echo "DRY RUN: would clone/update $repo at requested ref into $ROOT"
  echo "DRY RUN: would read database and Supabase auth from $SERVER_ENV without displaying values"
  echo "DRY RUN: would apply six server schemas explicitly"
  echo "DRY RUN: would install capped Redis on 127.0.0.1:$REDIS_PORT and the server on 127.0.0.1:$PORT"
  echo "DRY RUN: would schedule daily deletion of email accounts unconfirmed for more than seven days"
  echo "DRY RUN: would configure Caddy to bridge short upstream restart gaps"
  exit 0
fi
[ "$(id -u)" -eq 0 ] || { echo "--apply must run as root" >&2; exit 1; }
available_kb=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
free_kb=$(df -Pk /opt | awk 'NR == 2 { print $4 }')
[ "${available_kb:-0}" -ge 358400 ] || { echo "refusing: server needs at least 350 MB MemAvailable" >&2; exit 1; }
[ "${free_kb:-0}" -ge 2097152 ] || { echo "refusing: server needs at least 2 GB free under /opt" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
redis_was_installed=false
dpkg-query -W -f='${Status}' redis-server 2>/dev/null | grep -q 'install ok installed' && redis_was_installed=true
apt-get update
apt-get install -y --no-install-recommends redis-server postgresql-client python3-venv clang git ca-certificates curl iproute2
if ! $redis_was_installed; then
  systemctl disable --now redis-server.service redis.service 2>/dev/null || true
fi
id kolkhoz-greenfield >/dev/null 2>&1 || useradd --system --home-dir "$ROOT" --shell /usr/sbin/nologin kolkhoz-greenfield
systemctl stop kolkhoz-greenfield.service 2>/dev/null || true
if [ ! -e "$ROOT" ]; then git clone --filter=blob:none "$repo" "$ROOT"; fi
git_server fetch --tags --prune origin
git_server checkout --detach "$ref"
test "$(git_server rev-parse HEAD)" = "$(git_server rev-parse "$ref^{commit}")"
printf 'KOLKHOZ_BUILD_SHA=%s\n' "$(git_server rev-parse HEAD)" > /etc/kolkhoz-greenfield-build.env
chmod 0644 /etc/kolkhoz-greenfield-build.env
cd "$ROOT"
python3 -m venv "$ROOT/.venv"
"$ROOT/.venv/bin/pip" install --disable-pip-version-check -r "$ROOT/server/deploy/requirements.txt"
"$ROOT/.venv/bin/python" -c 'from research.kolkhoz_research.c_engine import CEngine; CEngine()'
test -s "$ROOT/policies/medium_policy.json"
test -s "$ROOT/policies/hard_policy.json"
"$ROOT/.venv/bin/python" -m server.kolkhoz_server.preflight --repo-root "$ROOT"
install -d -o kolkhoz-greenfield -g kolkhoz-greenfield "$ROOT/research/.build"
install -d -o root -g kolkhoz-greenfield -m 0750 /etc/kolkhoz-greenfield
chown -R kolkhoz-greenfield:kolkhoz-greenfield "$ROOT"

umask 077
database_url=$(sed -n 's/^DATABASE_URL=//p' "$SERVER_ENV" | tail -n 1)
supabase_url=$(sed -n 's/^KOLKHOZ_SUPABASE_URL=//p' "$SERVER_ENV" | tail -n 1)
publishable=$(sed -n 's/^KOLKHOZ_SUPABASE_PUBLISHABLE_KEY=//p' "$SERVER_ENV" | tail -n 1)
secret_key=$(sed -n 's/^KOLKHOZ_SUPABASE_SECRET_KEY=//p' "$SERVER_ENV" | tail -n 1)
[ -n "$database_url" ] && [ -n "$supabase_url" ] && [ -n "$publishable" ] && [ -n "$secret_key" ] || { echo "database/Supabase settings incomplete" >&2; exit 1; }
for schema in postgres_schema.sql lobby_schema.sql distributed_schema.sql command_schema.sql population_schema.sql notifications_schema.sql commerce_schema.sql; do
  DATABASE_URL="$database_url" psql "$database_url" -v ON_ERROR_STOP=1 -f "$ROOT/server/$schema" >/dev/null
done
unset database_url supabase_url publishable secret_key
install -d -o redis -g redis /var/lib/redis-greenfield
install -o root -g redis -m 0640 "$here/redis-greenfield.conf" /etc/redis/kolkhoz-greenfield.conf
install -o root -g root -m 0644 "$here/kolkhoz-greenfield-redis.service" /etc/systemd/system/kolkhoz-greenfield-redis.service
install -o root -g root -m 0644 "$here/kolkhoz-greenfield.service" /etc/systemd/system/kolkhoz-greenfield.service
install -o root -g root -m 0644 "$here/kolkhoz-admin-control.service" /etc/systemd/system/kolkhoz-admin-control.service
install -o root -g root -m 0755 "$here/health-watch.sh" /usr/local/sbin/kolkhoz-health-watch
install -o root -g root -m 0755 "$here/ai-canary.sh" /usr/local/sbin/kolkhoz-ai-canary
install -o root -g root -m 0644 "$here/kolkhoz-health-watch.service" /etc/systemd/system/kolkhoz-health-watch.service
install -o root -g root -m 0644 "$here/kolkhoz-health-watch.timer" /etc/systemd/system/kolkhoz-health-watch.timer
install -o root -g root -m 0644 "$here/kolkhoz-ai-canary.service" /etc/systemd/system/kolkhoz-ai-canary.service
install -o root -g root -m 0644 "$here/kolkhoz-ai-canary.timer" /etc/systemd/system/kolkhoz-ai-canary.timer
install -o root -g root -m 0644 "$here/kolkhoz-unconfirmed-account-cleanup.service" /etc/systemd/system/kolkhoz-unconfirmed-account-cleanup.service
install -o root -g root -m 0644 "$here/kolkhoz-unconfirmed-account-cleanup.timer" /etc/systemd/system/kolkhoz-unconfirmed-account-cleanup.timer
install -o root -g root -m 0644 "$here/Caddyfile" /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy
systemctl daemon-reload
systemctl enable --now kolkhoz-greenfield-redis.service
systemctl enable kolkhoz-greenfield.service
systemctl enable --now kolkhoz-admin-control.service
systemctl restart kolkhoz-greenfield.service
systemctl enable --now kolkhoz-health-watch.timer
systemctl enable --now kolkhoz-ai-canary.timer
systemctl enable --now kolkhoz-unconfirmed-account-cleanup.timer
ready=false
for _ in $(seq 1 30); do
  if curl --fail --silent --max-time 2 http://127.0.0.1:18787/ready >/dev/null; then
    ready=true
    break
  fi
  sleep 1
done
$ready || { systemctl status kolkhoz-greenfield.service --no-pager >&2; exit 1; }
curl --fail --silent --max-time 5 http://127.0.0.1:18787/metrics/prometheus | grep -q '^kolkhoz_uptime_seconds '
/usr/local/sbin/kolkhoz-health-watch
echo "Kolkhoz server ready on loopback port 18787"
