# Server deployment

The live DigitalOcean procedure is authoritative and documented in
[`digitalocean/README.md`](digitalocean/README.md). The generic unit and environment
files in this directory are templates for another single-host installation.

## Install

From a checked-out release at `/opt/kolkhoz-server`:

```bash
python3 -m venv /opt/kolkhoz-server/.venv
/opt/kolkhoz-server/.venv/bin/pip install --only-binary :all: --require-hashes \
  -r server/deploy/requirements.lock
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/postgres_schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/lobby_schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/distributed_schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/command_schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/population_schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/notifications_schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/commerce_schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/tournament_schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/identity_schema.sql
sudo install -o root -g root -m 0600 \
  server/deploy/kolkhoz-server.env.example /etc/kolkhoz-server.env
sudo install -o root -g root -m 0644 \
  server/deploy/kolkhoz-server.service /etc/systemd/system/kolkhoz-server.service
```

`requirements.txt` is the human-maintained input. Regenerate the Linux/Python 3.12
production lock after intentional dependency updates:

```bash
uv pip compile server/deploy/requirements.txt \
  --output-file server/deploy/requirements.lock \
  --generate-hashes --python-version 3.12 \
  --python-platform x86_64-manylinux_2_28 --only-binary :all:
```

Account deletion also requires `KOLKHOZ_SUPABASE_SECRET_KEY` on the server.
Use the project secret key (or the legacy service-role key); never copy it into
Flutter configuration. The authenticated `DELETE /account` route permanently
removes the Supabase user and their profile/entitlement data while retaining the
minimal store-purchase tombstone that prevents a surrendered purchase from being
linked to a new account.

Commerce claims require `APPLE_ROOT_CERTIFICATE_PATHS`, `APPLE_APP_ID`,
`APPLE_APP_BUNDLE_ID`, and `KOLKHOZ_APPLE_FULL_GAME_PRODUCT_ID`. Keep
`KOLKHOZ_ENFORCE_FULL_GAME=false` while configuring and testing the first
storefront, then enable it for the paid-access release.

Weekly tournaments default to Saturday at 7 PM in
`America/Indiana/Indianapolis`. Configure the recurring event with
`KOLKHOZ_TOURNAMENT_WEEKDAY` (Monday is `0`), `KOLKHOZ_TOURNAMENT_HOUR`, and
`KOLKHOZ_TOURNAMENT_TIMEZONE`. Enrollment opens 30 minutes before the start.

App Store Server API operations also require `APPLE_IAP_KEY_ID`,
`APPLE_IAP_ISSUER_ID`, and `APPLE_IAP_PRIVATE_KEY_PATH`. The private `.p8` key can
be downloaded only once. Store it outside the checkout with mode `0600`; never
commit it or print its contents. Sandbox signed-notification delivery was verified
against the production webhook on July 14, 2026. Apple does not enable production
App Store Server API access until the app has a production release, so repeat the
production `TEST` notification after launch.

Edit `/etc/kolkhoz-server.env` with the production database URL, then start the
service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now kolkhoz-server
sudo systemctl status kolkhoz-server
curl --fail --silent http://127.0.0.1:18787/health
```

The database role needs `SELECT`, `INSERT`, `UPDATE`, and `DELETE` on the `server_*`,
`game_session_leases`, and `population_*` tables plus the existing profile/social
tables. Schema migration should run as a separate privileged deployment step, never
automatically at process startup.

Before deploying, the complete schema composition can be verified against a
disposable local PostgreSQL container (never the configured production database):

```bash
server/tools/postgres_smoke.sh
```

The smoke applies the existing Supabase migration history, applies every new server
schema twice to prove rerunnability, and exercises game/event, lobby, lease, command,
population, and result writes. Docker is the only host dependency.

## Capacity settings

`KOLKHOZ_SHARDS` controls the number of single-owner game mailboxes in this process.
`KOLKHOZ_DB_POOL_SIZE` bounds concurrent PostgreSQL connections. Begin with values near
the available CPU count and tune them from queue latency and database saturation; more
shards do not make one game concurrent.

Redis Streams partitions route mutations to game workers. A single-host deployment may
omit `KOLKHOZ_COMMAND_PARTITIONS` and consume all partitions. In a multi-host deployment,
assign every partition exactly once across the live worker set; use stable worker
identities and coordinated reassignment during failover. Overlapping assignments cause
lease contention, while missing assignments cause command timeouts. The PostgreSQL
session lease and fencing token remain the final stale-owner safety boundary.

The three `KOLKHOZ_RUN_*` flags permit independent process roles. At larger scale, run
gateway-only replicas with all three disabled, a partitioned game-worker pool with only
`KOLKHOZ_RUN_COMMAND_WORKER=true`, and small independently elected deadline/population
scheduler pools. The all-enabled defaults are a single-host convenience, not the
million-connection topology.

The ASGI process exposes the compatibility HTTP API and
`/sessions/{sessionID}/realtime` WebSockets. `REDIS_URL` is required: Redis Pub/Sub
fans committed revisions to connections on every gateway replica. Put TLS, connection
limits, and broad request-rate limits at the reverse proxy. The ASGI gateway also applies
bounded source limits to guest/platform identity bootstrap, recovery email, session
creation, invite joining, and realtime connection setup. Invite joins are limited by
both source address and a hash of the bearer credential. Tune the
`KOLKHOZ_*_RATE_LIMIT` variables in the production environment without disabling the
persistent per-destination email quota. Request bodies have a single overall deadline
at both the ASGI gateway and Caddy edge.

The public `/health` and `/metrics` compatibility responses contain only liveness and
the citizen count. Caddy denies public access to `/ready`, `/canary`, and
`/metrics/prometheus`; host-local watchdogs reach those endpoints directly on port
18787. The restart control runs as `kolkhoz-admin` with a minimal environment and may
sudo only `systemctl restart kolkhoz-server.service`. Authentication is bounded and
performed off the ASGI event loop.

Scale gateways as independent service instances behind a WebSocket-capable load
balancer; connections are not sticky because durable revision catch-up repairs a
reconnect on any replica. Keep one Uvicorn worker per process and scale processes or
hosts instead: per-process connection buffers are bounded by
`KOLKHOZ_REALTIME_BUFFER_SIZE` (default 64), and slow consumers are closed with 1013.
Capacity planning for hundreds of thousands of sockets must include OS file-descriptor
limits, load-balancer limits, Redis fanout capacity, and regional sharding; no single
Python process is intended to own the aggregate connection population.

## Rollback

Stop `kolkhoz-server`, restore the previous application release, and restart it. The
event tables are append-only by revision, so an application rollback does not require
discarding games. Do not remove the schema while any release may need replay recovery.
