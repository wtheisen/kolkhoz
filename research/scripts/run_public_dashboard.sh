#!/usr/bin/env bash
set -euo pipefail

cd /Users/wtheisen/Dropbox/linux_files/programs/kolkhoz

password="$(/usr/bin/security find-generic-password \
  -a kolkhoz \
  -s com.wtheisen.kolkhoz-research-dashboard \
  -w)"

export KOLKHOZ_DASHBOARD_USERNAME="${KOLKHOZ_DASHBOARD_USERNAME:-kolkhoz}"
export KOLKHOZ_DASHBOARD_PASSWORD="$password"

exec /opt/homebrew/bin/python3 -m research.kolkhoz_research.cli dashboard \
  --host 127.0.0.1 \
  --port 8877
