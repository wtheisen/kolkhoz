# Field Plan multiplane world and depth-card pipeline

This document is the durable production contract for turning finished scene artwork into
the scrollable Kolkhoz world. Read it before changing the Figma world file, generating a
new raster master, running depth estimation, producing depth cards, exporting runtime
plates, or changing the world-camera viewport.

## Goal

Build one continuous 2.5D journey:

```text
Menu -> Brigade houses and plots -> Fields -> station -> railway ->
rolling farms and hills -> increasingly snowy country -> Siberian forest and camp
```

The player should be able to dolly past the near world rather than merely zooming into a
single flat background. The current mixed procedural/raster stack is visually rough, but
it is the correct structural baseline: near cards occlude deeper cards, the railway is a
continuous spatial spine, and the full route can be tested before finished art exists.

## Vocabulary

Use these terms consistently:

| Term | Meaning |
| --- | --- |
| **Multiplane world** | The complete scrollable 2.5D scene made from registered planes. |
| **Raster master** | One finished, full-scene reference image used for composition, style, depth estimation, and extraction. |
| **Camera station** | One materially distinct view along the route. A distant approach and a close terminal view are separate camera stations even when they depict the same place. |
| **Depth map / estimate** | A continuous per-pixel estimate of relative distance. Research normalizes it to `0 = far`, `1 = near`. |
| **Depth segmentation** | The semantically corrected partition of a depth map into useful planes. |
| **Matte / mask** | The exact per-pixel alpha ownership for a region. |
| **Depth card** | One world-space plane that the camera can approach and pass. This is the preferred term for the scroll-passable unit. |
| **Plate** | The raster artwork registered to a depth card. |
| **Underpaint** | A completed far background that prevents holes behind all nearer cards. It may be procedural, raster, or a registered combination of both. |
| **Procedural atmosphere** | A deterministic runtime-rendered sky, color, and print-grain layer. It is registered in Figma but is not exported as a unique scene raster. |
| **Disocclusion** | Previously hidden artwork revealed when a nearer card moves away. |
| **Infill** | Reconstructed artwork for a disoccluded area. |
| **Bleed** | Extra artwork beyond the initially visible mask edge, needed for motion. |
| **Route spine** | A continuous special element, currently the road/station/railway route, that must remain registered across the world. |

Do not use *plate* to mean an entire scroll stop, a depth estimate, or an arbitrary crop.

## Authority and ownership

### Figma is the art source of truth

