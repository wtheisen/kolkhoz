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
