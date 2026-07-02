# Kolkhoz Research Harness

This directory is the new home for training, benchmarking, promotion, and AutoML
orchestration. It is intentionally separate from the playable app.

The app should depend on the C game engine and the smallest runtime policy inference
surface it needs. Research code can depend on heavier training, tournament, seed mining,
and experiment-history tools, but those should not be bundled into iOS or Flutter apps.

## Current Boundary

The harness talks to the C engine directly. It does not import Swift package targets and
does not shell out to Swift policy tools.

Today the C API is sufficient for:

- building/loading the C engine as a local shared library;
- running deterministic C-engine smoke games;
- recording engine source/header hashes for provenance;
- loading and saving C MLP policy artifacts;
- running paired candidate-vs-baseline rotated-seat benchmarks;
- running model-pool tournaments;
- mining hard seed panels;
- training C-backed MLP policies with the engine's policy-gradient trainer.

The remaining research gap is no longer "call Swift tooling". The bigger gap is model
backend breadth. The C MLP backend is useful for continuity with the archived Swift-era
experiments, but deeper or less regular architectures should live in a Torch backend
where MPS can accelerate batched policy/value updates. The intended boundary is:

- C engine: rules, legal actions, deterministic simulation, final game adjudication.
- Python harness: experiment orchestration, durable records, promotion gates, tournaments,
  seed mining, and backend selection.
- Model backend: `c-mlp` today; future `torch-mps` policy/value models without changing the
  app runtime or promotion logic.

The Torch/MPS path can already import the current C MLP policy exactly, drive batches of
C-engine games through shared legal-action features, run short policy-gradient updates on
MPS, export MLP results back to the C-compatible artifact schema, and save Torch-native
`.pt` checkpoints for architectures that the app runtime cannot load directly.

## Quick Smoke

```bash
python3 -m research.kolkhoz_research.cli engine-smoke --games 8
```

The command compiles `ios/KolkhozSwiftUI/Sources/KolkhozCEngine/KolkhozCEngine.c` into a
local ignored shared library under `research/.build/`, loads it with `ctypes`, and runs
deterministic C-engine games.

## Core Commands

Train a small C-backed policy:

```bash
python3 -m research.kolkhoz_research.cli train \
  --output research/runs/smoke/candidate.json \
  --layers 128,128 \
  --round-curriculum \
  --episodes 512 \
  --batch-size 128 \
  --thread-count 4 \
  --record
```

Benchmark an existing candidate against a policy artifact or the heuristic baseline:

```bash
python3 -m research.kolkhoz_research.cli benchmark \
  --candidate research/runs/smoke/candidate.json \
  --baseline training/rl/runs/beat_promoted_wide_seat_heads_v1/20260702T144243Z/candidate.json \
  --games-per-seat 120 \
  --seed 13500000 \
  --min-win-delta 0.0 \
  --min-rank-delta 0.0 \
  --min-margin-delta 0.0 \
  --record
```

Run a model-pool tournament:

```bash
python3 -m research.kolkhoz_research.cli tournament \
  --models research/runs/a/candidate.json research/runs/b/candidate.json \
  --baseline research/runs/current_baseline.json
```

Mine hard seed panels:

```bash
python3 -m research.kolkhoz_research.cli mine-seeds \
  --candidate research/runs/smoke/candidate.json \
  --baseline research/runs/current_baseline.json \
  --seed-count 32 \
  --games-per-seed 4
```

Check Torch/MPS parity for an existing C MLP artifact:

```bash
python3 -m research.kolkhoz_research.cli torch-parity \
  --model training/rl/runs/beat_promoted_wide_seat_heads_v1/20260702T144243Z/candidate.json \
  --games-per-seat 4 \
  --rollout-envs 64
```

Run a small batched Torch/MPS update and export a C-compatible artifact:

```bash
python3 -m research.kolkhoz_research.cli torch-train \
  --start-model training/rl/runs/beat_promoted_wide_seat_heads_v1/20260702T144243Z/candidate.json \
  --output research/runs/torch_mps_repro/candidate.json \
  --episodes 64 \
  --batch-size 8 \
  --rollout-envs 64 \
  --learning-rate 0.0001
```

Use `--unbatched` only for debugging or timing comparisons against the old one-game path.
Only plain `mlp` policies started from a C JSON artifact can be exported back to JSON.
Scratch models and residual models should be written as `.pt` checkpoints and evaluated
with `torch-benchmark`.

Train a deeper Torch-native residual policy from scratch:

```bash
python3 -m research.kolkhoz_research.cli torch-train \
  --architecture residual-mlp \
  --layers 512,512,512,512 \
  --output research/runs/residual_mlp_4x512/candidate.pt \
  --episodes 256 \
  --batch-size 16 \
  --rollout-envs 64 \
  --learning-rate 0.0001
```

Train an action-conditioned transformer policy from scratch:

```bash
python3 -m research.kolkhoz_research.cli torch-train \
  --architecture action-transformer \
  --layers 256,4,4,1024 \
  --output research/runs/action_transformer_256x4/candidate.pt \
  --episodes 512 \
  --batch-size 16 \
  --rollout-envs 64 \
  --learning-rate 0.0001
```

For `action-transformer`, `--layers` means `width,depth,attention_heads,feedforward`.
This architecture scores the legal action candidates jointly for each decision, so it must
be saved as a Torch `.pt` checkpoint and evaluated with `torch-benchmark`.

Benchmark a Torch `.pt` candidate against the promoted C baseline with paired seeds:

```bash
python3 -m research.kolkhoz_research.cli torch-benchmark \
  --candidate research/runs/residual_mlp_4x512/candidate.pt \
  --baseline training/rl/runs/beat_promoted_wide_seat_heads_v1/20260702T144243Z/candidate.json \
  --games-per-seat 32 \
  --rollout-envs 64 \
  --seed 43000000 \
  --record
```

Serve the local experiment dashboard:

```bash
python3 -m research.kolkhoz_research.cli dashboard --port 8765
```

The dashboard reads durable records from `research/history/experiments.jsonl` and live
run state from the ignored `research/history/current_experiment.json` file written by
training and benchmark commands.

All commands emit structured JSON. Add `--record` to append the record to
`research/history/experiments.jsonl`.

## Directory Contract

```text
research/
  kolkhoz_research/      Python orchestration and C bindings
  configs/               Experiment configs, once C training API exists
  history/               Durable experiment records
  runs/                  Ignored generated logs/artifacts
```

Generated candidate models and benchmark logs belong in `research/runs/`, not in app
source directories.
