# New Visual Design Direction

## Status

This document defines the proposed replacement for Kolkhoz's pixel-art language. The
migration is incremental and selected with `app/builder.sh --new-art`. The legacy renderer
and assets remain the default and fallback until each new slice is complete.

## Historical Anchor

The primary reference is the 1931 color lithograph *Kolkhoznik, read the book! The book
will help fulfill the plan of the second Bolshevik spring*. Its useful language is
diagrammatic: fields, roads, books, buildings, machinery, infrastructure, ordinary
people, flat ink, and typography used as architecture.

- [Wikimedia Commons catalog record](https://commons.wikimedia.org/wiki/File:%D0%9A%D0%BE%D0%BB%D1%85%D0%BE%D0%B7%D0%BD%D0%B8%D0%BA,_%D1%87%D0%B8%D1%82%D0%B0%D0%B9_%D0%BA%D0%BD%D0%B8%D0%B3%D1%83!_%D0%9A%D0%BD%D0%B8%D0%B3%D0%B0_%D0%BF%D0%BE%D0%BC%D0%BE%D0%B6%D0%B5%D1%82_%D0%B2%D1%8B%D0%BF%D0%BE%D0%BB%D0%BD%D0%B8%D1%82%D1%8C_%D0%BF%D0%BB%D0%B0%D0%BD_%D0%B2%D1%82%D0%BE%D1%80%D0%BE%D0%B9_%D0%B1%D0%BE%D0%BB%D1%8C%D1%88%D0%B5%D0%B2%D0%B8%D1%81%D1%82%D1%81%D0%BA%D0%BE%D0%B9_%D0%B2%D0%B5%D1%81%D0%BD%D1%8B.jpg)

Do not assemble generic "Soviet-looking" symbols or freely mix later socialist realism,
wartime art, space-race imagery, postwar medals, and unrelated avant-garde motifs.

## Two Coordinated Compositions

### Agricultural Ledger: Menus

Menus, setup, rules, profiles, progression, settings, online management, logs, and results
use a strict rectilinear ledger derived from agricultural reports and publishing catalogs.

- Stable left contents column for identity and global navigation.
- One row of preset or section headings.
- Numbered option rows with a title, one generated illustration, short live copy, and a
  stamped state mark.
- Stable bottom action strip.
- Predictable scanning and responsive reflow take priority over scenery.

### Collective Field Plan: Gameplay

Planning, swap, trick, assignment, requisition, game over, players, hands, plots, jobs,
and the north use a shallow axonometric agricultural work plan.

- Fields and parcels organize state.
- Roads and utilities establish reading order.
- Buildings and machinery establish scale but remain secondary.
- Calm paper plates protect text and controls from scenery.
- Ordinary people appear at human scale, never as generic monumental heroes.

Menus and gameplay share palette, typography, paper, icons, cards, borders, stamps,
focus marks, and disabled states. Entering a game should feel like leaving the planning
office and stepping into the plan it describes.

## Historical And Cultural Responsibility

- Record source, date, region, medium, and original purpose for major references.
- Distinguish kolkhoz and sovkhoz material culture.
- Research clothing, buildings, machinery, crops, and terminology.
- Do not collapse the USSR's peoples into one invented peasant costume.
- Use real translation and complete Cyrillic fonts; never fake Cyrillic.
- Do not use real political leaders as character art.
- Use flags, stars, medals, and the hammer and sickle only with specific justification.
- Do not turn famine, deportation, requisition, or repression into cheerful decoration.
- Obtain knowledgeable historical or cultural review before final production approval.

## Shared Visual System

### Color

- aged cream: reading surfaces;
- coal black: type and divisions;
- brick red: selection, urgency, and primary action;
- muted field green: progress and legal state;
- wheat ochre: crops and warm emphasis;
- gray-blue: distance and secondary information.

Color should look printed, not emitted. Selection must never depend on color alone.

### Print

Use flat ink, technical linework, halftone, hatch, restrained paper grain, slightly dry
edges, and small registration offsets in illustrations. Keep live text, ranks, icons, and
semantic borders crisp. Avoid bevels, glass, metallic chrome, and gradients.

### Typography

Use PT Sans Narrow Bold for display headings and PT Sans for live body copy. Both are
locally bundled and Cyrillic-complete. Use tabular numerals where values must compare.
Distress belongs to surrounding artwork, never live glyphs.

### Generated Artwork

All visible pictograms and illustrations are created through the image generator. Generate
isolated artwork without UI text or frames, then remove the chroma background and validate
alpha. Flutter owns layout, typography, focus, selection, disabled state, progress, and
nine-slice composition.

Cards resemble agricultural pamphlets, notices, or seed guides. Rank and suit remain the
first read. The Saboteur uses interruption, damaged infrastructure, censored print, or
broken field geometry rather than a generic spy stereotype.

## Reusable Chrome

Use a small raster kit rather than screen-sized panels:

- seamless paper textures;
- neutral and brick-red nine-slice underlays;
- generated pictograms and illustrations;
- code-driven disabled, focus, selection, and progress states.

`PrintedUnderlay` uses the same cap-safe painter as the existing pixel chrome and falls
back to existing underlays. Do not bake text, icons, or size-specific shadows into it.

## Night Mode And Floodlights

Night mode comes after the light migration. It uses blue-charcoal and slate rather than
featureless black while retaining bright spot colors. Optional period worksite floodlights
may illuminate selected parcels and primary actions with flat halftone cones. Lighting is
atmosphere only and never replaces semantic state. Support day, night with lights, and
night without lights.

## Responsive Priority

The 667 x 375 landscape layout is the governing test. Remove distant scenery before
shrinking text. Collapse navigation to icons, simplify illustrations, overlap hands while
preserving rank and suit, and move dense copy to details.

Priority: active control; rank and suit; legal/selected state; production totals; player
identity; environmental storytelling.

## Implementation Boundary

Flutter owns both renderers, assets, layout, animation, and appearance. The C engine
continues to own rules and state. `KOLKHOZ_ART_STYLE=field_plan` selects new composition.
`ArtAssetRef` and `ArtAssetImage` provide legacy fallback. Missing new assets must never
make a partial migration unplayable.

Light mode is first. The first vertical slice is the Agricultural Ledger create-game
screen, followed by the trick screen, then remaining menus and phases.

## Acceptance Criteria

- The specific early-1930s publishing basis is recognizable without generic symbols.
- Menus use the Ledger and gameplay uses the Field Plan consistently.
- English and Russian remain readable at the smallest size.
- State remains understandable without color or floodlights.
- Legacy builds and fallback assets remain functional.
- Generated concept images are never shipped directly as complete screens.
