#!/bin/sh
set -eu
[ "${1:-}" = "--apply" ] || { echo "DRY RUN: would stop/disable only kolkhoz-greenfield services; pass --apply"; exit 0; }
[ "$(id -u)" -eq 0 ] || { echo "must run as root" >&2; exit 1; }
systemctl disable --now kolkhoz-greenfield.service kolkhoz-greenfield-redis.service 2>/dev/null || true
rm -f /etc/systemd/system/kolkhoz-greenfield.service /etc/systemd/system/kolkhoz-greenfield-redis.service
systemctl daemon-reload
echo "services removed; checkout, secret environment, Redis data, and database schemas preserved"
