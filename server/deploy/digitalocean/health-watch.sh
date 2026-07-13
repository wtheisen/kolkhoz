#!/bin/sh
set -eu

base=http://127.0.0.1:18787
if ! curl --fail --silent --show-error --max-time 5 "$base/ready" >/dev/null; then
  logger -p daemon.alert -t kolkhoz-health-watch "Kolkhoz production readiness failed"
  exit 1
fi
metrics=$(curl --fail --silent --show-error --max-time 5 "$base/metrics/prometheus")
echo "$metrics" | grep -q '^kolkhoz_lifecycle_healthy 1' || {
  logger -p daemon.alert -t kolkhoz-health-watch "Kolkhoz lifecycle reconciler is unhealthy"
  exit 1
}
echo "$metrics" | grep -q '^kolkhoz_population_healthy 1' || {
  logger -p daemon.alert -t kolkhoz-health-watch "Kolkhoz population scheduler is unhealthy"
  exit 1
}
echo "$metrics" | grep -q '^kolkhoz_automatic_healthy 1' || {
  logger -p daemon.alert -t kolkhoz-health-watch "Kolkhoz automatic turn scheduler is unhealthy"
  exit 1
}
