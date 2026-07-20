#!/bin/sh
set -eu

cd /opt/kolkhoz-server
/opt/kolkhoz-server/.venv/bin/python -m server.kolkhoz_server.preflight \
  --repo-root /opt/kolkhoz-server
if [ -n "${KOLKHOZ_AI_CANARY_HEARTBEAT_URL:-}" ]; then
  curl --fail --silent --max-time 10 "$KOLKHOZ_AI_CANARY_HEARTBEAT_URL" >/dev/null
fi
