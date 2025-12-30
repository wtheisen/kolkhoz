// Kolkhoz - boardgame.io Game Definition
// A Soviet-themed trick-taking card game

import { INVALID_MOVE } from 'boardgame.io/core';
import { SUITS, PLAYER_NAMES, DEFAULT_VARIANTS } from './constants.js';
import { prepareJobPiles, revealJobs, prepareWorkersDeck, dealHands } from './utils/deckUtils.js';
import {
  isValidPlay,
  resolveTrick,
  applyTrickResult,
  applyAssignments,
  generateAutoAssignment,
  getTricksPerYear,
} from './utils/trickUtils.js';
import { performRequisition } from './utils/requisitionUtils.js';
import { getWinner, transitionToNextYear, setRandomTrump } from './utils/scoringUtils.js';

// Initialize a player
function createPlayer(idx, isHuman, name) {
  return {
    idx,
    isHuman,
    name,
    hand: [],
    plot: {
      revealed: [],
      hidden: [],
      medals: 0,
      stacks: [],
    },
    brigadeLeader: false,
    hasWonTrickThisYear: false,
    medals: 0,
  };
}

// Game setup function
function setup({ ctx, random }, setupData) {
  const variants = { ...DEFAULT_VARIANTS, ...(setupData?.variants || {}) };
  const numPlayers = ctx.numPlayers;

  // Create players
  const availableNames = [...PLAYER_NAMES];
  const players = [];

  for (let i = 0; i < numPlayers; i++) {
    if (i === 0) {
      // Human player
      players.push(createPlayer(0, true, 'Игрок'));
    } else {
      // AI player with random Russian name
      const nameIndex = Math.floor(random.Number() * availableNames.length);
      const name = availableNames.splice(nameIndex, 1)[0];
      players.push(createPlayer(i, false, name));
    }
  }

  // Initialize game state
  const G = {
    numPlayers,
    players,
    lead: Math.floor(random.Number() * numPlayers),
    year: 1,
    trump: null,
    jobPiles: prepareJobPiles(variants, random),
    revealedJobs: {},
    claimedJobs: [],
    accumulatedJobCards: {},
    workHours: {},
    jobBuckets: {},
    currentTrick: [],
    lastTrick: [],
    lastWinner: null,
    trickHistory: [],
    trickCount: 0,
    exiled: {},
    workersDeck: [],
    isFamine: false,
    variants,
    // For assignment phase
    pendingAssignments: {},
    needsManualAssignment: false,
  };

  // Initialize per-suit state
  for (const suit of SUITS) {
    G.accumulatedJobCards[suit] = [];
    G.workHours[suit] = 0;
    G.jobBuckets[suit] = [];
  }

  // Reveal jobs for year 1 and check for famine (Ace of Clubs)
  const { jobs, isFamine } = revealJobs(G.jobPiles, G.accumulatedJobCards, variants);
  G.revealedJobs = jobs;
  G.isFamine = isFamine;

  // Prepare deck and deal hands (4 cards during famine, 5 otherwise)
  G.workersDeck = prepareWorkersDeck(G.players, G.jobBuckets, G.exiled, variants, random);
  dealHands(G.players, G.workersDeck, G.isFamine);

  return G;
}

// Move: Set trump suit (planning phase)
function setTrump({ G, random }, suit) {
  if (suit && SUITS.includes(suit)) {
    G.trump = suit;
  } else {
    setRandomTrump(G, random);
  }
}

// Move: Play a card (trick phase)
function playCard({ G, ctx, playerID }, cardIndex) {
  const playerIdx = parseInt(playerID, 10);

  if (!isValidPlay(G, playerIdx, cardIndex)) {
    return INVALID_MOVE;
  }

  const player = G.players[playerIdx];
  const card = player.hand.splice(cardIndex, 1)[0];
  G.currentTrick.push([playerIdx, card]);
}

// Move: Assign a card to a job (assignment phase)
function assignCard({ G }, cardKey, targetSuit) {
  if (!G.pendingAssignments) {
    G.pendingAssignments = {};
  }
  G.pendingAssignments[cardKey] = targetSuit;
}

