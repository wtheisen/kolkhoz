#!/usr/bin/env bash
set -euo pipefail

repo_url="${KOLKHOZ_REPO_URL:-https://github.com/wtheisen/kolkhoz.git}"
repo_ref="${KOLKHOZ_REPO_REF:-main}"
app_dir="${KOLKHOZ_APP_DIR:-/opt/kolkhoz}"
service_file="/etc/systemd/system/kolkhoz-online.service"
env_file="/etc/kolkhoz-online.env"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this script as root." >&2
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential \
  ca-certificates \
  clang \
  git \
  python3 \
  python3-pip \
  python3-venv

if ! id -u kolkhoz >/dev/null 2>&1; then
  useradd --system --create-home --shell /usr/sbin/nologin kolkhoz
fi

if [[ ! -d "$app_dir/.git" ]]; then
  git clone "$repo_url" "$app_dir"
fi

cd "$app_dir"
git fetch --all --prune
git checkout "$repo_ref"
git pull --ff-only origin "$repo_ref"

python3 -m venv "$app_dir/.venv"
"$app_dir/.venv/bin/python" -m pip install --upgrade pip
"$app_dir/.venv/bin/python" -m pip install -r "$app_dir/deploy/digitalocean/requirements-online.txt"
"$app_dir/.venv/bin/python" -c \
  'from research.kolkhoz_research.c_engine import build_shared_library; build_shared_library(force=True)'
"$app_dir/.venv/bin/python" -m unittest \
  research.tests.test_online_server.OnlineServerTests.test_service_uses_current_engine_and_flutter_json_contract

if [[ ! -f "$env_file" ]]; then
  install -m 0600 -o root -g root /dev/null "$env_file"
  cat >"$env_file" <<'ENV'
KOLKHOZ_SUPABASE_URL=
KOLKHOZ_SUPABASE_PUBLISHABLE_KEY=
KOLKHOZ_ONLINE_DATABASE_URL=
ENV
  echo "Created $env_file. Fill in Supabase values before starting the service." >&2
fi

install -m 0644 "$app_dir/deploy/digitalocean/kolkhoz-online.service" "$service_file"
chown -R kolkhoz:kolkhoz "$app_dir"

systemctl daemon-reload
systemctl enable kolkhoz-online.service
if grep -Eq '^(KOLKHOZ_SUPABASE_URL|KOLKHOZ_SUPABASE_PUBLISHABLE_KEY|KOLKHOZ_ONLINE_DATABASE_URL)=$' "$env_file"; then
  echo "Fill in $env_file, then rerun this script to deploy." >&2
  exit 0
fi
systemctl restart kolkhoz-online.service

echo "Bootstrap complete."
echo "Kolkhoz online is running from $(git rev-parse HEAD)."
