#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

export EXPERIMENT="${EXPERIMENT:-masked_state_rnn_ppo_v1}"
export RUN_SCRIPT="${RUN_SCRIPT:-research/scripts/run_masked_state_rnn_ppo_v1.sh}"
export LAUNCH_BACKEND="${LAUNCH_BACKEND:-launchd}"

exec research/scripts/launch_supervised_warmstart_then_round_delta_ppo_v1.sh
