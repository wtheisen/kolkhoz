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
