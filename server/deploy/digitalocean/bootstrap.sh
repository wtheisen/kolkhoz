#!/bin/sh
set -eu

ROOT=/opt/kolkhoz-server
SERVER_ENV=/etc/kolkhoz-server.env
BUILD_ENV=/etc/kolkhoz-server-build.env
SERVICE=kolkhoz-server.service
REDIS_SERVICE=kolkhoz-server-redis.service
RUN_USER=kolkhoz-server
ADMIN_USER=kolkhoz-admin
ADMIN_ENV=/etc/kolkhoz-admin-control.env
REDIS_DIR=/var/lib/kolkhoz-server-redis
PORT=18787
REDIS_PORT=16379

# One-time inputs for upgrading the former parallel-rewrite installation. They are
# archived under the production namespace only after the replacement is healthy.
LEGACY_ROOT=/opt/kolkhoz-greenfield
LEGACY_SERVER_ENV=/etc/kolkhoz-greenfield.env
LEGACY_BUILD_ENV=/etc/kolkhoz-greenfield-build.env
LEGACY_SECRET_DIR=/etc/kolkhoz-greenfield
LEGACY_REDIS_DIR=/var/lib/redis-greenfield
LEGACY_SERVICE=kolkhoz-greenfield.service
LEGACY_REDIS_SERVICE=kolkhoz-greenfield-redis.service
LEGACY_RUN_USER=kolkhoz-greenfield
ARCHIVE_ROOT=/opt/kolkhoz-server.pre-rename
ARCHIVE_SERVER_ENV=/etc/kolkhoz-server.pre-rename.env
ARCHIVE_BUILD_ENV=/etc/kolkhoz-server-build.pre-rename.env
ARCHIVE_SECRET_DIR=/etc/kolkhoz-server.pre-rename
ARCHIVE_REDIS_DIR=/var/lib/kolkhoz-server-redis.pre-rename

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
apply=false
repo=
ref=
migrating=false
env_source=$SERVER_ENV

usage() { echo "usage: $0 --repo URL --ref COMMIT_OR_TAG [--apply]" >&2; exit 64; }
git_server() { git -c safe.directory="$ROOT" -C "$ROOT" "$@"; }
service_active() { systemctl is-active --quiet "$1"; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) [ "$#" -ge 2 ] || usage; repo=$2; shift 2 ;;
    --ref) [ "$#" -ge 2 ] || usage; ref=$2; shift 2 ;;
    --apply) apply=true; shift ;;
    *) usage ;;
  esac
done
[ -n "$repo" ] && [ -n "$ref" ] || usage
if [ ! -r "$SERVER_ENV" ]; then
  if [ -r "$LEGACY_SERVER_ENV" ]; then
    migrating=true
    env_source=$LEGACY_SERVER_ENV
  else
    echo "missing $SERVER_ENV" >&2
    exit 1
  fi
fi
grep -q '^DATABASE_URL=' "$env_source" || { echo "server database key missing" >&2; exit 1; }

server_port_owned=false
service_active "$SERVICE" && server_port_owned=true
service_active "$LEGACY_SERVICE" && server_port_owned=true
if ss -H -ltn "sport = :$PORT" | grep -q . && ! $server_port_owned; then
  echo "refusing: 127.0.0.1:$PORT is already in use" >&2
  exit 1
fi
redis_port_owned=false
service_active "$REDIS_SERVICE" && redis_port_owned=true
service_active "$LEGACY_REDIS_SERVICE" && redis_port_owned=true
if service_active "$LEGACY_SERVICE" || service_active "$LEGACY_REDIS_SERVICE"; then
  migrating=true
