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
