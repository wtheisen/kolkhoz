# Kolkhoz Real-Engine AI Experiments

Promotion gate: use `KolkhozPolicyBenchmark` against the real Swift `KolkhozEngine`.
The candidate must beat the all-heuristic baseline on paired rotated-seat games with:

- win-rate delta 95% CI lower bound >= `0.02`
- rank delta 95% CI lower bound > `0`
- margin delta 95% CI lower bound > `0`

Positive rank delta means the candidate's rank is lower/better than the same seat in an
all-heuristic game on the same seed.

## Architectures

Benchmarked on `seed=4100000`, `games_per_seat=100`, `samples=400`.

| Model | Hidden Size | Candidate Win | Heuristic Win | Win Delta 95% CI | Rank Delta 95% CI | Margin Delta 95% CI | Gate |
|---|---:|---:|---:|---|---|---|---|
| `policy_h48_lr004_e0005_s44_1k.json` | 48 | 0.6350 | 0.2950 | 0.3400 [0.2742, 0.4058] | 0.7775 [0.6310, 0.9240] | 13.9500 [12.0460, 15.8540] | pass |
| `policy_h48_lr004_e0005_s33.json` | 48 | 0.6075 | 0.2950 | 0.3125 [0.2467, 0.3783] | 0.7250 [0.5815, 0.8685] | 13.7225 [11.7414, 15.7036] | pass |
| `policy_h64_lr003_e0005_s55_1k.json` | 64 | 0.5725 | 0.2950 | 0.2775 [0.2131, 0.3419] | 0.7025 [0.5622, 0.8428] | 12.3275 [10.4046, 14.2504] | pass |
| `policy_h96_lr002_e002_s22.json` | 96 | 0.5775 | 0.2950 | 0.2825 [0.2176, 0.3474] | 0.6500 [0.5049, 0.7951] | 11.0675 [9.1611, 12.9739] | pass |

The 48-hidden model trained with seed 44 had the best architecture benchmark.

## Reward / Hyperparameter Sweeps

All sweeps started from `policy_h48_lr004_e0005_s44_1k.json` and used real engine
training through `KolkhozRealTrainer`.

| Sweep | Reward Weights | Hyperparameters | Result |
|---|---|---|---|
| `policy_sweep_winheavy_g4_p8_s002.json` | win=140, rank=4, margin=0.4 | generations=4, population=8, games_per_seat=12, sigma=0.002 | Kept parent; benchmark matched promoted h48 model |
| `policy_sweep_rankheavy_g4_p8_s003.json` | win=80, rank=16, margin=0.5 | generations=4, population=8, games_per_seat=12, sigma=0.003 | Accepted small mutations, but larger held-out benchmark was slightly worse on win/rank |
| `policy_sweep_marginheavy_g4_p8_s004.json` | win=70, rank=6, margin=2 | generations=4, population=8, games_per_seat=12, sigma=0.004 | Accepted one mutation, but did not beat promoted h48 benchmark |

Larger held-out benchmark on `seed=7100000`, `games_per_seat=300`, `samples=1200`:

| Model | Candidate Win | Heuristic Win | Win Delta 95% CI | Rank Delta 95% CI | Margin Delta 95% CI | Gate |
|---|---:|---:|---|---|---|---|
| `policy_h48_lr004_e0005_s44_1k.json` | 0.6225 | 0.2817 | 0.3408 [0.3034, 0.3783] | 0.7075 [0.6209, 0.7941] | 12.8817 [11.6857, 14.0776] | pass |
| `policy_sweep_rankheavy_g4_p8_s003.json` | 0.6175 | 0.2817 | 0.3358 [0.2984, 0.3732] | 0.6983 [0.6116, 0.7851] | 12.8908 [11.6915, 14.0901] | pass |

## Promoted Model

Promoted `policy_h48_lr004_e0005_s44_1k.json` to:

```text
ios/KolkhozSwiftUI/Sources/KolkhozCore/Resources/kolkhoz_policy.json
```

This is the default bundled model loaded by `KolkhozEngine`. If the file is absent or
incompatible, the engine falls back to the deterministic heuristic.

## Skepticism / Controls

Additional controls run after promotion:

| Model | Seed | Samples | Candidate Win | Heuristic Win | Win Delta 95% CI | Rank Delta 95% CI | Margin Delta 95% CI | Gate |
|---|---:|---:|---:|---:|---|---|---|---|
| promoted bundled model | 9100000 | 800 | 0.6025 | 0.2612 | 0.3412 [0.2953, 0.3872] | 0.7250 [0.6188, 0.8312] | 12.9800 [11.4662, 14.4938] | pass |
| promoted bundled model | 10100000 | 800 | 0.5900 | 0.2400 | 0.3500 [0.3039, 0.3961] | 0.8287 [0.7242, 0.9333] | 13.9450 [12.4475, 15.4425] | pass |
| random compatible model | 9100000 | 800 | 0.2712 | 0.2612 | 0.0100 [-0.0341, 0.0541] | -0.0300 [-0.1419, 0.0819] | -0.5825 [-1.7013, 0.5363] | fail |

These controls check that the promotion benchmark does not automatically pass arbitrary
compatible models.

## Rigorous Full-Game Benchmarks

`KolkhozPolicyBenchmark` now reports aggregate and per-seat results, top-or-tied wins,
strict wins, average rank, average margin, and 95% confidence intervals. Each sample is
a paired full-game comparison: candidate model in one rotated seat against three
heuristic opponents, plus an all-heuristic baseline for that same seat and seed.

| Model | Seed | Samples | Full Games | Candidate Top | Heuristic Top | Candidate Strict | Heuristic Strict | Top Delta 95% CI | Strict Delta 95% CI | Rank Delta 95% CI | Margin Delta 95% CI | Gate |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|---|
| promoted bundled model | 11100000 | 4000 | 8000 | 0.6200 | 0.2742 | 0.6002 | 0.2492 | 0.3458 [0.3254, 0.3661] | 0.3510 [0.3309, 0.3711] | 0.7298 [0.6821, 0.7774] | 13.7673 [13.1025, 14.4320] | pass |
| random compatible model | 11100000 | 4000 | 8000 | 0.2482 | 0.2742 | 0.2233 | 0.2492 | -0.0260 [-0.0449, -0.0071] | -0.0260 [-0.0443, -0.0077] | -0.1040 [-0.1522, -0.0558] | -0.8167 [-1.3105, -0.3230] | fail |
| promoted bundled model | 12100000 | 4000 | 8000 | 0.6188 | 0.2705 | 0.6000 | 0.2412 | 0.3483 [0.3281, 0.3684] | 0.3588 [0.3387, 0.3788] | 0.7430 [0.6957, 0.7903] | 13.7643 [13.1161, 14.4124] | pass |

Per-seat checks on both promoted-model runs stayed positive on every metric. Seat 3 was
the weakest seat, but still cleared the lower confidence bound comfortably:

