#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
RUN_DIR="${RUN_DIR:-research/runs/torch_mlp_self_play_seed_pool_v2/${RUN_ID}}"
START_MODEL="${START_MODEL:-research/runs/torch_mlp_vs_strongest_stage2_4x_v1/20260705T221143Z/candidate.pt}"
OPPONENT_MODEL="${OPPONENT_MODEL:-training/rl/runs/beat_promoted_wide_seat_heads_v1/20260702T144243Z/candidate.json}"
EXTRA_OPPONENT_MODELS="${EXTRA_OPPONENT_MODELS:-}"
PYTHON_BIN="${PYTHON_BIN:-/Applications/Xcode.app/Contents/Developer/usr/bin/python3}"
FORCE_CPU="${FORCE_CPU:-1}"
TORCH_SITE_PACKAGES="${TORCH_SITE_PACKAGES:-$HOME/Library/Python/3.9/lib/python/site-packages}"

POOL_SIZE="${POOL_SIZE:-${GENERATIONS:-8}}"
FINALISTS="${FINALISTS:-2}"
CHILD_GENERATIONS="${CHILD_GENERATIONS:-1}"
EPISODES_PER_GENERATION="${EPISODES_PER_GENERATION:-131072}"
TRAIN_SEED="${TRAIN_SEED:-${POOL_SEED:-80000000}}"
EVAL_SEED="${EVAL_SEED:-90000000}"
SELECTION_SEED="${SELECTION_SEED:-100000000}"
PROMOTION_SEED="${PROMOTION_SEED:-110000000}"
SEED_STRIDE="${SEED_STRIDE:-100000}"
STANDARD_EVAL_GAMES_PER_SEAT="${STANDARD_EVAL_GAMES_PER_SEAT:-${EVAL_GAMES_PER_SEAT:-256}}"
SELECTION_GAMES_PER_SEAT="${SELECTION_GAMES_PER_SEAT:-$STANDARD_EVAL_GAMES_PER_SEAT}"
PROMOTION_GAMES_PER_SEAT="${PROMOTION_GAMES_PER_SEAT:-$STANDARD_EVAL_GAMES_PER_SEAT}"
ARENA_GAMES_PER_SEAT="${ARENA_GAMES_PER_SEAT:-$STANDARD_EVAL_GAMES_PER_SEAT}"
BOOTSTRAP_SAMPLES="${BOOTSTRAP_SAMPLES:-1000}"
ARENA_MIN_MEAN_WIN_DELTA="${ARENA_MIN_MEAN_WIN_DELTA:-0.0}"
ARENA_MIN_WORST_MEAN_WIN_DELTA="${ARENA_MIN_WORST_MEAN_WIN_DELTA:--0.02}"

export RUN_ID RUN_DIR START_MODEL OPPONENT_MODEL EXTRA_OPPONENT_MODELS FORCE_CPU
export POOL_SIZE FINALISTS CHILD_GENERATIONS EPISODES_PER_GENERATION
export TRAIN_SEED EVAL_SEED SELECTION_SEED PROMOTION_SEED SEED_STRIDE
export STANDARD_EVAL_GAMES_PER_SEAT SELECTION_GAMES_PER_SEAT PROMOTION_GAMES_PER_SEAT ARENA_GAMES_PER_SEAT
export BOOTSTRAP_SAMPLES ARENA_MIN_MEAN_WIN_DELTA ARENA_MIN_WORST_MEAN_WIN_DELTA

mkdir -p "$RUN_DIR"
mkdir -p "${MPLCONFIGDIR:-/tmp/mpl}" "${PYTHONPYCACHEPREFIX:-/private/tmp/kolkhoz_pycache}"

if [[ -d "$TORCH_SITE_PACKAGES" ]]; then
  export PYTHONPATH="$TORCH_SITE_PACKAGES${PYTHONPATH:+:$PYTHONPATH}"
  export PYTHONNOUSERSITE="${PYTHONNOUSERSITE:-1}"
fi
export PYTHONPYCACHEPREFIX="${PYTHONPYCACHEPREFIX:-/private/tmp/kolkhoz_pycache}"
export MPLCONFIGDIR="${MPLCONFIGDIR:-/tmp/mpl}"

