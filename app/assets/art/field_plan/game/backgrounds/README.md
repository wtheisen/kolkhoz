# Field-Plan Gameplay Backgrounds

`trick-field-light.png` is the light-mode environmental plate for the trick area. It is
a 1672 x 941 RGB landscape asset rather than a 512 x 512 pictogram because it must retain
detail across the full gameplay surface.

The plate contains only environment: four continuous agricultural parcels, connecting
roads, distant fields, farm infrastructure, equipment, utilities, and small ordinary
workers for scale. Flutter must overlay cards, player identity, state, controls, and all
live text.

The composition targets the full 16:9 board rather than the post-rail content rectangle.
The leftmost 11 percent is a low-detail paper and distant-landscape safety zone for the
60-72 px Flutter board rail. The four playable parcel centers sit in the remaining area.
Top, right, and bottom edge scenery is expendable under responsive cropping; parcel
boundaries and distant landmarks stay inset.

## Card perspective calibration

To align the four played-card homographies against the painted parcels, run:

```bash
cd app
python3 tool/field_plan_calibration_overlay.py --serve
```

The local page shows the current Flutter screenshot and lets each card corner be dragged
in screenshot coordinates. A horizontal guide flashes when top or bottom edge points
align within three screenshot pixels. It previews the warped cards and emits a complete
`fieldPlanCardQuad` Dart snippet normalized to the four Flutter card slots. The static
PNG comparison remains available by running the script without `--serve`.

Composition reference: the approved integrated Field Plan trick mockup. Prompt direction:
early-1930s agricultural publishing illustration and technical field-plan diagram; muted
color lithograph; calm parcel centers; detail concentrated at roads, boundaries, and the
distant horizon. Do not add card holders, blank UI plates, labels, meters, portraits, or
controls to the environment asset.
