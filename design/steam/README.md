# Steam artwork

## Header capsule

`drafts/header-capsule-composition-v1.png` is the approved generated
composition. `drafts/header-capsule-precise-cards-v3.png` replaces its two
generated number cards with deterministic marketing cards using exact pip
layouts and suit assets from the production Flutter card renderer.
`exports/header-capsule-920x430-v3.png` is the current exact-size Steam review
export. It is not yet upload-ready.

The earlier `precise-cards-v1` and `precise-pips-v2` files are retained as
rejected comparisons. The first used mismatched production templates; the
second exposed rectangular repair panels instead of rebuilding each card.

Before export:

- verify the title is exactly `КОЛХО́З`, with the stress mark over the second
  `О`;
- inspect the result at Steam thumbnail size.

Rebuild the precise-card master and Steam-size export with:

```bash
cd app
flutter test --update-goldens \
  --dart-define=KOLKHOZ_ART_STYLE=field_plan \
  test/steam_card_face_render_test.dart
cd ..
python3 design/steam/tools/compose_header_capsule.py
```

`reference/kolkhoz-poster-style-source.png` is the stylistic source of truth.
Use its fresh-print design language: bright spot colors, hard geometric planes,
severe perspective, diagrammatic agricultural detail, and editorial collage.
Do not imitate physical aging, fading, foxing, or washed-out paper.
