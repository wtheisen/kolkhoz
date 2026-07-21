# Brigade to Fields Paper-Diorama Proof Plan

## Status

Accepted design direction, ready for implementation planning. This proof replaces neither
the production Field Plan renderer nor the existing World Lab until its geometry,
interaction, responsive, and art-direction gates pass.

## Objective

Prove that Kolkhoz can use one continuous, bidirectional paper-diorama world as its game
board and navigation surface.

The proof covers Brigade/Plot through Fields. It must demonstrate:

- free forward/backward scrolling along one fixed route;
- train-cab-height travel and smoothly elevated oblique hero views;
- light resistance and strong release snapping at Brigade and Fields;
- attractive, coherent frames at every intermediate camera position;
- physical cards laid into world-space gameplay surfaces;
- a truck carrying a completed trick from Brigade to the Fields staging yard;
- assignment from the staging yard into four permanent crop fields;
- completed-job rewards returning toward the winning plot;
- a screen-fixed private hand and compact shared-state HUD;
- usable layouts across the supported landscape-phone and desktop apertures.

This is a structural proof, not a production art pass and not an extension of the current
station-to-North depth-card experiment.

## Locked Product Decisions

### Camera and navigation

- Travel is restricted to one forward/backward route. There is no lateral exploration or
  free-look camera.
- Menus use roughly person height. Normal world travel uses roughly train-cab height.
- Hero views rise and tilt into elevated oblique compositions while retaining a visible
  horizon and nearly constant forward yaw.
- Players may stop anywhere and control their cameras independently.
- Brigade, Fields, and eventually North are magnetic stops: light resistance while
  crossing their capture zones, followed by a stronger snap after input ends.
- A decisive flick may pass through a magnetic stop.
- Phase changes and shared presentation events never commandeer a player's camera.

### Physical-card language

- Shared game state is represented by recognizable physical cards laid in the landscape.
- Card rank, suit, face-down state, ownership, selection, and legality remain readable.
- Cards overlap in physical spreads before shrinking. Responsive compression preserves
  rank and suit before full card artwork.
- The player's private hand is the only primary card area outside the world.

### Brigade/Plot

- Four player plots form quadrants around a communal road crossing.
- The viewer is always lower-right; the remaining seats keep a stable clockwise order.
- Each plot uses one combined physical spread for its revealed and hidden cards.
- Played trick cards land on the road, each nearest the quadrant of the player who played
  it.
- The road is both the communal trick area and the departure route toward Fields.

### Fields

The four jobs have permanent locations:

| | Left | Right |
| --- | --- | --- |
| Upper | Wheat | Sunflower |
| Lower | Potato | Beet |

- A central yard between the fields receives the truck and stages the completed trick.
- The brigade leader selects a staged worker card, then a legal crop field.
- Assigned cards spread physically inside their field. Trick rows are preferred when
  space permits but may merge because row identity has no gameplay meaning.
- Each field sign prominently mounts its reward card and shows crop, work toward 40,
  trump relevance, legal-target state, and completion state.
- When a job is claimed, its reward leaves the sign and the empty sign receives a clear
  checkmark or completion stamp.

### World events

- After a trick resolves, its four worker cards board a small truck at Brigade.
- The truck travels to Fields independently of every player's camera.
- The brigade leader must navigate to Fields before assignment controls become available.
- The truck unloads the cards into the central staging yard.
- One return journey may carry multiple rewards claimed by the submitted assignments.
- Vehicle motion is presentation state derived from authoritative engine transitions; it
  does not change rules, legal actions, or server ownership.

### Shared HUD

A compact fixed HUD redundantly presents:

- current year;
- phase;
- trump crop;
- active player;
- four job totals.

The same facts must remain visible in the landscape through signs, cards, field state,
and active-player treatment. The HUD assists orientation and does not become the primary
board.

## Current-Code Assessment

### Keep

- The C engine as the sole owner of rules, phases, legal actions, work, rewards, plots,
  requisition, and scoring.
- `TableViewModel`, `Seat`, `Trick`, `Job`, `TableCard`, and local/online projections.
- `GameCard`, card backs, selection/legality presentation, and the screen-fixed
  `HandTray`.