opponent_args=(--opponent-model "$OPPONENT_MODEL")
arena_opponents=("$OPPONENT_MODEL")
if [[ -n "$EXTRA_OPPONENT_MODELS" ]]; then
  IFS=':' read -r -a extra_opponents <<< "$EXTRA_OPPONENT_MODELS"
  for opponent in "${extra_opponents[@]}"; do
    if [[ -n "$opponent" ]]; then
      opponent_args+=(--opponent-model "$opponent")
      arena_opponents+=("$opponent")
    fi
  done
fi
ARENA_OPPONENT_COUNT="${#arena_opponents[@]}"
export ARENA_OPPONENT_COUNT

benchmark_common_args=(
  --bootstrap-samples "$BOOTSTRAP_SAMPLES"
  --rollout-envs "${BENCHMARK_ROLLOUT_ENVS:-32}"
  --round-curriculum
  --round-plot-cards "${ROUND_PLOT_CARDS:-6}"
  --round-famine-rate "${ROUND_FAMINE_RATE:-0.2}"
  --min-win-delta "${MIN_WIN_DELTA:-0.0}"
  --min-rank-delta "${MIN_RANK_DELTA:-0.0}"
  --min-margin-delta "${MIN_MARGIN_DELTA:-0.0}"
  --promotion-objective "${PROMOTION_OBJECTIVE:-utility}"
  --promotion-utility-win-weight "${PROMOTION_UTILITY_WIN_WEIGHT:-1.0}"
  --promotion-utility-rank-weight "${PROMOTION_UTILITY_RANK_WEIGHT:-0.05}"
  --promotion-utility-margin-weight "${PROMOTION_UTILITY_MARGIN_WEIGHT:-0.001}"
  --min-utility-delta "${MIN_UTILITY_DELTA:-0.0}"
  --candidate-pool-min-utility-delta "${CANDIDATE_POOL_MIN_UTILITY_DELTA:-0.0}"
)
if [[ -n "${RISK_MIN_WIN_DELTA_MEAN:-}" ]]; then
  benchmark_common_args+=(--risk-min-win-delta-mean "$RISK_MIN_WIN_DELTA_MEAN")
fi
if [[ -n "${RISK_MIN_RANK_DELTA_MEAN:-}" ]]; then
  benchmark_common_args+=(--risk-min-rank-delta-mean "$RISK_MIN_RANK_DELTA_MEAN")
fi
if [[ -n "${RISK_MIN_MARGIN_DELTA_MEAN:-}" ]]; then
  benchmark_common_args+=(--risk-min-margin-delta-mean "$RISK_MIN_MARGIN_DELTA_MEAN")
fi
if [[ "$FORCE_CPU" == "1" ]]; then
  benchmark_common_args+=(--cpu)
fi

