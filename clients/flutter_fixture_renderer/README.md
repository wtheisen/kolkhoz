# Kolkhoz Flutter Fixture Renderer

This is the first Flutter client foundation for Kolkhoz. It renders shared app-contract
fixtures and design tokens only.

It does not contain C engine FFI, action submission, online transport, or generated views.
Those belong in later slices after fixture rendering is stable.

## Data Sources

The app loads the repo-level shared contracts directly as Flutter assets:

- `shared/app-contracts/fixtures/`
- `shared/design/tokens.json`

`shared` is a symlink to the repo-level `../../shared` directory. Keep the repo-level
files as the source of truth. Do not copy fixture JSON into this app.

## Commands

```bash
flutter analyze
flutter test
flutter build macos --debug
```

Run commands from this directory. The generated macOS app is only a fixture viewer; it is
not a playable Kolkhoz client.