- Assignment helpers such as `assignmentControlCards` and
  `assignmentActionForJob`.
- Card identity and state-diff concepts from `CardMotionLayer`.
- The existing separation between the world aperture and hand-tray layout.
- The 1920 x 800 logical world aperture and its centered action-safe-area contract unless
  the proof demonstrates a concrete reason to revise it.

### Replace for the proof

- The three full-screen `FieldPlanWorldLayer` backgrounds as the spatial model.
- Page-index camera motion in `BrigadeFieldsCoordinator`.
- Vertical screen translation in `fieldPlanWorldCameraMatrix`.
- Phase-forced movement to Fields during assignment.
- Viewport-space card flights that require both endpoints to be on screen.
- The assumption that a hero area is one perspective painting with interactive quads
  overlaid afterward.

### Preserve only as reference

- The current production Field Plan renderer remains available until the proof is
  accepted.
- The station-to-North World Lab remains diagnostic evidence. Do not add Brigade-to-
  Fields production work to its twelve-card depth-stack model.
- Existing generated Brigade and Fields backgrounds may inform palette and composition,
  but they do not constrain proof geometry or asset reuse.

## Proposed Proof Architecture

### 1. Route-space coordinate system

Use one stable logical world coordinate system:

- route distance for forward/backward position;
- lateral distance from the road centerline;
- vertical elevation above the ground plane.

Every gameplay surface, scenery card, vehicle anchor, and camera keyframe uses these
coordinates. Normalized screen rectangles are derived output, never source geometry.

### 2. Camera rig

Represent the camera as a function of route position with authored keyframes for:

- route position;
- camera height;
- forward pitch;
- focal length or field of view;
- optional small lateral offset;
- magnetic-stop capture width and strength.

Interpolate height, pitch, and lens continuously. Brigade and Fields are smooth peaks in
the elevation/tilt curve rather than separate camera modes. Forward and reverse travel
must evaluate the same path and produce identical frames at the same route position.

### 3. Diorama scene graph

Use explicit world-space nodes instead of whole-screen backgrounds:

- ground cards: perspective-mapped quads for plots, fields, roads, and yards;
- vertical cutouts: houses, people, signs, trees, hedges, and machinery;
- shallow angled cards: hills, field banks, fences, and other framing forms;
- live card surfaces: plot spreads, trick anchors, staging anchors, and job-field spreads;
- route actors: truck and carried-card anchors;
- atmosphere/background owners that do not masquerade as traversable terrain.

Project each node through the same camera, depth-sort it, and map its raster or live
widget into the resulting screen quad. Existing card homography work can inform this
projection, but the proof needs one shared projector rather than separately calibrated
screen quads.

### 4. Continuous camera controller

Replace discrete page state with a local continuous route position and velocity.

- Trackpad, wheel, and drag input update velocity/position without snapping during input.
- Magnetic zones apply mild resistance while actively crossing a hero stop.
- On release, low-energy motion within a capture zone snaps to its exact hero keyframe.
- High-energy flicks retain enough momentum to pass through.
- Camera state is local presentation state and is never synchronized through the game
  server.

### 5. World-space presentation timeline

Add a presentation layer that observes model transitions and creates deterministic
world events:

- trick completed -> truck loads the four `lastTrick` card IDs and departs;
- truck arrived -> staged assignment cards become interactive at Fields;
- assignment selected -> selected card moves from staging to the chosen field;
- assignments submitted -> claimed reward IDs board the return journey;
- reward arrived -> the destination plot spread accepts the reward.

The engine state remains authoritative immediately. The presentation timeline controls
only where a card is drawn during transit and whether the local world interaction is
ready. AI and server execution do not wait for a human camera.

The timeline must advance even when its actors are off-camera, and reconnect them to the
correct world anchors if the player scrolls into view mid-event.

### 6. Interaction mapping

- Render live cards as interactive transformed widgets when their projected size is
  usable.
- Hit testing must follow the projected card or field polygon, not its untransformed
  source rectangle.
- Assignment requires the local viewer to be the brigade leader, the truck to have
  arrived, the camera to be within the Fields interaction zone, a staged card to be
  selected, and the engine to expose the matching legal action.