write_pool_status() {
  local status="$1"
  local phase="$2"
  local completed="$3"
  local append="${4:-0}"
  POOL_STATUS="$status" POOL_PHASE="$phase" POOL_COMPLETED="$completed" POOL_APPEND="$append" \
  "$PYTHON_BIN" - <<'PY'
from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path
from statistics import mean

repo = Path.cwd()
sys.path.insert(0, str(repo))
from research.kolkhoz_research.history import append_history, write_current_experiment

run_dir = Path(os.environ["RUN_DIR"])
pool_size = int(os.environ["POOL_SIZE"])
completed = int(os.environ["POOL_COMPLETED"])
finalists_requested = int(os.environ["FINALISTS"])

def read_json(path: Path) -> dict | None:
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None

def interval_mean(record: dict | None, key: str = "win_delta") -> float | None:
    if not record:
        return None
    intervals = record.get("intervals")
    if not isinstance(intervals, dict):
        return None
    item = intervals.get(key)
    if not isinstance(item, dict):
        return None
    value = item.get("mean")
    return float(value) if isinstance(value, (int, float)) else None

def compact_benchmark(path: Path) -> dict | None:
    record = read_json(path)
    if not record:
        return None
    return {
        "path": str(path),
        "status": record.get("status"),
        "candidate_model": record.get("candidate_model"),
        "baseline_model": record.get("baseline_model"),
        "seed": record.get("seed"),
        "games_per_seat": record.get("games_per_seat"),
        "total_games": record.get("total_games"),
        "summary": record.get("summary"),
        "intervals": record.get("intervals"),
        "promotion_eligible": bool((record.get("evidence") or {}).get("promotion_eligible")),
        "win_delta": interval_mean(record, "win_delta"),
        "rank_delta": interval_mean(record, "rank_delta"),
        "margin_delta": interval_mean(record, "margin_delta"),
        "utility_delta": interval_mean(record, "utility_delta"),
    }

generations = []
for index in range(1, pool_size + 1):
    seed_dir = run_dir / f"seed_{index:03d}"
    summary = read_json(seed_dir / "self_play_improvement.json")
    child = {}
    if summary:
        child_generations = summary.get("generations")
        if isinstance(child_generations, list) and child_generations and isinstance(child_generations[0], dict):
            child = child_generations[0]
    selection = compact_benchmark(seed_dir / "generation_001" / "benchmark.json")
    win_delta = selection.get("win_delta") if selection else None
    utility_delta = selection.get("utility_delta") if selection else None
    selection_score = utility_delta if isinstance(utility_delta, (int, float)) else win_delta
    generations.append(
        {
            "generation": index,
            "seed_run_dir": str(seed_dir),
            "seed": child.get("seed"),
            "eval_seed": int(os.environ["EVAL_SEED"]) + (index - 1) * int(os.environ["SEED_STRIDE"]),
            "selection_seed": int(os.environ["SELECTION_SEED"]),
            "candidate_model": child.get("candidate_model"),
            "training_record": child.get("training_record"),
            "selection_record": selection["path"] if selection else None,
            "benchmark_record": selection["path"] if selection else None,
            "benchmark_status": selection.get("status") if selection else child.get("benchmark_status"),
            "summary": selection.get("summary") if selection else child.get("summary"),
            "intervals": selection.get("intervals") if selection else child.get("intervals"),
            "win_delta": win_delta,
            "utility_delta": utility_delta,
            "selection_score": selection_score,
            "promoted": False,
        }
    )

ranked = sorted(
    [item for item in generations if isinstance(item.get("selection_score"), (int, float))],
    key=lambda item: float(item["selection_score"]),
    reverse=True,
)
finalists = ranked[:finalists_requested]

promotion_records = []
expected_arena_records = int(os.environ["ARENA_OPPONENT_COUNT"])
for finalist in finalists:
    promotion_dir = run_dir / f"finalist_{int(finalist['generation']):03d}"
    current_record = compact_benchmark(promotion_dir / "promotion_current_best.json")
    arena_records = []
    for path in sorted(promotion_dir.glob("arena_*.json")):
        record = compact_benchmark(path)
        if record:
            arena_records.append(record)
    arena_win_deltas = [
        record["win_delta"]
        for record in arena_records
        if isinstance(record.get("win_delta"), (int, float))
    ]
    arena_scores = [
        record["utility_delta"] if isinstance(record.get("utility_delta"), (int, float)) else record["win_delta"]
        for record in arena_records
        if isinstance(record.get("win_delta"), (int, float))
    ]
    current_score = (
        current_record["utility_delta"]
        if current_record and isinstance(current_record.get("utility_delta"), (int, float))
        else (current_record["win_delta"] if current_record and isinstance(current_record.get("win_delta"), (int, float)) else None)
    )
    arena_score = (
        mean([current_score, *arena_scores])
        if isinstance(current_score, (int, float)) and len(arena_scores) == expected_arena_records
        else None
    )
    arena_mean_win_delta = (
        mean([current_record["win_delta"], *arena_win_deltas])
        if current_record and isinstance(current_record.get("win_delta"), (int, float)) and len(arena_win_deltas) == expected_arena_records
        else None
    )
    worst_arena = min(arena_win_deltas) if arena_win_deltas else None
    complete_arena = (
        len(arena_records) == expected_arena_records
        and len(arena_win_deltas) == expected_arena_records
        and len(arena_scores) == expected_arena_records
    )
    eligible = bool(
        current_record
        and current_record.get("promotion_eligible")
        and isinstance(arena_score, (int, float))
        and complete_arena
        and isinstance(arena_mean_win_delta, (int, float))
        and arena_mean_win_delta >= float(os.environ["ARENA_MIN_MEAN_WIN_DELTA"])
        and isinstance(worst_arena, (int, float))
        and worst_arena >= float(os.environ["ARENA_MIN_WORST_MEAN_WIN_DELTA"])
    )
    promotion_records.append(
        {
            **finalist,
            "promotion_current_best": current_record,
            "arena_records": arena_records,
            "arena_score": arena_score,
            "arena_mean_win_delta": arena_mean_win_delta,
            "worst_arena_win_delta": worst_arena,
            "complete_arena": complete_arena,
            "expected_arena_records": expected_arena_records,
            "promotion_eligible": eligible,
            "promoted": eligible,
        }
    )

promoted = sorted(
    [item for item in promotion_records if item.get("promoted")],
    key=lambda item: item.get("arena_score") if isinstance(item.get("arena_score"), (int, float)) else -999.0,
    reverse=True,
)
best_finalist = max(
    promotion_records,
    key=lambda item: item.get("arena_score") if isinstance(item.get("arena_score"), (int, float)) else -999.0,
    default=(finalists[0] if finalists else None),
)
selected_promotion = promoted[0] if promoted else None
best_model = selected_promotion["candidate_model"] if selected_promotion else os.environ["START_MODEL"]
if promoted:
    promoted_path = run_dir / "promoted_best.pt"
    shutil.copyfile(selected_promotion["candidate_model"], promoted_path)
    best_model = str(promoted_path)

record = {
    "kind": "self_play_seed_pool",
    "status": os.environ["POOL_STATUS"],
    "phase": os.environ["POOL_PHASE"],
    "run_dir": str(run_dir),
    "start_model": os.environ["START_MODEL"],
    "current_best_model": os.environ["START_MODEL"],
    "opponent_model": os.environ["OPPONENT_MODEL"],
    "extra_opponent_models": [item for item in os.environ.get("EXTRA_OPPONENT_MODELS", "").split(":") if item],
    "requested_generations": pool_size,
    "completed_generations": completed,
    "promoted_count": len(promoted),
    "generations": generations,
    "latest_generation": generations[-1] if generations else None,
    "finalists": finalists,
    "promotion_records": promotion_records,
    "best_candidate": best_finalist,
    "selected_promotion": selected_promotion,
    "best_model": best_model,
    "training": {
        "episodes_per_generation": int(os.environ["EPISODES_PER_GENERATION"]),
        "child_generations": int(os.environ["CHILD_GENERATIONS"]),
        "batch_size": int(os.environ.get("BATCH_SIZE", "32")),
        "rollout_envs": int(os.environ.get("ROLLOUT_ENVS", "32")),
        "seed": int(os.environ["TRAIN_SEED"]),
        "eval_seed": int(os.environ["EVAL_SEED"]),
        "seed_stride": int(os.environ["SEED_STRIDE"]),
        "standard_eval_games_per_seat": int(os.environ["STANDARD_EVAL_GAMES_PER_SEAT"]),
        "selection_seed": int(os.environ["SELECTION_SEED"]),
        "promotion_seed": int(os.environ["PROMOTION_SEED"]),
        "selection_games_per_seat": int(os.environ["SELECTION_GAMES_PER_SEAT"]),
        "promotion_games_per_seat": int(os.environ["PROMOTION_GAMES_PER_SEAT"]),
        "arena_games_per_seat": int(os.environ["ARENA_GAMES_PER_SEAT"]),
    },
    "progress": {
        "completed_generations": completed,
        "total_generations": pool_size,
        "percent": min(1.0, completed / max(1, pool_size)),
    },
}
write_current_experiment(record)
if os.environ.get("POOL_APPEND") == "1":
    append_history(record)
    (run_dir / "seed_pool_v2.json").write_text(
        json.dumps(record, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
PY
}

select_finalists() {
  "$PYTHON_BIN" - <<'PY'
from __future__ import annotations

import json
import os
from pathlib import Path

run_dir = Path(os.environ["RUN_DIR"])
pool_size = int(os.environ["POOL_SIZE"])
finalists = int(os.environ["FINALISTS"])

items = []
def interval_mean(record: dict, key: str) -> float | None:
    item = ((record.get("intervals") or {}).get(key) or {}).get("mean")
    return float(item) if isinstance(item, (int, float)) else None

for index in range(1, pool_size + 1):
    path = run_dir / f"seed_{index:03d}" / "generation_001" / "benchmark.json"
    if not path.exists():
        continue
    data = json.loads(path.read_text(encoding="utf-8"))
    utility = interval_mean(data, "utility_delta")
    win = interval_mean(data, "win_delta")
    score = utility if isinstance(utility, (int, float)) else win
    if isinstance(score, (int, float)):
        items.append((float(score), index))

for _, index in sorted(items, reverse=True)[:finalists]:
    print(index)
PY
}

run_torch_benchmark() {
  local candidate="$1"
  local baseline="$2"
  local games_per_seat="$3"
  local seed="$4"
  local output="$5"
  local promotion_min_games="$6"
  local record_flag="${7:-0}"
  local cmd=(
    "$PYTHON_BIN" -m research.kolkhoz_research.cli torch-benchmark
    --candidate "$candidate"
    --baseline "$baseline"
    --games-per-seat "$games_per_seat"
    --seed "$seed"
    --promotion-min-games-per-seat "$promotion_min_games"
    --promotion-min-bootstrap-samples "$BOOTSTRAP_SAMPLES"
    "${benchmark_common_args[@]}"
  )
  if [[ "$record_flag" == "1" && "${RECORD:-1}" == "1" ]]; then
    cmd+=(--record)
  fi
  {
    printf '[seed_pool_v2] benchmark CMD='
    printf '%q ' "${cmd[@]}"
    printf '\n'
  }
  "${cmd[@]}" > "$output"
}

{
  printf 'RUN_ID=%s\n' "$RUN_ID"
  printf 'RUN_DIR=%s\n' "$RUN_DIR"
  printf 'START_MODEL=%s\n' "$START_MODEL"
  printf 'OPPONENT_MODEL=%s\n' "$OPPONENT_MODEL"
  printf 'EXTRA_OPPONENT_MODELS=%s\n' "$EXTRA_OPPONENT_MODELS"
  printf 'POOL_SIZE=%s\n' "$POOL_SIZE"
  printf 'FINALISTS=%s\n' "$FINALISTS"
  printf 'CHILD_GENERATIONS=%s\n' "$CHILD_GENERATIONS"
  printf 'EPISODES_PER_GENERATION=%s\n' "$EPISODES_PER_GENERATION"
  printf 'TRAIN_SEED=%s\n' "$TRAIN_SEED"
  printf 'EVAL_SEED=%s\n' "$EVAL_SEED"
  printf 'SELECTION_SEED=%s\n' "$SELECTION_SEED"
  printf 'PROMOTION_SEED=%s\n' "$PROMOTION_SEED"
  printf 'STANDARD_EVAL_GAMES_PER_SEAT=%s\n' "$STANDARD_EVAL_GAMES_PER_SEAT"
  printf 'SELECTION_GAMES_PER_SEAT=%s\n' "$SELECTION_GAMES_PER_SEAT"
  printf 'PROMOTION_GAMES_PER_SEAT=%s\n' "$PROMOTION_GAMES_PER_SEAT"
  printf 'ARENA_GAMES_PER_SEAT=%s\n' "$ARENA_GAMES_PER_SEAT"
  printf 'FORCE_CPU=%s\n' "$FORCE_CPU"
} | tee "$RUN_DIR/launch.txt"

write_pool_status running starting 0

completed=0
for ((index = 1; index <= POOL_SIZE; index += 1)); do
  seed_dir="$RUN_DIR/seed_$(printf '%03d' "$index")"
  train_seed=$((TRAIN_SEED + (index - 1) * SEED_STRIDE))
  eval_seed=$((EVAL_SEED + (index - 1) * SEED_STRIDE))
  mkdir -p "$seed_dir"

  write_pool_status running "seed_${index}_starting" "$completed"

  cmd=(
    "$PYTHON_BIN" -m research.kolkhoz_research.cli self-play-improve
    --start-model "$START_MODEL"
    --run-dir "$seed_dir"
    --generations "$CHILD_GENERATIONS"
    --episodes-per-generation "$EPISODES_PER_GENERATION"
    --seed "$train_seed"
    --seed-stride "$SEED_STRIDE"
    --architecture mlp
    --layers "${LAYERS:-256,256}"
    --batch-size "${BATCH_SIZE:-32}"
    --learning-rate "${LEARNING_RATE:-0.00005}"
    --temperature "${TEMPERATURE:-0.8}"
    --rollout-envs "${ROLLOUT_ENVS:-32}"
    --opponent-schedule "${OPPONENT_SCHEDULE:-constant}"
    "${opponent_args[@]}"
    --win-weight "${WIN_WEIGHT:-1.0}"
    --rank-weight "${RANK_WEIGHT:-0.05}"
    --margin-weight "${MARGIN_WEIGHT:-0.001}"
    --reward-mode "${REWARD_MODE:-paired-baseline-delta}"
    --reward-schedule "${REWARD_SCHEDULE:-constant}"
    --advantage-mode "${ADVANTAGE_MODE:-batch}"
    --policy-loss-reduction "${POLICY_LOSS_REDUCTION:-episode-mean}"
    --ppo-epochs "${PPO_EPOCHS:-4}"
    --ppo-minibatch-size "${PPO_MINIBATCH_SIZE:-128}"
    --ppo-clip "${PPO_CLIP:-0.2}"
    --value-loss-weight "${VALUE_LOSS_WEIGHT:-0.5}"
    --entropy-weight "${ENTROPY_WEIGHT:-0.01}"
    --reference-kl-weight "${REFERENCE_KL_WEIGHT:-0.005}"
    --eval-interval "${EVAL_INTERVAL:-8192}"
    --eval-games-per-seat "$STANDARD_EVAL_GAMES_PER_SEAT"
    --eval-seed "$eval_seed"
    --eval-bootstrap-samples "${EVAL_BOOTSTRAP_SAMPLES:-$BOOTSTRAP_SAMPLES}"
    --eval-include-heuristic
    --select-best-eval-checkpoint
    --round-curriculum
    --curriculum-schedule constant
    --curriculum-rounds 2
    --round-plot-cards "${ROUND_PLOT_CARDS:-6}"
    --round-famine-rate "${ROUND_FAMINE_RATE:-0.2}"
    --benchmark-games-per-seat "$SELECTION_GAMES_PER_SEAT"
    --benchmark-seed "$SELECTION_SEED"
    --benchmark-bootstrap-samples "$BOOTSTRAP_SAMPLES"
    --benchmark-rollout-envs "${BENCHMARK_ROLLOUT_ENVS:-32}"
    --benchmark-round-curriculum
    --promotion-min-games-per-seat "$PROMOTION_GAMES_PER_SEAT"
    --promotion-min-bootstrap-samples "$BOOTSTRAP_SAMPLES"
    --min-win-delta "${MIN_WIN_DELTA:-0.0}"
    --min-rank-delta "${MIN_RANK_DELTA:-0.0}"
    --min-margin-delta "${MIN_MARGIN_DELTA:-0.0}"
    --stop-on-rejection
    --overwrite-best
  )

  if [[ "$FORCE_CPU" == "1" ]]; then
    cmd+=(--cpu)
  fi
  if [[ "${RECORD:-1}" == "1" ]]; then
    cmd+=(--record)
  fi

  {
    printf '\n[seed_pool_v2] seed %03d/%03d\n' "$index" "$POOL_SIZE"
    printf '[seed_pool_v2] train_seed=%s eval_seed=%s selection_seed=%s\n' "$train_seed" "$eval_seed" "$SELECTION_SEED"
    printf '[seed_pool_v2] CMD='
    printf '%q ' "${cmd[@]}"
    printf '\n'
  } | tee "$seed_dir/launch.txt"

  "${cmd[@]}"
  completed="$index"
  write_pool_status running "seed_${index}_complete" "$completed"
done

write_pool_status running selection_complete "$completed"

finalist_indices="$(select_finalists)"
printf '%s\n' "$finalist_indices" > "$RUN_DIR/finalists.txt"
for finalist_index in $finalist_indices; do
  finalist_dir="$RUN_DIR/finalist_$(printf '%03d' "$finalist_index")"
  seed_dir="$RUN_DIR/seed_$(printf '%03d' "$finalist_index")"
  candidate="$seed_dir/generation_001/candidate.pt"
  mkdir -p "$finalist_dir"

  write_pool_status running "finalist_${finalist_index}_promotion" "$completed"
  run_torch_benchmark \
    "$candidate" \
    "$START_MODEL" \
    "$PROMOTION_GAMES_PER_SEAT" \
    "$PROMOTION_SEED" \
    "$finalist_dir/promotion_current_best.json" \
    "$PROMOTION_GAMES_PER_SEAT" \
    1

  arena_number=0
  for opponent in "${arena_opponents[@]}"; do
    arena_number=$((arena_number + 1))
    run_torch_benchmark \
      "$candidate" \
      "$opponent" \
      "$ARENA_GAMES_PER_SEAT" \
      $((PROMOTION_SEED + arena_number * SEED_STRIDE)) \
      "$finalist_dir/arena_$(printf '%02d' "$arena_number").json" \
      "$PROMOTION_GAMES_PER_SEAT" \
      0
  done
  write_pool_status running "finalist_${finalist_index}_complete" "$completed"
done

write_pool_status completed complete "$completed" 1