| Seed | Seat | Candidate Top | Heuristic Top | Candidate Strict | Heuristic Strict | Top Delta 95% CI | Strict Delta 95% CI | Rank Delta 95% CI | Margin Delta 95% CI |
|---:|---:|---:|---:|---:|---:|---|---|---|---|
| 11100000 | 3 | 0.5060 | 0.2750 | 0.4840 | 0.2520 | 0.2310 [0.1897, 0.2723] | 0.2320 [0.1913, 0.2727] | 0.4440 [0.3448, 0.5432] | 7.8830 [6.6669, 9.0991] |
| 12100000 | 3 | 0.5090 | 0.2780 | 0.4880 | 0.2460 | 0.2310 [0.1894, 0.2726] | 0.2420 [0.2009, 0.2831] | 0.4750 [0.3774, 0.5726] | 8.0850 [6.9143, 9.2557] |

## Self-Play League Setup

`KolkhozSelfPlayTrainer` is a candidate generator that mutates the current policy against
a rotating pool of prior accepted policies. It uses the real Swift `KolkhozEngine`, rotates
the candidate through all four seats, and keeps a bounded league with `--pool-size`.

Quick smoke command:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozSelfPlayTrainer \
  --start Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --output ../../training/rl/runs/policy_self_play.json \
  --history ../../training/rl/runs/policy_self_play_history.json \
  --generations 1 --population 2 --games-per-seat 1
```

Serious run shape:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozSelfPlayTrainer \
  --start Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --output ../../training/rl/runs/policy_self_play.json \
  --history ../../training/rl/runs/policy_self_play_history.json \
  --generations 24 --population 24 --games-per-seat 24 \
  --opponents-per-candidate 4 --pool-size 7 --sigma 0.002
```

Do not promote from self-play score alone. Any candidate still needs the paired
`KolkhozPolicyBenchmark` gate against the all-heuristic baseline on held-out seeds.

## 2026-06-30 Self-Play Search

Goal: use the self-play league to create a stronger model after a human comfortably beat
the bundled policy.

Runs attempted:

| Candidate | Selection setup | Result |
|---|---|---|
| `policy_self_play_g3_p6_s13000001.json` | league, generations=3, population=6, games_per_seat=4, sigma=0.002 | Accepted one self-play mutation, but same-seed heuristic benchmark was essentially tied with bundled policy. |
| `policy_self_play_g3_p8_sigma004_s13000002.json` | league, generations=3, population=8, games_per_seat=4, sigma=0.004 | Best heuristic benchmark of this batch, but direct model-vs-bundled comparison failed. |
| `policy_self_play_g3_p8_sigma006_s13000003.json` | league, generations=3, population=8, games_per_seat=4, sigma=0.006 | Passed heuristic gate, but underperformed the sigma=0.004 candidate and bundled policy. |
| `policy_self_play_direct_g4_p10_s13000004.json` | direct current-policy pool, generations=4, population=10, games_per_seat=6, sigma=0.003 | All mutations rejected by validation. |
| `policy_self_play_direct_g3_p16_sigma001_s13000005.json` | direct current-policy pool, generations=3, population=16, games_per_seat=6, sigma=0.001 | All mutations rejected by validation. |

Key held-out direct comparison:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_self_play_g3_p8_sigma004_s13000002.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 300 --seed 13500000 --min-win-delta 0
```

Result: direct comparison failed. Aggregate top-or-tied delta was `-0.0067`
`[-0.0140, 0.0006]`, rank delta was `-0.0142` `[-0.0294, 0.0011]`, and margin delta
was `-0.2908` `[-0.5069, -0.0748]`. Seat 1 margin/rank were worse with confidence.

Conclusion: no self-play candidate from this batch should replace
`Sources/KolkhozCore/Resources/kolkhoz_policy.json`. The important tooling improvement is
the new `--baseline-model` direct-comparison gate; future searches should optimize against
that direct gate instead of treating heuristic-gate passes as evidence of improvement over
the current bundled model.

## 2026-06-30 Policy-Gradient RL

Added `KolkhozPolicyGradientTrainer`, a real REINFORCE-style trainer over the Swift
`KolkhozEngine`. It samples legal policy actions during complete games, accumulates
`grad log pi(action)` for the existing one-hidden-layer policy network, applies final
score/rank/win returns, and writes the same `KolkhozPolicyModel` JSON format used by the
app.

Training modes:

- all-seat stochastic self-play: every seat samples from the trainable policy and all
  seats contribute centered returns
- frozen-opponent training: one rotated seat samples from the trainable policy while the
  other seats play a frozen bundled policy greedily

Runs attempted:

| Candidate | Setup | Direct result vs bundled model |
|---|---|---|
| `policy_pg_self_play_e256_lr0004_s14002000.json` | all-seat, episodes=256, lr=0.0004, temperature=1.2 | Behavior-identical to bundled model on 400 direct samples; updates were too small to change greedy actions. |
| `policy_pg_self_play_e512_lr004_s14003000.json` | all-seat, episodes=512, lr=0.04, temperature=0.85 | Worse than bundled: top delta `-0.0150` `[-0.0418, 0.0118]`, rank delta `-0.0275` `[-0.0810, 0.0260]`, margin delta `-0.2450` `[-1.1286, 0.6386]`. |
| `policy_pg_vs_bundle_e512_lr004_s14004000.json` | frozen bundled opponents, episodes=512, lr=0.04, temperature=0.9 | Best checkpoint: top delta `0.0075` `[-0.0088, 0.0238]`, rank delta `0.0175` `[-0.0214, 0.0564]`, margin delta `0.4800` `[-0.1585, 1.1185]`; not promotable because lower bounds did not clear zero and seat 3 top rate was slightly worse. |
| `policy_pg_vs_bundle_e1024_lr002_s14005000.json` | continued from best checkpoint, frozen bundled opponents, episodes=1024, lr=0.02, temperature=0.85 | Worse than bundled overall: top delta `-0.0125` `[-0.0360, 0.0110]`; seat 3 regressed. |
| `policy_pg_vs_bundle_e512_lr006_s14006000.json` | frozen bundled opponents, episodes=512, lr=0.06, temperature=0.8 | Clear fail: top delta `-0.0250` `[-0.0445, -0.0055]`, rank delta `-0.0425` `[-0.0824, -0.0026]`. |

Larger held-out direct comparison for the best checkpoint:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_pg_vs_bundle_e512_lr004_s14004000.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 300 --seed 14017000 --min-win-delta 0
```

Result: no promotion. Aggregate top-or-tied delta was `0.0075`
`[-0.0048, 0.0198]`, strict-win delta was `0.0100` `[-0.0024, 0.0224]`,
rank delta was `0.0067` `[-0.0202, 0.0335]`, and margin delta was `-0.2467`
`[-0.6670, 0.1737]`. Seat 3 margin was worse with confidence:
`-0.8533` `[-1.6341, -0.0726]`.

Conclusion: the repo now has a real RL self-play/frozen-opponent trainer, and the best
checkpoint shows a small positive top-rate signal, but no policy-gradient checkpoint from
this batch should replace `Sources/KolkhozCore/Resources/kolkhoz_policy.json` yet because
the held-out margin/seat results are not stronger. The next serious pass should either
train longer from the frozen-opponent setup with held-out seat-balanced validation or
increase model/action capacity; simply increasing the step size degraded the policy.

