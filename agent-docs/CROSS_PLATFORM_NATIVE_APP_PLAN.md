# Cross-Platform Native App Plan

Kolkhoz should ship as downloadable native apps that share game truth without sharing a
custom UI renderer. Flutter is the app surface for Android, iOS, macOS, Windows, and
Linux, rendering C-engine state and assets through native Flutter widgets.

## Source Of Truth

The C engine remains the source of truth for gameplay:

- rules, phase flow, scoring, legal actions, AI turns, and saved-game replay;
- portable actions equivalent to `KCAction`;
- C state accessors and action logs for client projection;
- authoritative validation and viewer redaction for future online services.

Clients must not duplicate rules. A client renders projected state, asks for legal
actions, submits one portable action, and waits for the engine or server to return the
next state. Save/restore and reconnect should keep using seed, variants, controllers, and
the portable action log.

## Native Renderer Direction

Flutter is the planned renderer for downloadable clients because it gives one native app
surface while still binding to the shared C engine through FFI. Flutter owns its UI
through Flutter-owned visual constants, shared assets, and direct C-engine projections.

Do not generate platform-specific views from a custom UI DSL. The shared layer should
describe gameplay state only; Flutter should implement idiomatic app UI.

## Runtime Projection

The Flutter client projects C-engine state plus legal actions into local Dart runtime
models. These models are normal app code, not shared JSON contracts:

- seats, viewer identity, current phase, year, trump, famine, and turn ownership;
- preferred panel and available panels;
- prompts and primary commands for the active phase;
- visible cards, job buckets, plots, north history, and scores.

Do not reintroduce JSON presentation contracts, fixture repositories, or compatibility
schemas for parity work.

## Visual Constants And Assets

Flutter owns visual constants directly in Dart app code:

- dark/light color roles and suit colors;
- spacing, radii, strokes, and shadows;
- typography scale and Handjet font intent;
- card dimensions, aspect ratio, and corner metrics;
- board layout constants, panel sizes, and animation timings.

PNG cards, icons, chrome, title art, and fonts live in
`clients/flutter_app/ios_resources/`.

## Screenshot Alignment

Use live C-engine projections and focused Dart model builders for screenshot checks. Keep
test data in code near the tests instead of adding shared JSON fixtures.

## Roadmap

1. Keep the Flutter app on direct C-engine FFI.
2. Keep C-engine action/state contracts stable enough for save/replay and research.
3. Expand platform builds through Flutter's platform wrappers.
4. Add online transport around an authoritative service using the same C engine.
5. Deliver viewer-redacted snapshots and legal actions to each client.
6. Add live updates after the HTTP foundation is stable.
