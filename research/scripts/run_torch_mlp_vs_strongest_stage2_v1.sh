#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

BASELINE="${BASELINE:-training/rl/runs/beat_promoted_wide_seat_heads_v1/20260702T144243Z/candidate.json}"
START_MODEL="${START_MODEL:-research/runs/torch_mlp_rl_sanity_v1/20260705T214957Z/candidate.pt}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
RUN_DIR="${RUN_DIR:-research/runs/torch_mlp_vs_strongest_stage2_v1/${RUN_ID}}"
OUTPUT="${OUTPUT:-$RUN_DIR/candidate.pt}"
BENCHMARK_OUTPUT="${BENCHMARK_OUTPUT:-$RUN_DIR/benchmark.json}"
PYTHON_BIN="${PYTHON_BIN:-/Applications/Xcode.app/Contents/Developer/usr/bin/python3}"
FORCE_CPU="${FORCE_CPU:-1}"
TORCH_SITE_PACKAGES="${TORCH_SITE_PACKAGES:-$HOME/Library/Python/3.9/lib/python/site-packages}"

mkdir -p "$RUN_DIR"
mkdir -p "${MPLCONFIGDIR:-/tmp/mpl}" "${PYTHONPYCACHEPREFIX:-/private/tmp/kolkhoz_pycache}"

if [[ -d "$TORCH_SITE_PACKAGES" ]]; then
  export PYTHONPATH="$TORCH_SITE_PACKAGES${PYTHONPATH:+:$PYTHONPATH}"
  export PYTHONNOUSERSITE="${PYTHONNOUSERSITE:-1}"
fi
export PYTHONPYCACHEPREFIX="${PYTHONPYCACHEPREFIX:-/private/tmp/kolkhoz_pycache}"
export MPLCONFIGDIR="${MPLCONFIGDIR:-/tmp/mpl}"

train_cmd=(
  "$PYTHON_BIN" -m research.kolkhoz_research.cli torch-train
  --output "$OUTPUT"
  --architecture mlp
  --layers "${LAYERS:-256,256}"
  --scratch-seed "${SCRATCH_SEED:-9101}"
  --scratch-scale "${SCRATCH_SCALE:-0.02}"
  --episodes "${EPISODES:-32768}"
  --batch-size "${BATCH_SIZE:-32}"
  --rollout-envs "${ROLLOUT_ENVS:-32}"
  --seed "${SEED:-76300000}"
  --learning-rate "${LEARNING_RATE:-0.00005}"
  --temperature "${TEMPERATURE:-0.8}"
  --opponent-mode model-pool
  --opponent-schedule constant
  --opponent-model "$BASELINE"
  --reward-mode "${REWARD_MODE:-paired-baseline-delta}"
  --reward-baseline "$BASELINE"
  --reward-schedule constant
  --win-weight "${WIN_WEIGHT:-1.0}"
  --rank-weight "${RANK_WEIGHT:-0.05}"
  --margin-weight "${MARGIN_WEIGHT:-0.001}"
  --advantage-mode "${ADVANTAGE_MODE:-batch}"
  --policy-loss-reduction "${POLICY_LOSS_REDUCTION:-episode-mean}"
  --ppo
  --ppo-epochs "${PPO_EPOCHS:-4}"
  --ppo-minibatch-size "${PPO_MINIBATCH_SIZE:-128}"
  --ppo-clip "${PPO_CLIP:-0.2}"
  --value-loss-weight "${VALUE_LOSS_WEIGHT:-0.5}"
  --entropy-weight "${ENTROPY_WEIGHT:-0.01}"
  --eval-interval "${EVAL_INTERVAL:-2048}"
  --eval-games-per-seat "${EVAL_GAMES_PER_SEAT:-32}"
  --eval-seed "${EVAL_SEED:-76400000}"
  --eval-bootstrap-samples "${EVAL_BOOTSTRAP_SAMPLES:-500}"
  --eval-baseline "$BASELINE"
  --eval-include-heuristic
  --select-best-eval-checkpoint
  --round-curriculum
  --curriculum-schedule constant
  --curriculum-rounds 2
  --round-plot-cards "${ROUND_PLOT_CARDS:-6}"
  --round-famine-rate "${ROUND_FAMINE_RATE:-0.2}"
)

