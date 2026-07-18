# Scale and failure harness

Run a quick executable check:

```bash
python3 -m server.tools.scale_harness \
  --players 10000 --operations 500 --concurrency 32 \
  --output /tmp/kolkhoz-scale.json
```

The process exits nonzero when a configured threshold fails. Its JSON separates:

- `local`: measured in-process runtime, SQLite persistence, bounded-admission,
  and cold replay/recovery evidence. `playersModeled` describes the workload
  shape; `gamesExecuted` states exactly how much was materialized.
- `capacityScenarios`: arithmetic projections for 10K, 100K, and 1M concurrent
  connections. These are explicitly labeled `modeled-not-measured`; they are
  planning inputs, not proof that the gateway or database sustained that load.

The projection reserves 30% operating headroom, an additional N+1 instance,
and at least two replicas. Change `--connections-per-gateway` and
`--games-per-worker` only from deployed benchmark evidence.

This local harness deliberately excludes network, TLS, authentication,
PostgreSQL, and WebSocket fanout. A production capacity claim requires a
distributed test against the deployed stack and failure injection in its
actual gateway, broker, worker, and database tiers.

## Deployed staging load

With `server/deploy/staging` running, exercise the real load balancer, ASGI
gateways, Redis command/realtime planes, PostgreSQL repositories, C engine, and
WebSockets:

```bash
python3 -m server.tools.distributed_load \
  --base-url http://127.0.0.1:18080 \
  --staging-identities 100 --staging-offset 100 \
  --games 100 --concurrency 32 --actions-per-game 1 \
  --websockets 25 --websocket-seconds 10 \
  --output /tmp/kolkhoz-distributed-load.json
```

The staging bootstrap provides identities 1 through 1024. Use a fresh offset for
repeated active-game runs. For non-staging deployments, pass `--identities` with a
JSON list of bearer tokens or `{ "token", "deviceID" }` objects. The report labels
this evidence `deployed-http-websocket-stack`; it still describes only the host and
resource limits on which it was run.

## Unconfirmed account cleanup

Preview Supabase email accounts that are still completely unconfirmed after seven
days without printing addresses or user IDs:

```bash
python3 -m server.tools.cleanup_unconfirmed_accounts --older-than-days 7
```

Production runs the same command daily with `--delete` from a hardened systemd
oneshot service. The command requires `KOLKHOZ_SUPABASE_URL` and the server-only
`KOLKHOZ_SUPABASE_SECRET_KEY`; never expose that secret to Flutter.
