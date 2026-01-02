# Kolkhoz - Agent Quick Start Guide

A Soviet-themed trick-taking card game built with boardgame.io and React.

## Tech Stack
- **boardgame.io 0.50.2** - Game state management
- **React 18.2** - UI rendering
- **Vite 5.0** - Build tool
- **Vitest** - Testing

## Quick Commands
```bash
npm install          # Install dependencies
npm run dev          # Dev server at localhost:3000
npm run build        # Build to docs/ (GitHub Pages)
npm run test:run     # Run tests once
npm run test         # Watch mode tests
```

## Project Layout
```
src/
  game/                    # Game logic (boardgame.io)
    KolkhozGame.js         # Main game definition - phases, moves
    constants.js           # SUITS, VALUES, THRESHOLD, variants
    Card.js                # Card class
    utils/
      trickUtils.js        # Trick resolution, card validation
      deckUtils.js         # Deck prep, dealing
      scoringUtils.js      # Scoring, year transitions
      requisitionUtils.js  # Requisition phase logic
    __tests__/
      KolkhozGame.test.js  # Game logic tests
  client/
    App.jsx                # Lobby with variant selection
    Board.jsx              # Main game board + flying card animation
    components/
      TrickAreaHTML.jsx    # Main play area (HTML/CSS flexbox layout)
      TrickAreaHTML.css    # Responsive layout styles
    styles/
      board.css            # Global styles, fixed player hand
```

## Game Flow
1. **Planning** - Reveal jobs, set trump (or famine = no trump)
2. **Swap** - Optional hand/plot card exchange (years 2-5)
3. **Trick** - Play 4 tricks (3 in famine), follow suit rules
4. **Assignment** - Brigade leader assigns cards to jobs
5. **Requisition** - Failed jobs cause card exile to GULAG
6. Repeat for 5 years. **Lowest score wins**.

## Key Files to Read First
1. `src/game/KolkhozGame.js` - Understand phases and moves
2. `src/game/constants.js` - Game constants and variants
3. `src/game/utils/trickUtils.js` - Core trick mechanics

## Testing
```bash
npm run test:run
```
Tests use boardgame.io's `Client` with mock random for deterministic results.

## Common Tasks

### Adding a new move
1. Add function in `KolkhozGame.js` moves object
2. Add to AI enumeration if applicable
3. Add tests in `__tests__/KolkhozGame.test.js`

### Modifying phase transitions
- Check `next`, `endIf`, `onBegin`, `onEnd` hooks in phase definitions
- Key file: `src/game/KolkhozGame.js`

### Fixing game logic bugs
1. Add failing test first
2. Fix in appropriate utils file
3. Verify with `npm run test:run`

## Build & Deploy
```bash
npm run build        # Outputs to docs/
git add docs/ && git commit -m "Build" && git push
```
GitHub Pages serves from `/docs` on master branch.
