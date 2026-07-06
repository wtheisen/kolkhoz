# Flutter Dogfood Log

## 2026-07-03 14:38 EDT

Automated source-gate verification passed with:

```bash
scripts/verify_flutter_source_gate.sh
```

Evidence covered by the script:

- Rebuilt `clients/flutter_app/native/macos/libkolkhoz_c_engine.dylib`.
- C engine syntax check passed.
- Dart format check passed with no changes.
- Flutter analyzer passed with no issues.
- Flutter tests passed with 53 tests.
- Flutter macOS debug app built successfully.
- C engine syntax check passed.
- Flutter analyze, tests, and macOS debug build passed.

Additional deterministic Flutter parity coverage added in
`clients/flutter_app/test/parity_gate_test.dart`:

- Fixed-seed table projection.
- Full deterministic local game through game over.
- 36-card `ordenNachalniku` plot stack projection.
- Saved action-log restore from a non-planning phase.
- Camp/northern requisition final projection.
- Medals plus accumulated-jobs final scoring projection.
- Online redacted snapshot projection for remote seats, stacks, and legal actions.

Manual GUI dogfood status:

- The macOS app launches from
  `clients/flutter_app/build/macos/Build/Products/Debug/kolkhoz_app.app`.
- Computer Use could not capture the app state; `get_app_state` timed out after launch.
- The app bundle identifier collides with an old fixture-renderer build:
  `com.example.kolkhozFixtureRenderer`.
- Full manual GUI dogfood remains open until the app can be uniquely launched and
  inspected through Computer Use or another interactive path.

Open manual flows:

- Local one-human game from lobby to game over.
- Local hot-seat game with at least two human seats.
- 36-card `littleKolkhoz` game that creates and displays plot stacks.
- Save, quit, restore, and continue from a non-planning phase.
- Tutorial from the lobby and from the in-game options panel.
- Online host plus join with two Flutter clients, including action submit and refresh.
- Online error path with an unavailable server or invalid invite code.

## 2026-07-03 15:12 EDT

Dogfood enablement work completed:

- Changed the Flutter macOS bundle identifier from the old fixture-renderer id to
  `com.williamtheisen.kolkhoz`, so Computer Use and macOS process lookup no longer
  collide with `clients/flutter_fixture_renderer`.
- Fixed the native macOS launch path after an invalid `FlutterAppDelegate`
  `super.applicationDidFinishLaunching` call caused a runtime crash during
  dogfood experiments.
- Kept the stock `MainFlutterWindow` as the single Flutter window owner and added
  deterministic debug launch placement. WindowServer now reports the debug app
  window at `X=360, Y=155, Width=1200, Height=800` instead of the earlier
  off-display `X=-1560` placement.
- Added native window Accessibility metadata for the macOS window title/role.

Current evidence:

- Window-id capture works and renders the live Flutter lobby:
  `/tmp/kolkhoz_window_29468.png`.
- Later captures after click attempts also render the lobby:
  `/tmp/kolkhoz_after_start_click.png` and `/tmp/kolkhoz_after_pid_click.png`.
- The source gate passed after the launch and placement fixes.

Remaining blocker:

- Computer Use still cannot dogfood the app interactively in this Codex session.
  `get_app_state` now fails quickly with `Computer Use server error -10005:
  cgWindowNotFound` instead of hanging.
- `System Events` still reports the app process as visible but with zero
  Accessibility windows: `{frontmost=false, visible=true, count of windows=0}`.
- WindowServer can capture the app by window id, but the window is not included
  in `.optionOnScreenOnly`, so global and process-targeted click events do not
  reach Flutter.

Next practical path:

- Use window-id screenshot capture as the visual dogfood evidence path for now.
- To get true interactive dogfooding, run the app in a normal user desktop
  session where macOS marks the debug window as on-screen, or add a Flutter
  integration-test/VM-service harness that can drive taps inside the app without
  relying on macOS Accessibility.
