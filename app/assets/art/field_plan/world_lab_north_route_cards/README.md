# North route terrain cards

Twelve transparent, persistent world-space terrain cards used by the world-depth lab.
They replace the earlier RM18-RM38 full-screen crossfade proof.

The cards were authored against vanishing-point Y `0.40`. Flutter applies the one-time
`+0.11625H` (`+93 px` in the 1920 x 800 aperture) registration migration required by
the current Y `0.51625` horizon. RM40 is already registered to the current camera and is
not shifted.

- A01-A04: warm agricultural country
- A05-A08: cooling fields and intermittent snow
- A09-A10: deep snow country
- A11-A12: forest foothills before RM40

The railway is intentionally absent. Flutter owns one continuous registered route spine.
RM40 remains the terminal anchor and depth-card stack. These are proof exports; Figma
component IDs are recorded in `manifest.json` after synchronization.

Runtime paints the complete A01-A12 terrain stack first, then the road underlay, the
complete railway pass, and finally the station overlay. Do not interleave individual
railway segments with individual cards: nearer cards hide the station-side rail and make
the road-station-track handoff appear vertically detached. Keeping the station separate
also prevents the track from painting across its facade. The compact station and its road
sit to the left of the railway instead of spanning the route, so the rails remain visible
through the foreground and the two approach paths meet beside the platform.

`a09-valley-floor-proof.png` is a supplemental plate registered to A09 at the same
world Z. It fills the otherwise empty deep-snow basin beneath the programmatic railway
without creating a thirteenth terrain card or baking route geometry into the art. It is
a Flutter motion proof pending promotion to an editable Figma component; A09's original
side-hill plate remains unchanged. Flutter dynamically registers the basin's top edge two
pixels below the projected RM40 hut ground contact. It paints after RM40 snow and forest
but before the hut, foreground, A01-A12 terrain, and route overlays.

Generation and chroma-removal provenance lives in
`research/runs/world_depth/north_route_cards_20260716_203435_EDT/`.

The supplemental valley-floor generation prompt and provenance are recorded in
`VALLEY_FLOOR_PROMPT.md`.
