#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parent
bootstrap = (root / "bootstrap.sh").read_text()
server = (root / "kolkhoz-server.service").read_text()
admin = (root / "kolkhoz-admin-control.service").read_text()
admin_sudoers = (root / "kolkhoz-admin-control.sudoers").read_text()
redis = (root / "redis-kolkhoz-server.conf").read_text()
redis_service = (root / "kolkhoz-server-redis.service").read_text()
caddy = (root / "Caddyfile").read_text()
requirements_lock = (root.parent / "requirements.lock").read_text()
watch = (root / "health-watch.sh").read_text()
watch_timer = (root / "kolkhoz-health-watch.timer").read_text()
account_cleanup = (root / "kolkhoz-unconfirmed-account-cleanup.service").read_text()
account_cleanup_timer = (root / "kolkhoz-unconfirmed-account-cleanup.timer").read_text()
postgres_backup = (root / "postgres-backup.sh").read_text()
postgres_backup_timer = (root / "kolkhoz-postgres-backup.timer").read_text()

assert "ROOT=/opt/kolkhoz-server" in bootstrap
assert "SERVER_ENV=/etc/kolkhoz-server.env" in bootstrap
assert "SERVICE=kolkhoz-server.service" in bootstrap
assert "REDIS_SERVICE=kolkhoz-server-redis.service" in bootstrap
assert "RUN_USER=kolkhoz-server" in bootstrap
assert "LEGACY_ROOT=/opt/kolkhoz-greenfield" in bootstrap
assert "rollback_legacy" in bootstrap and "trap rollback_legacy" in bootstrap
assert 'cp -a "$LEGACY_REDIS_DIR/." "$REDIS_DIR/"' in bootstrap
assert 'mv "$LEGACY_ROOT" "$ARCHIVE_ROOT"' in bootstrap
assert 'userdel "$LEGACY_RUN_USER"' in bootstrap
assert "KOLKHOZ_ONLINE_DATABASE_URL" not in bootstrap
assert bootstrap.count("_schema.sql") == 9
assert "--apply" in bootstrap and "DRY RUN:" in bootstrap
assert bootstrap.index('cd "$ROOT"') < bootstrap.index(
    "from research.kolkhoz_research.c_engine"
)
assert "requirements.lock" in bootstrap and "--require-hashes" in bootstrap
assert 'runuser -u "$RUN_USER"' in bootstrap
assert 'chown -R root:root "$ROOT/.venv"' in bootstrap
assert "MemAvailable:" in bootstrap and "358400" in bootstrap
assert "2097152" in bootstrap
assert "redis_was_installed" in bootstrap
assert "disable --now redis-server.service" in bootstrap
assert '. "$env_file"' not in bootstrap
assert 'psql "$database_url"' in bootstrap
assert bootstrap.index('psql "$database_url"') < bootstrap.index("unset database_url")
assert "127.0.0.1 --port 18787" in server
assert "User=kolkhoz-server" in server
assert "WorkingDirectory=/opt/kolkhoz-server" in server
assert "CPUQuota=100%" in server
assert "MemoryMax=300M" in server
assert "TasksMax=128" in server and "LimitNOFILE=8192" in server
assert "port 16379" in redis and "bind 127.0.0.1" in redis
assert "dir /var/lib/kolkhoz-server-redis" in redis
assert "maxmemory 64mb" in redis and "maxmemory-policy noeviction" in redis
assert "maxclients 1000" in redis
assert "CONFIG SET maxclients 1000" in redis_service
assert 'systemctl enable --now "$REDIS_SERVICE"' in bootstrap
assert 'systemctl restart "$SERVICE"' in bootstrap
assert "caddy validate" in bootstrap and "systemctl reload caddy" in bootstrap
assert "lb_try_duration 5s" in caddy and "lb_try_interval 100ms" in caddy
assert "header_up X-Forwarded-For {remote_host}" in caddy
assert "stream_close_delay 5m" in caddy
assert "read_header 10s" in caddy and "read_body 15s" in caddy
assert (
    "@private_diagnostics path /metrics/prometheus /metrics/prometheus/ "
    "/ready /ready/ /canary /canary/"
) in caddy
assert "User=kolkhoz-admin" in admin and "Group=kolkhoz-admin" in admin
assert "EnvironmentFile=/etc/kolkhoz-admin-control.env" in admin
assert "EnvironmentFile=/etc/kolkhoz-server.env" not in admin
assert "NoNewPrivileges=true" not in admin
assert admin_sudoers.strip() == (
    "kolkhoz-admin ALL=(root) NOPASSWD: /bin/systemctl restart kolkhoz-server.service"
)
assert "visudo -cf" in bootstrap
assert 'install -o root -g "$ADMIN_USER" -m 0440' in bootstrap
locked_requirements = [
    line
    for line in requirements_lock.splitlines()
    if line and not line.startswith((" ", "#", "--"))
]
assert locked_requirements and all("==" in line for line in locked_requirements)
assert "--hash=sha256:" in requirements_lock
assert "for _ in $(seq 1 30)" in bootstrap
assert "server.kolkhoz_server.preflight" in bootstrap
assert "policies/medium_policy.json" in bootstrap
assert "KOLKHOZ_BUILD_SHA" in bootstrap and "kolkhoz-server-build.env" in server
assert "kolkhoz-health-watch.timer" in bootstrap
assert "/ready" in watch and "lifecycle_healthy" in watch
assert "OnUnitActiveSec=60s" in watch_timer
assert "--older-than-days 7 --delete" in account_cleanup
assert "KOLKHOZ_SUPABASE_SECRET_KEY" not in account_cleanup
assert "OnUnitActiveSec=1d" in account_cleanup_timer
assert "kolkhoz-unconfirmed-account-cleanup.timer" in bootstrap
assert ". /etc/kolkhoz-server.env" in postgres_backup
assert "kolkhoz-postgres-backup.timer" in bootstrap
assert "OnCalendar=*-*-* 05:15:00 UTC" in postgres_backup_timer
assert 'git -c safe.directory="$ROOT" -C "$ROOT"' in bootstrap
print("DigitalOcean server package invariants valid")
