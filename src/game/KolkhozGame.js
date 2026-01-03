// Kolkhoz - boardgame.io Game Definition
// A Soviet-themed trick-taking card game

import { INVALID_MOVE } from 'boardgame.io/core';
import { SUITS, PLAYER_NAMES, DEFAULT_VARIANTS, MAX_YEARS } from './constants.js';
import { prepareJobPiles, revealJobs, prepareWorkersDeck, dealHands } from './utils/deckUtils.js';
import {
  isValidPlay,
  resolveTrick,
  applyTrickResult,
  applyAssignments,
  generateAutoAssignment,
  isYearComplete,
} from './utils/trickUtils.js';
import { performRequisition } from './utils/requisitionUtils.js';
import { getWinner, transitionToNextYear, setRandomTrump } from './utils/scoringUtils.js';
import { getPrioritizedMoves } from './utils/aiUtils.js';

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
  console.log('Game setup - setupData:', setupData);
  console.log('Game setup - variants.allowSwap:', variants.allowSwap);
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
    // For AI assignment animation - pending assignments to be animated then applied
    pendingAIAssignments: null,
    // Trump selector rotates each year
    trumpSelector: Math.floor(random.Number() * numPlayers),
  };

  // Initialize per-suit state
  for (const suit of SUITS) {
    G.accumulatedJobCards[suit] = [];
    G.workHours[suit] = 0;
    G.jobBuckets[suit] = [];
  }

  // Reveal jobs for year 1
  const { jobs } = revealJobs(G.jobPiles, G.accumulatedJobCards, variants);
  G.revealedJobs = jobs;
  // Famine year is ALWAYS the last year (Year 5)
  G.isFamine = (G.year === MAX_YEARS);

  // Initialize drunkard replacements (job rewards that compensate for exiled Jacks)
  G.drunkardReplacements = [];

  // Prepare deck and deal hands (4 cards during famine, 5 otherwise)
  G.workersDeck = prepareWorkersDeck(G.players, G.jobBuckets, G.exiled, variants, random, G.drunkardReplacements);
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

  // For AI players, defer assignment for animation
  // Player 0 is human, others are AI
  if (G.lastWinner !== 0) {
    G.pendingAIAssignments = {
      trick: JSON.parse(JSON.stringify(G.lastTrick)),
      assignments: { ...G.pendingAssignments },
      winner: G.lastWinner,
      trump: G.trump,
    };
    G.pendingAssignments = {};
    // Don't apply yet - React will animate then call applySingleAssignment for each
    // Go to aiAssignment phase where FlyingCard animation will call applySingleAssignment
    events.setPhase('aiAssignment');
    return;
  }

  // Human player - apply immediately
  applyAssignments(G, G.pendingAssignments, G.variants);
  G.pendingAssignments = {};

  // Check if year is complete and route to appropriate phase
  if (isYearComplete(G)) {
    events.setPhase('plotSelection');
  } else {
    events.setPhase('trick');
  }
}

// Move: Swap a plot card with a hand card
// plotType: 'hidden' or 'revealed' - card takes on that position's state
function swapCard({ G, playerID }, plotCardIndex, handCardIndex, plotType = 'hidden') {
  const playerIdx = parseInt(playerID, 10);
  const player = G.players[playerIdx];

  // Check if player already swapped this turn (limit: 1 swap per player)
  if (G.swapCount && G.swapCount[playerIdx]) {
    return INVALID_MOVE;
  }

  if (plotCardIndex < 0 || handCardIndex < 0) {
    return;
  }

  if (handCardIndex >= player.hand.length) {
    return INVALID_MOVE;
  }

  const plotArray = plotType === 'revealed' ? player.plot.revealed : player.plot.hidden;

  if (plotCardIndex >= plotArray.length) {
    return INVALID_MOVE;
  }

  // True swap - cards exchange positions exactly
  const temp = plotArray[plotCardIndex];
  plotArray[plotCardIndex] = player.hand[handCardIndex];
  player.hand[handCardIndex] = temp;

  // Track the swap for UI animation and undo functionality
  G.lastSwap = {
    playerIdx,
    plotType,
    plotCardIndex,
    handCardIndex,
    // Store the card that went INTO the plot (for visual feedback)
    newPlotCard: { ...plotArray[plotCardIndex] },
    timestamp: Date.now(),
  };

  // Track that this player has swapped (limit: 1 swap per player)
  if (!G.swapCount) G.swapCount = {};
  G.swapCount[playerIdx] = true;
}

