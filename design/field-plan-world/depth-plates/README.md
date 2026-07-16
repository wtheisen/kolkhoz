# World depth plates

Read [`../DEPTH_CARD_PIPELINE.md`](../DEPTH_CARD_PIPELINE.md) before using this historic
seven-band reference. The current contract distinguishes raster masters, depth cards,
plates, mattes, underpaint, and route-spine layers and makes Figma the art source of
truth.

Figma working file: [Kolkhoz 2.5D World Depth Layers](https://www.figma.com/design/MQdTuEmeZVkWS79EJcLEOF)

The production Flutter app does not reference this directory. Keep exports here until
the depth-camera prototype is approved, then copy only the selected runtime plates into
Flutter-owned assets.

`world-depth-plates-v1.svg` is an editable vector reconstruction of the supplied
single-image world. It is not a crop or mask of that reference.

The SVG uses a logical `1000 × 2108` coordinate system only to preserve the
reference aspect and provide shared registration. It does not prescribe an export
resolution. Every top-level `Pxx_*` group contains a nearly transparent full-canvas
registration rectangle and owns one overlapping depth band:

| Group | Depth range | Content |
| --- | --- | --- |
| `P00_SKYLINE_FAR_NORTH` | `0.00–0.09` | skyline and North label |
| `P10_NORTH_WORKS` | `0.05–0.21` | compound, barracks, fences, towers |
| `P20_RIVER_UPPER_FARMSTEADS` | `0.16–0.31` | river, bridge, trees, farmsteads |
| `P30_UPPER_FIELDS` | `0.26–0.47` | wheat and sunflower fields |
| `P40_LOWER_FIELDS` | `0.42–0.69` | potato and beet fields |
| `P50_PLOT_HUB` | `0.64–0.88` | four fenced plots and central office |
| `P60_FOREGROUND_FARM_EDGE` | `0.83–1.00` | foreground farms, people, cow |

The overlap is deliberate. Flutter should move these as depth planes around the
center-road registration spine and should not expose hard horizontal slice seams.
The final paper grain is a separate, non-semantic overlay and can be omitted from
individual exports.

When importing to Figma, preserve the seven named groups as separate layers. Export
transparent PNG or WebP plates at whatever scale the runtime calibration requires;
do not bake cards, labels, controls, or live state into the exports.

The current Figma node mapping is:

| Plate | Figma layer | Vector art |
| --- | --- | --- |
| P00 | `7:6` | `11:29` |
| P10 | `7:7` | `11:45` |
| P20 | `7:8` | `11:87` |
| P30 | `7:9` | `11:171` plus crop overlay `12:2` |
| P40 | `7:10` | `11:211` plus crop overlay `12:410` |
| P50 | `7:11` | `11:250` plus crop overlay `13:2` |
| P60 | `7:12` | `11:306` |
