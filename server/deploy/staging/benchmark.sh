#!/bin/sh
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
compose="docker compose --env-file $here/benchmark.env -f $here/compose.benchmark.yaml"
results=${BENCHMARK_RESULTS_DIR:-$here/results}
base_url=${BENCHMARK_BASE_URL:-http://127.0.0.1:19080}
identities=${BENCHMARK_IDENTITIES:-$here/benchmark-identities.json}
max_players=${BENCHMARK_MAX_PLAYERS:-25}

case "$max_players" in 25|1000|5000|10000) ;; *) echo "BENCHMARK_MAX_PLAYERS must be 25, 1000, 5000, or 10000" >&2; exit 64;; esac
if [ "$max_players" -gt 1000 ] && [ "${BENCHMARK_CONFIRM_LARGE_RUN:-}" != "YES_I_ACCEPT_VPS_LOAD_AND_COST" ]; then
  echo "5K/10K requires BENCHMARK_CONFIRM_LARGE_RUN=YES_I_ACCEPT_VPS_LOAD_AND_COST" >&2
  exit 64
fi
[ -r "$identities" ] || { echo "missing private identity file: $identities" >&2; exit 66; }
preflight_tier=$max_players; [ "$max_players" = 25 ] && preflight_tier=smoke
python3 "$here/benchmark_preflight.py" --tier "$preflight_tier"
mkdir -p "$results"

health_gate() {
  curl --fail --silent --max-time 5 "$base_url/ready" >/dev/null
  [ "$max_players" = 25 ] && return 0
  for service in gateway-a gateway-b gateway-c gateway-d worker-a worker-b worker-c worker-d deadline-scheduler population-scheduler lifecycle-reconciler; do
    state=$($compose ps --format json "$service" | python3 -c 'import json,sys; rows=[json.loads(x) for x in sys.stdin if x.strip()]; print(rows[0].get("Health", "") if rows else "missing")')
    [ "$state" = "healthy" ] || { echo "$service is not healthy ($state)" >&2; return 1; }
  done
}

metric_gate() {
  if [ "$max_players" = 25 ]; then
    metrics=$(curl --fail --silent --max-time 5 "$base_url/metrics/prometheus")
    echo "$metrics" | awk '
      /^kolkhoz_redis_command_dlq_total / && $2 > 0 { bad=1 }
      /^kolkhoz_shard_overload_total / && $2 > 0 { bad=1 }
      /^kolkhoz_store_errors_total / && $2 > 0 { bad=1 }
      END { exit bad }' || { echo "smoke abort threshold reached" >&2; return 1; }
    return 0
  fi
  for service in gateway-a gateway-b gateway-c gateway-d worker-a worker-b worker-c worker-d; do
    metrics=$($compose exec -T "$service" python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8787/metrics/prometheus',timeout=3).read().decode())")
    echo "$metrics" | awk '
      /^kolkhoz_redis_command_dlq_total / && $2 > 0 { bad=1 }
      /^kolkhoz_shard_overload_total / && $2 > 0 { bad=1 }
      /^kolkhoz_store_errors_total / && $2 > 0 { bad=1 }
      /^kolkhoz_readiness_ready / && $2 < 1 { bad=1 }
      END { exit bad }' || { echo "abort threshold reached in $service" >&2; return 1; }
  done
}

for players in 25 1000 5000 10000; do
  [ "$players" -le "$max_players" ] || break
  output="$results/$players.json"
  if [ -s "$output" ] && python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["passed"]' "$output" 2>/dev/null; then
    echo "resuming: $players already passed"
    continue
  fi
  health_gate
  concurrency=128; [ "$players" -ge 5000 ] && concurrency=256
  python3 -m server.tools.distributed_load --base-url "$base_url" \
    --identities "$identities" --games "$players" --concurrency "$concurrency" \
    --actions-per-game 2 --websockets "$players" --websocket-seconds "${BENCHMARK_WEBSOCKET_SECONDS:-60}" \
    --timeout "${BENCHMARK_REQUEST_TIMEOUT:-30}" --output "$output"
  python3 - "$output" "${BENCHMARK_MAX_P95_MS:-2000}" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
limit = float(sys.argv[2])
bad = {name: data["p95Ms"] for name, data in result["latency"].items() if data["p95Ms"] > limit}
if bad:
    raise SystemExit(f"p95 abort threshold {limit}ms exceeded: {bad}")
PY
  health_gate
  metric_gate
done
