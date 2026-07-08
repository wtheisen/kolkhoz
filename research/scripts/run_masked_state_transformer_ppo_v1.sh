#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

RUN_DIR="${RUN_DIR:-research/runs/masked_state_transformer_ppo_v1/$(date -u +%Y%m%dT%H%M%SZ)}"
OUTPUT="${OUTPUT:-$RUN_DIR/candidate.pt}"
EPISODES="${EPISODES:-4096}"
BATCH_SIZE="${BATCH_SIZE:-16}"
HIDDEN_SIZE="${HIDDEN_SIZE:-128}"
LAYER_COUNT="${LAYER_COUNT:-2}"
HEAD_COUNT="${HEAD_COUNT:-4}"
CONTEXT_LENGTH="${CONTEXT_LENGTH:-8}"
DROPOUT="${DROPOUT:-0.0}"
PPO_EPOCHS="${PPO_EPOCHS:-2}"
PPO_MINIBATCH_SIZE="${PPO_MINIBATCH_SIZE:-512}"
PPO_CLIP="${PPO_CLIP:-0.2}"
VALUE_LOSS_WEIGHT="${VALUE_LOSS_WEIGHT:-0.5}"
ENTROPY_WEIGHT="${ENTROPY_WEIGHT:-0.01}"
LEARNING_RATE="${LEARNING_RATE:-0.0001}"
TEMPERATURE="${TEMPERATURE:-1.0}"
EVAL_INTERVAL="${EVAL_INTERVAL:-1024}"
EVAL_GAMES_PER_SEAT="${EVAL_GAMES_PER_SEAT:-16}"
EVAL_SEED="${EVAL_SEED:-93700000}"
SEED="${SEED:-92700000}"
FORCE_CPU="${FORCE_CPU:-1}"
RECORD="${RECORD:-1}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

mkdir -p "$RUN_DIR"

{
  printf 'RUN_DIR=%s\n' "$RUN_DIR"
  printf 'OUTPUT=%s\n' "$OUTPUT"
  printf 'ARCHITECTURE=masked-state-transformer\n'
  printf 'EPISODES=%s\n' "$EPISODES"
  printf 'BATCH_SIZE=%s\n' "$BATCH_SIZE"
  printf 'HIDDEN_SIZE=%s\n' "$HIDDEN_SIZE"
  printf 'LAYER_COUNT=%s\n' "$LAYER_COUNT"
  printf 'HEAD_COUNT=%s\n' "$HEAD_COUNT"
  printf 'CONTEXT_LENGTH=%s\n' "$CONTEXT_LENGTH"
  printf 'PPO_EPOCHS=%s\n' "$PPO_EPOCHS"
  printf 'PPO_MINIBATCH_SIZE=%s\n' "$PPO_MINIBATCH_SIZE"
  printf 'EVAL_INTERVAL=%s\n' "$EVAL_INTERVAL"
  printf 'EVAL_GAMES_PER_SEAT=%s\n' "$EVAL_GAMES_PER_SEAT"
  printf 'SEED=%s\n' "$SEED"
  printf 'EVAL_SEED=%s\n' "$EVAL_SEED"
} > "$RUN_DIR/launch.txt"

args=(
  -m research.kolkhoz_research.cli masked-state-transformer-train
  --output "$OUTPUT"
  --episodes "$EPISODES"
  --batch-size "$BATCH_SIZE"
  --hidden-size "$HIDDEN_SIZE"
  --layer-count "$LAYER_COUNT"
  --head-count "$HEAD_COUNT"
  --context-length "$CONTEXT_LENGTH"
  --dropout "$DROPOUT"
  --ppo-epochs "$PPO_EPOCHS"
  --ppo-minibatch-size "$PPO_MINIBATCH_SIZE"
  --ppo-clip "$PPO_CLIP"
  --value-loss-weight "$VALUE_LOSS_WEIGHT"
  --entropy-weight "$ENTROPY_WEIGHT"
  --learning-rate "$LEARNING_RATE"
  --temperature "$TEMPERATURE"
  --eval-interval "$EVAL_INTERVAL"
  --eval-games-per-seat "$EVAL_GAMES_PER_SEAT"
  --eval-seed "$EVAL_SEED"
  --seed "$SEED"
)

if [[ "$FORCE_CPU" == "1" ]]; then
  args+=(--cpu)
fi

if [[ "$RECORD" == "1" ]]; then
  args+=(--record)
fi

"$PYTHON_BIN" "${args[@]}"