## 2026-06-30 Paired-Baseline Policy Gradient

Improved `KolkhozPolicyGradientTrainer` frozen-opponent mode to use a paired same-seed
baseline advantage. For each sampled training episode, the trainer can now run the frozen
bundled policy greedily on the same seed and use:

```text
sampled_policy_reward(training_seat) - bundled_policy_reward(training_seat)
```

as the policy-gradient scale. This aligns the update with the direct model-vs-bundled
benchmark instead of using only absolute game outcome. The trainer also gained
`--checkpoint-every` so intermediate models can be benchmarked instead of only the final
checkpoint.

Reward-function runs attempted:

| Candidate | Reward / setup | Result |
|---|---|---|
| `policy_pg_paired_vs_bundle_e1024_lr004_m008_s14018000.json` | win=1.0, rank=0.25, margin=0.08, episodes=1024, lr=0.04, paired baseline | Quick 400-sample benchmark was directionally positive, but 1200-sample held-out benchmark failed: top delta `-0.0042` `[-0.0171, 0.0088]`, margin delta `-0.0458` `[-0.4587, 0.3671]`; seat 1 rank regressed with confidence. |
| `policy_pg_paired_vs_bundle_ckpt_lr003_m010_s14030000_e1536.json` | win=1.0, rank=0.25, margin=0.10, episodes=1536, lr=0.03, checkpoint sweep | Best checkpoint from the margin-heavy checkpoint sweep. Quick 240-sample benchmark tied top rate and improved strict/rank/margin, but did not beat top rate. |
| `policy_pg_paired_vs_bundle_winrank_e1024_s14050000_e1024.json` | win=1.4, rank=0.45, margin=0.02, episodes=1024, lr=0.035, checkpoint sweep | Best reward-function candidate so far. Quick 240-sample benchmark: top delta `0.0292` `[0.0023, 0.0561]`, rank delta `0.0208` `[-0.0451, 0.0868]`. Larger held-out benchmark stayed positive but did not clear gate. |

Held-out direct comparison for the best win/rank-heavy candidate:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_pg_paired_vs_bundle_winrank_e1024_s14050000_e1024.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 300 --seed 14061000 --min-win-delta 0
```

Result: promising but not promotable. Aggregate top-or-tied delta was `0.0067`
`[-0.0056, 0.0189]`, strict-win delta was `0.0083` `[-0.0032, 0.0199]`,
rank delta was `0.0025` `[-0.0221, 0.0271]`, and margin delta was `0.1942`
`[-0.1571, 0.5455]`. Seat 1 improved across top/rank/margin, seat 3 improved strict
and margin but had rank delta `-0.0233` `[-0.0807, 0.0340]`.

Conclusion: reward shaping matters. The win/rank-heavy reward is the best policy-gradient
direction so far and should be the next branch to extend, but it still should not replace
the bundled evolutionary model until a held-out direct benchmark has positive lower
bounds on top/rank/margin and no seat-specific regression.

## 2026-06-30 Adam Policy Gradient

Added `--optimizer adam` to `KolkhozPolicyGradientTrainer` while keeping the existing
SGD path. Adam keeps first/second moment estimates for the existing policy-gradient
updates and still writes the same `KolkhozPolicyModel` JSON format.

Runs attempted:

| Candidate | Optimizer / reward setup | Result |
|---|---|---|
| `policy_pg_adam_winrank_continue_s14070000_e768.json` | continued from `policy_pg_paired_vs_bundle_winrank_e1024_s14050000_e1024.json`, optimizer=adam, lr=0.003, win=1.4, rank=0.45, margin=0.02, checkpoint sweep | Best Adam checkpoint. Quick 240-sample benchmark had top delta `0.0250` `[-0.0434, 0.0934]`, strict delta `0.0333` `[-0.0369, 0.1036]`, margin improved. Larger held-out benchmark improved top/strict but failed on margin and seat 2. |
| `policy_pg_adam_balanced_s14090000_e256.json` | fresh from bundled model, optimizer=adam, lr=0.002, win=1.2, rank=0.6, margin=0.06, checkpoint sweep | Best checkpoint from balanced Adam branch, but only weak quick-sweep signal: top delta `0.0042` `[-0.0507, 0.0591]`, rank delta `0.0542` `[-0.0481, 0.1565]`; later checkpoints regressed. |

Held-out direct comparison for the best Adam continuation checkpoint:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_pg_adam_winrank_continue_s14070000_e768.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 300 --seed 14081000 --min-win-delta 0
```

Result: no promotion. Aggregate top-or-tied delta was `0.0158`
`[-0.0132, 0.0449]`, strict-win delta was `0.0175` `[-0.0119, 0.0469]`,
rank delta was `0.0033` `[-0.0600, 0.0667]`, and margin delta was `-0.0217`
`[-1.0311, 0.9877]`. Seat 1 improved strongly, but seat 2 regressed:
top delta `-0.0333` `[-0.0903, 0.0236]`, rank delta `-0.0900`
`[-0.2046, 0.0246]`, margin delta `-1.6000` `[-3.6079, 0.4079]`.

Conclusion: Adam can push top/strict-win rates higher than SGD, but the current shared
policy still creates seat-specific regressions. The next useful direction is likely a
seat-balanced objective or validation-in-the-loop selection rather than simply more Adam
steps.

## 2026-06-30 Seat-Balanced Adam Policy Gradient

Added two trainer controls to address the seat-specific regressions seen in the Adam
branch:

- `--seat-balanced-update`: averages the batch gradient by training seat before applying
  an optimizer update, so one seat's noisy rollouts cannot dominate the shared policy.
- `--advantage-clip`: clips paired-baseline advantages before applying `grad log pi`,
  reducing outlier updates from high-variance final-score swings.

Run attempted:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyGradientTrainer \
  --start Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --output ../../training/rl/runs/policy_pg_adam_seatbalanced_winrank_s14110000.json \
  --history ../../training/rl/runs/policy_pg_adam_seatbalanced_winrank_s14110000_history.json \
  --checkpoint-every 256 --episodes 1024 --batch-size 16 \
  --optimizer adam --learning-rate 0.0025 --temperature 0.85 \
  --win-weight 1.4 --rank-weight 0.45 --margin-weight 0.02 \
  --paired-baseline --seat-balanced-update --advantage-clip 2.0
```

Checkpoint sweep:

| Candidate | Quick / medium result |
|---|---|
| `policy_pg_adam_seatbalanced_winrank_s14110000_e256.json` | Quick seed looked strong, but 480-sample cross-seed benchmark failed: top delta `-0.0167` `[-0.0498, 0.0165]`. |
| `policy_pg_adam_seatbalanced_winrank_s14110000_e512.json` | Quick seed looked best, but full 1200-sample held-out benchmark failed hard: top delta `-0.0208` `[-0.0453, 0.0036]`, rank delta `-0.0550` `[-0.1059, -0.0041]`, margin delta `-1.2100` `[-2.0202, -0.3998]`. |
| `policy_pg_adam_seatbalanced_winrank_s14110000_e768.json` | 480-sample cross-seed benchmark was positive but not decisive: top delta `0.0229` `[-0.0138, 0.0596]`, rank delta `0.0521` `[-0.0292, 0.1334]`. |
| `policy_pg_adam_seatbalanced_winrank_s14110000_e1024.json` | Best checkpoint from this branch; promoted to full held-out benchmark. |

Held-out direct comparison for `policy_pg_adam_seatbalanced_winrank_s14110000_e1024.json`:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_pg_adam_seatbalanced_winrank_s14110000_e1024.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 300 --seed 14123000 --min-win-delta 0
```

