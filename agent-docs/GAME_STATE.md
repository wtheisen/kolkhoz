# Game State (G) Reference

The `G` object is boardgame.io's game state. All game logic mutates `G` directly.

## Complete G Structure

```javascript
G = {
  // ─────────────────────────────────────────────
  // CORE STATE
  // ─────────────────────────────────────────────
  numPlayers: 4,
  year: 1,                    // Current year (1-5)
  trump: 'Hearts',            // Trump suit (null during famine)
  isFamine: false,            // Ace of Clubs revealed = famine year
  lead: 0,                    // Player index who leads current trick

  // ─────────────────────────────────────────────
  // PLAYERS
  // ─────────────────────────────────────────────
  players: [
    {
      idx: 0,
      isHuman: true,
      name: 'Игрок',
      hand: [                 // Cards in hand
        { suit: 'Hearts', value: 10 },
        // ...
      ],
      plot: {
        revealed: [],         // Visible cards (job rewards)
        hidden: [],           // Hidden plot cards
        medals: 0,            // Accumulated medals
        stacks: [],           // ordenNachalniku variant
      },
      brigadeLeader: false,   // Won most recent trick
      hasWonTrickThisYear: false,
      medals: 0,              // Medals this year
    },
    // players[1], [2], [3] = AI players
  ],

  // ─────────────────────────────────────────────
  // TRICK TRACKING
  // ─────────────────────────────────────────────
  currentTrick: [             // [playerIdx, card] pairs
    [0, { suit: 'Hearts', value: 10 }],
    [1, { suit: 'Hearts', value: 7 }],
    // ...
  ],
  lastTrick: [],              // Previous trick for display
  lastWinner: 0,              // Index of last trick winner
  trickCount: 0,              // Tricks played this year (0-4)
  trickHistory: [],           // Historical data

  // ─────────────────────────────────────────────
  // JOB MANAGEMENT
  // ─────────────────────────────────────────────
  revealedJobs: {             // Job cards for current year
    Hearts: { suit: 'Hearts', value: 3 },
    Diamonds: { suit: 'Diamonds', value: 2 },
    Clubs: { suit: 'Clubs', value: 1 },     // Ace = famine!
    Spades: { suit: 'Spades', value: 4 },
  },
  jobPiles: {                 // Remaining job cards by suit
    Hearts: [{ suit, value }, ...],
    Diamonds: [...],
    Clubs: [...],
    Spades: [...],
  },
  workHours: {                // Work hours assigned to each job
    Hearts: 25,
    Diamonds: 0,
    Clubs: 42,                // >= 40 = completed
    Spades: 15,
  },
  jobBuckets: {               // Cards assigned to each job this year
    Hearts: [{ suit, value }, ...],
    // ...
  },
  claimedJobs: ['Clubs'],     // Jobs completed this year
  accumulatedJobCards: {      // Unclaimed rewards (accumulateJobs variant)
    Hearts: [],
    // ...
  },

  // ─────────────────────────────────────────────
  // ASSIGNMENT PHASE
  // ─────────────────────────────────────────────
  pendingAssignments: {       // Card -> Job mapping
    'Hearts-10': 'Hearts',
    'Clubs-8': 'Clubs',
  },
  needsManualAssignment: false,

  // ─────────────────────────────────────────────
  // DECK & EXILE
  // ─────────────────────────────────────────────
  workersDeck: [],            // Cards to deal
  exiled: {                   // Cards in GULAG by year
    1: ['Hearts-5', 'Spades-12'],
    2: [],
    // ...
  },

  // ─────────────────────────────────────────────
  // SWAP PHASE
  // ─────────────────────────────────────────────
  swapConfirmed: {            // Player confirmations
    0: false,
    1: true,                  // AI auto-confirms
    2: true,
    3: true,
  },

  // ─────────────────────────────────────────────
  // PHASE CONTROL
  // ─────────────────────────────────────────────
  yearEndProcessed: false,    // Prevents double year-end processing

  // ─────────────────────────────────────────────
  // VARIANTS
  // ─────────────────────────────────────────────
  variants: {
    deckType: 52,             // 36 or 52
    nomenclature: true,       // J/Q/K special effects
    allowSwap: true,          // Hand/plot swap
    northernStyle: false,     // No job rewards
    miceVariant: false,       // All reveal in requisition
    ordenNachalniku: false,   // Stack jobs (36-card)
    medalsCount: false,       // Medals in score
    accumulateJobs: false,    // Carry over unclaimed
  },
};
```

## Card Object
```javascript
{
  suit: 'Hearts',   // 'Hearts', 'Diamonds', 'Clubs', 'Spades'
  value: 10,        // 6-13 (J=11, Q=12, K=13), 1-5 for job cards
}
```

## Key State Mutations

### Playing a Card
```javascript
// In playCard move
const card = player.hand.splice(cardIndex, 1)[0];
G.currentTrick.push([playerIdx, card]);
```

### Resolving a Trick
```javascript
// In applyTrickResult (trickUtils.js)
G.lastWinner = winnerPid;
G.lastTrick = [...G.currentTrick];
G.currentTrick = [];
G.trickCount++;
G.lead = winnerPid;
G.players[winnerPid].brigadeLeader = true;
G.players[winnerPid].medals++;
```

### Completing a Job
```javascript
// In handleCompletedJob (trickUtils.js)
G.claimedJobs.push(suit);
G.players[G.lastWinner].plot.revealed.push(...rewards);
```

### Year Transition
```javascript
// In transitionToNextYear (scoringUtils.js)
G.year++;
G.trickCount = 0;
G.currentTrick = [];
G.trump = null;
for (const suit of SUITS) {
  G.workHours[suit] = 0;
  G.jobBuckets[suit] = [];
}
G.claimedJobs = [];
// Deal new hands...
```

### Exile to GULAG
```javascript
// In handleRequisition (requisitionUtils.js)
G.exiled[G.year].push(`${card.suit}-${card.value}`);
// Remove from player's plot
player.plot.revealed = player.plot.revealed.filter(c => c !== card);
```

## State Validation Checks

### Valid Card Play
```javascript
// From trickUtils.js
if (G.currentTrick.length === 0) return true;  // Lead = any card
const leadSuit = G.currentTrick[0][1].suit;
const hasLeadSuit = player.hand.some(c => c.suit === leadSuit);
if (hasLeadSuit) return card.suit === leadSuit;
return true;  // Can't follow = any card
```

### Year Complete
```javascript
const tricksPerYear = G.isFamine ? 3 : 4;
if (G.trickCount >= tricksPerYear) {
  // Year is over, go to requisition
}
```

### Game Over
```javascript
if (G.year > MAX_YEARS) {
  return true; // Game ends
}
```

## Debugging Tips

### Log Current State
```javascript
console.log('Year:', G.year, 'Phase:', ctx.phase);
console.log('Trump:', G.trump, 'Famine:', G.isFamine);
console.log('Trick:', G.trickCount, 'Current:', G.currentTrick.length);
console.log('Lead:', G.lead, 'Turn:', ctx.currentPlayer);
```

### Check Player Hands
```javascript
G.players.forEach((p, i) => {
  console.log(`Player ${i}: ${p.hand.length} cards, ${p.plot.hidden.length} hidden`);
});
```

### Trace Phase Transitions
The code has existing debug logs:
```javascript
console.log('[DEBUG] trick.onEnd - trickCount:', G.trickCount);
console.log('[DEBUG] Phase transition:', ctx.phase, '→', nextPhase);
```
