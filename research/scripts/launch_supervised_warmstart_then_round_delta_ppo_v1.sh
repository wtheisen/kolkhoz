#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

REPO_ROOT="$(pwd)"
EXPERIMENT="${EXPERIMENT:-supervised_warmstart_then_round_delta_ppo_v1}"
RUN_SCRIPT="${RUN_SCRIPT:-research/scripts/run_supervised_warmstart_then_round_delta_ppo_v1.sh}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
RUN_DIR="${RUN_DIR:-research/runs/${EXPERIMENT}/${RUN_ID}}"
ABS_RUN_DIR="$REPO_ROOT/$RUN_DIR"

BASELINE="${BASELINE:-training/rl/runs/beat_promoted_wide_seat_heads_v1/20260702T144243Z/candidate.json}"
START_MODEL="${START_MODEL:-research/runs/action_transformer_paired_delta_fullgame_v3/20260704T031950Z/checkpoints/candidate_ep4096.pt}"
ROLLOUTS_PER_ACTION="${ROLLOUTS_PER_ACTION:-2}"
SEARCH_HORIZON="${SEARCH_HORIZON:-full-game}"
SEARCH_TARGET="${SEARCH_TARGET:-paired-baseline}"
DETERMINIZE_SEARCH="${DETERMINIZE_SEARCH:-1}"
FORCE_CPU="${FORCE_CPU:-1}"
LAUNCH_BACKEND="${LAUNCH_BACKEND:-nohup}"

mkdir -p "$ABS_RUN_DIR"

SAFE_EXPERIMENT="${EXPERIMENT//_/-}"
SAFE_RUN_ID="${RUN_ID//_/-}"
JOB_LABEL="com.wtheisen.kolkhoz.research.${SAFE_EXPERIMENT}.${SAFE_RUN_ID}"
WRAPPER="$ABS_RUN_DIR/launchd_wrapper.sh"
PLIST="$ABS_RUN_DIR/${JOB_LABEL}.plist"
LOG="$ABS_RUN_DIR/run.log"
ERR="$ABS_RUN_DIR/run.err"
STATUS="$ABS_RUN_DIR/launcher_status.json"