- Nonleaders may navigate and inspect but never receive assignment affordances.
- World focus/inspection may magnify or clarify a spread without changing ownership or
  camera route position.

## Responsive Contract

Validate at minimum these world apertures above the hand tray:

- 667 x 311 small landscape phone;
- 852 x 329 standard landscape phone;
- 932 x 366 large landscape phone;
- representative desktop window.

Responsive priority:

1. active card and legal target;
2. card rank, suit, and face-down state;
3. active player and phase;
4. job totals and reward state;
5. plot ownership and score;
6. full card artwork;
7. nonessential scenery.

Keep world geometry and player/crop positions stable across sizes. Adapt card overlap,
card scale, scenery density, HUD density, and inspection behavior instead of rearranging
the board.

## Art and Figma Plan

### Structural blockout first

Build the first proof with flat colors, labeled paper rectangles, route geometry, real
game cards, and simple silhouette cutouts. Do not generate final landscape art until:

- camera travel reads as physical passage;
- both hero frames are useful game boards;
- midpoints remain composed;
- card sizes work on phones;
- the truck can be followed or encountered mid-route;
- reverse travel has no pops or ordering failures.

### Production asset model after geometry approval

Create an additive Figma proof page organized by world-space component, not by screenshot:

- Brigade ground and plot surfaces;
- central road/trick crossing;
- Brigade vertical cutouts;
- travel corridor ground and side scenery;
- truck and cargo components;
- Fields 2 x 2 ground surfaces and central yard;
- four job signs and completion variants;
- Fields vertical cutouts and distant scenery;
- shared procedural sky/paper owners.

Each component records world bounds, plane orientation, depth order, native raster size,
maximum projected size, and safe bleed. Raster density is chosen from the component's
closest approved view, not from a distant master screenshot.

The existing depth-card pipeline must not be silently reinterpreted. If the proof is
accepted, update that contract explicitly to distinguish route-space diorama components
from depth cards extracted for local parallax around a raster master.

## Implementation Sequence

### Phase 0: Acceptance fixtures

- Add deterministic offline and online-projection fixtures for a four-card completed
  trick, Fields assignment, and one or more claimed rewards.
- Capture current Brigade and Fields gameplay requirements as data assertions before
  replacing presentation.
- Define screenshot positions for both hero stops and at least five midpoints.

### Phase 1: Isolated diorama lab

- Add a dedicated Brigade-to-Fields proof entry point and keep it separate from the
  current World Lab.
- Feed it real `TableViewModel` fixtures and real `GameCard` widgets.
- Add route-space debug guides, camera readouts, plane labels, and visibility toggles.

Exit gate: the lab renders deterministic real game state without production integration.

### Phase 2: Projector and camera path

- Implement the world coordinate types, shared projection, plane homography, depth sort,
  and camera-path interpolation.
- Block out Brigade, travel corridor, and Fields using flat paper shapes.
- Verify exact frame equality when approaching the same route position from either
  direction.

Exit gate: slow travel no longer reads as zooming a painting, and no plane reveals
unowned background or crosses another plane incorrectly.

### Phase 3: Scroll physics and sticky stops

- Support wheel, trackpad, drag, fling, resistance, and release snap.
- Tune hero capture zones independently from camera keyframes.
- Ensure strong flicks can bypass a stop and small corrections settle reliably.

Exit gate: navigation is quick during play but controllable during inspection on macOS
and touch-sized test surfaces.

### Phase 4: Brigade gameplay surface

- Add four stable plot quadrants with viewer lower-right.
- Add physical hidden/revealed plot spreads and responsive compression.
- Add the communal road crossing and four trick landing anchors.
- Preserve pass, swap, trick play, selection, ownership, and score readability.

Exit gate: a complete trick can be played and plot state inspected at the settled Brigade
view on every target aperture.

### Phase 5: Truck journey

- Derive a truck event from the trick-to-assignment transition.
- Load the four physical trick cards, travel along the route, and unload at Fields.
- Keep the event advancing off-camera and make mid-event entry deterministic.
- Add nonintrusive world/HUD cues that assignment is waiting at Fields without moving the
  camera.

