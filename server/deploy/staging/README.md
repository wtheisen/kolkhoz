# Distributed staging stack

This Compose stack runs the production adapters as separate roles:

- HAProxy in front of two gateway-only ASGI processes;
- two game-worker processes with disjoint ownership of all 16 command partitions;
- independent deadline and population scheduler processes;
- one dedicated lifecycle reconciliation process;
- durable PostgreSQL and append-only Redis.

It is a laptop-scale topology test, not a production capacity configuration. Resource
limits intentionally make queue saturation and unhealthy processes visible.

```bash
cd server/deploy/staging
cp .env.example .env
docker compose up --build -d --wait
python3 smoke.py
python3 chaos.py
docker compose down
```

Use `docker compose down -v` to erase all staging data and force the migration/bootstrap
scripts to run again. Static bearer tokens and load-test tokens of the form
`staging:<canonical-uuid>` work only when `KOLKHOZ_ENVIRONMENT=staging`; the production
process refuses that token configuration otherwise. Load tests must provision matching
`auth.users` and `public.profiles` rows before those users complete games.

The bootstrap provisions 1,024 deterministic load identities. Identity `n` uses UUID
`20000000-0000-4000-8000-{n:012d}` and bearer token
`staging:20000000-0000-4000-8000-{n:012d}` for `1 <= n <= 1024`. Generate tokens with:

```bash
python3 -c 'print("\n".join(f"staging:20000000-0000-4000-8000-{n:012d}" for n in range(1, 1025)))'
```

The load-balanced endpoint is `http://127.0.0.1:18080`. Direct gateway ports 18787 and
28787 exist solely for cross-replica tests. Do not expose this stack to the internet.

`chaos.py` is intentionally bounded and restores interrupted services in `finally`. It
tests partition-owner loss and takeover, gateway/WebSocket reconnect catch-up, bounded
Redis and PostgreSQL interruption, recovery, and a rolling application restart.

## Single-VPS capacity benchmark

`compose.benchmark.yaml` reuses the same production image and topology on the existing
VPS, but is a separate Compose project bound only to loopback port 19080. It requires a
dedicated database whose name contains `benchmark` and a non-zero, benchmark-only Redis
database. It does not start PostgreSQL or Redis and must never point at live data.

The benchmark topology has four gateways behind HAProxy, four workers with disjoint
ownership of 64 partitions, and dedicated deadline, population, and lifecycle
processes. Conservative container limits reserve failure headroom on a single host.
The capacity preflight requires at least 8 CPUs, 16 GiB RAM, 20 GiB free disk, and a
65,536 file limit for 1K, with higher hard floors for 5K and 10K. It will refuse the
current 1-vCPU VPS for every capacity tier.

```bash
cp benchmark.env.example benchmark.env
# Fill only dedicated benchmark PostgreSQL and Redis endpoints.
python3 seed_benchmark.py \
  --database-url "$DEDICATED_BENCHMARK_DATABASE_URL" \
  --confirm-database kolkhoz_benchmark
./benchmark_stack.sh start # only after the host passes the 1K capacity preflight
BENCHMARK_MAX_PLAYERS=1000 ./benchmark.sh
./benchmark_stack.sh stop
```

The deterministic `staging:<uuid>` auth path is enabled only inside containers with
`KOLKHOZ_ENVIRONMENT=staging`; HAProxy binds to `127.0.0.1`, so use SSH locally and do
not publish port 19080. The seed command creates matching private `auth.users`, profile,
and stats rows in the confirmed benchmark database. These are synthetic concurrent
human identities: 1,000 games means 1,000 connected human players plus three AI seats
per game, not 4,000 human players.

On the current 1-vCPU/1-GB VPS, only run the default 25-session smoke tier against a
resource-capped production service on loopback port 18787:

```bash
python3 benchmark_preflight.py --tier smoke
BENCHMARK_BASE_URL=http://127.0.0.1:18787 ./benchmark.sh
```

This smoke tier checks correctness and basic latency; it is not capacity evidence.
It does not start the 4+4 Compose topology or alter the production Caddy route. The
package in `../digitalocean/` installs the production service with
systemd `CPUQuota`/`MemoryMax`, `/opt/kolkhoz-greenfield`, and a capped loopback Redis.
It uses the existing Supabase database's additive `server_*` tables and production
authentication; it does not seed synthetic identities. A session smoke therefore
requires a private identity file containing real bearer tokens. Without one, limit the
production verification to `/ready` and `/metrics/prometheus`.

The ramp stops on load-tool errors, readiness loss, any command DLQ/shard-overload/store
error counter, or a 2-second operation p95. A successful stage writes `results/N.json`;
rerunning resumes after passed files. Runs above 1K are deliberately locked:

```bash
BENCHMARK_MAX_PLAYERS=10000 \
BENCHMARK_CONFIRM_LARGE_RUN=YES_I_ACCEPT_VPS_LOAD_AND_COST \
./benchmark.sh
```

Review CPU, memory, database connections/latency, Redis memory/stream lag, and host
network saturation after every stage. Stop the project without deleting result files
using `benchmark_stack.sh stop`. Purge requires
`BENCHMARK_CONFIRM_PURGE=YES_DELETE_BENCHMARK_CONTAINERS`.
