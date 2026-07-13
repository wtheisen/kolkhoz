#!/bin/sh
set -eu

cd /opt/kolkhoz-greenfield
/opt/kolkhoz-greenfield/.venv/bin/python -m server.kolkhoz_server.preflight \
  --repo-root /opt/kolkhoz-greenfield
if [ -n "${KOLKHOZ_AI_CANARY_HEARTBEAT_URL:-}" ]; then
  curl --fail --silent --max-time 10 "$KOLKHOZ_AI_CANARY_HEARTBEAT_URL" >/dev/null
fi
