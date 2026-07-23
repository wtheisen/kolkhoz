# Static hero raster underlays

Status: production Flutter underlays, generated 2026-07-22. These three images are
the raster source of truth for the static Brigade, Fields, and North gameplay panels.

All three underlays were generated with the built-in Codex image generator. The
canonical 1930s agricultural poster was the style authority; the earlier three-panel
mockup was composition guidance only. Native outputs were `1942 x 809` and were
normalized without cropping to the locked `1920 x 800` (12:5) logical aperture.

Shared constraints for every prompt:

- card-free Flutter environment underpaint;
- centered 86% action-safe area;
- early Soviet lithographic poster design;
- cream, charcoal, scarlet, pale green, olive, and ochre structural palette;
- hard geometric planes, aged paper, halftone grain, slight ink misregistration,
  diagrammatic infrastructure, and long printed shadows;
- no cards, books, placards, text, numbers, UI, hand tray, border, logo, or watermark;
- no photorealism, glossy rendering, soft gradients, or modern objects.

## Brigade

- Runtime file: `app/assets/art/field_plan/game/backgrounds/static-hero-brigade-underlay-v1.png`
- Built-in source: `exec-d116d094-14ba-4733-9c89-0a1c1a32084e.png`
- Prompt: Create one ultra-wide collective-farm Brigade landscape with exactly four
  irregular plots in a 2x2 composition around an unmistakable communal trick plaza.
  Cream roads radiate toward the plaza. Put an industrial collective-farm skyline,
  bridge, power lines, tiny workers, tractors, trucks, machinery, and sparse
  infrastructure on the horizon and margins. Reserve broad clean live-card landing
  zones in every plot and at the communal center; keep people and vehicles away from
  those five zones. Avoid fenced generic plots and near-overhead board rendering.

## Fields

- Runtime file: `app/assets/art/field_plan/game/backgrounds/static-hero-fields-underlay-v1.png`
- Built-in source: `exec-ba6e4157-1a36-4d3a-98b6-2bc90b49f5d3.png`
- Prompt: Create one ultra-wide job-assignment landscape with exactly four monumental
  crop fields in a 2x2 arrangement: wheat, beet, sunflower, and potato. Express crop
  identity through the land itself rather than fences. Cream roads divide and connect
  the planes; a modest farm complex, windmill, silo, power lines, tractors, trucks, and
  tiny workers occupy the horizon and margins. Keep quiet upper-middle card zones and
  place crop motifs mainly along lower or outer field edges. Leave small clear edge
  areas for live progress placards.

## North

- Runtime file: `app/assets/art/field_plan/game/backgrounds/static-hero-north-underlay-v1.png`
- Built-in source: `exec-2e0d2234-2575-4aa2-b823-b9c4ac5aa991.png`
- Prompt: Create one ultra-wide severe snowy northern archive with exactly five long
  horizontal wooden barracks stacked in physical depth, each with a broad dark roof and
  restrained scarlet facade. Keep generous clear central roof zones for overlapping
  live cards and clear left roof edges for live year plaques. A strong foreground
  railway converges toward a distant watchtower and tiny train; add snow wedges,
  telegraph poles, hard fences, sparse black conifers, utility sheds, and tiny workers.
  The camp must read as one poster landscape, not five UI rows or a colossal prison.

## Production contract

The underlays remain indivisible 1920 x 800 assets. Flutter owns every live card,
label, selection state, legal target, and action above them. Production screenshots
and widget tests live under `app/test/static_hero_production/`; the standalone lab is
only a quick raster-composition sandbox. No Figma promotion or depth-card segmentation
is required for this static-panel path.
