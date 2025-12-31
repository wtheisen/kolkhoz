# Game Phases & Transitions

## Phase Flow Diagram

```
                        ┌──────────────┐
                        │   planning   │ ← Game starts here
                        │  (set trump) │
                        └──────┬───────┘
                               │
              ┌────────────────┴────────────────┐
              │ year > 1 && allowSwap variant?  │
              └────────────────┬────────────────┘
                    yes        │        no
                     ↓         │         ↓
              ┌──────────┐     │    ┌──────────┐
              │   swap   │     └───→│  trick   │
              └────┬─────┘          └────┬─────┘
                   │                     │
                   └─────────────────────┘
                               │
                               ↓
                        ┌──────────────┐
                        │    trick     │←────────────┐
                        │ (play cards) │             │
                        └──────┬───────┘             │
                               │                     │
              ┌────────────────┴────────────────┐    │
              │      all cards same suit?       │    │
              └────────────────┬────────────────┘    │
                    no         │        yes          │
                     ↓         │         ↓           │
              ┌────────────┐   │   (auto-assign)     │
              │ assignment │   │         │           │
              └─────┬──────┘   │         │           │
                    │          │         │           │
                    └──────────┴─────────┘           │
                               │                     │
                               ↓                     │
                      ┌────────────────┐             │
                      │ plotSelection  │             │
                      │  (auto-hide)   │             │
                      └───────┬────────┘             │
                              │                      │
              ┌───────────────┴───────────────┐      │
              │    trickCount < tricksPerYear │      │
              │      (4 normal, 3 famine)     │      │
              └───────────────┬───────────────┘      │
                    no        │        yes           │
                     ↓        │         └────────────┘
              ┌─────────────┐
              │ requisition │
              │ (exile cards)│
              └──────┬──────┘
                     │
        ┌────────────┴────────────┐
        │     year < MAX_YEARS    │
        └────────────┬────────────┘
              yes    │      no
               ↓     │       ↓
        ┌──────────┐ │  ┌──────────┐
        │ planning │ │  │ GAME OVER│
        └──────────┘ │  └──────────┘
              ↑      │
              └──────┘
```

## Phase Definitions

### 1. Planning Phase

**Purpose:** Set trump suit for the year, reveal job cards.

**Moves:** `declareTrump(suit)`

**Hooks:**
```javascript
planning: {
  start: true,  // Game starts here
  onBegin: ({ G, random }) => {
    // Reveal job cards
    // Check for famine (Ace of Clubs)
    // If famine, auto-set trump to null
  },
  endIf: ({ G }) => G.trump !== null || G.isFamine,
  next: ({ G }) => {
    if (G.year > 1 && G.variants.allowSwap) return 'swap';
    return 'trick';
  },
  turn: { order: TurnOrder.ONCE },  // First player declares trump
}
```

**Key Logic:**
- Central Planner (first player) chooses trump
- Famine year = no trump selection needed
- Jobs revealed from job piles

---

### 2. Swap Phase

**Purpose:** Allow players to exchange hand cards with hidden plot cards.

**Moves:** `swapCard(plotIndex, handIndex, plotType)`, `confirmSwap()`

**Hooks:**
```javascript
swap: {
  onBegin: ({ G }) => {
    G.swapConfirmed = {};
    // Auto-confirm AI players
    for (const p of G.players) {
      if (!p.isHuman) G.swapConfirmed[p.idx] = true;
    }
  },
  endIf: ({ G }) => {
    // End when all players confirmed
    return Object.keys(G.swapConfirmed).length === G.numPlayers;
  },
  next: 'trick',
  turn: {
    activePlayers: { all: 'swap' },  // Simultaneous
  },
}
```

**Key Logic:**
- Only available years 2-5 with `allowSwap` variant
- All players act simultaneously
- Can swap with revealed OR hidden plot cards
- Card takes on the position's state (revealed stays revealed)

---

### 3. Trick Phase

**Purpose:** Players play cards, tricks are resolved.

**Moves:** `playCard(cardIndex)`

**Hooks:**
```javascript
trick: {
  onBegin: ({ G }) => {
    if (G.currentTrick.length === 0) {
      G.currentTrick = [];
    }
  },
  onEnd: ({ G, ctx }) => {
    // Resolve trick if complete
    // Apply assignments if auto-assignable
    // Check for year end
  },
  endIf: ({ G, ctx }) => {
    // End when trick complete OR year complete
  },
  next: ({ G }) => {
    if (G.needsManualAssignment) return 'assignment';
    const tricksPerYear = G.isFamine ? 3 : 4;
    if (G.trickCount >= tricksPerYear) return 'requisition';
    return 'trick';
  },
  turn: {
    order: {
      first: ({ G }) => G.lead,
      next: ({ G, ctx }) => (ctx.playOrderPos + 1) % ctx.numPlayers,
    },
  },
}
```

