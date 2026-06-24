# iOS/Web Layout Divergences

Captured on 2026-06-23 from the local Vite web app and the iPhone 17 Pro simulator.
This is a layout map only; it does not judge game-rule differences. The iOS hand
tray clipping is intentionally excluded from this pass.

## Current Comparison Pass

Rechecked after the iOS layout alignment pass on 2026-06-23.

Evidence:
- Web baseline: `/tmp/kolkhoz-layout-compare/`
- Current iOS captures: `/tmp/kolkhoz-compare-pass2/ios/`

Status:
- **Plot:** Mostly aligned. iOS now uses the web structure: opponent summaries
  above, human hidden/revealed plot boxes below. Remaining difference is visual
  treatment: iOS uses a brighter command-panel header and compact opponent cards,
  while web is darker and lets the plot panel dominate the whole frame.
- **North:** Mostly aligned. iOS now preserves the five year columns even when
  empty. Remaining difference is visual treatment: web has a full "North" title
  band and stronger cold/dark atmosphere; iOS relies on icon nav plus the active
  column highlight.
- **Jobs:** Structurally close. Both show four job tiles with progress, suit,
  reward, and card stack space. Remaining difference is density: iOS spends more
  height on the panel title row, while web gives more vertical space to buckets.
- **Menu:** Structurally close. Both use a central command/rules panel. Remaining
  difference is style: web is a dark modal-like board panel; iOS is a brighter
  parchment command panel.
- **Board/HUD:** Still the main actionable divergence, excluding the intentionally
  icon-only nav. Web reads as one dense labeled status strip; iOS reads as
  separate icon counters. This is the best next target if the goal is more web
  layout parity.
- **Lobby:** Still a product-style divergence. Web uses live title text and a
  visible language toggle; iOS uses a title-card image and no visible language
  affordance.

## High-Priority Divergences

### 1. Navigation Rail

Web reference:
- `src/client/components/layout/NavBar.jsx:16` renders a vertical left rail.
- `src/client/components/layout/NavBar.jsx:23` through `:56` show visible labels for
  Menu, Brigade, Jobs, The North, and Plot.
- `src/client/components/layout/NavBar.jsx:58` through `:65` includes a language
  toggle at the bottom of the rail.
- `src/client/components/layout/NavBar.css:3` through `:14` reserves a labeled rail
  width with `clamp(100px, 13vw, 150px)`.

iOS divergence:
- `ios/KolkhozSwiftUI/Sources/KolkhozAppFeature/Board/GameBoardView.swift:140`
  through `:181` renders the same panel set.
- `GameBoardView.swift:184` through `:202` makes each `NavButton` icon-only; the
  title is used for help/accessibility, not visible layout.
- There is no in-game language toggle equivalent.

Layout implication:
The iOS rail is functionally compact but visually diverges from the web app's
main orientation system. If the iOS layout is supposed to inherit the web
hierarchy, visible short labels or a separate language affordance should be
restored before tuning spacing.

### 2. Plot Overview

Web reference:
- `src/client/components/views/PlotView.jsx:217` through `:290` keeps the three
  opponents visible in read-only plot mode.
- `PlotView.jsx:292` through `:342` places the human hidden and revealed plot boxes
  below the opponent row.

iOS divergence:
- `ios/KolkhozSwiftUI/Sources/KolkhozAppFeature/Board/GameSections.swift:1108`
  through `:1133` shows only the human private plot in normal overview mode.
- `GameSections.swift:1195` through `:1243` has an all-player composition, but only
  for the swap flow.

Layout implication:
The iOS Plot panel loses the web app's comparative context outside swap. This is
the biggest structural divergence after navigation: web treats Plot as a table
view of every player's storage, while iOS treats it as the human player's private
inventory.

### 3. Empty North State

Web reference:
- `src/client/components/views/GulagView.jsx:44` through `:77` always renders five
  year columns.
