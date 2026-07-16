# Raster depth-layer reconstruction

Read [`../DEPTH_CARD_PIPELINE.md`](../DEPTH_CARD_PIPELINE.md) first. It is the current
production contract for terminology, Figma ownership, master-page organization,
depth-card extraction/inpainting, ordering, and the unresolved viewport/aspect-ratio
decision. This directory contains earlier reconstruction sources and should not override
that contract.

This is the isolated source-art workspace for rebuilding the three approved Field Plan
raster scenes as independently movable depth plates. The existing raster scenes are the
visual source of truth. The tall historic poster is not an art-direction source for this
work.

## Scope

- Reconstruct `brigade-plot-light-v10.png`, `fields-light-v2.png`, and
  `north-light.png` as registered semantic layers.
- Preserve each scene's palette, print texture, perspective, horizon, central axis, and
  composition.
- Paint complete terrain behind extracted structures and crops so plates can separate
  without holes.
- Keep all layers registered to the current camera contract while the canonical logical
  aspect ratio remains under review. Do not assume the legacy 16:9 canvas is the final
  production aperture.
- Keep editable source artifacts here. Runtime exports are generated into Flutter-owned
  assets by the sync command below.

Not in this pass: finished connector scenery, live cards, controls, or production-board
integration.

## Figma to Flutter pipeline

Figma page `02 - Depth Panels`, frame
`WORLD CAMERA VIEW · Toggle Individual Depth Layers` (`22:3`), is the runtime export
source. Direct visible children must use:

```text
PLATE_ID · Z 0.00 · Semantic Name
```

From `app/`, run:

```bash
FIGMA_ACCESS_TOKEN=... dart run tool/sync_world_depth_plates.dart
```

The token needs Figma's `file_content:read` scope. The command validates the required
ten-layer base stack, preserves Figma child order, exports each frame as a registered
transparent PNG, and atomically replaces
`app/assets/art/field_plan/world_depth/manifest.json` plus its images. Additional
semantically named connector plates are allowed; missing or renamed base plates fail the
sync.

`app/tool/run_field_plan_world_lab.sh` always syncs before launching. The first time, pass
`FIGMA_ACCESS_TOKEN`; on macOS the launcher stores it in Keychain under
`com.kolkhoz.figma.world-depth` and retrieves it automatically on later runs. An explicit
environment token still takes precedence. The launcher fails when no token is available
instead of silently building stale plates.

## Scene packages

- `brigade/plate-map.json`
- `fields/plate-map.json`
- `north/plate-map.json`

Each package contains an ownership blockout and a physical dolly-stack SVG. Physical
planes use full-canvas registration but paint only their owned depth band, so the camera
can pass every plane without encountering an opaque full-frame wall.

## Earlier editable dolly stack reference

Figma page `03 · Editable Dolly Stack` and the SVGs below are earlier physical-stack
references. They are not the Flutter export authority. That page contains two views:

- `REGISTERED COMPOSITES` overlaps each scene's planes at the source camera framing.
- `ACTUAL STACK · CAMERA DOLLIES LEFT → RIGHT` places all fifteen planes on one
  global world-Z rail so spacing and order can be manipulated directly.

The physical structural sources are:

- `brigade/brigade-dolly-plates.svg`
- `fields/fields-dolly-plates.svg`
- `north/north-dolly-plates.svg`

The earlier fifteen-plane travel order was:

```text
Brigade camera Z 0.00
  B40 0.35 -> B30 0.70 -> B20 1.05 -> B10 1.40 -> B00 1.75

  connector gap

Fields camera Z 3.00
  F40 3.35 -> F30 3.70 -> F20 4.05 -> F10 4.40 -> F00 4.75

  connector gap

North camera Z 6.00
  N40 6.35 -> N30 6.70 -> N20 7.05 -> N10 7.40 -> N00 7.75
```

The live ten-layer base stack intentionally omits speculative bands from that earlier
model. Do not restore them unless they acquire a concrete visual purpose in the current
Figma camera frame.
