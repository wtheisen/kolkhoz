#!/bin/sh
set -eu
[ "${1:-}" = "--apply" ] || { echo "DRY RUN: would stop/disable only kolkhoz-server services; pass --apply"; exit 0; }
[ "$(id -u)" -eq 0 ] || { echo "must run as root" >&2; exit 1; }
systemctl disable --now kolkhoz-server.service kolkhoz-server-redis.service kolkhoz-unconfirmed-account-cleanup.timer 2>/dev/null || true
rm -f /etc/systemd/system/kolkhoz-server.service /etc/systemd/system/kolkhoz-server-redis.service /etc/systemd/system/kolkhoz-unconfirmed-account-cleanup.service /etc/systemd/system/kolkhoz-unconfirmed-account-cleanup.timer
systemctl daemon-reload
echo "services removed; checkout, secret environment, Redis data, and database schemas preserved"