EXPORT_NAMES=(
  BASELINE
  START_MODEL
  RUN_ID
  RUN_DIR
  TRAJECTORIES
  SUPERVISED
  OUTPUT
  PPO_START_MODEL
  PPO_REFERENCE_MODEL
  PYTHON_BIN
  PYTHONNOUSERSITE
  SKIP_GENERATE
  SKIP_PRETRAIN
  FORCE_CPU
  GAMES
  DATA_SEED
  SEATS
  MAX_SEARCH_ACTIONS
  ROLLOUT_ACTION_LIMIT
  ROLLOUTS_PER_ACTION
  SEARCH_HORIZON
  SEARCH_TARGET
  SEARCH_TEMPERATURE
  MIN_SEARCH_Q_MARGIN
  MIN_SEARCH_Q_STD
  SKIP_FORCED_TARGETS
  DETERMINIZE_SEARCH
  ROLLOUT_SAMPLE
  ROLLOUT_TEMPERATURE
  WIN_WEIGHT
  RANK_WEIGHT
  MARGIN_WEIGHT
  LAYERS
  SCRATCH_SEED
  PRETRAIN_EPOCHS
  PRETRAIN_BATCH_SIZE
  PRETRAIN_LEARNING_RATE
  PRETRAIN_VALUE_LOSS_WEIGHT
  PRETRAIN_MIN_POLICY_Q_MARGIN
  PRETRAIN_POLICY_CONFIDENCE_SCALE
  PRETRAIN_MIN_POLICY_WEIGHT
  PRETRAIN_Q_VALUE_LOSS_WEIGHT
  PRETRAIN_PHASE_SAMPLE_WEIGHTS
  TARGET_TEMPERATURE
  TRANSFORMER_DROPOUT
  EPISODES
  GENERATIONS
  EPISODES_PER_GENERATION
  SEED
  SEED_STRIDE
  BATCH_SIZE
  ROLLOUT_ENVS
  ARCHITECTURE
  OPPONENT_MODEL
  OPPONENT_SCHEDULE
  REWARD_MODE
  REWARD_SCHEDULE
  EARLY_WIN_WEIGHT
  EARLY_RANK_WEIGHT
  EARLY_MARGIN_WEIGHT
  LATE_WIN_WEIGHT
  LATE_RANK_WEIGHT
  LATE_MARGIN_WEIGHT
  ADVANTAGE_MODE
  POLICY_LOSS_REDUCTION
  CURRICULUM_SCHEDULE
  CURRICULUM_ROUNDS
  SCALED_CURRICULUM_ROUNDS
  MIXED_CURRICULUM_PROFILE
  BENCHMARK_GAMES_PER_SEAT
  BENCHMARK_SEED
  BENCHMARK_BOOTSTRAP_SAMPLES
  BENCHMARK_ROLLOUT_ENVS
  BENCHMARK_ROUND_CURRICULUM
  MIN_WIN_DELTA
  MIN_RANK_DELTA
  MIN_MARGIN_DELTA
  PROMOTION_OBJECTIVE
  PROMOTION_UTILITY_WIN_WEIGHT
  PROMOTION_UTILITY_RANK_WEIGHT
  PROMOTION_UTILITY_MARGIN_WEIGHT
  MIN_UTILITY_DELTA
  CANDIDATE_POOL_MIN_UTILITY_DELTA
  RISK_MIN_WIN_DELTA_MEAN
  RISK_MIN_RANK_DELTA_MEAN
  RISK_MIN_MARGIN_DELTA_MEAN
  PROMOTION_MIN_GAMES_PER_SEAT
  PROMOTION_MIN_BOOTSTRAP_SAMPLES
  PROMOTE_ON_SELECTION
  PPO_SEED
  LEARNING_RATE
  TEMPERATURE
  ROUND_RANK_WEIGHT
  ROUND_MARGIN_WEIGHT
  TWO_ROUND_RANK_WEIGHT
  TWO_ROUND_MARGIN_WEIGHT
  PPO_EPOCHS
  PPO_MINIBATCH_SIZE
  PPO_CLIP
  VALUE_LOSS_WEIGHT
  ENTROPY_WEIGHT
  REFERENCE_KL_WEIGHT
  EVAL_INTERVAL
  EVAL_GAMES_PER_SEAT
  EVAL_SEED
  EVAL_BOOTSTRAP_SAMPLES
  EVAL_PATIENCE
  RECORD
  TRAIN_MLP
  TRAIN_RESIDUAL
  RUN_BENCHMARKS
  MLP_OUTPUT
  RESIDUAL_OUTPUT
  EXTRA_OPPONENT_MODELS
  MLP_BENCHMARK
  RESIDUAL_BENCHMARK
  MLP_LAYERS
  RESIDUAL_LAYERS
  MLP_SCRATCH_SEED
  RESIDUAL_SCRATCH_SEED
  PHASE_SAMPLE_WEIGHTS
  EPOCHS
  LIMIT_STATES
  POOL_SIZE
  FINALISTS
  POOL_SEED
  POOL_EVAL_SEED
  CHILD_GENERATIONS
  TRAIN_SEED
  SELECTION_SEED
  PROMOTION_SEED
  STANDARD_EVAL_GAMES_PER_SEAT
  SELECTION_GAMES_PER_SEAT
  PROMOTION_GAMES_PER_SEAT
  ARENA_GAMES_PER_SEAT
  BOOTSTRAP_SAMPLES
  ARENA_MIN_MEAN_WIN_DELTA
  ARENA_MIN_WORST_MEAN_WIN_DELTA
  BENCHMARK_GAMES_PER_SEAT
  BENCHMARK_SEED
  BENCHMARK_BOOTSTRAP_SAMPLES
  BENCHMARK_ROLLOUT_ENVS
  LAUNCH_BACKEND
  EXPERIMENT
  RUN_SCRIPT
)