if [[ -n "$START_MODEL" && "$START_MODEL" != "scratch" ]]; then
  train_cmd=( "${train_cmd[@]:0:4}" --start-model "$START_MODEL" "${train_cmd[@]:4}" )
  train_cmd+=(
    --reference-model "$START_MODEL"
    --reference-kl-weight "${REFERENCE_KL_WEIGHT:-0.005}"
  )
fi

benchmark_cmd=(
  "$PYTHON_BIN" -m research.kolkhoz_research.cli torch-benchmark
  --candidate "$OUTPUT"
  --baseline "$BASELINE"
  --games-per-seat "${BENCHMARK_GAMES_PER_SEAT:-64}"
  --seed "${BENCHMARK_SEED:-76500000}"
  --bootstrap-samples "${BENCHMARK_BOOTSTRAP_SAMPLES:-1000}"
  --rollout-envs "${BENCHMARK_ROLLOUT_ENVS:-32}"
  --round-curriculum
  --round-plot-cards "${ROUND_PLOT_CARDS:-6}"
  --round-famine-rate "${ROUND_FAMINE_RATE:-0.2}"
  --promotion-min-games-per-seat "${PROMOTION_MIN_GAMES_PER_SEAT:-64}"
  --promotion-min-bootstrap-samples "${PROMOTION_MIN_BOOTSTRAP_SAMPLES:-1000}"
  --promotion-objective "${PROMOTION_OBJECTIVE:-utility}"
  --promotion-utility-win-weight "${PROMOTION_UTILITY_WIN_WEIGHT:-1.0}"
  --promotion-utility-rank-weight "${PROMOTION_UTILITY_RANK_WEIGHT:-0.05}"
  --promotion-utility-margin-weight "${PROMOTION_UTILITY_MARGIN_WEIGHT:-0.001}"
  --min-utility-delta "${MIN_UTILITY_DELTA:-0.0}"
  --candidate-pool-min-utility-delta "${CANDIDATE_POOL_MIN_UTILITY_DELTA:-0.0}"
)
if [[ -n "${RISK_MIN_WIN_DELTA_MEAN:-}" ]]; then
  benchmark_cmd+=(--risk-min-win-delta-mean "$RISK_MIN_WIN_DELTA_MEAN")
fi
if [[ -n "${RISK_MIN_RANK_DELTA_MEAN:-}" ]]; then
  benchmark_cmd+=(--risk-min-rank-delta-mean "$RISK_MIN_RANK_DELTA_MEAN")
fi
if [[ -n "${RISK_MIN_MARGIN_DELTA_MEAN:-}" ]]; then
  benchmark_cmd+=(--risk-min-margin-delta-mean "$RISK_MIN_MARGIN_DELTA_MEAN")
fi

if [[ "$FORCE_CPU" == "1" ]]; then
  train_cmd+=(--cpu)
  benchmark_cmd+=(--cpu)
fi

if [[ "${RECORD:-1}" == "1" ]]; then
  train_cmd+=(--record)
  benchmark_cmd+=(--record)
fi

{
  printf 'RUN_ID=%s\n' "$RUN_ID"
  printf 'RUN_DIR=%s\n' "$RUN_DIR"
  printf 'BASELINE=%s\n' "$BASELINE"
  printf 'START_MODEL=%s\n' "$START_MODEL"
  printf 'OUTPUT=%s\n' "$OUTPUT"
  printf 'BENCHMARK_OUTPUT=%s\n' "$BENCHMARK_OUTPUT"
  printf 'FORCE_CPU=%s\n' "$FORCE_CPU"
  printf 'TRAIN_CMD='
  printf '%q ' "${train_cmd[@]}"
  printf '\nBENCHMARK_CMD='
  printf '%q ' "${benchmark_cmd[@]}"
  printf '\n'
} | tee "$RUN_DIR/launch.txt"

"${train_cmd[@]}"
"${benchmark_cmd[@]}" | tee "$BENCHMARK_OUTPUT"