// Move: Submit all assignments
function submitAssignments({ G, events }) {
  // Validate all cards are assigned
  if (Object.keys(G.pendingAssignments).length !== G.lastTrick.length) {
    return INVALID_MOVE;
  }

  // Get all suits represented in the trick
  const suitsInTrick = new Set(G.lastTrick.map(([, card]) => card.suit));

  // Validate assignments - cards can only go to jobs represented in the trick
  for (const [, targetSuit] of Object.entries(G.pendingAssignments)) {
    if (!suitsInTrick.has(targetSuit)) {
      return INVALID_MOVE;
    }
  }

  applyAssignments(G, G.pendingAssignments, G.variants);
  G.pendingAssignments = {};

  // Check if all tricks are done
  const tricksPerYear = getTricksPerYear(G.isFamine);
  if (G.trickCount >= tricksPerYear) {
    events.endPhase();
  } else {
    events.setPhase('trick');
  }
}

// Move: Swap a hidden plot card with a hand card
function swapCard({ G, playerID }, hiddenCardIndex, handCardIndex) {
  const playerIdx = parseInt(playerID, 10);
  const player = G.players[playerIdx];

  if (hiddenCardIndex < 0 || handCardIndex < 0) {
    return;
  }

  if (
    hiddenCardIndex >= player.plot.hidden.length ||
    handCardIndex >= player.hand.length
  ) {
    return INVALID_MOVE;
  }

  const temp = player.plot.hidden[hiddenCardIndex];
  player.plot.hidden[hiddenCardIndex] = player.hand[handCardIndex];
  player.hand[handCardIndex] = temp;
}

// Move: Confirm swap is complete
function confirmSwap({ G, playerID }) {
  const playerIdx = parseInt(playerID, 10);
  if (!G.swapConfirmed) {
    G.swapConfirmed = {};
  }
  G.swapConfirmed[playerIdx] = true;
}

