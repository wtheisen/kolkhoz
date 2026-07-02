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
- recording engine source/header hashes for provenance.

The C API still needs explicit research endpoints before this can fully replace the old
Swift trainer:

- load/save policy model artifacts without Swift;
- run candidate-vs-baseline paired rotated-seat benchmarks;
- run model-pool tournaments;
- mine seed panels;
- train policy-gradient candidates from model/config artifacts;
- emit structured benchmark/training records with engine/model/schema provenance.

## Quick Smoke

```bash
python3 -m research.kolkhoz_research.cli engine-smoke --games 8
```

The command compiles `ios/KolkhozSwiftUI/Sources/KolkhozCEngine/KolkhozCEngine.c` into a
local ignored shared library under `research/.build/`, loads it with `ctypes`, and runs
deterministic C-engine games.

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
