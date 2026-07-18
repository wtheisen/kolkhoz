# North route terrain cards

Twelve transparent, persistent world-space terrain cards used by the world-depth lab.
They replace the earlier RM18-RM38 full-screen crossfade proof.

- A01-A04: warm agricultural country
- A05-A08: cooling fields and intermittent snow
- A09-A10: deep snow country
- A11-A12: forest foothills before RM40

The railway is intentionally absent. Flutter owns one continuous registered route spine.
RM40 remains the terminal anchor and depth-card stack. These are proof exports; Figma
component IDs are recorded in `manifest.json` after synchronization.

`a09-valley-floor-proof.png` is a supplemental plate registered to A09 at the same
world Z. It fills the otherwise empty deep-snow basin beneath the programmatic railway
without creating a thirteenth terrain card or baking route geometry into the art. It is
a Flutter motion proof pending promotion to an editable Figma component; A09's original
side-hill plate remains unchanged and paints above the supplement.

Generation and chroma-removal provenance lives in
`research/runs/world_depth/north_route_cards_20260716_203435_EDT/`.

The supplemental valley-floor generation prompt and provenance are recorded in
`VALLEY_FLOOR_PROMPT.md`.