Result: closer, but still no promotion. Aggregate top-or-tied delta was `0.0158`
`[-0.0107, 0.0423]`, strict-win delta was `0.0083` `[-0.0183, 0.0350]`,
rank delta was `0.0150` `[-0.0404, 0.0704]`, and margin delta was `0.0750`
`[-0.8502, 1.0002]`. Seat 0 and seat 3 improved directionally, seat 2 was roughly
neutral on top/rank but lower on margin, and seat 1 regressed slightly:
top delta `-0.0100` `[-0.0667, 0.0467]`, strict delta `-0.0333`
`[-0.0910, 0.0243]`.

Conclusion: seat-balanced updates reduced the earlier seat-2 collapse and produced a
directionally positive aggregate model, but the confidence intervals and seat-1 regression
still block promotion. The next branch should avoid single-seed checkpoint selection and
use multi-seed validation before spending the full benchmark.

## 2026-06-30 Focused Weak-Seat Continuation

Added `--training-seats` to `KolkhozPolicyGradientTrainer`, allowing frozen-opponent
training to rotate through a subset of seats instead of all four seats. This was added to
continue from the best seat-balanced checkpoint while focusing updates on the seats that
held-out validation showed as weak.

Run attempted:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyGradientTrainer \
  --start ../../training/rl/runs/policy_pg_adam_seatbalanced_winrank_s14110000_e1024.json \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --output ../../training/rl/runs/policy_pg_adam_focus_s12_s14130000.json \
  --history ../../training/rl/runs/policy_pg_adam_focus_s12_s14130000_history.json \
  --checkpoint-every 128 --episodes 512 --batch-size 16 \
  --optimizer adam --learning-rate 0.0012 --temperature 0.8 \
  --win-weight 1.4 --rank-weight 0.45 --margin-weight 0.04 \
  --paired-baseline --seat-balanced-update --advantage-clip 1.5 \
  --training-seats 1,2
```

Checkpoint sweep on a 480-sample held-out seed found `e256` as the best focused
checkpoint: top delta `0.0271` `[-0.0139, 0.0681]`, rank delta `0.0646`
`[-0.0215, 0.1506]`, and margin improved directionally.

Full held-out direct comparison for `policy_pg_adam_focus_s12_s14130000_e256.json`:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_pg_adam_focus_s12_s14130000_e256.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 300 --seed 14141000 --min-win-delta 0
```

Result: no promotion. Aggregate top-or-tied delta was `0.0058`
`[-0.0195, 0.0312]`, strict-win delta was `0.0033` `[-0.0224, 0.0291]`,
rank delta was `0.0067` `[-0.0500, 0.0634]`, and margin delta was `0.0992`
`[-0.8071, 1.0055]`. Seats 0 and 1 improved directionally, but seats 2 and 3 regressed:
seat 2 margin delta `-1.2833` `[-2.9811, 0.4145]`, seat 3 top delta `-0.0233`
`[-0.0744, 0.0277]`.

Conclusion: focused weak-seat continuation can repair the targeted seats, but it shifts
the regression elsewhere. The next branch should add validation-in-loop selection across
multiple held-out seeds/seats so checkpoints are selected for all-seat robustness before
the expensive full benchmark.

## 2026-06-30 Multi-Seed Checkpoint Selection

Added `KolkhozPolicySelector`, a real-engine checkpoint selector that evaluates multiple
candidate JSON models across multiple held-out seeds before choosing which one deserves a
full benchmark. It uses the same paired candidate-vs-bundled model comparison as
`KolkhozPolicyBenchmark`, reports aggregate confidence intervals plus worst-seat deltas,
and applies a selection score that penalizes seat-specific regressions.

Selector run:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicySelector \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --seeds 14150000,14160000,14170000 \
  --games-per-seat 80 \
  --model ../../training/rl/runs/policy_pg_adam_seatbalanced_winrank_s14110000_e1024.json \
  --model ../../training/rl/runs/policy_pg_adam_focus_s12_s14130000_e256.json \
  --model ../../training/rl/runs/policy_pg_adam_winrank_continue_s14070000_e768.json \
  --model ../../training/rl/runs/policy_pg_paired_vs_bundle_winrank_e1024_s14050000_e1024.json
```

Selector result: `policy_pg_adam_winrank_continue_s14070000_e768.json` was best, with
960 validation samples: top delta `0.0458` `[0.0134, 0.0783]`, strict delta `0.0417`
`[0.0087, 0.0746]`, rank delta `0.1135` `[0.0462, 0.1809]`, and margin delta `1.3094`
`[0.1727, 2.4461]`. However, worst-seat top and margin were still negative:
worst-seat top delta `-0.0208`, worst-seat margin delta `-0.7167`.

Fresh full benchmark for the selector-chosen model:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_pg_adam_winrank_continue_s14070000_e768.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 300 --seed 14180000 --min-win-delta 0
```

Result: no promotion. Aggregate top-or-tied delta was `-0.0075`
`[-0.0353, 0.0203]`, strict-win delta was `-0.0075` `[-0.0354, 0.0204]`,
rank delta was `-0.0042` `[-0.0630, 0.0546]`, and margin delta was `-0.4258`
`[-1.3933, 0.5416]`. Seat 1 regressed most: top delta `-0.0367`
`[-0.0901, 0.0167]`.

Conclusion: multi-seed validation is necessary but the current selector sample size is
not sufficient to prove promotion. The next branch should either raise validation
strength before selecting checkpoints or change the model/action capacity; repeated
small reward/optimizer tweaks are producing seed-sensitive candidates rather than a
stable stronger policy.

## 2026-06-30 Benchmark-Aligned Heuristic-Opponent Policy Gradient

Added two trainer controls to make the policy-gradient objective closer to the direct
promotion benchmark:

- `--opponent-mode heuristic`: in frozen-opponent mode, only the training seat uses the
  trainable/bundled model; all other seats use the normal heuristic AI. This matches the
  direct benchmark surface better than training against three greedy bundled-model
  opponents.
- `--strict-weight`: adds separate reward for strict wins, so top-or-tied and strict-win
  pressure can be tuned independently.

Initial benchmark-aligned run:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyGradientTrainer \
  --start Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-mode heuristic \
  --output ../../training/rl/runs/policy_pg_heur_strict_s14200000.json \
  --history ../../training/rl/runs/policy_pg_heur_strict_s14200000_history.json \
  --checkpoint-every 256 --episodes 1024 --batch-size 16 \
  --optimizer adam --learning-rate 0.0025 --temperature 0.85 \
  --win-weight 1.1 --strict-weight 0.5 --rank-weight 0.45 --margin-weight 0.03 \
  --paired-baseline --seat-balanced-update --advantage-clip 2.0
