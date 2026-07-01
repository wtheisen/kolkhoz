# Kolkhoz RL Policy

The active training path is the Swift `KolkhozPolicyGradientTrainer` executable using
the C-compatible headless engine. The old Python surrogate, black-box evolver, Swift
evolution trainer, and selector tools have been removed because they were slower or no
longer matched the promotion gate.

The bundled policy remains:

```text
ios/KolkhozSwiftUI/Sources/KolkhozCore/Resources/kolkhoz_policy.json
```

Do not replace it unless a candidate beats that bundled policy on fresh paired
rotated-seat real-engine validation.

## Train

```bash
cd ios/KolkhozSwiftUI
swift run -c release KolkhozPolicyGradientTrainer \
  --engine c-direct \
  --scratch --layers 128,128 --scratch-scale 0.05 --shared-heads \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-mode heuristic \
  --optimizer adam \
  --episodes 2048 --batch-size 256 \
  --checkpoint-every 512 \
  --validation-baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --validation-seeds 9810000,9811000,9812000,9813000 \
  --validation-games-per-seat 8 \
  --output ../../training/rl/runs/policy_candidate.json
```

Useful controls:

- `--behavior-clone-steps N --behavior-clone-only` for v5 scratch behavior cloning.
- `--imitation-weight` and `--imitation-head-weights` to keep specific heads near a teacher policy.
- `--opponent-mode heuristic` to train in the same opponent distribution used by the bundled-policy comparison.
- `--round-curriculum` only for explicitly round-scoped probes; full-game validation is still required.

## Diagnose

```bash
cd ios/KolkhozSwiftUI
swift run -c release KolkhozPolicyDiagnostics \
  --candidate ../../training/rl/runs/policy_candidate.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 32 \
  --seed 9840000 \
  --driver baseline
```

Use diagnostics before long runs. Recent failures were concentrated in swap behavior:
new v5 models over-passed swaps compared with the bundled hybrid model.

## Benchmark

The promotion gate is `KolkhozPolicyBenchmark`, not trainer validation output.

```bash
cd ios/KolkhozSwiftUI
swift run -c release KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_candidate.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 300 \
  --seed 13500000 \
  --bootstrap-samples 2000 \
  --min-win-delta 0.02 \
  --min-rank-delta 0.0 \
  --min-margin-delta 0.0
```

Passing requires positive aggregate lower bounds and no unacceptable per-seat regression.
Keep failed candidates out of source control.
