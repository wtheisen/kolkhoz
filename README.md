# Kolkhoz

Kolkhoz is a Soviet-themed trick-taking card game. The repo has four active owners:
the portable C engine, the Flutter app, the online server, and the Python/Torch research harness.

## Current Status

- `engine/KolkhozCEngine/` is the source of truth for rules, legal actions, phase flow,
  AI, scoring, policy features, and deterministic simulation.
- `clients/flutter_app/` is the standalone client for desktop/mobile work, including
  app state, C-engine projection, animation, controls, and assets.
- `clients/flutter_app/ios_resources/` owns the app's pixel-art cards, icons, UI chrome,
  fonts, and tutorial art.
- `server/` owns the authoritative online API, durable sessions, realtime transport,
  matchmaking, social/results services, and deployment.
- `research/` owns model training, benchmarking, promotion records, seed mining, and
  dashboard tooling.

The legacy React app and the transitional native Apple app have been removed. Do not
recreate retired adapters, platform-specific rule layers, package targets, or
compatibility layers for retired clients.

Generated output and local caches are not part of the source layout. It is safe to
regenerate Flutter build products, Dart tool state, Python caches, `research/.build/`,
and the local macOS C-engine dylib. Research run directories and legacy promoted model
artifacts may still be benchmark inputs, so clean them through the research CLI instead
of deleting them by hand.

## Quick Start

Check the C engine directly:

```bash
clang -std=c11 -I engine/KolkhozCEngine/include \
  -fsyntax-only engine/KolkhozCEngine/KolkhozCEngine.c
```

Check the Flutter client:

```bash
cd clients/flutter_app
flutter analyze
flutter test
flutter build macos --debug
```

Check the research harness:

```bash
python3 -m research.kolkhoz_research.cli engine-smoke --games 8
```

Run the combined Flutter source gate:

```bash
scripts/verify_flutter_source_gate.sh
```

## Game Flow

1. **Planning** - Reveal jobs and set trump. Year 5 is famine and has no trump.
2. **Swap** - In years 2-5, each player may swap one hand card with a hidden or revealed plot card when the swap variant is enabled.
3. **Trick** - Play 4 tricks in normal years and 3 tricks in famine. Players must follow the lead suit if able.
4. **Assignment** - The trick winner assigns captured cards to jobs. Legal target jobs are the suits present in the completed trick.
5. **Year end** - Remaining hand cards move to hidden plots.
6. **Requisition** - Failed jobs may reveal and exile matching plot cards.
7. Repeat for 5 years. **Highest final plot score wins**.

## Special Cards

Special cards apply only when `nomenclature` is enabled and the card is in the trump suit:

- **Jack, Drunkard** - Contributes 0 work hours. If its assigned job fails, the Drunkard is exiled instead of player plot cards for that job.
- **Queen, Informant** - If its assigned job fails, matching hidden plot cards are all revealed.
- **King, Party Official** - If its assigned job fails, two matching revealed plot cards are exiled instead of one.

Famine has no trump, so trump special-card effects do not apply in year 5.

## Saboteur Variant

Default Kolkhoz includes the Saboteur card. In engine state it is the dedicated
`wrecker-14` worker card, not a fifth crop suit or a job reward.

- It is shuffled into the worker deck when the `wrecker` variant flag is enabled.
- It counts as matching every crop suit for follow-suit, trump checks, assignment target
  legality, plot reveal, and requisition.
- If Saboteur is led to a trick, there is no ordinary lead suit; the highest played card
  wins unless trump is present.
- Saboteur has value `14`, so it can win tricks and contributes 14 work hours when
  assigned to a job.
- A job bucket containing Saboteur can still claim its reward after reaching 40 hours, but
  it is treated as failed during requisition.
- If Saboteur is in a player's plot, it can match any failed job for requisition, but the
  same Saboteur card is exiled at most once in that year's requisition report.

## Layout

```text
engine/
  KolkhozCEngine/
    KolkhozCEngine.c
    include/KolkhozCEngine.h
clients/
  flutter_app/
    lib/
    ios_resources/
    native/macos/libkolkhoz_c_engine.dylib
    tool/build_c_engine_macos.sh
research/
  kolkhoz_research/
  configs/
  dashboard/
  runs/                         # ignored local experiments and model outputs
server/
  kolkhoz_server/               # authoritative online runtime
  deploy/                       # service and staging deployment
  tests/                        # server contracts and distributed failure gates
training/
  rl/runs/                      # ignored legacy promoted/baseline JSON models
agent-docs/
```

## Data Flow

```text
Flutter gesture
    -> LiveGameStore
    -> Dart FFI action
    -> C engine applies manual action
    -> C engine advances one automatic step at a time
    -> Dart projects C state into TableViewModel
    -> Flutter renders
```

For research:

```text
Python CLI
    -> ctypes C engine wrapper
    -> C engine simulations/features
    -> C MLP or Torch/MPS policy backend
    -> benchmark/tournament/promotion records
```

## Key Files

- `engine/KolkhozCEngine/KolkhozCEngine.c` - rules, legal actions, AI, scoring, C policy features.
- `engine/KolkhozCEngine/include/KolkhozCEngine.h` - public C API used by Flutter and research.
- `clients/flutter_app/lib/src/c_engine_bridge.dart` - Dart FFI bridge.
- `clients/flutter_app/lib/src/live_game_store.dart` - Flutter runtime store.
- `clients/flutter_app/lib/src/table_view_projection.dart` - C snapshot to Flutter table model.
- `research/kolkhoz_research/c_engine.py` - Python `ctypes` wrapper and local shared-library build.
- `research/kolkhoz_research/cli.py` - training, benchmark, tournament, seed-mining CLI.