```

Multi-seed selector result on seeds `14210000,14220000,14230000`,
`games_per_seat=60`: `policy_pg_heur_strict_s14200000_e1024.json` was best with
top delta `0.0333` `[-0.0064, 0.0731]`, strict delta `0.0333`
`[-0.0074, 0.0740]`, rank delta `0.0444` `[-0.0388, 0.1277]`, margin delta
`1.6889` `[0.3334, 3.0444]`, and positive worst-seat means.

Fresh full benchmark:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_pg_heur_strict_s14200000_e1024.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 300 --seed 14240000 --min-win-delta 0
```

Result: no promotion. Aggregate top-or-tied delta was `0.0317`
`[-0.0016, 0.0649]`, strict-win delta was `0.0250` `[-0.0084, 0.0584]`,
rank delta was `0.0425` `[-0.0266, 0.1116]`, and margin delta was `0.8283`
`[-0.2884, 1.9451]`. Seat 3 still regressed on strict/rank/margin.

Focused continuation on weak seats 2 and 3:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyGradientTrainer \
  --start ../../training/rl/runs/policy_pg_heur_strict_s14200000_e1024.json \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-mode heuristic \
  --output ../../training/rl/runs/policy_pg_heur_strict_focus_s23_s14250000.json \
  --history ../../training/rl/runs/policy_pg_heur_strict_focus_s23_s14250000_history.json \
  --checkpoint-every 128 --episodes 512 --batch-size 16 \
  --optimizer adam --learning-rate 0.0012 --temperature 0.8 \
  --win-weight 1.0 --strict-weight 0.7 --rank-weight 0.5 --margin-weight 0.05 \
  --paired-baseline --seat-balanced-update --advantage-clip 1.5 \
  --training-seats 2,3
```

Selector result on seeds `14260000,14270000,14280000`, `games_per_seat=60`:
`policy_pg_heur_strict_focus_s23_s14250000_e512.json` was best with top delta
`0.0444` `[0.0033, 0.0856]`, strict delta `0.0361` `[-0.0055, 0.0777]`,
rank delta `0.1153` `[0.0299, 0.2007]`, margin delta `1.6667`
`[0.2159, 3.1175]`, and positive worst-seat means.

Fresh full benchmark:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_pg_heur_strict_focus_s23_s14250000_e512.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 300 --seed 14290000 --min-win-delta 0
```

Result: closest checkpoint so far, but still no promotion. Aggregate top-or-tied delta
was `0.0317` `[-0.0002, 0.0636]`, strict-win delta was `0.0308`
`[-0.0013, 0.0630]`, rank delta was `0.0667` `[-0.0013, 0.1347]`, and margin
delta was `0.9475` `[-0.1715, 2.0665]`. Seat 2 regressed on top/strict/margin.

Focused continuation on seat 2 only found `policy_pg_heur_strict_focus_s2_s14300000_e128.json`
as the best small checkpoint on seeds `14310000,14320000,14330000`, with selector top
delta `0.0319` `[-0.0105, 0.0743]`, strict delta `0.0319` `[-0.0101, 0.0740]`,
rank delta `0.0792` `[-0.0114, 0.1697]`, margin delta `1.6681`
`[0.1807, 3.1554]`, and positive worst-seat means.

Longer continuation from that checkpoint:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyGradientTrainer \
  --start ../../training/rl/runs/policy_pg_heur_strict_focus_s2_s14300000_e128.json \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-mode heuristic \
  --output ../../training/rl/runs/policy_pg_heur_long_s14340000.json \
  --history ../../training/rl/runs/policy_pg_heur_long_s14340000_history.json \
  --checkpoint-every 256 --episodes 2048 --batch-size 16 \
  --optimizer adam --learning-rate 0.0005 --temperature 0.72 \
  --win-weight 1.0 --strict-weight 0.75 --rank-weight 0.5 --margin-weight 0.05 \
  --paired-baseline --seat-balanced-update --advantage-clip 1.0
```

Training advantage did not increase monotonically in 256-episode windows:

| Episodes | Avg paired advantage | Avg top rate | Avg margin |
|---:|---:|---:|---:|
| 16-256 | 0.0115 | 0.2598 | -12.0381 |
| 272-512 | 0.0426 | 0.2529 | -12.2021 |
| 528-768 | 0.1205 | 0.2598 | -11.4746 |
| 784-1024 | 0.0625 | 0.2549 | -11.6309 |
| 1040-1280 | 0.0684 | 0.2539 | -11.6855 |
| 1296-1536 | 0.0623 | 0.2510 | -12.7783 |
| 1552-1792 | -0.0365 | 0.2578 | -11.8584 |
| 1808-2048 | -0.0826 | 0.2598 | -11.2852 |

Selector result on seeds `14350000,14360000,14370000`, `games_per_seat=50`: none of
the longer checkpoints beat the earlier short checkpoint robustly. The best long
checkpoint was `policy_pg_heur_long_s14340000_e1280.json`, but its selector score was
negative and it had worst-seat top delta `-0.0600`, worst-seat rank delta `-0.0333`,
and worst-seat margin delta `-0.7800`.

Conclusion: benchmark-aligned heuristic-opponent training is the best RL direction so
far and produced the closest full benchmark (`top_delta` lower bound only `-0.0002`),
but simply training longer with this reward did not improve held-out selector strength.
The next useful step is to improve the reward/validation loop or policy features rather
than assume monotonic reward increases imply benchmark improvement.

## 2026-06-30 Hidden-Capacity Expansion

Added `--expand-hidden` and `--expand-scale` to `KolkhozPolicyGradientTrainer`. This
widens a loaded compatible policy while preserving all existing hidden units and adding
small random new units. The feature contract stays unchanged, so widened policies remain
compatible with the current app/benchmark loader.

Run attempted from the closest 48-hidden checkpoint:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyGradientTrainer \
  --start ../../training/rl/runs/policy_pg_heur_strict_focus_s23_s14250000_e512.json \
  --expand-hidden 96 --expand-scale 0.006 \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-mode heuristic \
  --output ../../training/rl/runs/policy_pg_heur_wide96_s14400000.json \
  --history ../../training/rl/runs/policy_pg_heur_wide96_s14400000_history.json \
  --checkpoint-every 128 --episodes 768 --batch-size 16 \
  --optimizer adam --learning-rate 0.0008 --temperature 0.78 \
  --win-weight 1.0 --strict-weight 0.75 --rank-weight 0.5 --margin-weight 0.05 \
  --paired-baseline --seat-balanced-update --advantage-clip 1.2
```

Selector result on seeds `14410000,14420000,14430000`, `games_per_seat=60`:
`policy_pg_heur_wide96_s14400000_e640.json` was the best widened checkpoint. It had
top delta `0.0292` `[-0.0105, 0.0689]`, strict delta `0.0278`
`[-0.0122, 0.0678]`, rank delta `0.0833` `[-0.0008, 0.1674]`, and a strong margin
delta `2.5681` `[1.1211, 4.0150]`, but still had worst-seat top delta `-0.0333`
and worst-seat rank delta `-0.0611`.

