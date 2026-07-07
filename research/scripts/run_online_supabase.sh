#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
env_file="${KOLKHOZ_ONLINE_ENV_FILE:-$repo_root/.env.kolkhoz-online}"

if [[ -f "$env_file" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
fi

cd "$repo_root"
python3 -m research.kolkhoz_research.cli serve-online "$@"
