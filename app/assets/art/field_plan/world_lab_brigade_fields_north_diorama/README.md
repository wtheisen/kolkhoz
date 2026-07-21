# Brigade–Fields–North diorama lab assets

These are Flutter motion-prototype assets, not authoritative production depth
cards. Promote approved art through the Figma/depth-card pipeline before using
it in the production world stack.

## `north-barracks-v1.png`

- Status: world-lab draft
- Generated: 2026-07-20 with the built-in image-generation tool
- Style references: `world_lab_rm40_y0/forest.png` and
  `world_lab_brigade_fields_diorama/farm-building-v1.png`
- Source: `north-barracks-chroma-v1.png`
- Processing: flat green background removed with the image-generation skill's
  chroma-key helper using soft matte and despill

Prompt summary: one extremely wide, low, single-story Soviet timber labor-camp
barracks viewed from a moderately elevated oblique angle, rendered as a
restrained 1930s agricultural lithograph with muted navy/charcoal/gray-brown
ink, aged paper texture, economical geometry, sparse roof snow, small repeated
windows, one plain door, and no people, landscape, signage, symbols, shadow, or
modern infrastructure. The building was isolated on a uniform green key color
for extraction and authored to support repeated receding year rows with
overlapping physical playing cards.

## Projected texture derivatives

`north-barracks-front-texture-v1.png` and
`north-barracks-roof-texture-v1.png` are rectangular source-pixel crops of the
draft asset. Flutter projects them as independent front and roof planes against
the locked `1920 x 800` North horizon. Playing-card spreads use a third
projected plane on the roof. The original generated perspective is therefore
reference material only; runtime geometry owns the visible perspective.
