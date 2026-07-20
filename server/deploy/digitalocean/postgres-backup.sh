#!/bin/sh
set -eu
set -a
. /etc/kolkhoz-server.env
set +a
case "$DATABASE_URL" in
  postgresql://*@127.0.0.1:5432/kolkhoz_production) ;;
  *) echo "Refusing to back up an unexpected database target" >&2; exit 1 ;;
esac
backup_dir=/var/backups/kolkhoz-postgres
install -d -o root -g root -m 0700 "$backup_dir"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
final="$backup_dir/kolkhoz-$stamp.dump"
temporary="$final.tmp"
umask 077
/usr/lib/postgresql/17/bin/pg_dump "$DATABASE_URL" --format=custom --no-owner --no-acl --file="$temporary"
test -s "$temporary"
mv "$temporary" "$final"
find "$backup_dir" -type f -name 'kolkhoz-*.dump' -mtime +14 -delete
