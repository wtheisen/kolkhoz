#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

BASELINE="${BASELINE:-training/rl/runs/beat_promoted_wide_seat_heads_v1/20260702T144243Z/candidate.json}"
START_MODEL="${START_MODEL:-}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
RUN_DIR="${RUN_DIR:-research/runs/supervised_warmstart_then_round_delta_ppo_v1/${RUN_ID}}"
TRAJECTORIES="${TRAJECTORIES:-$RUN_DIR/trajectories.jsonl}"
SUPERVISED="${SUPERVISED:-$RUN_DIR/supervised.pt}"
OUTPUT="${OUTPUT:-$RUN_DIR/candidate.pt}"
PPO_START_MODEL="${PPO_START_MODEL:-$SUPERVISED}"
PPO_REFERENCE_MODEL="${PPO_REFERENCE_MODEL:-$SUPERVISED}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

mkdir -p "$RUN_DIR"

CPU_ARGS=()
if [[ "${FORCE_CPU:-1}" != "0" ]]; then
  CPU_ARGS=(--cpu)
fi

DETERMINIZE_ARGS=()
if [[ "${DETERMINIZE_SEARCH:-1}" == "0" ]]; then
  DETERMINIZE_ARGS=(--no-determinize-search)
fi

PROMOTION_ARGS=(
  --promotion-objective "${PROMOTION_OBJECTIVE:-utility}"
  --promotion-utility-win-weight "${PROMOTION_UTILITY_WIN_WEIGHT:-1.0}"
  --promotion-utility-rank-weight "${PROMOTION_UTILITY_RANK_WEIGHT:-0.05}"
  --promotion-utility-margin-weight "${PROMOTION_UTILITY_MARGIN_WEIGHT:-0.001}"
  --min-utility-delta "${MIN_UTILITY_DELTA:-0.0}"
  --candidate-pool-min-utility-delta "${CANDIDATE_POOL_MIN_UTILITY_DELTA:-0.0}"
)
if [[ -n "${RISK_MIN_WIN_DELTA_MEAN:-}" ]]; then
  PROMOTION_ARGS+=(--risk-min-win-delta-mean "$RISK_MIN_WIN_DELTA_MEAN")
fi
if [[ -n "${RISK_MIN_RANK_DELTA_MEAN:-}" ]]; then
  PROMOTION_ARGS+=(--risk-min-rank-delta-mean "$RISK_MIN_RANK_DELTA_MEAN")
fi
if [[ -n "${RISK_MIN_MARGIN_DELTA_MEAN:-}" ]]; then
  PROMOTION_ARGS+=(--risk-min-margin-delta-mean "$RISK_MIN_MARGIN_DELTA_MEAN")
fi

GEN_CMD=(
  "$PYTHON_BIN" -m research.kolkhoz_research.cli supervised-generate
  --output "$TRAJECTORIES"
  --games "${GAMES:-256}"
  --seed "${DATA_SEED:-61200000}"
  --input-size 200
  --seats "${SEATS:-0,1,2,3}"
  --max-search-actions "${MAX_SEARCH_ACTIONS:-8}"
  --rollout-action-limit "${ROLLOUT_ACTION_LIMIT:-512}"
  --rollout-model "$BASELINE"
  --rollouts-per-action "${ROLLOUTS_PER_ACTION:-1}"
  --search-horizon "${SEARCH_HORIZON:-full-game}"
  --search-target "${SEARCH_TARGET:-paired-baseline}"
  --search-temperature "${SEARCH_TEMPERATURE:-0.25}"
  --min-search-q-margin "${MIN_SEARCH_Q_MARGIN:-0.0}"
  --min-search-q-std "${MIN_SEARCH_Q_STD:-0.0}"
  --win-weight "${WIN_WEIGHT:-1.0}"
  --rank-weight "${RANK_WEIGHT:-0.05}"
  --margin-weight "${MARGIN_WEIGHT:-0.001}"
  --record
  ${CPU_ARGS[@]+"${CPU_ARGS[@]}"}
  ${DETERMINIZE_ARGS[@]+"${DETERMINIZE_ARGS[@]}"}
)

if [[ "${ROLLOUT_SAMPLE:-0}" != "0" ]]; then
  GEN_CMD+=(--rollout-sample --rollout-temperature "${ROLLOUT_TEMPERATURE:-0.8}")
