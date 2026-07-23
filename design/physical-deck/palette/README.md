# Canonical poster palette

This folder translates the canonical poster reference into reusable solid design
inks for the physical deck. The source poster is a scan, so its paper grain,
registration noise, and isolated discoloration are not palette colors.

The six core colors should carry most artwork:

- Paper cream `#F5D19A`
- Harvest gold `#E9B353`
- Field green `#B7B34A`
- Poster red `#E13212`
- Slate charcoal `#58595B`
- Ink black `#120E08`

Four support colors are available for highlights and secondary fills:

- Sunlit yellow `#F1C667`
- Deep olive `#7B794A`
- Earth brown `#754E2F`
- Workwear gray `#93876A`

Use the colors as flat inks first. Apply print grain, small registration variation,
or paper texture afterward. Do not simulate age by washing every fill toward beige;
that is what made earlier face-card generations look weak beside the suit artwork.

For a single face-card figure, start with paper cream, ink black, one dominant core
color, one secondary core color, and at most two support colors. Reserve poster red
for a small focal accent.

Machine-readable values and role descriptions live in
`canonical-poster-palette-v1.json`. Web tooling can import
`canonical-poster-palette-v1.css`.