Figma file: [Kolkhoz 2.5D World Depth Layers](https://www.figma.com/design/MQdTuEmeZVkWS79EJcLEOF)

Figma owns:

- raster-master organization and approval;
- editable card artwork, masks, registration, names, and world-Z metadata;
- component ownership for each approved card;
- the authoritative global card order and static composite review.

An image in `research/runs/` or `app/assets/` is not independently authoritative. Every
approved card must be traceable to a canonical Figma component and must appear in the
global Figma stack.

### Research is a workbench

`research/world_depth/` owns raw depth estimation, draft quantization, matte generation,
inpainting experiments, comparisons, and evidence. Outputs under `research/runs/` are
ignored working artifacts. They do not become world cards merely because they look good
or run in the demo.

### Flutter owns motion validation

Flutter owns projection, camera travel, parallax, occlusion behavior, device layout, and
continuous-motion validation. Runtime files under
`app/assets/art/field_plan/world_depth/` are exports/derivatives of the Figma contract.
They are not a second editable art source.

## Required Figma page architecture

Figma design files do not provide nested pages, so use numbered pages and clear sections.

### `00 · Raster Masters`

A contact sheet containing every approved or active raster master in world-travel order.
Masters must be separated, never overlaid. Each entry should show:

- stable master ID and route label;
- status: draft, approved for segmentation, or superseded;
- source/provenance and generation prompt link;
- logical registration size and native raster size;
- route interval or intended camera stop.

### One page per raster master

Name pages in route order, for example:

```text
MASTER · 03 · Fields Station
```

Each master page contains:

1. untouched raster master;
2. raw depth estimate;
3. normalized/corrected depth map;
4. candidate depth-band visualizations;
5. final semantically corrected segmentation;
6. one exact matte per selected card;
7. extracted source pixels for each card;
8. disocclusion/infill and bleed working art;
9. final card components with world-Z metadata;
10. a registered composite and motion-review notes.

The final card component on this page owns the editable artwork. Do not maintain an
unlinked duplicate on another page.

### `Depth Cards`

This is the complete global dolly assembly. It contains instances of every approved card
component from every master page.

- All instances share one registration/camera frame.
- Every card is individually visibility-toggleable.
- Far artwork renders beneath near artwork.
- Figma lists frontmost layers first, so the Layers panel reads near/start at the top and
  far/destination toward the bottom.
- The underpaint is at the back.
- Procedural underpaint owners appear as named toggleable Figma groups or components;
  do not flatten them into scene-specific raster plates merely to fit the stack model.
- A continuous route-spine card may have special projection semantics, but it must remain
  visually registered with every contributing master.
- Depth estimates, comparison grids, prompts, and rejected variants do not belong here.

The master page is authoritative for a card's art. The world-stack page is authoritative
for the complete order and assembly. Component instances prevent those two views from
drifting.

As of 2026-07-17, frame `225:3` on the `Depth Cards` page is the canonical new-pass
assembly. It contains the twelve A01-A12 station-to-North approach cards, the valid RM40
Y0 terminal layers, and explicit named owners for the programmatic sky, ground
underpaint, and railway route spine. The obsolete baked railway raster is not part of
this stack.

### `Old Depth Cards`

This page is a non-destructive archive of the earlier mixed structural proof. Frame
`22:3` preserves the superseded DC01-DC07 cards, the old Menu/Brigade/transition layers,
the earlier route raster, and copies of the new-pass layers as they appeared at the time
of the split. It is reference material only:

- do not export runtime art from this page;
- do not add newly approved cards here;
- do not use its layer order as the current world contract;
- do not delete it while older experiments or screenshots still refer to its node IDs.

## Raster-master to depth-card pipeline

Use this sequence for every raster master:

```text
approved raster master
    -> raw monocular depth estimate
    -> normalized depth plus semantic correction
    -> edge-aware depth segmentation
    -> exact mattes
    -> original source-pixel extraction
    -> disocclusion inpainting and edge bleed
    -> authoritative matte reapplied
    -> Figma card components
    -> instances in the global world stack
    -> Flutter dolly validation
```

### 1. Approve one coherent master

The master establishes composition, palette, visual language, major silhouettes, horizon,
vanishing point, and route topology. It is not yet a set of runtime cards.

A depth-card stack provides local parallax and disocclusion around the camera station
shown by its raster master. It does not create unlimited forward travel or turn a tiny
distant destination into a close terminal view. Whenever the camera must materially
advance until the same landmark has a different framing, scale, or foreground
relationship, author another registered raster master for that camera station. For
example, the zoomed-out snowy approach to North and the close camp-at-the-forest
terminal backplate are separate masters. Define their overlap and route-spine
registration explicitly so Flutter can transition between them without a scale pop.

Do not manufacture a new full-scene raster master for every hill merely to make a journey
feel long. Full masters are sparse anchor views: they lock art direction, route
registration, and materially different terminal framing. Travel through the land comes
from persistent world-space terrain cards positioned at successive Z depths. Those cards
remain visible together, scale independently, occlude one another, and leave the frame
after the camera passes them. A full-master crossfade is not a substitute for travel.

The current station-to-camp proof uses twelve approach terrain cards arranged as six
left/right pairs, followed by the RM40 terminal stack. The intermediate RM18-RM38 images
are route storyboards and palette references, not runtime full-screen plates. The
railway remains one continuous route-spine owner rather than being baked independently
into each terrain card.

Railway surface art may be modular without becoming a second route owner. The current
proof repeats one alpha raster sleeper/fastener/ballast tile at stable world-space
positions while the programmatic spine owns the continuous rail centerline, perspective,
station boundary, and terminal endpoint. Do not tile a complete screen-space railway;
that bakes perspective and produces stepped or misregistered rails during travel.

Time progression is a separate axis from camera distance. Do not treat years as depth
cards. When progression is mostly additive, prefer one registered base master plus
reusable world-space growth components over several near-identical full rasters. Figma
owns the component art and the six state composites; runtime code owns deterministic
instance visibility and transforms. If a year truly changes the entire atmosphere or
terrain, use a registered year-state raster-master variant instead. In either case,
keep the camera, route spine, horizon, surviving landmarks, and reused card boundaries
registered so switching years does not create a scale, parallax, or silhouette pop.

Avoid repeated whole-image generative passes. Each pass can soften registration, simplify
small objects unpredictably, and accumulate blurry or embossed artifacts.

### 2. Estimate continuous depth

Preserve the raw estimator output before normalization or quantization. Depth estimation
is evidence, not final ownership. Paper grain, shadows, repeated trees, and stylized flat
shapes can create false depth.

### 3. Choose a useful card count

Do not decide in advance that every master has eight cards. A typical master is expected
to yield roughly 5-10 cards, but the actual count comes from:

- meaningful depth discontinuities;
- maximum acceptable parallax/reprojection error over the camera move;
- semantic integrity (do not split one house or tree across cards);
- occlusion and the amount of newly revealed surface;
- minimum useful region size;
- route, station, and railway continuity;
- motion review after the first extraction.

Do not use equal-width horizontal slices or equal grayscale bins as the final answer.
Estimator quantizations are candidates that must be merged, split, and corrected around
objects and silhouettes.

### 4. Extract source pixels

The visible pixels on each card come from the approved master whenever possible. Do not
ask the image generator to recreate every card independently from a blank mask; doing so
causes inconsistent houses, colors, texture, perspective, and railway registration.

Do not extract a unique sky raster when the scene only needs a flat printed atmosphere.
Use the shared procedural sky owner: a registered color field, repeatable paper texture,
and deterministic sparse cloud marks. Treat master sky pixels as palette, registration,
and cloud-shape reference rather than a required exported plate. Keep ground behind the
horizon as a separate owner so clearing a forest reveals snow below the horizon, not sky.

### 5. Reconstruct hidden pixels

For every card, remove nearer ownership and reconstruct the surface that plausibly
continues behind it. Generate enough bleed for the card's full projected motion, not just
for its source-camera silhouette.

The image generator supplies missing artwork. It does not own geometry. Give it the
master, target card, matte/outline, style authority, neighboring context, and explicit
invariants. After generation, reapply the authoritative matte or expanded production
matte so the generator cannot move the depth boundary.

### 6. Size cards for their closest view

The master raster's pixel dimensions are not a ceiling for every card. A farm occupying
150 pixels in the distant master may need a much larger working crop before the camera
approaches it. Generate or inpaint tight card crops at the density required by their
largest projected on-screen size, then register those rasters back into the logical
Figma frame.

### 7. Validate in motion

Static Figma toggling checks ownership and composition; it does not prove parallax.
Validate the assembled stack in Flutter across the complete camera range. Split or merge
cards only for visible motion, occlusion, or reprojection failures.

## Composition and art direction that must survive segmentation

The world route is structural, not optional decoration:

- Fields end at the station threshold.
- A dirt road approaches from the foreground and terminates at the station's near face.
- The modest collective-farm station crosses horizontally and divides the scene.
- Railway begins behind the station and continues toward North.
- No railway sleepers appear on the near/Fields side of the station.
- Tracks wind through broad hills, fields, farms, houses, and valleys.
- The agricultural-to-northern transition is gradual, not a sudden snow boundary.
- Terrain becomes progressively more desolate and snowy approaching the forest.
- North is a psychologically looming Siberian forest, not a colossal prison building.
- The forest is gradually cleared for more barracks and a larger work camp over the
  years; the camp remains subordinate to the forest at first.

The approved visual direction is a restrained Soviet-era agricultural print:

- large graphic color shapes and economical silhouettes;
- muted limited palette with warm agricultural fields and colder North;
- aged paper/lithographic character and slightly imperfect registration;
- simple functional rural structures;
- restrained detail that remains stable during motion;
- no photorealism, glossy concept-art rendering, fantasy architecture, modern railway
  infrastructure, signage, labels, UI, logos, or watermarks.

## Resolution, aspect ratio, and safe areas

### Current state

The existing `1672 x 941` frame is a legacy registration size inherited from the earlier
gameplay backgrounds. It is approximately 16:9 (`1672 * 9 / 16 = 940.5`) and was adopted
by the depth experiments and camera calibration. There is no documented device,
performance, image-generation, or print rationale for choosing 1672 specifically.

Do not treat `1672 x 941` as proven production resolution or as the pixel-density ceiling
for card art. Also do not change it casually: current plate-pixel constants, evidence
tests, and exported manifests assume it.

### The hand does not cover the current world scene

The production Flutter layout currently ends `FieldPlanWorldScene` at the top of the hand
tray. The hand occupies separate layout space; it does not normally conceal the bottom of
the environment. The consequence is that the visible world aperture is shorter and wider
than the full device screen.

Current phone-layout tests imply approximate world-aperture ratios of:

| Device test | Approximate aperture | Ratio |
| --- | ---: | ---: |
| Small landscape phone | `667 x 311` | `2.14:1` |
| Standard landscape phone | `852 x 329` | `2.59:1` |
| Large landscape phone | `932 x 366` | `2.55:1` |

A 16:9 master therefore does not naturally match the gameplay aperture. With the current
`BoxFit.contain`, it preserves the full image but can leave unused horizontal space unless
camera scaling or other composition compensates.

### Locked authoring aperture

Separate these three concepts:

1. **Logical registration space**: stable coordinates for camera, masks, and Figma.
2. **Artwork pixel density**: per-master and per-card raster detail.
3. **Runtime export density**: device/performance-specific files loaded by Flutter.

The canonical authoring aperture for new raster masters and depth-card registration is
locked to **12:5 (`2.4:1`)**. Use a **`1920 x 800` logical Figma frame**.

This ratio is derived from the gameplay aperture rather than a video convention. The
current layout rules, applied to the tested phone sizes plus a representative desktop
window, produce an approximate `2.09:1` through `2.79:1` range. A 2.4:1 master centered
in that range limits the widest/narrowest target to roughly 13-14% total crop on one axis
when using cover/overscan behavior:

- at `2.09:1`, approximately 87% of the master width remains visible;
- at `2.79:1`, approximately 86% of the master height remains visible.

Every Figma master page must therefore include a centered **86% width x 86% height action
safe area**. Essential route topology, station threshold, interactive landmarks, and
attention-critical silhouettes stay inside that area. Sky, field edges, foreground
framing, and other expendable scenery provide overscan outside it.

`1920 x 800` is a logical registration frame, not a promise of generator detail and not a
runtime texture-size requirement. Individual cards may use denser rasters based on their
closest projected view. Runtime exports may be smaller or tightly cropped while retaining
the same logical bounds.

The Flutter camera contract was migrated to `1920 x 800` on 2026-07-17. The former
canonical `Depth Cards` frame `225:3` is now empty; the active approach components live
on `CARDS · Station to North Approach` (`209:2`). The `Old Depth Cards` archive and its
earlier near-world rasters remain legacy `1672 x 941` evidence; Flutter may temporarily
scale those old Menu/Brigade/Fields assets while they are replaced, but they are not
production aspect or perspective references. Do not create new production raster masters
in the legacy aspect.

The active normalized vanishing point is `(0.50, 0.51625)`, placing the horizon at pixel
`y = 413` on the `1920 x 800` RM40 authoring plate. This is the selected midpoint between
the upper and lower readable forest/snow seam positions. The fixed North base migrated
with it from the legacy `[836, 394]` anchor to current `[960, 413]`. The earlier `y = 0.40`
belongs to the `1672 x 941` calibration proof, not the current backplate. RM40's railway
terminates inside the camp scene, so extrapolating its finite rail edges also does not
locate the camera horizon.

Pre-RM40 depth cards were authored against normalized horizon Y `0.40`. Register those
cards `+0.11625H` lower (`+93 px` in the canonical aperture) before projection so their
art-space horizon follows the current camera even at a card's 1:1 reference position.
Do not apply that migration to the RM40 terminal cards: they are the current calibration
source and already use Y `0.51625` directly.

### 2026-07-17 motion review notes

The first browser motion pass at the 12:5 aperture found two runtime-only failures that
were not visible in the static Figma composite:

- the approach scene's positioned cards could paint outside a zero-sized background,
  revealing the dark scaffold color around camera Z 6.29; the hybrid scene and its
  internal stacks now receive tight full-frame constraints;
- treating RM40 as a late crossfade left an empty beige interval around camera Z 7.28
  and hid the destination during most of the approach. RM40 is now the persistent
  farthest backplate: it is visible behind every approach card from the beginning and
  reaches full registration at Z 8.05 through projection alone.

The railway route spine was corrected in the following motion pass. One shared
world-space curve now owns the ballast centerline, rail paths, raster sleeper positions,
and sleeper rotation. Lateral bends are attenuated by camera distance, so they compress
near the horizon and open as the camera approaches. The closest visible track point stays
centered while the route winds through the terrain, and the final bend terminates beside
the Y0 utility hut.

Keep the rail `Paint` in explicit `PaintingStyle.stroke`. Flutter's default fill style
implicitly closes an open curved path and creates a large dark polygon; a straight route
can hide that bug. Do not add separate per-card railway curves or independently move the
sleeper tiles.

The active modular sleeper art must contain only one timber and its fasteners. Do not
compress a full track slice into each sleeper position: embedded rail pixels become
upright posts and duplicate the continuous route rails. Draw variable-width rails over
the repeated sleepers so the steel remains continuous and narrows toward the horizon.

The railway is one continuous world-space route, but it must not be composited once
above the completed terrain stack. Split its rendering at the same world-Z midpoint
boundaries as the approach cards. Paint each terrain card, then only the matching route
interval; all nearer cards are painted afterward and therefore occlude that interval.
This makes the railway pass behind hill crests instead of floating over them while
preserving one curve, one set of sleeper positions, and continuous registration.

The ballast underlay is a narrow translucent terrain stain, not an opaque road or
bridge deck. Keep the underlying field or snow visible beneath it. Sleepers and rails
provide the readable track structure; a broad flat ballast polygon makes the route look
detached from the landscape even when its depth ordering is correct.

Continuous review from Fields through Camp found that a single hard-edged ballast stain
still widened into a beige ribbon at close camera positions. The active proof therefore
uses a narrower two-density multiply stain: a faint terrain-colored outer contact and a
slightly stronger inner overstrike. Railway geometry also extends a very small distance
past each terrain-card midpoint before the nearer card occludes it. That overlap closes
sampling hairlines at interval boundaries without creating a second route, duplicating
sleepers, or changing the terrain-first compositing order.

The same review exposed an art gap behind the route around camera Z 6.1-7.5: the A09/A10
side hills left the central snow basin visually empty, so the railway still read against
a smooth underpaint. The current Flutter proof registers a supplemental central
valley-floor plate to A09 at exactly the same world Z. It paints behind A09 and before
A09's railway interval, preserving twelve terrain cards and one programmatic route.
This supplement is runtime motion evidence only until its matte and artwork are promoted
to an editable A09 component on the canonical Figma `Depth Cards` stack.

The World Lab defaults to `NEW PASS ONLY`. Its Legacy history toggle restores the
superseded Menu/Brigade/Fields stack only for registration comparisons. Keep that old
art opt-in: new route cards, procedural underpaint, railway spine, and RM40 terminal
must remain reviewable without obsolete scenery obscuring them.

Do not assume that requesting a `2048 x 1152` or 4K image fixes generator blur. The
approved style-pass output was natively about `1671 x 941` and still contained softness
and embossed texture. Nominal pixels are not equivalent to genuine spatial detail.

## Naming and metadata

Use stable IDs. A recommended Figma layer/component name is:

```text
<MASTER_ID>-<CARD_ID> · Z <worldZ> · <Semantic Name>
```

Every approved card needs:

- master ID and card ID;
- world-Z value or explicit special projection role;
- canonical matte;
- native raster dimensions;
- logical registration bounds;
- maximum tested projected size;
- generation/inpainting provenance;
- status and review date.

Runtime filenames may be shorter, but the export manifest must preserve traceability to
the Figma node/component and master.

## Ordering rules

- Back-to-front render order is underpaint, far cards, middle cards, near cards.
- Figma's layer panel displays that visual stack in the reverse listing direction:
  frontmost/near cards appear at the top.
- The global panel should read from Menu/Brigade near cards toward Fields, snowy country,
  forest, and camp as the user moves downward through the layer list.
- Preserve internal compositing order when moving a whole master block.
- Never place a far continuation above a nearer master block; it will paint over the near
  world even if each block is internally correct.

## Future-agent checklist

Before generating or editing a world card:

1. Read this document, `research/world_depth/BRIEF.md`, and the locked camera contract.
2. Inspect the current Figma pages and node IDs; do not infer current truth from an old
   export or screenshot.
3. Identify the raster master and its canonical page/component ownership.
4. Preserve camera geometry and route topology while solving art problems.
5. Preserve raw estimator output and record all depth transforms.
6. Let depth evidence and motion determine card count; do not force a fixed count.
7. Extract approved source pixels before generating missing content.
8. Generate disocclusion/bleed, then reapply authoritative masks.
9. Add approved card components to their master page and instances to the global stack.
10. Verify Figma composition and Flutter motion before calling a card production-ready.

Do not replace checked-in app assets, change the camera contract, or publish/commit work
unless the task explicitly includes those actions. Never attempt destructive Git repair
when the checkout reports `bad tree object HEAD`.

## Decisions still open

- per-device runtime export policy;
- acceptable maximum reprojection error used to split cards;
- final estimator/semantic-masking combination;
- exact production master boundaries along the Menu-to-Camp route.

Record those decisions here when they are resolved so they are not rediscovered in a
later session.
