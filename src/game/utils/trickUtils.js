// Trick utility functions for boardgame.io
// Adapted from TrickPhaseManager.js

import { THRESHOLD } from '../constants.js';

// Check if a card play is valid (follow suit rules)
export function isValidPlay(G, playerIdx, cardIndex) {
  const player = G.players[playerIdx];
  if (cardIndex < 0 || cardIndex >= player.hand.length) {
    return false;
  }

  const card = player.hand[cardIndex];

  // First card in trick - any card is valid
  if (G.currentTrick.length === 0) {
    return true;
  }

  // Must follow lead suit if able
  const leadSuit = G.currentTrick[0][1].suit;
  const hasLeadSuit = player.hand.some((c) => c.suit === leadSuit);

  if (hasLeadSuit) {
    return card.suit === leadSuit;
  }

  // Can't follow suit - any card is valid
  return true;
}

// Get valid card indices for a player
export function getValidCardIndices(G, playerIdx) {
  const player = G.players[playerIdx];
  const validIndices = [];

  for (let i = 0; i < player.hand.length; i++) {
    if (isValidPlay(G, playerIdx, i)) {
      validIndices.push(i);
    }
  }

  return validIndices;
}

// Resolve a completed trick - determine winner
export function resolveTrick(G) {
  if (G.currentTrick.length !== G.numPlayers) {
    return null;
  }

  const leadSuit = G.currentTrick[0][1].suit;
  const trumpCards = G.currentTrick.filter(([, c]) => c.suit === G.trump);

  // Find winner - highest trump, or highest lead suit
  const cardsToCheck =
    trumpCards.length > 0
      ? trumpCards
      : G.currentTrick.filter(([, c]) => c.suit === leadSuit);

  let bestPid = null;
  let maxValue = -1;

  for (const [pid, card] of cardsToCheck) {
    if (card.value > maxValue) {
      maxValue = card.value;
      bestPid = pid;
    }
  }

  return bestPid;
}

// Apply trick result to game state
export function applyTrickResult(G, winnerPid) {
  G.lastWinner = winnerPid;
  G.lastTrick = [...G.currentTrick];
  G.currentTrick = [];
  G.trickCount++;
  G.lead = winnerPid;

  // Clear brigade leader flags and set new one
  for (const p of G.players) {
    p.brigadeLeader = false;
  }
  G.players[winnerPid].brigadeLeader = true;
  G.players[winnerPid].hasWonTrickThisYear = true;
  G.players[winnerPid].medals++;

  return winnerPid;
}

// Check if all cards in trick are same suit (for auto-assignment)
export function allCardsSameSuit(trick) {
  if (trick.length === 0) return false;
  const firstSuit = trick[0][1].suit;
  return trick.every(([, card]) => card.suit === firstSuit);
}

// Get number of tricks (3 during famine, 4 otherwise)
export function getTricksPerYear(isFamine) {
  return isFamine ? 3 : 4;
}

// Apply card assignments to jobs
export function applyAssignments(G, assignments, variants) {
  // assignments is an object: { "Hearts-10": "Clubs", ... }
  for (const [cardKey, targetSuit] of Object.entries(assignments)) {
    // Find the card in lastTrick
    const [suit, valueStr] = cardKey.split('-');
    const value = parseInt(valueStr, 10);
    const card = { suit, value };

    G.jobBuckets[targetSuit].push(card);

    let workValue = value;

    // Special effects for nomenclature variant (Drunkard = Jack of trump)
    if (variants.nomenclature && suit === G.trump && value === 11) {
      workValue = 0;
    }

    G.workHours[targetSuit] += workValue;
  }

  // Check for completed jobs
  for (const suit of Object.keys(G.workHours)) {
    if (G.workHours[suit] >= THRESHOLD && !G.claimedJobs.includes(suit)) {
      handleCompletedJob(G, suit, variants);
    }
  }
}

// Handle a completed job
function handleCompletedJob(G, suit, variants) {
  G.claimedJobs.push(suit);

  if (variants.deckType === 36 && variants.ordenNachalniku) {
    // Create a stack for the winner's plot
    const bucket = [...G.jobBuckets[suit]];
    if (bucket.length === 0) return;

    const lowestCard = bucket.reduce((lowest, card) =>
      card.value < lowest.value ? card : lowest
    );

    const otherCards = bucket
      .filter((c) => !(c.suit === lowestCard.suit && c.value === lowestCard.value))
      .sort((a, b) => a.value - b.value);

    const winner = G.players[G.lastWinner];
    if (!winner.plot.stacks) {
      winner.plot.stacks = [];
    }

    winner.plot.stacks.push({
      revealed: [lowestCard],
      hidden: otherCards,
    });

    G.jobBuckets[suit] = [];
  } else if (variants.deckType !== 36) {
    // Award job rewards to winner
    const winner = G.players[G.lastWinner];
    const rewards = Array.isArray(G.revealedJobs[suit])
      ? G.revealedJobs[suit]
      : [G.revealedJobs[suit]];

    for (const card of rewards) {
      winner.plot.revealed.push(card);
    }

    // Clear accumulated cards for this job
    if (variants.accumulateJobs) {
      G.accumulatedJobCards[suit] = [];
    }
  }
}

// Generate auto-assignment for same-suit tricks
export function generateAutoAssignment(trick) {
  if (!allCardsSameSuit(trick)) return null;

  const targetSuit = trick[0][1].suit;
  const assignments = {};

  for (const [, card] of trick) {
    const key = `${card.suit}-${card.value}`;
    assignments[key] = targetSuit;
  }

  return assignments;
}
