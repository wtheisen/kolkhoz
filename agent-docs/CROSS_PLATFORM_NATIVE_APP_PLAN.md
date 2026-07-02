# Cross-Platform Native App Plan

Kolkhoz should ship as downloadable native apps that share game truth without sharing a
custom UI renderer. The current iOS SwiftUI app remains the visual reference. Future
Android, macOS, Windows, and Linux apps should use Flutter and render the same table
state, design tokens, and assets through native Flutter widgets.

## Source of Truth

The C engine remains the source of truth for gameplay:

- rules, phase flow, scoring, legal actions, AI turns, and saved-game replay;
- portable actions equivalent to `KCAction` / `KolkhozEngineAction`;
- snapshots equivalent to `KCEngine` / `KolkhozEngineSnapshot`;
- authoritative online validation and viewer redaction.

Clients must not duplicate rules. A client renders a snapshot, asks for legal actions,
submits one portable action, and waits for the engine or server to return the next
snapshot. Save/restore and reconnect should keep using seed, variants, controllers, and
the portable action log.

## Native Renderer Direction

The iOS app stays native SwiftUI. It already owns the best current expression of the
game: lobby, board layout, card art, phase panels, plot storage, jobs, online setup,
tutorial cues, accessibility, and device-specific polish.

Flutter is the planned renderer for Android and desktop because it gives one native app
surface for Android, macOS, Windows, and Linux while still binding to the shared C engine
through FFI. Flutter should mirror the SwiftUI app by consuming the same contracts and
tokens, not by copying SwiftUI code and not by reviving the removed web app.

Do not generate SwiftUI or Flutter views from a custom UI DSL. The shared layer should
describe state and visual constants; each renderer should implement idiomatic native UI.

## Shared Presentation Contract

The presentation contract turns an engine snapshot plus legal actions into a
platform-neutral table view model. It owns UI state truth that is not itself a rule:

- seats, viewer identity, current phase, year, trump, famine, and turn ownership;
- preferred panel and available panels;
- prompts and primary commands for the active phase;
- visible cards, hidden card counts, work meters, trick slots, plot sections, scores,
  requisition events, and online status;
- legal actions as stable action IDs that map back to portable engine actions;
- selected, disabled, highlighted, valid-target, and pending states;
- right-side info/rules/options panel content.

The first scaffold lives in `shared/app-contracts/`. It is intentionally JSON-first so
Swift and Dart can add small typed adapters later without locking the project into
codegen.

## Shared Design Tokens And Assets

The shared design source lives in `shared/design/tokens.json`. Tokens capture visual
constants that should line up across clients:

- dark/light color roles and suit colors;
- spacing, radii, strokes, and shadows;
- typography scale and Handjet font intent;
- card dimensions, aspect ratio, and corner metrics;
- board layout constants, panel sizes, and animation timings.

The SwiftUI implementation is still the reference when a token is ambiguous. Shared
tokens should migrate gradually from proven SwiftUI constants, not from speculative
values. Existing PNG card, icon, chrome, and title assets under the iOS resources are
the reference assets until a shared asset package is introduced.

## Fixtures And Screenshot Alignment

Canonical JSON fixtures should cover the states that most often drift between clients:

- lobby/options and online setup;
- planning trump selection;
- swap selection and confirmation;
- trick play with legal and disabled cards;
- assignment drag/drop targets and pending assignments;
- requisition audit/exile state;
- game over and final scores;
- online redacted viewer snapshots.

SwiftUI and Flutter should render fixture screenshots at agreed viewport sizes. Screenshot
comparison should check structure, visible content, token use, and obvious layout drift;
it should not require pixel-identical output from different UI frameworks.

## Staged Roadmap

1. Keep iOS runtime on the C engine.
   - Maintain `KolkhozEngineAction`, `KolkhozEngineSnapshot`, action-log replay,
     redaction, and smoke tests as the gameplay boundary.

2. Define shared native app contracts.
   - Document the table view model JSON shape.
   - Add fixtures for representative phases.
   - Add shared design tokens derived from SwiftUI constants.

3. Add iOS projection smoke tests when useful.
   - A Foundation-only Swift adapter can decode fixture JSON and project from
     `KolkhozEngineSnapshot` into the table view model.
   - Keep this adapter small; do not introduce view generation.

4. Create Flutter fixture renderer.
   - Build widgets that render the fixture JSON and tokens without engine FFI first.
   - Compare screenshots against SwiftUI reference fixtures.

5. Bind Flutter to the C engine through Dart FFI.
   - Generate or hand-maintain minimal Dart bindings for portable actions, snapshots,
     legal actions, save/restore, and replay.
   - Reuse the same fixture states for UI and action conformance tests.

6. Add online transport parity.
   - Keep the server authoritative.
   - Deliver viewer-redacted snapshots and legal actions to each native client.
   - Add live updates after the HTTP foundation is stable.

