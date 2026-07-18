# World Route Components

Reusable raster artwork projected by the world-depth runtime. These assets do
not contain baked camera perspective; code places and scales them along the
authoritative route spine.

## Railway sleeper tile

`rail-sleeper-only.png` is the active alpha-cut orthographic module generated
with the built-in image-generation tool. It contains one horizontal timber and
two compact fastener groups only. The runtime repeats it at stable world-space
positions between the Fields station and the North terminal, beneath the two
continuous programmatic rails.

`rail-sleeper-tile.png` is the rejected earlier full-track slice. It contains
baked rail and ballast pixels and must not be compressed into a thin sleeper
strip; doing so turns the embedded rails into upright posts and duplicates the
actual route rails.

Ballast, rail centers, sleeper centers, and bounded sleeper rotation all derive
from the same perspective-attenuated curve. The camera tracks the closest
visible point on that curve, so the railway can wind through the hills without
sliding sideways as the player advances.

At runtime that single route is rendered in world-Z intervals matching the 12
terrain cards. Each card is followed by its own interval, then nearer cards are
painted over it. Hills therefore occlude the track naturally without introducing
independent per-card curves. The ballast is only a narrow translucent stain so
the terrain remains visible beneath the sleepers and rails.

The original chroma-key generation is retained with the research run, not
packaged with the app.

See `PROMPT.md` for the generation prompt and reference roles.
