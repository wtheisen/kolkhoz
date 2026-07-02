# Kolkhoz App Contracts

This directory defines the first shared contract layer for native Kolkhoz clients.
It is not a rules engine and it is not a UI DSL.

## Layers

```text
C engine contracts
  portable actions, legal actions, snapshots, replay, save/restore, online validation
    |
    v
Presentation contract
  platform-neutral table view model and UI interaction state
    |
    v
Native renderers
  SwiftUI iOS now; Flutter for Android, macOS, Windows, and Linux later
```

The C engine owns game truth. The presentation contract owns renderer-neutral UI state
truth. Native clients own pixels, gestures, accessibility, and platform conventions.

## Files

- `schemas/table-view-model.schema.json` documents the platform-neutral table view model.
- `fixtures/*.json` are canonical states for SwiftUI and future Flutter fixture rendering.

## Contract Rules

- `contractVersion` changes when the JSON shape changes incompatibly.
- `engineBoundary.snapshotRevision` should track the C/Swift snapshot shape that was used
  to build the view model.
- `legalActions[].engineAction` is the payload that must round-trip to the C engine or
  server. Clients may display labels or prompts, but they must submit engine actions.
- Hidden information must be redacted before it enters a viewer-specific view model.
- `selection`, `disabled`, `highlighted`, and `pending` are presentation state. They do
  not make an action legal unless the matching engine action is present.
- Panel names mirror current native app concepts: `brigade`, `jobs`, `plot`, `north`,
  `options`, and `rules`.

## Renderer Guidance

SwiftUI remains the visual reference. Flutter should render these contracts with native
Flutter widgets and shared tokens from `../design/tokens.json`. Do not base new clients
on the removed web app, and do not add React/Vite/npm packaging back to the repo.

