# Kolkhoz RL Policy

The real training gate is the Swift `KolkhozRealTrainer` executable. It runs in-process
against `KolkhozEngine`, rotates the candidate policy through all four seats, and plays
heuristic opponents using the actual game rules.

The Python/PyTorch script is only a fast candidate generator. Its environment is a
simplified surrogate and its scores are not evidence of real game strength.

Train a quick model:

```bash
python3 training/rl/kolkhoz_rl.py train --episodes 1000
```

Train against the real Swift engine:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozRealTrainer \
  --start ../../training/rl/runs/policy_h48_lr004_e0005_s44_1k.json \
  --output ../../training/rl/runs/policy_real.json \
  --generations 8 --population 16 --games-per-seat 25 --sigma 0.003
```

Held-out real-engine evaluation without further training:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozRealTrainer \
  --start ../../training/rl/runs/policy_real.json \
  --output /tmp/policy_eval_copy.json \
  --generations 0 --games-per-seat 100 --seed 3200000
```

Paired promotion benchmark against the all-heuristic baseline:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_real.json \
  --games-per-seat 300 --seed 7100000 --min-win-delta 0.02
```

Only copy a model to `Sources/KolkhozCore/Resources/kolkhoz_policy.json` when
`promotion_gate=pass`. Current experiment notes are in `training/rl/EXPERIMENTS.md`.

Evaluate an exported model:

```bash
python3 training/rl/kolkhoz_rl.py eval --games 500
```

Evaluate against the actual Swift game engine:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyEval --model ../../training/rl/runs/policy.json --games 500
```

Do a small Python-driven black-box tuning pass using the actual Swift engine as the reward source:

```bash
python3 training/rl/real_engine_evolve.py \
  --start training/rl/runs/policy.json \
  --output training/rl/runs/policy.real-tuned.json \
  --generations 5 --population 4 --games 40
```

The Swift app falls back to the deterministic heuristic AI when `kolkhoz_policy.json` is
absent, malformed, or has a mismatched feature version.