Fresh full benchmark:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_pg_heur_wide96_s14400000_e640.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 300 --seed 14440000 --min-win-delta 0
```

Result: no promotion. Aggregate top-or-tied delta was `0.0183`
`[-0.0123, 0.0490]`, strict-win delta was `0.0258` `[-0.0049, 0.0566]`,
rank delta was `0.0217` `[-0.0423, 0.0856]`, and margin delta was `0.9592`
`[-0.1107, 2.0290]`. Seat 2 improved strongly with confidence, but seat 1 regressed
with confidence: top delta `-0.0600` `[-0.1181, -0.0019]` and rank delta
`-0.1233` `[-0.2379, -0.0088]`.

Focused seat-1 repair attempted:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyGradientTrainer \
  --start ../../training/rl/runs/policy_pg_heur_wide96_s14400000_e640.json \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-mode heuristic \
  --output ../../training/rl/runs/policy_pg_heur_wide96_focus_s1_s14450000.json \
  --history ../../training/rl/runs/policy_pg_heur_wide96_focus_s1_s14450000_history.json \
  --checkpoint-every 64 --episodes 256 --batch-size 16 \
  --optimizer adam --learning-rate 0.00045 --temperature 0.72 \
  --win-weight 1.0 --strict-weight 0.8 --rank-weight 0.55 --margin-weight 0.04 \
  --paired-baseline --seat-balanced-update --advantage-clip 1.0 \
  --training-seats 1
```

Selector result on seeds `14460000,14470000,14480000`, `games_per_seat=60`: none of
the seat-1 repair checkpoints beat the earlier 48-hidden checkpoint
`policy_pg_heur_strict_focus_s23_s14250000_e512.json`. The widened repair checkpoints
kept positive aggregate rank/margin signals, but still had negative worst-seat top,
rank, or margin deltas.

Conclusion: widening to 96 hidden units increased some margin/rank signals, especially
for seat 2, but did not solve the all-seat robustness problem. The next useful direction
is not blind capacity increase; it is a training/selection loop that explicitly rejects
updates causing per-seat validation regressions, or a richer state/action representation
that can improve seat 1 without giving back seat 2.

## 2026-06-30 Corrected Rotated-Seat Seed Schedule

The earlier benchmark and selector loops used this seed schedule:

```text
seedBase + seat * gamesPerSeat + gameIndex
```

That made per-seat rows partly measure different held-out seed/deal blocks, not just the
candidate occupying a different seat. Updated both `KolkhozPolicyBenchmark` and
`KolkhozPolicySelector` to use:

```text
seedBase + gameIndex
```

for every candidate seat. Candidate-vs-baseline remains paired on the same seed, and now
all four rotated candidate seats also see the same held-out seed indices.

Why seats can still differ after this fix:

- The initial lead and initial trump selector are sampled from the seed, so a model in
  seat 0, 1, 2, or 3 experiences a different relation to those roles.
- Swap order always starts at player 0 after year 1.
- Trick winners become the next lead and own assignment choices, so an early policy
  difference changes later phase control.
- Requisition depends on who won tricks, what was exposed, and which cards were assigned
  to failed suits.

Corrected selector screen on seeds `14610000,14620000,14630000`,
`games_per_seat=80`:

| Candidate | Top Delta 95% CI | Strict Delta 95% CI | Rank Delta 95% CI | Margin Delta 95% CI | Worst Seat Top | Worst Seat Rank | Worst Seat Margin | Score |
|---|---|---|---|---|---:|---:|---:|---:|
| `policy_pg_heur_strict_focus_s23_s14250000_e512.json` | `0.0271 [-0.0095, 0.0637]` | `0.0260 [-0.0109, 0.0629]` | `0.0646 [-0.0119, 0.1411]` | `1.0813 [-0.2139, 2.3764]` | -0.0042 | 0.0083 | 0.2833 | 0.0716 |
| `policy_pg_heur_strict_focus_s2_s14300000_e128.json` | `0.0333 [-0.0034, 0.0700]` | `0.0312 [-0.0058, 0.0683]` | `0.0771 [-0.0004, 0.1546]` | `1.4000 [0.1035, 2.6965]` | 0.0042 | 0.0292 | 0.4292 | 0.0962 |
| `policy_pg_heur_wide96_s14400000_e640.json` | `0.0385 [0.0039, 0.0732]` | `0.0323 [-0.0031, 0.0677]` | `0.0854 [0.0111, 0.1598]` | `2.1052 [0.8333, 3.3771]` | 0.0167 | 0.0250 | 0.5333 | 0.1181 |
| `policy_pg_heur_wide96_focus_s1_s14450000_e64.json` | `0.0396 [0.0046, 0.0745]` | `0.0354 [-0.0000, 0.0708]` | `0.0938 [0.0192, 0.1683]` | `2.1198 [0.8412, 3.3984]` | 0.0208 | 0.0208 | 1.1542 | 0.1231 |
| `policy_pg_blend_s23_a075.json` | `0.0312 [-0.0024, 0.0649]` | `0.0292 [-0.0047, 0.0631]` | `0.0781 [0.0070, 0.1492]` | `1.2479 [0.0543, 2.4416]` | -0.0083 | 0.0208 | -0.4000 | 0.0698 |
| `policy_pg_blend_s23_s2_075_025.json` | `0.0271 [-0.0098, 0.0639]` | `0.0260 [-0.0111, 0.0632]` | `0.0635 [-0.0134, 0.1405]` | `1.0406 [-0.2571, 2.3384]` | -0.0042 | 0.0083 | 0.1375 | 0.0706 |
| `policy_pg_blend_s23_s2_100_025.json` | `0.0375 [-0.0003, 0.0753]` | `0.0448 [0.0066, 0.0830]` | `0.0729 [-0.0095, 0.1554]` | `2.0521 [0.7135, 3.3907]` | -0.0083 | -0.0250 | 0.6625 | 0.0817 |

The corrected selector picked `policy_pg_heur_wide96_focus_s1_s14450000_e64.json`.

Corrected full benchmark for that candidate:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_pg_heur_wide96_focus_s1_s14450000_e64.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 400 --seed 14640000 --min-win-delta 0
```

Result: no promotion. Aggregate top-or-tied delta was `0.0187`
`[-0.0079, 0.0454]`, strict-win delta was `0.0206` `[-0.0064, 0.0476]`,
rank delta was `0.0531` `[-0.0026, 0.1088]`, and margin delta was `1.3206`
`[0.3769, 2.2643]`. Seat 3 improved with confidence, but seat 0 regressed
directionally on top, strict, and rank:

```text
seat_0 top_delta=-0.0150 [-0.0660, 0.0360]
seat_0 strict_delta=-0.0250 [-0.0769, 0.0269]
seat_0 rank_delta=-0.0475 [-0.1497, 0.0547]
seat_0 margin_delta=0.8675 [-1.0452, 2.7802]
```

Corrected full benchmark for the best 48-hidden control
`policy_pg_heur_strict_focus_s2_s14300000_e128.json`:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_pg_heur_strict_focus_s2_s14300000_e128.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 400 --seed 14690000 --min-win-delta 0
```

