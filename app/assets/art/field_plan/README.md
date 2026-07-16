# Field-Plan Art Assets

World raster masters, depth segmentation, Figma card ownership, and runtime plate exports
follow `design/field-plan-world/DEPTH_CARD_PIPELINE.md`. Read that contract before adding
or replacing anything under `world_depth/`.

This is the incremental non-pixel asset family described in
`agent-docs/NEW_VISUAL_DESIGN.md`.

Build it with:

```bash
cd app
./builder.sh --new-art
```

The legacy build remains the default. New widgets pair generated and legacy assets with
`ArtAssetRef`; `ArtAssetImage` falls back automatically when new art is missing or fails
to decode. Never move or overwrite `assets/ui/` during migration.

```text
shared/   fonts, paper, crop marks, status marks, and common pictograms
ledger/   menu underlays, navigation, tabs, stamps, and report illustrations
game/     cards, players, fields, roads, buildings, and phase illustrations
```

## Rules

- Generate pictograms and illustrations with the image generator.
- Generate new source artwork and production pictograms at 512 x 512.
- Keep text live in Flutter.
- Use semantic filenames rather than mirroring the old tree.
- Prefer transparent PNG/WebP for illustrations.
- Keep texture separate from semantic icons.
- Use code-native drawing only for layout and semantic state such as focus, selection,
  progress, and boundaries.
- Verify the smallest supported landscape size before adding detail.
- Record source provenance and prompts for each production batch.