fi
if ss -H -ltn "sport = :$REDIS_PORT" | grep -q . && ! $redis_port_owned; then
  echo "refusing: Redis port $REDIS_PORT belongs to another process" >&2
  exit 1
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
  echo "DRY RUN: would read server credentials from $env_source without displaying values"
  $migrating && echo "DRY RUN: would migrate the existing production installation to the kolkhoz-server namespace"
  echo "DRY RUN: would apply nine server schemas, then retire legacy local Supabase objects"
  echo "DRY RUN: would install capped Redis on 127.0.0.1:$REDIS_PORT and the server on 127.0.0.1:$PORT"
  echo "DRY RUN: would schedule daily deletion of email accounts unconfirmed for more than seven days"
  echo "DRY RUN: would keep detailed diagnostics host-local and install a least-privilege admin restart service"
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
apt-get install -y --no-install-recommends redis-server postgresql-client python3-venv clang git ca-certificates curl iproute2 sudo
if ! $redis_was_installed; then
  systemctl disable --now redis-server.service redis.service 2>/dev/null || true
fi

id "$RUN_USER" >/dev/null 2>&1 || useradd --system --home-dir "$ROOT" --shell /usr/sbin/nologin "$RUN_USER"
id "$ADMIN_USER" >/dev/null 2>&1 || useradd --system --user-group --home-dir /nonexistent --shell /usr/sbin/nologin "$ADMIN_USER"
if [ "$env_source" != "$SERVER_ENV" ]; then
  install -o root -g root -m 0600 "$env_source" "$SERVER_ENV"
fi
install -d -o root -g "$RUN_USER" -m 0750 /etc/kolkhoz-server
admin_env_tmp=$(mktemp)
for key in KOLKHOZ_SUPABASE_URL KOLKHOZ_SUPABASE_PUBLISHABLE_KEY KOLKHOZ_ADMIN_USER_IDS; do
  grep "^${key}=" "$SERVER_ENV" >> "$admin_env_tmp" || { echo "missing $key for admin control" >&2; exit 1; }
done
for key in KOLKHOZ_RESTART_COOLDOWN_SECONDS KOLKHOZ_ADMIN_AUTH_TIMEOUT_SECONDS KOLKHOZ_ADMIN_RATE_LIMIT KOLKHOZ_ADMIN_RATE_WINDOW_SECONDS KOLKHOZ_ADMIN_RATE_CAPACITY; do
  grep "^${key}=" "$SERVER_ENV" >> "$admin_env_tmp" || true
done
install -o root -g "$ADMIN_USER" -m 0440 "$admin_env_tmp" "$ADMIN_ENV"
rm -f "$admin_env_tmp"
if [ ! -e /etc/kolkhoz-server/firebase-fcm.json ] && [ -r "$LEGACY_SECRET_DIR/firebase-fcm.json" ]; then
  install -o root -g "$RUN_USER" -m 0440 "$LEGACY_SECRET_DIR/firebase-fcm.json" /etc/kolkhoz-server/firebase-fcm.json
fi

# Updating an existing production checkout requires the server to stop before its
# files move. During the one-time migration the former service stays live until
# the new checkout, environment, schemas, and unit files are ready.
systemctl stop "$SERVICE" 2>/dev/null || true
if [ ! -e "$ROOT" ]; then git clone --filter=blob:none "$repo" "$ROOT"; fi
git_server fetch --tags --prune origin
git_server checkout --detach "$ref"
test "$(git_server rev-parse HEAD)" = "$(git_server rev-parse "$ref^{commit}")"
printf 'KOLKHOZ_BUILD_SHA=%s\n' "$(git_server rev-parse HEAD)" > "$BUILD_ENV"
chmod 0644 "$BUILD_ENV"
cd "$ROOT"
python3 -m venv "$ROOT/.venv"
chown -R "$RUN_USER:$RUN_USER" "$ROOT/.venv"
runuser -u "$RUN_USER" -- "$ROOT/.venv/bin/pip" install \
  --disable-pip-version-check --no-cache-dir --only-binary :all: --require-hashes \
  -r "$ROOT/server/deploy/requirements.lock"
chown -R root:root "$ROOT/.venv"
"$ROOT/.venv/bin/python" -c 'from research.kolkhoz_research.c_engine import CEngine; CEngine()'
test -s "$ROOT/policies/medium_policy.json"
test -s "$ROOT/policies/hard_policy.json"
"$ROOT/.venv/bin/python" -m server.kolkhoz_server.preflight --repo-root "$ROOT"
install -d -o "$RUN_USER" -g "$RUN_USER" "$ROOT/research/.build"
chown -R "$RUN_USER:$RUN_USER" "$ROOT"