// Move: Confirm swap is complete
function confirmSwap({ G, playerID, events }) {
  const playerIdx = parseInt(playerID, 10);
  if (!G.swapConfirmed) {
    G.swapConfirmed = {};
  }
  G.swapConfirmed[playerIdx] = true;
  // End this player's turn, moving to next player
  events.endTurn();
}

// Move: Undo the last swap (allows player to change their mind)
function undoSwap({ G, playerID }) {
  const playerIdx = parseInt(playerID, 10);
  const player = G.players[playerIdx];

  // Can only undo if player has swapped and we have the swap info
  if (!G.swapCount?.[playerIdx] || !G.lastSwap || G.lastSwap.playerIdx !== playerIdx) {
    return INVALID_MOVE;
  }

  const { plotType, plotCardIndex, handCardIndex } = G.lastSwap;
  const plotArray = plotType === 'revealed' ? player.plot.revealed : player.plot.hidden;

  // Swap the cards back
  const temp = plotArray[plotCardIndex];
  plotArray[plotCardIndex] = player.hand[handCardIndex];
  player.hand[handCardIndex] = temp;

  // Clear the swap tracking
  delete G.swapCount[playerIdx];
  delete G.lastSwap;
}

// Move: Apply a single AI assignment (called by React after animation)
function applySingleAssignment({ G }, cardKey, targetSuit) {
  if (!G.pendingAIAssignments) return;

  // Apply this single card to the job bucket
  const [suit, valueStr] = cardKey.split('-');
  const value = parseInt(valueStr, 10);
  const card = { suit, value };

  G.jobBuckets[targetSuit].push(card);

  // Calculate work value (handling nomenclature variant)
  let workValue = value;
  if (G.variants.nomenclature && suit === G.trump && value === 11) {
    workValue = 0;
  }
  G.workHours[targetSuit] += workValue;

  // Check for completed job
  const THRESHOLD = 40;
  if (G.workHours[targetSuit] >= THRESHOLD && !G.claimedJobs.includes(targetSuit)) {
    // Handle completed job inline (simplified from handleCompletedJob)
    G.claimedJobs.push(targetSuit);

    if (G.variants.deckType === 36 && G.variants.ordenNachalniku) {
      const bucket = [...G.jobBuckets[targetSuit]];
      if (bucket.length > 0) {
        const lowestCard = bucket.reduce((lowest, c) =>
          c.value < lowest.value ? c : lowest
        );
        const otherCards = bucket
          .filter((c) => !(c.suit === lowestCard.suit && c.value === lowestCard.value))
          .sort((a, b) => a.value - b.value);
        const winner = G.players[G.pendingAIAssignments.winner];
        if (!winner.plot.stacks) winner.plot.stacks = [];
        winner.plot.stacks.push({ revealed: [lowestCard], hidden: otherCards });
        G.jobBuckets[targetSuit] = [];
      }
    } else if (G.variants.deckType !== 36) {
      const winner = G.players[G.pendingAIAssignments.winner];
      const rewards = Array.isArray(G.revealedJobs[targetSuit])
        ? G.revealedJobs[targetSuit]
        : [G.revealedJobs[targetSuit]];
      for (const c of rewards) {
        if (c) winner.plot.revealed.push(c);
      }
      G.revealedJobs[targetSuit] = null;
      if (G.variants.accumulateJobs) {
        G.accumulatedJobCards[targetSuit] = [];
      }
    }
  }

  // Remove this card from pending assignments
  delete G.pendingAIAssignments.assignments[cardKey];

  // Check if all assignments are done - phase endIf will trigger transition
  if (Object.keys(G.pendingAIAssignments.assignments).length === 0) {
    G.pendingAIAssignments = null;
  }
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
      turn: {
        order: {
          first: ({ G }) => G.trumpSelector,
          next: () => undefined, // Only one player selects trump
        },
      },
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
      next: ({ G }) => {
        const goToSwap = G.variants.allowSwap && G.year > 1;
        console.log('Planning next - allowSwap:', G.variants.allowSwap, 'year:', G.year, 'goToSwap:', goToSwap);
        return goToSwap ? 'swap' : 'trick';
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
          if (autoAssign && winner !== 0) {
            // AI won with same-suit trick - defer assignments for animation
            G.pendingAIAssignments = {
              trick: JSON.parse(JSON.stringify(G.lastTrick)),
              assignments: { ...autoAssign },
              winner: winner,
              trump: G.trump,
            };
            // Don't apply yet - go to aiAssignment phase, React will animate
            G.needsManualAssignment = false;
          } else {
            // Human won - always show assignment screen, let player assign manually
            G.needsManualAssignment = true;
          }
          // Year-end processing now handled by plotSelection → requisition flow
        }
      },
      next: ({ G }) => {
        if (G.needsManualAssignment) {
          return 'assignment';
        }

        if (G.pendingAIAssignments) {
          return 'aiAssignment';
        }

        if (isYearComplete(G)) {
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
        // Clear any existing assignments - player must assign manually
        G.pendingAssignments = {};
      },
      // next is handled by submitAssignments using events.setPhase()
      next: 'trick',
    },

    // Phase for animating AI assignments - blocks until all cards are assigned
    aiAssignment: {
      moves: { applySingleAssignment },
      turn: {
        order: {
          // Human player controls the animation calls
          first: () => 0,
          next: () => undefined,
        },
      },
      // Phase ends when all assignments are applied (pendingAIAssignments cleared)
      endIf: ({ G }) => !G.pendingAIAssignments,
      next: ({ G }) => {
        // After AI assignments complete, check if year is done
        if (isYearComplete(G)) {
          return 'plotSelection';
        }
        return 'trick';
      },
    },

    plotSelection: {
      onBegin: ({ G, events }) => {
        // Auto-add all remaining cards to plot
        for (const player of G.players) {
          while (player.hand.length > 0) {
            const card = player.hand.pop();
            player.plot.hidden.push(card);
          }
        }
        // Transition immediately after onBegin runs
        events.setPhase('requisition');
      },
      next: 'requisition',
    },

    requisition: {
      onBegin: ({ G }) => {
        // Perform requisition and store animation data in G.requisitionData
        performRequisition(G, G.variants);
        // DON'T transition here - wait for user to click continue
      },
      moves: {
        continueToNextYear: ({ G, random, events }) => {
          // Clear animation data
          G.requisitionData = null;
          // Transition to next year
          transitionToNextYear(G, G.variants, random);

          // Transition to next phase based on game state
          if (G.year > 5) {
            // Game over - don't transition
            return;
          }
          events.setPhase('planning');
        },
      },
      turn: {
        // Any player can click continue (human player controls)
        activePlayers: { all: 'requisitionWait' },
      },
      next: ({ G }) => {
        if (G.year > 5) {
          return undefined; // Game over handled by endIf at game level
        }
        return 'planning';
      },
    },

    swap: {
      moves: { swapCard, confirmSwap, undoSwap },
      turn: {
        order: {
          first: () => 0, // Human player goes first
          next: ({ ctx }) => {
            // Rotate through all players: 0 → 1 → 2 → 3 → end
            const nextPlayer = parseInt(ctx.currentPlayer, 10) + 1;
            return nextPlayer >= ctx.numPlayers ? undefined : nextPlayer;
          },
        },
      },
      onBegin: ({ G }) => {
        // Reset swap confirmation tracking - each player confirms on their turn
        G.swapConfirmed = {};
        // Reset swap count - each player can swap at most 1 card
        G.swapCount = {};
      },
      endIf: ({ G, ctx }) => {
        // End when all players have confirmed their swaps
        if (!G.swapConfirmed) return false;
        for (let i = 0; i < ctx.numPlayers; i++) {
          if (!G.swapConfirmed[i]) return false;
        }
        return true;
      },
      onEnd: ({ G }) => {
        delete G.swapConfirmed;
        delete G.swapCount;
      },
      next: 'trick',
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

  // AI configuration - uses smart heuristics for better play
  ai: {
    enumerate: (G, ctx, playerID) => {
      const playerIdx = parseInt(playerID, 10);

      // Get moves sorted by strategic value (best first)
      const prioritizedMoves = getPrioritizedMoves(G, ctx, playerIdx);

      // Return only the top moves to guide MCTS toward better decisions
      // Taking top 3 gives some variety while avoiding bad moves
      const topMoves = prioritizedMoves.slice(0, Math.min(3, prioritizedMoves.length));

      // Return in boardgame.io format (without scores)
      return topMoves.map(({ move, args }) => ({ move, args }));
    },
  },
};