- `src/client/components/views/GulagView.css:104` through `:129` keeps those columns
  as the dominant layout even when all years are empty.

iOS divergence:
- `ios/KolkhozSwiftUI/Sources/KolkhozAppFeature/Board/GameSections.swift:1489`
  through `:1545` switches to a different component when there are no exiled cards.
- `GameSections.swift:1554` through `:1604` renders a single summary card with year
  chips instead of five empty columns.

Layout implication:
The empty state is visually useful, but it changes the user's spatial model.
The web app teaches "North is five year columns" immediately; iOS only reveals
that structure after the first exile.

## Medium-Priority Divergences

### 4. Board Status Strip

Web reference:
- `src/client/components/TrickAreaHTML.jsx:89` through `:166` uses one dense info
  bar for year, task/trump, lead, four job gauges, and cellar score.
- `src/client/components/TrickAreaHTML.css:205` through `:239` styles year/trump/lead
  as text-bearing cells.
- `TrickAreaHTML.css:413` through `:468` keeps job badges and cellar score in that
  same strip.

iOS divergence:
- `ios/KolkhozSwiftUI/Sources/KolkhozAppFeature/Board/GameBoardView.swift:707`
  through `:765` uses a denser icon-counter strip and adds a separate Plot score.
- In compact mode, labels are dropped for Year, Trump, Cellar, and Plot.

Layout implication:
The same data is mostly present, but the label density and score model differ.
Before pixel-polishing the iOS header, decide whether it should match the web's
"one labeled command strip" or remain a mobile-native icon dashboard.

### 5. Lobby Language and Title Treatment

Web reference:
- `src/client/App.jsx:157` through `:191` uses a two-column lobby with title/actions
  on the left and options/rules on the right.
- `App.jsx:175` through `:182` puts the language toggle beside the author row.
- `src/client/styles/lobby.css:20` through `:38` anchors the left column and author
  row.

iOS divergence:
- `ios/KolkhozSwiftUI/Sources/KolkhozAppFeature/Lobby/LobbyView.swift:28` through
  `:39` also computes a two-column layout.
- `LobbyView.swift:94` through `:148` replaces live title text with a title-card
  image and does not include language switching.

Layout implication:
The macro layout matches, but the title and language affordance do not. This is
probably acceptable if the iOS app is intentionally image-led, but it is a clear
web parity gap.

## Low-Priority Divergence

### 6. Jobs Panel Density

Web reference:
- `src/client/components/views/JobsView.jsx:96` through `:222` renders four job
  tiles in one row with suit, trump state, progress track, reward card, stack, and
  drop hints.
- `src/client/components/views/JobsView.css:14` through `:24` fixes the four-column
  grid.

iOS divergence:
- `ios/KolkhozSwiftUI/Sources/KolkhozAppFeature/Board/GameSections.swift:631`
  through `:681` renders four columns when there is room, but falls back to a 2x2
  grid in compact or short assignment boards.
- `GameSections.swift:692` through `:735` adds a captured-card header rail during
  assignment.
- `GameSections.swift:838` through `:938` keeps the same core tile data but uses
  less web-like spacing and tap affordances.

Layout implication:
This is a deliberate mobile adaptation more than a bug. Keep it behind the
Navigation, Plot, and North fixes unless the goal becomes strict visual parity.

## Suggested Fix Order

1. Restore the web navigation hierarchy in iOS: visible labels or abbreviated
   labels, plus a language toggle location.
2. Make the iOS Plot overview show opponent summaries in normal read-only mode,
   not only during swap.
3. Make empty North preserve the five-column structure, possibly with a compact
   empty-state banner above it.
4. Decide whether the iOS status strip should stay icon-first or move closer to
   the web's labeled info bar.
5. Treat Lobby language/title differences as a product decision, not a spacing
   bug.
6. Leave Jobs panel layout mostly as-is unless strict parity is required.
