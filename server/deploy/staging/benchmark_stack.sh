#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
compose="docker compose --env-file $here/benchmark.env -f $here/compose.benchmark.yaml"
case "${1:-}" in
  start)
    python3 "$here/benchmark_preflight.py" --tier "${BENCHMARK_CAPACITY_TIER:-1000}"
    $compose up --build -d --wait
    ;;
  stop) $compose down ;;
  purge)
    [ "${BENCHMARK_CONFIRM_PURGE:-}" = "YES_DELETE_BENCHMARK_CONTAINERS" ] || { echo "purge confirmation missing" >&2; exit 64; }
    $compose down --remove-orphans
    rm -rf "$here/results"
    ;;
  status) $compose ps ;;
  *) echo "usage: $0 {start|stop|status|purge}" >&2; exit 64 ;;
esac
