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

Train with a self-play league against prior accepted policies:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozSelfPlayTrainer \
  --start Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --output ../../training/rl/runs/policy_self_play.json \
  --history ../../training/rl/runs/policy_self_play_history.json \
  --generations 12 --population 16 --games-per-seat 12 \
  --opponents-per-candidate 3 --pool-size 5 --sigma 0.0025
```

For a longer unattended search, raise `--generations`, `--population`, and
`--games-per-seat`. The self-play score is only a candidate-generation signal; it is not
promotion evidence by itself because a policy can overfit the current league.

Train with real policy-gradient self-play:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyGradientTrainer \
  --start Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --output ../../training/rl/runs/policy_pg_self_play.json \
  --history ../../training/rl/runs/policy_pg_self_play_history.json \
  --episodes 2000 --batch-size 32 --learning-rate 0.04 \
  --temperature 0.9
```

Train one sampled policy seat against frozen bundled-policy opponents, rotating the
learning seat by episode:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyGradientTrainer \
  --start Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-mode heuristic \
  --output ../../training/rl/runs/policy_pg_vs_bundle.json \
  --history ../../training/rl/runs/policy_pg_vs_bundle_history.json \
  --checkpoint-every 256 \
  --episodes 1024 --batch-size 16 --optimizer adam --learning-rate 0.003 \
  --temperature 0.9 --paired-baseline \
  --expand-hidden 96 --expand-scale 0.006 \
  --win-weight 1.0 --strict-weight 0.4 --rank-weight 0.25 --margin-weight 0.05 \
  --score-delta-weight 0.015 --margin-delta-weight 0.01 \
  --seat-balanced-update --advantage-clip 2.0 \
  --training-seats 0,1,2,3
```

`KolkhozPolicyGradientTrainer` samples legal actions during full Swift-engine games,
records REINFORCE-style `grad log pi(action)` terms, scores final outcomes, and updates
the same JSON network format that the app loads. Frozen-opponent mode is useful when the
goal is specifically to beat the current bundled model instead of only improving a
symmetric self-play league. `--opponent-mode heuristic` trains the sampled policy seat
against the same non-model heuristic opponents used by the direct promotion benchmark;
omit it or pass `--opponent-mode model` to train against greedy copies of the opponent
model. `--paired-baseline` makes frozen-opponent training compare the sampled policy seat
against a same-seed greedy bundled-policy baseline before applying the gradient.
`--checkpoint-every N` writes intermediate models named from the output path so they can
be benchmarked before later updates drift. `--optimizer adam` enables an Adam update over
the same policy-gradient estimate; omit it or pass `--optimizer sgd` for the original
clipped SGD update. `--seat-balanced-update` averages frozen-opponent gradients by
training seat before applying an optimizer step, and `--advantage-clip` limits
paired-baseline reward outliers. `--training-seats` can restrict frozen-opponent training
to a subset of rotated seats for focused continuation runs. `--expand-hidden N` widens a
loaded policy while preserving the original hidden units, and `--expand-scale` controls
the small random initialization for the added units. `--score-delta-weight` and
`--margin-delta-weight` add dense score/margin shaping after sampled actions while keeping
the final paired-baseline reward in place. `--round-curriculum` trains on synthetic
single-year real-engine states instead of full games; pair it with `--round-plot-cards`
and `--round-famine-rate` to randomize existing plots and famine rounds before doing any
full-game fine-tuning or promotion benchmark. Sweep `--win-weight`, `--strict-weight`,
`--rank-weight`, and `--margin-weight` when testing reward functions; early runs should
prefer promotion-aligned rewards that improve strict top rate without creating a bad
seat-specific regression.

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
  --model ../../training/rl/runs/policy_self_play.json \
  --games-per-seat 300 --seed 7100000 --min-win-delta 0.02
```

Direct comparison against the currently bundled model:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_self_play.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 300 --seed 13500000 --min-win-delta 0
```

Compare several checkpoints against the bundled model across multiple held-out seed
families before spending time on a larger benchmark:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicySelector \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --seeds 14150000,14160000,14170000 \
  --games-per-seat 80 \
  --model ../../training/rl/runs/policy_pg_adam_seatbalanced_winrank_s14110000_e1024.json \
  --model ../../training/rl/runs/policy_pg_adam_focus_s12_s14130000_e256.json
```

`KolkhozPolicySelector` is still validation, not promotion. It is useful for filtering
noisy policy-gradient checkpoints, but the selected model must still clear a larger fresh
paired benchmark before replacing the bundled policy.

Both `KolkhozPolicyBenchmark` and `KolkhozPolicySelector` reuse each held-out seed across
all four rotated candidate seats. This keeps per-seat rows from being confounded by
different deal/lead/trump-selector seed blocks.

Only copy a model to `Sources/KolkhozCore/Resources/kolkhoz_policy.json` when
it clears both the heuristic promotion gate and a direct comparison against the current
bundled model. Current experiment notes are in `training/rl/EXPERIMENTS.md`.

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