umask 077
database_url=$(sed -n 's/^DATABASE_URL=//p' "$SERVER_ENV" | tail -n 1)
supabase_url=$(sed -n 's/^KOLKHOZ_SUPABASE_URL=//p' "$SERVER_ENV" | tail -n 1)
publishable=$(sed -n 's/^KOLKHOZ_SUPABASE_PUBLISHABLE_KEY=//p' "$SERVER_ENV" | tail -n 1)
secret_key=$(sed -n 's/^KOLKHOZ_SUPABASE_SECRET_KEY=//p' "$SERVER_ENV" | tail -n 1)
[ -n "$database_url" ] && [ -n "$supabase_url" ] && [ -n "$publishable" ] && [ -n "$secret_key" ] || { echo "database/Supabase settings incomplete" >&2; exit 1; }
for schema in postgres_schema.sql lobby_schema.sql distributed_schema.sql command_schema.sql population_schema.sql notifications_schema.sql commerce_schema.sql tournament_schema.sql identity_schema.sql; do
  DATABASE_URL="$database_url" psql "$database_url" -v ON_ERROR_STOP=1 -f "$ROOT/server/$schema" >/dev/null
done
DATABASE_URL="$database_url" psql "$database_url" -v ON_ERROR_STOP=1 \
  -f "$here/retire_legacy_supabase.sql" >/dev/null
unset database_url supabase_url publishable secret_key

install -d -o redis -g redis "$REDIS_DIR"
install -o root -g redis -m 0640 "$here/redis-kolkhoz-server.conf" /etc/redis/kolkhoz-server.conf
install -o root -g root -m 0644 "$here/kolkhoz-server-redis.service" /etc/systemd/system/kolkhoz-server-redis.service
install -o root -g root -m 0644 "$here/kolkhoz-server.service" /etc/systemd/system/kolkhoz-server.service
install -o root -g root -m 0644 "$here/kolkhoz-admin-control.service" /etc/systemd/system/kolkhoz-admin-control.service
visudo -cf "$here/kolkhoz-admin-control.sudoers"
install -o root -g root -m 0440 "$here/kolkhoz-admin-control.sudoers" /etc/sudoers.d/kolkhoz-admin-control
install -o root -g root -m 0755 "$here/health-watch.sh" /usr/local/sbin/kolkhoz-health-watch
install -o root -g root -m 0755 "$here/ai-canary.sh" /usr/local/sbin/kolkhoz-ai-canary
install -o root -g root -m 0644 "$here/kolkhoz-health-watch.service" /etc/systemd/system/kolkhoz-health-watch.service
install -o root -g root -m 0644 "$here/kolkhoz-health-watch.timer" /etc/systemd/system/kolkhoz-health-watch.timer
install -o root -g root -m 0644 "$here/kolkhoz-ai-canary.service" /etc/systemd/system/kolkhoz-ai-canary.service
install -o root -g root -m 0644 "$here/kolkhoz-ai-canary.timer" /etc/systemd/system/kolkhoz-ai-canary.timer
install -o root -g root -m 0644 "$here/kolkhoz-unconfirmed-account-cleanup.service" /etc/systemd/system/kolkhoz-unconfirmed-account-cleanup.service
install -o root -g root -m 0644 "$here/kolkhoz-unconfirmed-account-cleanup.timer" /etc/systemd/system/kolkhoz-unconfirmed-account-cleanup.timer
install -o root -g root -m 0755 "$here/postgres-backup.sh" /usr/local/sbin/kolkhoz-postgres-backup
install -o root -g root -m 0644 "$here/kolkhoz-postgres-backup.service" /etc/systemd/system/kolkhoz-postgres-backup.service
install -o root -g root -m 0644 "$here/kolkhoz-postgres-backup.timer" /etc/systemd/system/kolkhoz-postgres-backup.timer
install -o root -g root -m 0644 "$here/Caddyfile" /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy
systemctl daemon-reload

