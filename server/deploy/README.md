# Greenfield server deployment

These files deploy the PostgreSQL-backed, partitioned server independently of the
legacy `research.kolkhoz_research.cli serve-online` process. Do not run both services
on the same port.

## Install

From a checked-out release at `/opt/kolkhoz`:

```bash
python3 -m venv /opt/kolkhoz/.venv
/opt/kolkhoz/.venv/bin/pip install -r server/deploy/requirements.txt
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/postgres_schema.sql
sudo install -o root -g root -m 0600 \
  server/deploy/kolkhoz-server.env.example /etc/kolkhoz-server.env
sudo install -o root -g root -m 0644 \
  server/deploy/kolkhoz-server.service /etc/systemd/system/kolkhoz-server.service
```

Edit `/etc/kolkhoz-server.env` with the production database URL, then start the
service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now kolkhoz-server
sudo systemctl status kolkhoz-server
curl --fail --silent http://127.0.0.1:8787/health
```

The database role needs `SELECT`, `INSERT`, and `UPDATE` on `server_games` and
`server_game_events`. Schema migration should run as a separate privileged deployment
step, never automatically at process startup.

## Capacity settings

`KOLKHOZ_SHARDS` controls the number of single-owner game mailboxes in this process.
`KOLKHOZ_DB_POOL_SIZE` bounds concurrent PostgreSQL connections. Begin with values near
the available CPU count and tune them from queue latency and database saturation; more
shards do not make one game concurrent.

The process currently exposes the compatibility HTTP gateway. Put TLS and request-rate
limits at the reverse proxy. WebSocket/realtime gateway deployment should be added as a
separate unit when that transport is implemented.

## Rollback

Stop `kolkhoz-server`, restore the previous application release, and restart it. The
event tables are append-only by revision, so an application rollback does not require
discarding games. Do not remove the schema while any release may need replay recovery.
