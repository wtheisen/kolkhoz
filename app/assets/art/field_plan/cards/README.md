# Field-Plan Card Art

This directory contains the parallel light-mode card artwork selected by
`KOLKHOZ_ART_STYLE=field_plan`. Until a complete card family exists, card rendering must
fall back to the corresponding asset under `assets/ui/Cards/`.

## Suits

`suits/` contains 256 x 256 transparent crop emblems designed to remain legible at small
corner-index and counter sizes:

- `suit-wheat.png`
- `suit-sunflower.png`
- `suit-potato.png`
- `suit-beet.png`

## Faces

`faces/` begins the 512 x 512 transparent court-card portrait family. The first batch is
the four suit-specific Jacks:

- `face-jack-wheat.png`
- `face-jack-sunflower.png`
- `face-jack-potato.png`
- `face-jack-beet.png`

The art direction is ordinary early-1930s agricultural workers rendered like practical
handbook and muted color-lithograph illustrations. Avoid flags, medals, political
leaders, invented folk costume, military styling, and monumental heroic poses.

All eight source images were independently generated on flat magenta, processed with
`remove_chroma_key.py`, downsampled, and validated for a full alpha range.