Exit gate: multiple local cameras can conceptually be at different positions while the
same authoritative truck event remains coherent.

### Phase 6: Fields assignment surface

- Add the fixed wheat/sunflower/potato/beet 2 x 2 grid.
- Add central staging, card selection, legal field targeting, job signs, reward cards,
  work totals, and completion marks.
- Spread assigned workers physically; preserve rows when space permits and merge them
  when necessary.
- Gate human assignment interaction on Fields proximity and truck arrival without
  changing engine legality.

Exit gate: the brigade leader can assign all four cards through the real engine actions
on phone and desktop fixtures.

### Phase 7: Reward return and HUD

- Detect newly claimed reward cards and carry them toward the correct plot.
- Support multiple rewards from one assignment submission.
- Add the compact fixed HUD and duplicate its information in world signs/state.
- Keep the hand tray screen-fixed and visually separate from the world aperture.

Exit gate: the complete trick -> truck -> assignment -> reward loop is readable without
panel switching or forced camera motion.

### Phase 8: Art pass

- Approve blockout geometry before generating or extracting final art.
- Author component art at closest-view density and register it to the proven world planes.
- Replace debug shapes incrementally while retaining geometry toggles and evidence
captures.
- Review every replacement in forward motion, reverse motion, both hero frames, and all
target apertures.

Exit gate: final art preserves the exact Soviet-print paper-diorama direction without
weakening interaction or continuity.

### Phase 9: Production integration

- Put the new renderer behind an explicit development flag.
- Route both local and online `TableViewModel` projections through the same renderer.
- Remove assignment's forced page selection and retain attention cues instead.
- Run parity, gameplay, screenshot, performance, and device-layout gates.
- Replace the old production Field Plan renderer only after explicit visual acceptance.

## Verification Gates

### Geometry and camera

- Projection is finite and monotonic across the route.
- Identical route positions produce identical frames regardless of travel direction.
- Hero height/pitch transitions have continuous first derivatives and no scale pop.
- The road remains the central axis through Brigade, travel, and Fields.
- Ground cards never reveal holes when foreground cutouts pass the camera.

### Navigation

- Slow input can stop at arbitrary midpoints.
- Light drag resistance is perceptible but does not trap the player.
- Release near a hero stop snaps strongly and predictably.
- Fast flicks may cross hero capture zones.
- Phase changes never alter local camera position.

### Gameplay

- Viewer remains lower-right at Brigade.
- Trick cards retain the spatial identity of their players.
- Only the brigade leader can assign.
- Only engine-legal target fields respond.
- Worker cards, work totals, rewards, claims, and plot arrivals match the engine after
  every action.
- Local and online projections produce the same world state under equivalent snapshots.

### Responsive and visual

- Capture Brigade, Fields, and at least five midpoints at every target aperture.
- Capture the camera lift into and out of both hero views.
- Capture empty, moderate, and maximum-density plot and job spreads.
- Verify ranks and suits at the smallest aperture before accepting full-card readability.
- Inspect truck motion when followed, crossed, entered late, and viewed in reverse camera
  travel.
- Confirm the world still reads with the HUD temporarily hidden.

### Performance

- Profile continuous scroll, hero snap, truck travel, and dense card spreads in a debug
  and representative release/profile build.
- Avoid rebuilding off-camera scenery and card spreads unnecessarily.
- Reject an art/component count that cannot maintain the app's target frame pacing on a
  representative phone.

## Proof Acceptance Criteria

The proof is accepted only when:

1. Brigade-to-Fields travel feels like movement through a landscape rather than zooming
   layered screenshots.
2. Brigade and Fields are both attractive hero compositions and fully usable game boards.
3. Every sampled midpoint is intentionally composed and free of card seams, holes, or
   perspective contradictions.
4. Camera lift, tilt, resistance, and snapping feel smooth in both directions.
5. The player can ignore or follow the truck without losing assignment discoverability.
6. The complete trick-to-reward loop uses authoritative engine actions and works for local
   and online projections.
7. Small-phone presentation preserves gameplay-critical card information.
8. The Soviet-print paper-diorama character survives close inspection.

Only after those gates pass should the same route-space model expand toward menus,
station, railway, and North.
