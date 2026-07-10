# Layout screenshot harness

Generate all scenario/device screenshots from `clients/flutter_app`:

```bash
./tool/layout_screenshots.sh
```

The command updates phone-landscape PNGs for game states, the game-log panel, and the
main menu's create-game, player setup, online, how-to-play, profile, comrades, assist,
display, and rules screens. Each renders at small, standard, and large iPhone-class
sizes at 2x or 3x resolution while preserving the phone's logical layout size. Open the
folder as a contact sheet in Finder, or inspect individual images. To compare the current
UI against the saved PNGs without updating them:

```bash
./tool/layout_screenshots.sh --check
```

Add or adjust named UI fixtures in `test/support/layout_scenarios.dart`. Add screen sizes
to `_devices` in `test/layout_screenshot_test.dart`.
