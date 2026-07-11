# Flutter Source-of-Truth Gate

The C engine remains the source of truth for rules, legal actions, phase flow, AI, and
scoring. The Flutter app is the app/client source of truth for UX, navigation,
persistence, and local play.

## Ownership Boundary

| Area | Source of truth | Notes |
| --- | --- | --- |
| Rules, legal actions, phases, AI, scoring | C engine | Keep changes in `engine/KolkhozCEngine/`. |
| Local app runtime and state projection | Flutter | Project direct C-engine state into Dart render models. |
| Client UX, navigation, tutorial, settings | Flutter | New app behavior lands here first. |
| Save/restore behavior | Flutter + C action log | Saves should replay through the C engine. |
| Online transport and redaction behavior | Flutter client + `server/` | Keep the server authoritative and viewer-redacted. |
| Training/benchmarking | Research harness | Python/Torch code calls the C engine directly. |

## Promotion Checklist

| Gate | Required evidence | Status |
| --- | --- | --- |
| Local gameplay works through every phase | Deterministic Flutter parity tests cover planning, trick, assignment, requisition, game over | Covered by `parity_gate_test.dart` |
| Variant projection is complete | Tests cover 52-card Kolkhoz, 36-card `ordenNachalniku`, northern/camp behavior, medals, accumulated jobs | Covered by `parity_gate_test.dart` |
| Human controller privacy is correct | Hot-seat viewer tests cover active human seat and reveal behavior | Covered |
| App controls are functional | Tests cover new game, return to lobby, tutorial, and game-over restart callbacks | Covered |
| Save/restore is reliable | Tests cover action-log payload round trip, corrupt-save fallback, restored table state | Covered |
| UI can be dogfooded as the app | Manual pass completes full local and online games from the Flutter UI | See `agent-docs/FLUTTER_DOGFOOD_LOG.md` |
| CI enforces Flutter ownership | Required checks run analyze, portable tests, macOS build, C engine syntax, and server/research smoke | Enforced by `.github/workflows/ci.yml`; the local superset is `scripts/verify_flutter_source_gate.sh` |
| Docs point future work to Flutter | Agent docs state Flutter owns app/client behavior | Covered |

## Required Local Checks

Run these before claiming a source-of-truth milestone:

```bash
scripts/verify_flutter_source_gate.sh
```

The script expands to:

```bash
clients/flutter_app/tool/build_c_engine_macos.sh
clang -std=c11 -I engine/KolkhozCEngine/include \
  -fsyntax-only engine/KolkhozCEngine/KolkhozCEngine.c
cd clients/flutter_app
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build macos --debug
```

The Flutter tests load `native/macos/libkolkhoz_c_engine.dylib` on macOS. Rebuild it
before running parity-gate tests whenever the C engine API changes.

## Manual Dogfood Gate

Before declaring a broad app milestone complete, record one pass for each relevant flow:

- Local one-human game from lobby to game over.
- Local hot-seat game with at least two human seats.
- 36-card `littleKolkhoz` game that creates and displays plot stacks.
- Save, quit, restore, and continue from a non-planning phase.
- Tutorial from the lobby and from the in-game options panel.
- Online host plus join with two Flutter clients, including action submit and refresh.
- Online error path with an unavailable server or invalid invite code.

## Migration Rule

New app/client behavior should be implemented in Flutter first. If Flutter behavior and
older notes disagree, treat Flutter plus the C engine as authoritative.