Result: clear fail. Aggregate top-or-tied delta was `-0.0213`
`[-0.0492, 0.0067]`, rank delta was `-0.0712` `[-0.1308, -0.0117]`, and seat 2
regressed with confidence.

Conclusion: the corrected schedule reduces artificial seat-block variance and makes the
widened seat-1 repair checkpoint the best current RL candidate. It still cannot be
promoted because the corrected full benchmark does not clear top/rank lower bounds and
shows a seat-0 directional regression. The next trainer improvement should integrate
small held-out same-seed rotated-seat validation into checkpoint selection or update
acceptance, instead of relying on training reward alone.

## 2026-06-30 Dense Score-Delta Shaping

Added dense shaping to `KolkhozPolicyGradientTrainer`:

- `--score-delta-weight`: adds an immediate policy-gradient term when the sampled
  training-seat action changes that seat's `finalScore`.
- `--margin-delta-weight`: adds an immediate term for the sampled action's change to
  that seat's score margin over the best opponent.

The final paired-baseline game reward is still applied. This shaping only adds
intermediate credit assignment so the trainer does not have to infer every useful
swap/play/assignment choice from game-over reward alone.

First shaped run from the corrected best checkpoint:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyGradientTrainer \
  --start ../../training/rl/runs/policy_pg_heur_wide96_focus_s0_s14700000_e320.json \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-mode heuristic \
  --output ../../training/rl/runs/policy_pg_heur_shaped_s12_s14880000.json \
  --history ../../training/rl/runs/policy_pg_heur_shaped_s12_s14880000_history.json \
  --checkpoint-every 64 --episodes 384 --batch-size 16 \
  --optimizer adam --learning-rate 0.00022 --temperature 0.68 \
  --win-weight 1.0 --strict-weight 0.8 --rank-weight 0.65 --margin-weight 0.035 \
  --score-delta-weight 0.015 --margin-delta-weight 0.01 \
  --paired-baseline --seat-balanced-update --advantage-clip 0.8 \
  --training-seats 1,2
```

The dense shaping signal was nonzero during training, with `shaped` around `0.015` to
`0.027` per logged batch.

Corrected selector result on seeds `14890000,14900000,14910000`,
`games_per_seat=80`: `policy_pg_heur_shaped_s12_s14880000_e128.json` beat the parent
checkpoint. It had top delta `0.0573` `[0.0225, 0.0921]`, strict delta `0.0656`
`[0.0301, 0.1012]`, rank delta `0.1583` `[0.0831, 0.2336]`, margin delta
`3.0521` `[1.7996, 4.3046]`, and positive worst-seat means.

Corrected full benchmark:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_pg_heur_shaped_s12_s14880000_e128.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 500 --seed 14930000 --min-win-delta 0
```

Result: no promotion, but aggregate passed again. Aggregate top-or-tied delta was
`0.0270` `[0.0030, 0.0510]`, strict-win delta was `0.0310`
`[0.0070, 0.0550]`, rank delta was `0.0630` `[0.0125, 0.1135]`, and margin
delta was `1.4095` `[0.5727, 2.2463]`. Seat 2 improved with confidence and seat 3
improved on strict/margin, but seat 1 still regressed directionally:

```text
seat_1 top_delta=-0.0080 [-0.0538, 0.0378]
seat_1 strict_delta=-0.0120 [-0.0581, 0.0341]
seat_1 rank_delta=-0.0080 [-0.1007, 0.0847]
seat_1 margin_delta=0.1400 [-1.5511, 1.8311]
```

Conclusion: dense score/margin shaping is useful; it strengthened selector and full
benchmark aggregate results. It still does not by itself guarantee no seat-specific
regression. The next structural step should be a round-level curriculum: train on
single-year real-engine states with randomized existing plots/work/revealed jobs/famine
state, optimize dense score/margin/requisition outcome for that round, then fine-tune on
full games and gate updates with corrected rotated-seat validation.

## 2026-06-30 Round-Curriculum Policy Gradient

Added `--round-curriculum` to `KolkhozPolicyGradientTrainer`. In this mode the trainer
starts each episode from a randomized single-year `KolkhozState` with existing hand,
plot, work-hour, revealed-job, year, lead, trump-selector, and optional famine state,
then plays only until that year resolves. The curriculum uses the same legal-action
sampling, paired baseline, dense score/margin shaping, and final reward path as full-game
training, but with much shorter credit-assignment horizon.

The first attempt with `--round-plot-cards 7` exposed an impossible synthetic state: the
32-card worker deck could not support full hands plus 28 plot cards. The generator now
deals real hands first and caps each player's plot by the remaining deck capacity.

Successful run:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyGradientTrainer \
  --round-curriculum --round-plot-cards 3 --round-famine-rate 0.25 \
  --start ../../training/rl/runs/policy_pg_heur_shaped_s12_s14880000_e128.json \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-mode heuristic \
  --output ../../training/rl/runs/policy_pg_round_curriculum_s14980000.json \
  --history ../../training/rl/runs/policy_pg_round_curriculum_s14980000_history.json \
  --checkpoint-every 128 --episodes 768 --batch-size 16 \
  --optimizer adam --learning-rate 0.00018 --temperature 0.72 \
  --win-weight 0.8 --strict-weight 0.6 --rank-weight 0.5 --margin-weight 0.08 \
  --score-delta-weight 0.025 --margin-delta-weight 0.015 \
  --paired-baseline --seat-balanced-update --advantage-clip 0.8 \
  --training-seats 0,1,2,3
