# Kolkhoz SwiftUI

Native SwiftUI implementation of Kolkhoz for iOS.

## Open in Xcode

1. Run `xcodegen generate` if `KolkhozSwiftUI.xcodeproj` is missing or stale.
2. Open `KolkhozSwiftUI.xcodeproj` in Xcode.
3. Select the `KolkhozSwiftUIApp` scheme.
3. Choose an iPhone simulator or device.
4. Run.

The app is split into:

- `KolkhozCore`: Foundation-only game state and rules.
- `KolkhozAppFeature`: SwiftUI store and game screens.
- `KolkhozSwiftUIApp`: app entry point.
- `KolkhozSmokeTests`: plain Swift smoke tests for environments without XCTest.

## Local Verification

```bash
swift run KolkhozSmokeTests
swift build --target KolkhozAppFeature
swift build --target KolkhozSwiftUIApp
xcodegen generate
xcodebuild -project KolkhozSwiftUI.xcodeproj -scheme KolkhozSwiftUIApp -destination 'generic/platform=iOS Simulator' build
```

Full iOS simulator/device builds require Xcode. This machine currently has Command Line Tools selected, so `xcodebuild` cannot run until full Xcode is selected with `xcode-select`.

## Policy Training

The preferred RL path is the C-direct headless engine trainer. It trains v5
policies from scratch with separate action heads for trump selection, swap/no-swap,
card play, and assignment decisions. C-direct defaults to PPO with clipped
multi-epoch replay over sampled rollouts; `--optimizer sgd` keeps the older
parallel REINFORCE-style path available for comparisons. When `--league-models`
is supplied, training cycles the fixed league opponents and a small window of
recent self snapshots. Keep the bundled policy unchanged until a candidate passes
fresh real-engine paired validation.

```bash
swift build -c release --product KolkhozPolicyGradientTrainer
.build/release/KolkhozPolicyGradientTrainer \
  --scratch --layers 256,128,64 --scratch-scale 0.25 \
  --opponent-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --league-models path/to/previous_candidate.json,path/to/other_candidate.json \
  --paired-baseline \
  --advantage-baseline-beta 0.05 \
  --advantage-clip 6 \
  --value-learning-rate 0.02 \
  --optimizer ppo-adam \
  --ppo-epochs 4 \
  --ppo-minibatch-size 128 \
  --ppo-clip 0.2 \
  --entropy-weight 0.01 \
  --episodes 200000 \
  --batch-size 128 \
  --output ../../training/rl/runs/policy_candidate.json
```

Use the real-engine benchmark before considering promotion. It uses paired seeds,
medal-aware tie breaking, grouped bootstrap intervals, and hard aggregate and
per-seat lower-bound gates.

```bash
swift build -c release --product KolkhozPolicyBenchmark
.build/release/KolkhozPolicyBenchmark \
  --model ../../training/rl/runs/policy_candidate.json \
  --baseline-model Sources/KolkhozCore/Resources/kolkhoz_policy.json \
  --games-per-seat 200 \
  --bootstrap-samples 2000 \
  --min-win-delta 0.02 \
  --min-seat-win-delta 0.00 \
  --min-rank-delta 0.00 \
  --min-seat-rank-delta 0.00 \
  --min-margin-delta 0.00 \
  --min-seat-margin-delta 0.00
```