// Export the game definition
export const KolkhozGame = {
  name: 'kolkhoz',

  setup,

  minPlayers: 2,
  maxPlayers: 4,

  phases: {
    planning: {
      start: true,
      moves: { setTrump },
      next: 'trick',
      onBegin: ({ G }) => {
        // Famine year (Ace of Clubs revealed): no trump
        if (G.isFamine) {
          G.trump = null;
        }
      },
      endIf: ({ G }) => G.isFamine || G.trump !== null,
      onEnd: ({ G, random }) => {
        // If trump wasn't set (and not famine), set it randomly
        if (!G.isFamine && !G.trump) {
          setRandomTrump(G, random);
        }
      },
    },

    trick: {
      moves: { playCard },
      turn: {
        order: {
          first: ({ G }) => G.lead,
          next: ({ G, ctx }) => (ctx.playOrderPos + 1) % ctx.numPlayers,
        },
        minMoves: 1,
        maxMoves: 1,
      },
      endIf: ({ G, ctx }) => G.currentTrick.length === ctx.numPlayers,
      onEnd: ({ G }) => {
        // Resolve the trick
        const winner = resolveTrick(G);
        if (winner !== null) {
          applyTrickResult(G, winner);

          // Check for auto-assignment
          const autoAssign = generateAutoAssignment(G.lastTrick);
          if (autoAssign) {
            applyAssignments(G, autoAssign, G.variants);
            G.needsManualAssignment = false;
          } else {
            G.needsManualAssignment = true;
          }
        }
      },
      next: ({ G }) => {
        if (G.needsManualAssignment) {
          return 'assignment';
        }
        const tricksPerYear = getTricksPerYear(G.isFamine);
        if (G.trickCount >= tricksPerYear) {
          return 'plotSelection';
        }
        return 'trick';
      },
    },

    assignment: {
      moves: { assignCard, submitAssignments },
      turn: {
        order: {
          first: ({ G }) => G.lastWinner,
          next: () => undefined, // Only one player acts
        },
      },
      onBegin: ({ G }) => {
        // Pre-populate with default assignments (each card to its own suit)
        G.pendingAssignments = {};
        for (const [, card] of G.lastTrick) {
          const cardKey = `${card.suit}-${card.value}`;
          G.pendingAssignments[cardKey] = card.suit;
        }
      },
      next: ({ G }) => {
        const tricksPerYear = getTricksPerYear(G.isFamine);
        if (G.trickCount >= tricksPerYear) {
          return 'plotSelection';
        }
        return 'trick';
      },
    },

    plotSelection: {
      onBegin: ({ G }) => {
        // Auto-add all remaining cards to plot
        for (const player of G.players) {
          while (player.hand.length > 0) {
            const card = player.hand.pop();
            player.plot.hidden.push(card);
          }
        }
      },
      endIf: () => true, // Ends immediately after onBegin
      next: 'requisition',
    },

    requisition: {
      // Automatic phase - no moves, ends immediately
      onBegin: ({ G, random }) => {
        performRequisition(G, G.variants);

        // Transition to next year
        transitionToNextYear(G, G.variants, random);
      },
      endIf: () => true,
      next: ({ G }) => {
        if (G.year > 5) {
          return undefined; // Game over handled by endIf at game level
        }
        if (G.variants.allowSwap) {
          return 'swap';
        }
        return 'planning';
      },
    },

    swap: {
      moves: { swapCard, confirmSwap },
      turn: {
        activePlayers: { all: 'swap' },
      },
      onBegin: ({ G }) => {
        // Reset swap confirmation tracking
        G.swapConfirmed = {};
      },
      endIf: ({ G, ctx }) => {
        // End when all players have confirmed
        if (!G.swapConfirmed) return false;
        for (let i = 0; i < ctx.numPlayers; i++) {
          if (!G.swapConfirmed[i]) return false;
        }
        return true;
      },
      onEnd: ({ G }) => {
        // Clean up
        delete G.swapConfirmed;
      },
      next: 'planning',
    },
  },

  endIf: ({ G }) => {
    if (G.year > 5) {
      return getWinner(G, G.variants);
    }
  },

  // Hide other players' hands and hidden plots for multiplayer
  playerView: ({ G, ctx, playerID }) => {
    if (playerID === null) return G; // Spectator sees all

    const pid = parseInt(playerID, 10);
    const filteredG = JSON.parse(JSON.stringify(G)); // Deep clone

    filteredG.players = G.players.map((player, idx) => {
      const isCurrentPlayer = idx === pid;

      return {
        ...player,
        // Other players' hands show card count only
        hand: isCurrentPlayer
          ? player.hand
          : player.hand.map(() => ({ hidden: true })),
        plot: {
          ...player.plot,
          // Hidden plot cards stay hidden
          hidden: isCurrentPlayer
            ? player.plot.hidden
            : player.plot.hidden.map(() => ({ hidden: true })),
        },
      };
    });

    // Hide remaining deck
    filteredG.workersDeck = G.workersDeck.map(() => ({ hidden: true }));

    return filteredG;
  },

  // AI configuration
  ai: {
    enumerate: (G, ctx, playerID) => {
      const moves = [];
      const playerIdx = parseInt(playerID, 10);
      const player = G.players[playerIdx];

      if (ctx.phase === 'planning') {
        // AI can set any trump
        for (const suit of SUITS) {
          moves.push({ move: 'setTrump', args: [suit] });
        }
      } else if (ctx.phase === 'trick') {
        // Enumerate valid card plays
        for (let i = 0; i < player.hand.length; i++) {
          if (isValidPlay(G, playerIdx, i)) {
            moves.push({ move: 'playCard', args: [i] });
          }
        }
      } else if (ctx.phase === 'assignment' && playerIdx === G.lastWinner) {
        const pending = G.pendingAssignments || {};
        const pendingCount = Object.keys(pending).length;

        // If all cards assigned, submit
        if (pendingCount === G.lastTrick.length) {
          moves.push({ move: 'submitAssignments', args: [] });
        } else {
          // Get all suits represented in the trick
          const suitsInTrick = [...new Set(G.lastTrick.map(([, c]) => c.suit))];

          // Find next unassigned card and assign it
          for (const [, card] of G.lastTrick) {
            const key = `${card.suit}-${card.value}`;
            if (!pending[key]) {
              // Any card can go to any suit in the trick
              for (const targetSuit of suitsInTrick) {
                moves.push({ move: 'assignCard', args: [key, targetSuit] });
              }
              break; // Only enumerate for first unassigned card
            }
          }
        }
      } else if (ctx.phase === 'swap' || ctx.activePlayers?.[playerID] === 'swapping') {
        // AI can skip swapping by confirming
        moves.push({ move: 'confirmSwap', args: [] });
        // Or enumerate possible swaps
        for (let h = 0; h < player.plot.hidden.length; h++) {
          for (let c = 0; c < player.hand.length; c++) {
            moves.push({ move: 'swapCard', args: [h, c] });
          }
        }
      }

      return moves;
    },
  },
};