{
  printf '#!/usr/bin/env bash\n'
  printf 'set -Eeuo pipefail\n\n'
  printf 'export REPO_ROOT=%q\n' "$REPO_ROOT"
  printf 'export RUN_DIR=%q\n' "$RUN_DIR"
  printf 'export ABS_RUN_DIR=%q\n' "$ABS_RUN_DIR"
  printf 'export JOB_LABEL=%q\n' "$JOB_LABEL"
  printf 'export STATUS_PATH=%q\n' "$STATUS"
  printf 'export RUN_LOG=%q\n' "$LOG"
  printf 'export RUN_ERR=%q\n' "$ERR"
  printf 'export PYTHONUNBUFFERED=1\n'
  printf 'export PYTHONFAULTHANDLER=1\n'
  printf 'export PYTHONDONTWRITEBYTECODE=1\n'
  printf 'export PYTHONPYCACHEPREFIX=%q\n' "/private/tmp/kolkhoz_pycache"
  printf 'export PATH=%q\n' "$PATH"
  for name in "${EXPORT_NAMES[@]}"; do
    if [[ "${!name+x}" == "x" ]]; then
      printf 'export %s=%q\n' "$name" "${!name}"
    fi
  done
  cat <<'WRAPPER_BODY'

cd "$REPO_ROOT"
child_pid=""

write_status() {
  local status="$1"
  local exit_code="${2:-}"
  local child="${3:-$child_pid}"
  STATUS_VALUE="$status" EXIT_CODE_VALUE="$exit_code" CHILD_PID_VALUE="$child" \
    /usr/bin/python3 - <<'PY'
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

repo_root = Path(os.environ["REPO_ROOT"])
run_dir = os.environ["RUN_DIR"]
status_path = Path(os.environ["STATUS_PATH"])
status = os.environ["STATUS_VALUE"]
exit_code_text = os.environ.get("EXIT_CODE_VALUE", "")
child_pid_text = os.environ.get("CHILD_PID_VALUE", "")

def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

existing = {}
if status_path.exists():
    try:
        existing = json.loads(status_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        existing = {}

launcher = {
    "job_label": os.environ["JOB_LABEL"],
    "launcher_pid": os.getppid(),
    "child_pid": int(child_pid_text) if child_pid_text else None,
    "exit_code": int(exit_code_text) if exit_code_text else None,
    "run_dir": run_dir,
    "run_log": os.environ["RUN_LOG"],
    "run_err": os.environ["RUN_ERR"],
}
record = {
    **existing,
    "kind": "research_launch",
    "experiment": os.environ["EXPERIMENT"],
    "status": status,
    "updated_at": now_iso(),
    "repo_root": str(repo_root),
    "launcher": launcher,
}
if status == "running":
    record.pop("ended_at", None)
if "started_at" not in record:
    record["started_at"] = record["updated_at"]
if status != "running":
    record["ended_at"] = record["updated_at"]
status_path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")

sys.path.insert(0, str(repo_root))
from research.kolkhoz_research.history import append_history, write_current_experiment

if status == "running":
    append_history(
        {
            "kind": "research_launcher",
            "status": "running",
            "experiment": record["experiment"],
            "run_dir": run_dir,
            "launcher": launcher,
        }
    )
elif status == "completed":
    append_history(
        {
            "kind": "research_launcher",
            "status": "completed",
            "experiment": record["experiment"],
            "run_dir": run_dir,
            "launcher": launcher,
        }
    )
else:
    current_path = repo_root / "research/history/current_experiment.json"
    current = {}
    if current_path.exists():
        try:
            current = json.loads(current_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            current = {}
    current_blob = json.dumps(current, sort_keys=True)
    base = current if run_dir in current_blob else {}
    failed = {
        **base,
        "kind": base.get("kind", "research_launch"),
        "status": "failed",
        "previous_status": base.get("status"),
        "phase": base.get("phase", "launcher"),
        "run_dir": run_dir,
        "ended_at": record["ended_at"],
        "launcher": launcher,
    }
    write_current_experiment(failed)
    append_history(
        {
            "kind": "research_launcher",
            "status": "failed",
            "experiment": record["experiment"],
            "run_dir": run_dir,
            "launcher": launcher,
            "last_experiment": base or None,
        }
    )
PY
}

on_exit() {
  local code=$?
  if [[ "$code" == "0" ]]; then
    write_status completed "$code" "$child_pid"
  else
    write_status failed "$code" "$child_pid"
  fi
  exit "$code"
}

on_signal() {
  local signal_code="$1"
  if [[ -n "$child_pid" ]]; then
    kill "$child_pid" 2>/dev/null || true
  fi
  exit "$signal_code"
}

trap on_exit EXIT
trap 'on_signal 130' INT
trap 'on_signal 143' TERM

write_status running "" ""
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] research job $JOB_LABEL starting"
echo "repo=$REPO_ROOT"
echo "run_dir=$RUN_DIR"
echo "log=$RUN_LOG"
echo "err=$RUN_ERR"

"$RUN_SCRIPT" &
child_pid=$!
write_status running "" "$child_pid"
wait "$child_pid"
WRAPPER_BODY
} > "$WRAPPER"

chmod +x "$WRAPPER"

JOB_LABEL="$JOB_LABEL" WRAPPER="$WRAPPER" PLIST="$PLIST" LOG="$LOG" ERR="$ERR" REPO_ROOT="$REPO_ROOT" \
  /usr/bin/python3 - <<'PY'
from __future__ import annotations

import os
import plistlib
from pathlib import Path

plist = {
    "Label": os.environ["JOB_LABEL"],
    "ProgramArguments": ["/bin/bash", os.environ["WRAPPER"]],
    "WorkingDirectory": os.environ["REPO_ROOT"],
    "RunAtLoad": True,
    "KeepAlive": False,
    "StandardOutPath": os.environ["LOG"],
    "StandardErrorPath": os.environ["ERR"],
    "EnvironmentVariables": {
        "PYTHONUNBUFFERED": "1",
        "PYTHONFAULTHANDLER": "1",
    },
}
Path(os.environ["PLIST"]).write_bytes(plistlib.dumps(plist, sort_keys=True))
PY

case "$LAUNCH_BACKEND" in
  terminal)
    : > "$LOG"
    : > "$ERR"
    COMMAND_FILE="$ABS_RUN_DIR/run_in_terminal.command"
    {
      printf '#!/usr/bin/env bash\n'
      printf 'set -uo pipefail\n'
      printf 'terminal_window_id="$(/usr/bin/osascript <<'\''APPLESCRIPT'\'' 2>/dev/null || true\n'
      printf 'tell application "Terminal"\n'
      printf '  if (count of windows) > 0 then return id of front window\n'
      printf 'end tell\n'
      printf 'APPLESCRIPT\n'
      printf ')"\n'
      printf 'close_terminal_window() {\n'
      printf '  local code="$?"\n'
      printf '  if [[ -n "$terminal_window_id" ]]; then\n'
      printf '    (\n'
      printf '      sleep 0.5\n'
      printf '      /usr/bin/osascript <<APPLESCRIPT >/dev/null 2>&1 || true\n'
      printf 'tell application "Terminal"\n'
      printf '  try\n'
      printf '    close (first window whose id is $terminal_window_id)\n'
      printf '  end try\n'
      printf 'end tell\n'
      printf 'APPLESCRIPT\n'
      printf '    ) &\n'
      printf '  fi\n'
      printf '  trap - EXIT\n'
      printf '  exit "$code"\n'
      printf '}\n'
      printf 'trap close_terminal_window EXIT\n'
      printf 'cd %q\n' "$REPO_ROOT"
      printf '/bin/bash %q >>%q 2>>%q\n' "$WRAPPER" "$LOG" "$ERR"
    } > "$COMMAND_FILE"
    chmod +x "$COMMAND_FILE"
    echo "$COMMAND_FILE" > "$ABS_RUN_DIR/terminal_command.txt"
    /usr/bin/open -a Terminal "$COMMAND_FILE"
    LAUNCHER_PID=""
    ;;
  nohup)
    : > "$LOG"
    : > "$ERR"
    nohup /bin/bash "$WRAPPER" >>"$LOG" 2>>"$ERR" &
    LAUNCHER_PID=$!
    echo "$LAUNCHER_PID" > "$ABS_RUN_DIR/launcher.pid"
    ;;
  launchd)
    DOMAIN="gui/$(id -u)"
    if launchctl print "$DOMAIN/$JOB_LABEL" >/dev/null 2>&1; then
      launchctl bootout "$DOMAIN/$JOB_LABEL"
    fi
    launchctl bootstrap "$DOMAIN" "$PLIST"
    LAUNCHER_PID=""
    ;;
  *)
    echo "unknown LAUNCH_BACKEND=$LAUNCH_BACKEND; expected terminal, nohup, or launchd" >&2
    exit 2
    ;;
esac

echo "launched_label=$JOB_LABEL"
echo "backend=$LAUNCH_BACKEND"
if [[ -n "${LAUNCHER_PID:-}" ]]; then
  echo "launcher_pid=$LAUNCHER_PID"
fi
echo "run_dir=$ABS_RUN_DIR"
echo "status=$STATUS"
echo "stdout=$LOG"
echo "stderr=$ERR"
echo "plist=$PLIST"