```

Selector over the parent plus round checkpoints on seeds `14990000,15000000,15010000`,
`games_per_seat=80`, picked `policy_pg_round_curriculum_s14980000_e640.json`.
Selector result for that checkpoint: top delta `0.0281` `[-0.0063, 0.0626]`,
strict delta `0.0208` `[-0.0138, 0.0555]`, rank delta `0.0729`
`[-0.0003, 0.1461]`, margin delta `1.5844` `[0.3159, 2.8528]`, worst-seat top
delta `-0.0083`, worst-seat rank delta `-0.0375`, worst-seat margin delta `-0.1833`.

Fresh confirmation benchmarks for the selector winner:

| Seed | Samples | Top Delta 95% CI | Strict Delta 95% CI | Rank Delta 95% CI | Margin Delta 95% CI | Seat Result |
|---:|---:|---|---|---|---|---|
| `15070000` | 2000 | `0.0295 [0.0058, 0.0532]` | `0.0340 [0.0100, 0.0580]` | `0.0705 [0.0219, 0.1191]` | `1.3260 [0.5046, 2.1474]` | all seat means nonnegative |
| `15130000` | 2000 | `0.0555 [0.0312, 0.0798]` | `0.0585 [0.0342, 0.0828]` | `0.1135 [0.0617, 0.1653]` | `3.0490 [2.2151, 3.8829]` | all seat means positive |

Promotion decision: promote `policy_pg_round_curriculum_s14980000_e640.json` to
`ios/KolkhozSwiftUI/Sources/KolkhozCore/Resources/kolkhoz_policy.json`. This is the
first gradient-based RL checkpoint in this search to beat the current evolutionary
bundled model on two fresh real-engine paired rotated-seat benchmark blocks.

## 2026-06-30 Post-Promotion Continuation Attempts

After promoting `policy_pg_round_curriculum_s14980000_e640.json`, tried to improve on the
new bundled policy directly. All runs used the promoted model as both `--start` and
`--opponent-model`, with `--opponent-mode heuristic`, paired same-state baseline,
seat-balanced updates, and held-out full-game selection against
`Sources/KolkhozCore/Resources/kolkhoz_policy.json`.

Runs attempted:

| Candidate family | Setup | Best selector result vs promoted policy | Decision |
|---|---|---|---|
| `policy_pg_full_finetune_s15190000` | full-game continuation, 512 episodes, strict/rank/margin reward, low LR | `e192`: top delta `0.0042 [-0.0035, 0.0118]`, rank delta `0.0042 [-0.0091, 0.0174]`, margin delta `0.1135 [-0.1148, 0.3419]` | no promotion |
| `policy_pg_round_long_balanced_s15250000` | round curriculum, 2048 episodes, balanced strict/rank/margin reward, plot=3, famine=0.25 | `e512`: top delta `0.0042 [-0.0023, 0.0106]`, rank delta `0.0125 [-0.0004, 0.0254]`, margin delta `0.2833 [-0.0602, 0.6269]`, worst-seat top `-0.0042` | no promotion |
| `policy_pg_round_long_margin_s15310000` | round curriculum, 2048 episodes, margin-heavy reward, plot=4, famine=0.35 | best score stayed negative; `e1280` top delta `0.0069 [-0.0036, 0.0175]`, margin delta `0.1792 [-0.2067, 0.5650]`, worst-seat margin `-0.5722` | no promotion |
| `policy_pg_round_strict_s15450000` | round curriculum, 2048 episodes, strict/top-heavy reward, lower dense margin pressure, plot=3, famine=0.20 | `e2048`: top delta `0.0052 [-0.0088, 0.0192]`, strict delta `0.0073 [-0.0064, 0.0210]`, rank delta `0.0177 [-0.0094, 0.0449]`, margin delta `-0.0177 [-0.5312, 0.4958]` | no promotion |

Conclusion: the curriculum trainer had not obviously plateaued during the successful
promotion run, but simply training longer from the promoted model did not produce a
benchmark-clear improvement. Reward-function changes moved the tiny directional gains
around but did not clear top/strict/rank confidence intervals, and they still introduced
small worst-seat regressions. The next improvement attempt should change the trainer,
not just extend these runs: add validation-gated checkpoint acceptance during training,
try a larger or phase-specialized policy head, or add a real intermediate requisition/job
completion reward instead of only final score deltas.

## 2026-06-30 Validation-Gated and Job-Shaped Trainer

Added held-out validation directly to `KolkhozPolicyGradientTrainer`:

- `--validation-seeds`
- `--validation-games-per-seat`
- `--validation-output`
- `--validation-baseline-model`

When validation is enabled, every checkpoint is evaluated with the same paired
rotated-seat direct comparison used by `KolkhozPolicySelector`. The trainer prints
aggregate deltas plus worst-seat deltas and saves the best validation score to
`--validation-output` or an automatic `*_best.json`.

Also added intermediate real-engine shaping terms:

- `--work-delta-weight`: reward sampled actions that increase total assigned work hours.
- `--claim-delta-weight`: reward sampled actions that create newly claimed jobs.
- `--own-requisition-weight`: penalize sampled actions that immediately create
  requisition events for the acting player's own plot cards.

Validation-gated plain curriculum run:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyGradientTrainer \
  --round-curriculum --round-plot-cards 3 --round-famine-rate 0.25 \
  --start Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-mode heuristic \
  --output ../../training/rl/runs/policy_pg_validated_round_s15610000.json \
  --history ../../training/rl/runs/policy_pg_validated_round_s15610000_history.json \
  --validation-output ../../training/rl/runs/policy_pg_validated_round_s15610000_best.json \
  --validation-seeds 15670000,15680000 \
  --validation-games-per-seat 24 \
  --checkpoint-every 128 --episodes 768 --batch-size 16 --seed 15610000 \
  --optimizer adam --learning-rate 0.00010 --temperature 0.72 \
  --win-weight 0.85 --strict-weight 0.75 --rank-weight 0.55 --margin-weight 0.07 \
  --score-delta-weight 0.025 --margin-delta-weight 0.015 \
  --paired-baseline --seat-balanced-update --advantage-clip 0.7 \
  --training-seats 0,1,2,3
```

Best in-training validation checkpoint was `policy_pg_validated_round_s15610000_best.json`.
Fresh selector on seeds `15850000,15860000,15870000`, `games_per_seat=80`: top delta
`0.0052` `[-0.0046, 0.0150]`, strict delta `0.0042` `[-0.0062, 0.0146]`, rank delta
`0.0083` `[-0.0117, 0.0283]`, margin delta `0.0969` `[-0.2395, 0.4333]`,
worst-seat margin `-0.2833`. No promotion.

Job-shaped validation run:

```bash
cd ios/KolkhozSwiftUI
swift run KolkhozPolicyGradientTrainer \
  --round-curriculum --round-plot-cards 3 --round-famine-rate 0.25 \
  --start Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --opponent-mode heuristic \
  --output ../../training/rl/runs/policy_pg_jobshaped_validated_s15730000.json \
  --history ../../training/rl/runs/policy_pg_jobshaped_validated_s15730000_history.json \
  --validation-output ../../training/rl/runs/policy_pg_jobshaped_validated_s15730000_best.json \
  --validation-seeds 15790000,15800000 \
  --validation-games-per-seat 24 \
  --checkpoint-every 128 --episodes 1024 --batch-size 16 --seed 15730000 \
  --optimizer adam --learning-rate 0.00009 --temperature 0.76 \
  --win-weight 0.8 --strict-weight 0.8 --rank-weight 0.55 --margin-weight 0.055 \
  --score-delta-weight 0.018 --margin-delta-weight 0.010 \
  --work-delta-weight 0.0015 --claim-delta-weight 0.18 --own-requisition-weight 0.12 \
  --paired-baseline --seat-balanced-update --advantage-clip 0.7 \
  --training-seats 0,1,2,3
```

The validation gate selected `policy_pg_jobshaped_validated_s15730000_e128.json` and
rejected later checkpoints as they developed seat and margin regressions. Fresh selector
result for the saved best model: top delta `0.0042` `[-0.0016, 0.0099]`, strict delta
`0.0042` `[-0.0016, 0.0099]`, rank delta `0.0073` `[-0.0025, 0.0171]`, margin delta
`0.1646` `[-0.0054, 0.3346]`, worst-seat top `-0.0042`, worst-seat rank `-0.0042`.
No promotion.

Conclusion: validation-gated checkpointing works and prevents late overtraining from
being mistaken for progress. Job/requisition shaping produced the best fresh selector
score in this batch, but the effect is still too small and seat-sensitive to replace the
promoted model. The next trainer change should either use validation rollback during
training or split the policy/action heads by phase so assignment-specific shaping cannot
disturb trump, swap, and trick behavior globally.
