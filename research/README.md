# Kolkhoz Research Harness

This directory owns current model training, benchmarking, promotion decisions, run
history, and the research dashboard. The retired Swift policy tools and native Apple app
research paths are gone; do not add compatibility wrappers for them.

The current boundary is:

- C engine: rules, legal actions, phase flow, deterministic simulation, policy features,
  and final game adjudication.
- Python research harness: experiment orchestration, durable records, model cleanup,
  paired benchmarks, promotion decisions, seed pools, and dashboards.
- Torch backend: current training and evaluation for `.pt` policies and C-compatible MLP
  JSON artifacts.

Historical model artifacts under `training/rl/runs/` are kept only as model inputs or
benchmarks. Old epoch snapshots are disposable; keep final `candidate.json`,
`candidate_best.json`, and explicitly referenced promoted baselines. Do not add new
training code or new experiment launchers under `training/`; use `research/`.

## Smoke

```bash
python3 -m research.kolkhoz_research.cli engine-smoke --games 8
```

## Active Training Path

The lead path is the two-round Torch MLP self-play seed pool:

```bash
RUN_SCRIPT=research/scripts/run_torch_mlp_self_play_seed_pool_v2.sh \
EXPERIMENT=torch_mlp_self_play_seed_pool_v2 \
research/scripts/launch_supervised_warmstart_then_round_delta_ppo_v1.sh
```

This starts from the current strongest Torch MLP, trains multiple child seeds, ranks them
on a shared selection panel, then promotes finalists through a larger current-best panel
and arena checks.

The bootstrap path for producing or refreshing the current strongest MLP is:

```bash
RUN_SCRIPT=research/scripts/run_torch_mlp_vs_strongest_stage2_v1.sh \
EXPERIMENT=torch_mlp_vs_strongest_stage2_v1 \
research/scripts/launch_supervised_warmstart_then_round_delta_ppo_v1.sh
```

## Secondary Path

The action-transformer supervised warmstart plus paired round-delta PPO branch is still
available for follow-up experiments:

```bash
research/scripts/launch_supervised_warmstart_then_round_delta_ppo_v1.sh
```

This generates or reuses supervised search labels, pretrains an action transformer, then
PPO-finetunes against the promoted baseline and runs a fresh holdout benchmark.

## Expert Online Trajectories

Finished online games can be exported as hidden-information-safe supervised records once
all four seats are human, every player's pre-game display rating meets the threshold, and
the recorded engine build and source digest match the local engine exactly:

```bash
DATABASE_URL=postgresql://... \
python3 -m research.kolkhoz_research.cli export-online-trajectories \
  --output research/runs/expert_games/trajectories.jsonl \
  --min-player-rating 1600
```

The export replays every durable action through the C engine, rejects incompatible or
invalid histories, and omits account identifiers. Its JSONL output can be passed directly
to `supervised-pretrain`; human choices provide hard policy labels and final results
provide value targets.

## Benchmarks And Promotion

Run a paired benchmark:

```bash
python3 -m research.kolkhoz_research.cli torch-benchmark \
  --candidate research/runs/torch_mlp_vs_strongest_stage2_4x_v1/20260705T221143Z/candidate.pt \
  --baseline training/rl/runs/beat_promoted_wide_seat_heads_v1/20260702T144243Z/candidate.json \
  --round-curriculum \
  --games-per-seat 256 \
  --bootstrap-samples 1000 \
  --promotion-objective utility
```

Promotion uses paired same-seed, rotated-seat C-engine games. The current script defaults
use utility mode:

```text
utility = win_delta + 0.05 * rank_delta + 0.001 * margin_delta
```

Use optional mean-risk budgets when a run should reject models that trade away too much
win, rank, or margin despite positive utility.

## Cleanup

Check what the cleanup tool would remove:

```bash
python3 -m research.kolkhoz_research.cli cleanup-artifacts --include-files
```

Remove stale local training snapshots without deleting final candidates:

```bash
python3 -m research.kolkhoz_research.cli cleanup-artifacts --delete
```

For an aggressive local cleanup, while still respecting models referenced by history:

```bash
python3 -m research.kolkhoz_research.cli cleanup-artifacts \
  --keep-json-checkpoints 0 \
  --keep-torch-checkpoints 1 \
  --keep-latest-runs-per-experiment 0 \
  --delete
```

Do not manually wipe `research/runs/`, `training/rl/runs/`, or
`research/history/current_experiment.json` as generic repo cleanup. Those paths are
ignored, but they can contain active run state, recent benchmark outputs, or baseline
models referenced by configs and history.