fi
if [[ "${SKIP_FORCED_TARGETS:-0}" != "0" ]]; then
  GEN_CMD+=(--skip-forced-targets)
fi

PRETRAIN_CMD=(
  "$PYTHON_BIN" -m research.kolkhoz_research.cli supervised-pretrain
  --trajectory "$TRAJECTORIES"
  --output "$SUPERVISED"
  --architecture action-transformer
  --layers "${LAYERS:-256,4,4,1024}"
  --scratch-seed "${SCRATCH_SEED:-6121}"
  --epochs "${PRETRAIN_EPOCHS:-8}"
  --batch-size "${PRETRAIN_BATCH_SIZE:-64}"
  --learning-rate "${PRETRAIN_LEARNING_RATE:-0.0003}"
  --value-loss-weight "${PRETRAIN_VALUE_LOSS_WEIGHT:-0.1}"
  --target-temperature "${TARGET_TEMPERATURE:-0.25}"
  --min-policy-q-margin "${PRETRAIN_MIN_POLICY_Q_MARGIN:-0.0}"
  --policy-confidence-scale "${PRETRAIN_POLICY_CONFIDENCE_SCALE:-0.05}"
  --min-policy-weight "${PRETRAIN_MIN_POLICY_WEIGHT:-0.0}"
  --q-value-loss-weight "${PRETRAIN_Q_VALUE_LOSS_WEIGHT:-0.0}"
  --transformer-dropout "${TRANSFORMER_DROPOUT:-0.05}"
  --record
  ${CPU_ARGS[@]+"${CPU_ARGS[@]}"}
)

if [[ -n "$START_MODEL" ]]; then
  PRETRAIN_CMD+=(--start-model "$START_MODEL")
fi
if [[ -n "${PRETRAIN_PHASE_SAMPLE_WEIGHTS:-}" ]]; then
  PRETRAIN_CMD+=(--phase-sample-weights "$PRETRAIN_PHASE_SAMPLE_WEIGHTS")
fi

PPO_CMD=(
  "$PYTHON_BIN" -m research.kolkhoz_research.cli torch-train
  --start-model "$PPO_START_MODEL"
  --output "$OUTPUT"
  --episodes "${EPISODES:-8192}"
  --batch-size "${BATCH_SIZE:-16}"
  --rollout-envs "${ROLLOUT_ENVS:-16}"
  --seed "${PPO_SEED:-61300000}"
  --learning-rate "${LEARNING_RATE:-0.00001}"
  --temperature "${TEMPERATURE:-0.6}"
  --opponent-mode model-pool
  --opponent-schedule constant
  --opponent-model "$BASELINE"
  --reward-mode paired-baseline-round-delta
  --reward-baseline "$BASELINE"
  --win-weight "${WIN_WEIGHT:-1.0}"
  --rank-weight "${RANK_WEIGHT:-0.05}"
  --margin-weight "${MARGIN_WEIGHT:-0.001}"
  --round-rank-weight "${ROUND_RANK_WEIGHT:-0.10}"
  --round-margin-weight "${ROUND_MARGIN_WEIGHT:-0.002}"
  --two-round-rank-weight "${TWO_ROUND_RANK_WEIGHT:-0.15}"
  --two-round-margin-weight "${TWO_ROUND_MARGIN_WEIGHT:-0.003}"
  --advantage-mode batch
  --policy-loss-reduction episode-mean
  --ppo
  --ppo-epochs "${PPO_EPOCHS:-4}"
  --ppo-minibatch-size "${PPO_MINIBATCH_SIZE:-128}"
  --ppo-clip "${PPO_CLIP:-0.2}"
  --value-loss-weight "${VALUE_LOSS_WEIGHT:-0.25}"
  --entropy-weight "${ENTROPY_WEIGHT:-0.002}"
  --reference-model "$PPO_REFERENCE_MODEL"
  --reference-kl-weight "${REFERENCE_KL_WEIGHT:-0.01}"
  --transformer-dropout 0.0
  --eval-interval "${EVAL_INTERVAL:-1024}"
  --eval-games-per-seat "${EVAL_GAMES_PER_SEAT:-256}"
  --eval-seed "${EVAL_SEED:-52800000}"
  --eval-bootstrap-samples "${EVAL_BOOTSTRAP_SAMPLES:-1000}"
  --eval-baseline "$BASELINE"
  --eval-include-heuristic
  --select-best-eval-checkpoint
  --eval-patience "${EVAL_PATIENCE:-0}"
  --serious-run
  --record
  ${CPU_ARGS[@]+"${CPU_ARGS[@]}"}
)