rollback_needed=false
rollback_legacy() {
  if $rollback_needed; then
    echo "new production service did not become ready; restoring the previous services" >&2
    systemctl stop "$SERVICE" "$REDIS_SERVICE" 2>/dev/null || true
    systemctl start "$LEGACY_REDIS_SERVICE" 2>/dev/null || true
    systemctl start "$LEGACY_SERVICE" 2>/dev/null || true
  fi
}
trap rollback_legacy EXIT HUP INT TERM

if $migrating; then
  systemctl stop kolkhoz-ai-canary.service kolkhoz-unconfirmed-account-cleanup.service 2>/dev/null || true
  systemctl stop "$LEGACY_SERVICE" 2>/dev/null || true
  systemctl stop "$LEGACY_REDIS_SERVICE" 2>/dev/null || true
  rollback_needed=true
  if [ -d "$LEGACY_REDIS_DIR" ] && [ -z "$(find "$REDIS_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    cp -a "$LEGACY_REDIS_DIR/." "$REDIS_DIR/"
    chown -R redis:redis "$REDIS_DIR"
  fi
fi

systemctl enable --now "$REDIS_SERVICE"
systemctl enable "$SERVICE"
systemctl restart "$SERVICE"
systemctl enable kolkhoz-admin-control.service
systemctl restart kolkhoz-admin-control.service
systemctl enable --now kolkhoz-health-watch.timer
systemctl enable --now kolkhoz-ai-canary.timer
systemctl enable --now kolkhoz-unconfirmed-account-cleanup.timer
systemctl enable --now kolkhoz-postgres-backup.timer
ready=false
for _ in $(seq 1 30); do
  if curl --fail --silent --max-time 2 http://127.0.0.1:18787/ready >/dev/null; then
    ready=true
    break
  fi
  sleep 1
done
$ready || { systemctl status "$SERVICE" --no-pager >&2; exit 1; }
curl --fail --silent --max-time 5 http://127.0.0.1:18787/metrics/prometheus | grep -q '^kolkhoz_uptime_seconds '
/usr/local/sbin/kolkhoz-health-watch

rollback_needed=false
trap - EXIT HUP INT TERM
if $migrating; then
  systemctl disable "$LEGACY_SERVICE" "$LEGACY_REDIS_SERVICE" 2>/dev/null || true
  rm -f "/etc/systemd/system/$LEGACY_SERVICE" "/etc/systemd/system/$LEGACY_REDIS_SERVICE"
  systemctl daemon-reload
  [ ! -e "$LEGACY_ROOT" ] || [ -e "$ARCHIVE_ROOT" ] || mv "$LEGACY_ROOT" "$ARCHIVE_ROOT"
  [ ! -e "$LEGACY_SERVER_ENV" ] || [ -e "$ARCHIVE_SERVER_ENV" ] || mv "$LEGACY_SERVER_ENV" "$ARCHIVE_SERVER_ENV"
  [ ! -e "$LEGACY_BUILD_ENV" ] || [ -e "$ARCHIVE_BUILD_ENV" ] || mv "$LEGACY_BUILD_ENV" "$ARCHIVE_BUILD_ENV"
  [ ! -e "$LEGACY_SECRET_DIR" ] || [ -e "$ARCHIVE_SECRET_DIR" ] || mv "$LEGACY_SECRET_DIR" "$ARCHIVE_SECRET_DIR"
  [ ! -e "$LEGACY_REDIS_DIR" ] || [ -e "$ARCHIVE_REDIS_DIR" ] || mv "$LEGACY_REDIS_DIR" "$ARCHIVE_REDIS_DIR"
  if [ -d "$ARCHIVE_ROOT" ]; then chown -R root:root "$ARCHIVE_ROOT"; fi
  if [ -d "$ARCHIVE_SECRET_DIR" ]; then chown -R root:root "$ARCHIVE_SECRET_DIR"; chmod 0700 "$ARCHIVE_SECRET_DIR"; fi
  if id "$LEGACY_RUN_USER" >/dev/null 2>&1; then userdel "$LEGACY_RUN_USER"; fi
  if getent group "$LEGACY_RUN_USER" >/dev/null 2>&1; then groupdel "$LEGACY_RUN_USER"; fi
fi
echo "Kolkhoz server ready on loopback port 18787"
