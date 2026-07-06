#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <run-dir>" >&2
  exit 2
fi

RUN_DIR="${1%/}"
TAIL_LINES="${TAIL_LINES:-80}"
STATUS="$RUN_DIR/launcher_status.json"
PID_FILE="$RUN_DIR/launcher.pid"
TERMINAL_COMMAND_FILE="$RUN_DIR/terminal_command.txt"
PLIST="$(find "$RUN_DIR" -maxdepth 1 -name 'com.wtheisen.kolkhoz.research.*.plist' -print | sort | tail -n 1)"

echo "run_dir=$RUN_DIR"

if [[ -s "$STATUS" ]]; then
  echo
  echo "== launcher_status.json =="
  /usr/bin/python3 -m json.tool "$STATUS"
  STATUS="$STATUS" /usr/bin/python3 - <<'PY'
from __future__ import annotations

import json
import os
from pathlib import Path

def alive(pid: int | None) -> bool | None:
    if pid is None:
        return None
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True

record = json.loads(Path(os.environ["STATUS"]).read_text(encoding="utf-8"))
launcher = record.get("launcher") if isinstance(record.get("launcher"), dict) else {}
launcher_pid = launcher.get("launcher_pid")
child_pid = launcher.get("child_pid")
print(f"launcher_alive: {alive(launcher_pid)}")
print(f"child_alive: {alive(child_pid)}")
PY
else
  echo
  echo "no launcher status at $STATUS"
fi

if [[ -s "$PID_FILE" ]]; then
  echo
  echo "== nohup launcher =="
  LAUNCHER_PID="$(cat "$PID_FILE")"
  echo "launcher_pid: $LAUNCHER_PID"
  LAUNCHER_PID="$LAUNCHER_PID" STATUS="$STATUS" /usr/bin/python3 - <<'PY'
from __future__ import annotations

import json
import os
import signal
from pathlib import Path

def alive(pid: int | None) -> bool | None:
    if pid is None:
        return None
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True

launcher_pid = int(os.environ["LAUNCHER_PID"])
print(f"launcher_alive: {alive(launcher_pid)}")
status_path = Path(os.environ["STATUS"])
if status_path.exists():
    record = json.loads(status_path.read_text(encoding="utf-8"))
    child_pid = (record.get("launcher") or {}).get("child_pid")
    print(f"child_pid: {child_pid}")
    print(f"child_alive: {alive(child_pid)}")
PY
fi

if [[ -s "$TERMINAL_COMMAND_FILE" ]]; then
  echo
  echo "== terminal launcher =="
  sed -n '1,5p' "$TERMINAL_COMMAND_FILE"
fi

if [[ -n "$PLIST" && ! -s "$PID_FILE" && ! -s "$TERMINAL_COMMAND_FILE" ]]; then
  LABEL="$(
    PLIST="$PLIST" /usr/bin/python3 - <<'PY'
import os
import plistlib

with open(os.environ["PLIST"], "rb") as handle:
    print(plistlib.load(handle).get("Label", ""))
PY
  )"
  if [[ -n "$LABEL" ]]; then
    echo
    echo "== launchd =="
    if launchctl print "gui/$(id -u)/$LABEL" >/tmp/kolkhoz_launchd_status.$$ 2>&1; then
      sed -n '1,80p' /tmp/kolkhoz_launchd_status.$$
    else
      cat /tmp/kolkhoz_launchd_status.$$
    fi
    rm -f /tmp/kolkhoz_launchd_status.$$
  fi
fi

echo
echo "== current_experiment.json =="
/usr/bin/python3 - <<'PY'
from __future__ import annotations

import json
from pathlib import Path

path = Path("research/history/current_experiment.json")
if not path.exists():
    print("missing")
    raise SystemExit
record = json.loads(path.read_text(encoding="utf-8"))
keys = [
    "status",
    "previous_status",
    "kind",
    "phase",
    "pid",
    "updated_at",
    "heartbeat_at",
    "output_model",
    "run_dir",
    "progress",
    "selected_checkpoint_model",
]
for key in keys:
    if key in record:
        print(f"{key}: {record[key]}")
curve = record.get("curve") if isinstance(record.get("curve"), dict) else {}
points = curve.get("points") if isinstance(curve.get("points"), list) else []
if points:
    last = points[-1]
    print(
        "last_curve:",
        {
            key: last.get(key)
            for key in [
                "episode",
                "reward",
                "win",
                "rank",
                "margin",
                "win_delta",
                "rank_delta",
                "margin_delta",
            ]
        },
    )
PY

for log_name in run.log run.err; do
  LOG_PATH="$RUN_DIR/$log_name"
  echo
  echo "== tail $log_name =="
  if [[ -s "$LOG_PATH" ]]; then
    tail -n "$TAIL_LINES" "$LOG_PATH"
  else
    echo "missing or empty: $LOG_PATH"
  fi
done
