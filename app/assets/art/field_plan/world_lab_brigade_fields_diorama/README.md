# Brigade to Fields diorama lab assets

These are generated motion-study assets for the isolated Brigade to Fields lab. They
are not approved production plates and are not authoritative until promoted into the
Field Plan Figma depth-card stack described by
`design/field-plan-world/DEPTH_CARD_PIPELINE.md`.

## Active lab cards

- `route-ground-v2.png`: one crop-free orthographic terrain card for the complete
  Brigade-to-Fields route. The constant-width center road is wide enough for the truck;
  Flutter crops passed terrain from the source card and owns all perspective.
- `far-ridge-v1.png`: transparent distant mountain and foothill cutout.
- `mid-ridge-v1.png`: transparent rolling agricultural ridge and sparse tree cutout.
  The two atmospheric cards use separate camera-derived scale and vertical registration
  and replace the procedural horizon silhouettes; the sky remains a shared procedural
  owner.
- `field-ground-v1.png`: crop-free orthographic printed soil surface. Reused beneath
  all four fields.
- `crop-row-{wheat,sunflower,potato,beet}-v1.png`: transparent upright row cards.
  Several instances are placed at successive world-Z depths above the ground card.
- `travel-vegetation-v1.png`: transparent hedgerow, poplar, and conifer strip used as
  successive roadside depth cards.
- `farm-building-v1.png`: transparent long collective-farm building cutout. Runtime
  mirrors right-side instances so each building exposes the face toward the route.
- `truck-v2.png`: corrected near-centered rear farm truck, cropped to its useful alpha
  bounds. The slight elevated view preserves the empty cargo bed without implying a
  turn away from the road.

Each transparent final has a sibling `-chroma-v1.png` source. The source used a flat
magenta background and was converted locally with the Codex image-generation skill's
soft-matte, despill chroma-removal helper.

## Superseded proof

`fields-crop-surface-v1.png` is the first combined 2x2 crop sheet. It remains only as
style evidence. It is intentionally not referenced at runtime because baking plants
into the ground prevents independent crop skew, parallax, and occlusion.

`truck-v1.png` is the superseded strong rear-three-quarter truck. Its internal yaw
conflicted with a camera-facing world card and made the truck appear to turn off the
route.

`route-ground-v1.png` is the first continuous terrain card. Its road was too narrow for
the truck's world-space footprint and is retained as generation evidence only.

## Prompt set

All assets were generated with the built-in image generator using the existing
`fields-light-v2.png` and `brigade-plot-light-v10.png` artwork as strict style and
palette references. Shared constraints were:

- exact flat Soviet agricultural lithograph and paper-diorama language;
- economical dark blue-green linework, muted olive/ochre/red, aged-paper grain, and
  slightly imperfect registration;
- no photorealism, glossy rendering, text, logos, watermarks, or modern objects;
- ground art is orthographic with no horizon or perspective convergence;
- vertical cards use a straight-on silhouette, continuous ground-contact edge, and a
  perfectly flat magenta chroma background.

Asset-specific requests were a crop-free cultivated field surface; individual rows of
wheat, sunflowers, flowering potato plants, and beet plants; one continuous roadside
vegetation strip; one modest single-story timber work building; and one rear-view
collective-farm flatbed truck with an empty cargo bed.

The continuous landscape pass added an orthographic portrait terrain card with a
constant-width central dirt road, then widened only that road to roughly twelve percent
of the source width. It also added two straight-on chroma-key horizon cutouts: a pale
distant mountain/foothill strip and a nearer rolling-farm ridge with sparse trees. Both
were generated without sky, perspective convergence, shadows, text, or gameplay objects
and converted locally to cropped alpha PNGs.
