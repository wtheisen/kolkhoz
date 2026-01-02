# Kolkhoz Architecture

## Directory Structure

```
kolkhoz/
├── src/
│   ├── game/                      # boardgame.io game logic
│   │   ├── KolkhozGame.js         # Main game definition (526 lines)
│   │   ├── constants.js           # Game constants
│   │   ├── Card.js                # Card class
│   │   ├── index.js               # Exports
│   │   ├── utils/
│   │   │   ├── trickUtils.js      # Trick mechanics (193 lines)
│   │   │   ├── deckUtils.js       # Deck/dealing (149 lines)
│   │   │   ├── scoringUtils.js    # Scoring/transitions (175 lines)
│   │   │   └── requisitionUtils.js # Requisition logic (348 lines)
│   │   └── __tests__/
│   │       └── KolkhozGame.test.js
│   ├── client/
│   │   ├── App.jsx                # Lobby screen
│   │   ├── Board.jsx              # Main game board + flying card animation
│   │   ├── index.jsx              # React entry
│   │   ├── components/
│   │   │   ├── TrickAreaHTML.jsx  # Main play area (HTML/CSS layout)
│   │   │   ├── TrickAreaHTML.css  # Responsive flexbox styles
│   │   │   ├── AssignmentDragDrop.jsx  # Card assignment UI
│   │   │   ├── SwapDragDrop.jsx   # Swap phase UI
│   │   │   └── PlayCardDragDrop.jsx    # Card play UI
│   │   └── styles/
│   │       └── board.css          # Global styles, fixed player hand
│   └── ai/                        # (empty - AI uses boardgame.io MCTSBot)
├── public/                        # Static assets (card images)
├── docs/                          # BUILD OUTPUT (GitHub Pages)
├── package.json
├── vite.config.js
└── index.html
```

## Module Responsibilities

### Game Logic (`src/game/`)

| File | Purpose |
|------|---------|
| `KolkhozGame.js` | Phase definitions, moves, turn order, AI enumeration |
| `constants.js` | SUITS, VALUES, THRESHOLD (40), MAX_YEARS (5), variants |
| `Card.js` | Card class, display helpers, image paths |

### Utilities (`src/game/utils/`)

| File | Purpose |
|------|---------|
| `trickUtils.js` | `isValidPlay()`, `resolveTrick()`, `applyTrickResult()`, `applyAssignments()` |
| `deckUtils.js` | `prepareWorkersDeck()`, `dealHands()`, `revealJobs()` |
| `scoringUtils.js` | `calculateScores()`, `transitionToNextYear()`, `getWinner()` |
| `requisitionUtils.js` | `handleRequisition()`, special card effects (J/Q/K of trump) |

### Client (`src/client/`)

| File | Purpose |
|------|---------|
| `App.jsx` | Lobby UI, variant selection, starts game with boardgame.io Client |
| `Board.jsx` | Main board, routes to phase-specific UIs, handles moves, flying card animation |
| `components/TrickAreaHTML.jsx` | Main play area - info bar, player panels, card slots (HTML/CSS layout) |
| `components/TrickAreaHTML.css` | Responsive flexbox layout with CSS variables |
| `styles/board.css` | Global styles, player hand (fixed position at viewport bottom) |

### Frontend Layout Architecture

The game uses a **pure HTML/CSS flexbox layout** (not SVG):

```
.game-board (flex row)
├── .mobile-nav-bar (left sidebar - fixed width)
└── .game-content (flex column, fills remaining width)
    └── .trick-area-html (flex: 1, gold border)
        ├── .info-bar (year, trump, lead suit, job progress)
        ├── .play-area (flex: 1, min-height: 0)
        │   ├── .player-panels (3 bot panels + 1 spacer, space-between)
        │   └── .card-slots (flex: 1, align-items: stretch)
        │       └── .card-slot (aspect-ratio: 5/7, fills height)
        └── .player-hand-area (position: fixed, bottom: 0, translateY: 50%)
```

**Key CSS patterns:**
- **Card slots fill available space**: Uses `flex: 1` + `min-height: 0` chain to allow percentage heights
- **Player hand fixed at bottom**: `position: fixed` with `translateY(50%)` shows top 50% of cards
- **Trick area margin**: `margin-bottom: var(--visible-hand-height)` stops border above hand
- **Responsive sizing**: CSS custom properties (`--card-width`, `--visible-hand-height`) keep values in sync

## boardgame.io Integration

### Game Definition Pattern
```javascript
// KolkhozGame.js
export const KolkhozGame = {
  name: 'kolkhoz',
  setup: ({ ctx, random }) => initialGameState,
  phases: {
    planning: { ... },
    swap: { ... },
    trick: { ... },
    assignment: { ... },
    plotSelection: { ... },
    requisition: { ... },
  },
  moves: {
    declareTrump,
    playCard,
    submitAssignments,
    swapCard,
    confirmSwap,
  },
  ai: {
    enumerate: (G, ctx) => [...possibleMoves],
  },
};
```

### Phase Hooks
Each phase can define:
- `onBegin({ G, ctx })` - Run when entering phase
- `onEnd({ G, ctx })` - Run when leaving phase
- `endIf({ G, ctx })` - Return truthy to end phase
- `next({ G, ctx })` - Return next phase name
- `moves` - Phase-specific moves
- `turn.activePlayers` - For simultaneous actions (swap phase)

### Client Usage
```javascript
// App.jsx
import { Client } from 'boardgame.io/react';
import { Local } from 'boardgame.io/multiplayer';
import { KolkhozGame } from '../game';
import { Board } from './Board';

const KolkhozClient = Client({
  game: KolkhozGame,
  board: Board,
  multiplayer: Local(),
  numPlayers: 4,
});
```

## Data Flow

```
User Action (click card)
    ↓
Board.jsx calls moves.playCard(cardIndex)
    ↓
boardgame.io validates and applies move
    ↓
KolkhozGame mutates G state
    ↓
React re-renders with new G, ctx
    ↓
UI updates
```

## AI System

Uses boardgame.io's MCTSBot (Monte Carlo Tree Search):
- Enumerate function returns all legal moves
- Bot simulates games to find best move
- AI players auto-confirm in swap phase (don't swap strategically)

```javascript
ai: {
  enumerate: (G, ctx) => {
    const moves = [];
    // Add all legal moves for current phase
    if (ctx.phase === 'trick') {
      for (const idx of getValidCardIndices(G, playerIdx)) {
        moves.push({ move: 'playCard', args: [idx] });
      }
    }
    return moves;
  },
}
```

## Build System

**Vite Configuration:**
```javascript
// vite.config.js
export default {
  plugins: [react()],
  build: { outDir: 'docs' },  // GitHub Pages
  server: { port: 3000 },
};
```

**Output:** Static files in `docs/` - no server needed.

## Testing Architecture

```javascript
// __tests__/KolkhozGame.test.js
import { Client } from 'boardgame.io/client';
import { KolkhozGame } from '../KolkhozGame';

const client = Client({
  game: KolkhozGame,
  numPlayers: 4,
});

client.moves.playCard(0);
const { G, ctx } = client.getState();
expect(G.currentTrick.length).toBe(1);
```

Mock random for determinism:
```javascript
const mockRandom = {
  Number: () => 0.5,
  Die: (n) => Math.ceil(n / 2),
  Shuffle: (arr) => [...arr],
};
```