**Key Logic:**
- Must follow lead suit if able
- Trump beats lead suit
- Highest card in winning suit wins
- Winner becomes brigade leader and leads next

---

### 4. Assignment Phase

**Purpose:** Brigade leader assigns trick cards to jobs.

**Moves:** `submitAssignments(assignments)`

**Hooks:**
```javascript
assignment: {
  onBegin: ({ G }) => {
    G.pendingAssignments = {};
  },
  endIf: ({ G }) => !G.needsManualAssignment,
  next: 'plotSelection',
  turn: {
    order: {
      first: ({ G }) => G.lastWinner,  // Brigade leader
    },
  },
}
```

**Key Logic:**
- Only entered if cards are different suits
- Trump cards can go to any job
- Non-trump must go to their own suit's job
- Work hours increase, jobs may complete

---

### 5. Plot Selection Phase

**Purpose:** Remaining hand cards go to hidden plot.

**Hooks:**
```javascript
plotSelection: {
  onBegin: ({ G }) => {
    // Auto-move remaining hand to hidden plot
    for (const p of G.players) {
      p.plot.hidden.push(...p.hand);
      p.hand = [];
    }
  },
  endIf: () => true,  // Instant phase
  next: ({ G }) => {
    const tricksPerYear = G.isFamine ? 3 : 4;
    if (G.trickCount >= tricksPerYear) return 'requisition';
    return 'trick';
  },
}
```

**Key Logic:**
- Completely automatic
- All remaining cards become hidden plot
- Ends immediately

---

### 6. Requisition Phase

**Purpose:** Failed jobs cause card exile to GULAG.

**Hooks:**
```javascript
requisition: {
  onBegin: ({ G, ctx }) => {
    handleRequisition(G, G.variants);
    // Transition to next year or end game
  },
  endIf: () => true,  // Instant phase
  next: ({ G }) => {
    if (G.year > MAX_YEARS) return null;  // Game over
    return 'planning';
  },
}
```

**Key Logic:**
- Check each job: workHours < 40 = failed
- Failed job = highest matching suit card exiled
- Special cards modify behavior:
  - Jack of Trump (Drunkard): Exiled instead of player card
  - Queen of Trump (Informant): ALL players reveal plots
  - King of Trump (Party Official): 2 cards exiled

---

## Phase Transition Gotchas

### 1. Instant Phases
`plotSelection` and `requisition` end immediately via `endIf: () => true`. Their logic runs in `onBegin`.

### 2. Trump Reset
Trump is set to `null` in `transitionToNextYear()` to ensure planning phase doesn't auto-skip.

### 3. Famine Detection
```javascript
G.isFamine = revealedJobs.Clubs?.value === 1;  // Ace of Clubs
```
Famine means:
- 3 tricks instead of 4
- No trump suit
- 4 cards dealt instead of 5

### 4. Year-End Processing
Happens in `requisition.onBegin` via `transitionToNextYear()`:
- Increment year
- Reset work hours, job buckets
- Deal new cards
- Check for new famine

### 5. activePlayers Mode (Swap)
Swap phase uses `activePlayers: { all: 'swap' }` for simultaneous play. AI auto-confirms in `onBegin`.

## Common Phase Bugs

| Bug | Cause | Fix |
|-----|-------|-----|
| Infinite loop at year start | Trump not reset | Add `G.trump = null` in `transitionToNextYear` |
| Swap hangs | AI not confirming | Auto-confirm in `swap.onBegin` |
| Wrong trick count | Checking year instead of isFamine | Use `getTricksPerYear(G.isFamine)` |
| Double year-end | Phase re-entry | Use `yearEndProcessed` flag |

## Debugging Phase Issues

```javascript
// Add to any phase hook
console.log('[DEBUG] Phase:', ctx.phase);
console.log('[DEBUG] Year:', G.year, 'Trick:', G.trickCount);
console.log('[DEBUG] Trump:', G.trump, 'Famine:', G.isFamine);
console.log('[DEBUG] Players hands:', G.players.map(p => p.hand.length));
```
