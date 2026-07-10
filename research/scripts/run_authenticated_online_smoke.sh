#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="${KOLKHOZ_ONLINE_ENV_FILE:-$REPO_ROOT/.env.kolkhoz-online}"
SMOKE_EMAIL="codex-smoke@kolkhoz.local"
KEYCHAIN_SERVICE="Kolkhoz Online Smoke Test"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

if [[ -z "${KOLKHOZ_SMOKE_PASSWORD:-}" ]] && command -v security >/dev/null; then
  KOLKHOZ_SMOKE_PASSWORD="$(
    security find-generic-password \
      -a "$SMOKE_EMAIL" \
      -s "$KEYCHAIN_SERVICE" \
      -w
  )"
  export KOLKHOZ_SMOKE_PASSWORD
fi

python3 "$SCRIPT_DIR/run_authenticated_online_smoke.py"