HOLDOUT_OUTPUT="${HOLDOUT_OUTPUT:-$RUN_DIR/holdout_benchmark.json}"
HOLDOUT_CMD=(
  "$PYTHON_BIN" -m research.kolkhoz_research.cli torch-benchmark
  --candidate "$OUTPUT"
  --baseline "$BASELINE"
  --games-per-seat "${HOLDOUT_GAMES_PER_SEAT:-256}"
  --seed "${HOLDOUT_SEED:-93100000}"
  --bootstrap-samples "${HOLDOUT_BOOTSTRAP_SAMPLES:-1000}"
  --rollout-envs "${HOLDOUT_ROLLOUT_ENVS:-64}"
  "${PROMOTION_ARGS[@]}"
  --record
  ${CPU_ARGS[@]+"${CPU_ARGS[@]}"}
)

{
  echo "RUN_ID=$RUN_ID"
  echo "RUN_DIR=$RUN_DIR"
  echo "BASELINE=$BASELINE"
  echo "DETERMINIZE_SEARCH=${DETERMINIZE_SEARCH:-1}"
  echo "START_MODEL=${START_MODEL:-scratch}"
  echo "TRAJECTORIES=$TRAJECTORIES"
  echo "SUPERVISED=$SUPERVISED"
  echo "OUTPUT=$OUTPUT"
  echo "PPO_START_MODEL=$PPO_START_MODEL"
  echo "PPO_REFERENCE_MODEL=$PPO_REFERENCE_MODEL"
  echo "MIN_SEARCH_Q_MARGIN=${MIN_SEARCH_Q_MARGIN:-0.0}"
  echo "MIN_SEARCH_Q_STD=${MIN_SEARCH_Q_STD:-0.0}"
  echo "SKIP_FORCED_TARGETS=${SKIP_FORCED_TARGETS:-0}"
  echo "PRETRAIN_PHASE_SAMPLE_WEIGHTS=${PRETRAIN_PHASE_SAMPLE_WEIGHTS:-}"
  echo "EVAL_PATIENCE=${EVAL_PATIENCE:-0}"
  echo "PROMOTION_OBJECTIVE=${PROMOTION_OBJECTIVE:-utility}"
  echo "RUN_HOLDOUT=${RUN_HOLDOUT:-1}"
  echo "HOLDOUT_OUTPUT=$HOLDOUT_OUTPUT"
  echo "SKIP_GENERATE=${SKIP_GENERATE:-0}"
  echo "SKIP_PRETRAIN=${SKIP_PRETRAIN:-0}"
  printf '%q ' "${GEN_CMD[@]}"
  printf '\n'
  printf '%q ' "${PRETRAIN_CMD[@]}"
  printf '\n'
  printf '%q ' "${PPO_CMD[@]}"
  printf '\n'
  printf '%q ' "${HOLDOUT_CMD[@]}"
  printf '\n'
} | tee "$RUN_DIR/launch.txt"

if [[ "${SKIP_GENERATE:-0}" != "0" ]]; then
  if [[ ! -s "$TRAJECTORIES" ]]; then
    echo "SKIP_GENERATE requested but trajectories file is missing: $TRAJECTORIES" >&2
    exit 2
  fi
  echo "Skipping supervised-generate; using $TRAJECTORIES"
else
  "${GEN_CMD[@]}"
fi

if [[ "${SKIP_PRETRAIN:-0}" != "0" ]]; then
  if [[ ! -s "$SUPERVISED" ]]; then
    echo "SKIP_PRETRAIN requested but supervised checkpoint is missing: $SUPERVISED" >&2
    exit 2
  fi
  echo "Skipping supervised-pretrain; using $SUPERVISED"
else
  "${PRETRAIN_CMD[@]}"
fi

"${PPO_CMD[@]}"

if [[ "${RUN_HOLDOUT:-1}" != "0" ]]; then
  "${HOLDOUT_CMD[@]}" | tee "$HOLDOUT_OUTPUT"
fi
