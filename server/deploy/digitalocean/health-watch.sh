#!/bin/sh
set -eu

base=http://127.0.0.1:18787
ready=false
for _ in 1 2 3 4 5 6; do
  if curl --fail --silent --max-time 5 "$base/ready" >/dev/null; then
    metrics=$(curl --fail --silent --max-time 5 "$base/metrics/prometheus" || true)
    if echo "$metrics" | grep -q '^kolkhoz_lifecycle_healthy 1' \
      && echo "$metrics" | grep -q '^kolkhoz_population_healthy 1' \
      && echo "$metrics" | grep -q '^kolkhoz_automatic_healthy 1'; then
      ready=true
      break
    fi
  fi
  sleep 5
done
if ! $ready; then
  logger -p daemon.alert -t kolkhoz-health-watch "Kolkhoz production readiness failed"
  exit 1
fi
