# Kolkhoz World-Depth Workbench

The production terminology, Figma page architecture, raster-master workflow,
resolution/aspect-ratio status, and source-of-truth rules live in
`design/field-plan-world/DEPTH_CARD_PIPELINE.md`. Read that contract before starting a
new master, segmentation, inpainting, Figma, or runtime-plate task.

## Purpose

This workspace evaluates tools and art-production techniques for a continuous 2.5D dolly:

```text
Menu -> Brigade houses and plots -> Fields -> North
```

North is the terminal, deepest view. The camera approaches North and stops before it; it
does not pass through the final North background.

The workbench is deliberately isolated from gameplay. It may generate draft depth maps,
mattes, comparisons, and parallax previews. It does not directly replace Figma plates or
Flutter assets.

## Mental Model

| Art term | Engineering translation |
| --- | --- |
| Plate | Registered transparent sprite on a world-space plane |
| Matte | Per-pixel alpha mask |
| Depth band | Objects sharing an approximate Z value |
| Parallax | Screen-space motion caused by different Z values |
| Inpainting | Reconstructing pixels hidden by nearer objects |
| Composition | Spatial layout plus attention priority |
| Silhouette | Boundary of a segmented object |
| Vanishing point | Screen projection of the forward world axis |

More depth cards provide finer depth quantization only when their contents need visibly
different parallax or occlusion. A single raster master will often yield roughly 5-10
cards, but depth evidence, semantic integrity, disocclusion, and motion determine the
actual count. The renderer should remain count-agnostic.

## Authority Boundaries

- Flutter's world lab owns the final camera projection and continuous-motion validation.
- Figma owns editable plate assembly, registration, naming, and static composition review.
- This workspace owns offline estimation, draft matte generation, and comparison evidence.
- Production art remains under `app/assets/art/` and may change only through an explicitly
  approved production-art task.

## Camera Contract

`camera_contract.json` contains candidate values until the camera-calibration task marks
them locked. Research may use the candidate contract for diagnostic previews, but reports
must label those previews non-authoritative while its status is `candidate`.

The camera, not an individual illustration, establishes the shared vanishing point,
horizon, focal behavior, and movement along the global Z axis.

## North Source of Truth

The only source image for the initial bake-off is:

```text
app/assets/art/field_plan/game/backgrounds/north-light.png
```

It is a 1672 x 941 PNG. Do not substitute Figma screenshots, `world_depth/n00.png`, build
copies, or `north-year-*` variants.

North is a good first experiment because it is the terminal composition and the next
region to separate. Its expected semantic bands are summarized in `north_bakeoff.json`.

## Initial Experiment

Compare three current monocular-depth approaches on the single North source:

1. Depth Anything V2 Small
2. Apple Depth Pro
3. Marigold

This is a bake-off, not a runtime integration or model-training project. Do not fine-tune
models. Do not ship model weights. Verify repository and checkpoint licenses from their
official sources at the pinned revision.

For each successful model, preserve raw depth, normalize it to `0 = far` and `1 = near`,
and produce:

- a 16-bit grayscale depth map and color visualization;
- 5, 8, and 12-band equal-range and quantile quantizations;
- one alpha matte per band;
- source/depth comparisons and boundary overlays;
- evaluation crops defined in `north_bakeoff.json`;
- a crude five-band parallax preview;
- a self-contained HTML report copied into the ignored run directory.

The preview may expose holes and duplicated edges. Those failures reveal where background
inpainting or semantic correction is required.

## Evaluation Questions

- Does the model order mountains, forest bands, isolated trees, and foreground correctly?
- Are tree/snow and shadow boundaries useful enough to seed mattes?
- Does the open central approach remain a coherent surface?
- Does paper grain become false high-frequency depth?
- Do individual objects fragment across several bands?
- Does the output support semantic plates rather than arbitrary horizontal slices?
- How much manual correction would remain?

Generic depth benchmarks do not answer these questions. The report must show source-space
evidence.

## Output Contract

Generated results belong under:

```text
research/runs/world_depth/north_depth_bakeoff_<timestamp>/
```

That directory is ignored. Reusable code and focused tests may live in this workspace.
Use `report/index.html` as the standalone manager viewer or copy it into a run directory
and embed the run's results there.

## Decision Gate

The manager session should be able to choose one of four outcomes:

1. abandon automatic depth for this illustration style;
2. use one estimator only for draft depth ordering;
3. combine estimator depth with semantic/object masking;
4. run one additional narrowly justified experiment.

No output advances to Figma or production assets without that explicit decision.
