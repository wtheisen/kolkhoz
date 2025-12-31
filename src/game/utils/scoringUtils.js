// Scoring utility functions for boardgame.io
// Adapted from YearManager.js

import { SUITS, MAX_YEARS } from '../constants.js';
import { prepareWorkersDeck, dealHands, revealJobs } from './deckUtils.js';

// Calculate current scores (visible cards only)
export function calculateScores(G, variants) {
  const scores = {};

  for (let idx = 0; idx < G.players.length; idx++) {
    const p = G.players[idx];
    let score = 0;

    // Count revealed cards
    for (const c of p.plot.revealed || []) {
      score += c.value;
    }

    // Count medals if variant enabled
    if (variants.medalsCount) {
      score += (p.plot.medals || 0) + (p.medals || 0);
    }

    // Count stacks (ordenNachalniku variant)
    if (p.plot.stacks) {
      for (const stack of p.plot.stacks) {
        for (const c of stack.revealed || []) {
          score += c.value;
        }
      }
    }

    scores[idx] = score;
  }

  return scores;
}

// Calculate final scores (including hidden cards)
export function calculateFinalScores(G, variants) {
  const scores = calculateScores(G, variants);

  // Add hidden cards
  for (let idx = 0; idx < G.players.length; idx++) {
    const p = G.players[idx];
    for (const c of p.plot.hidden || []) {
      scores[idx] += c.value;
    }
  }

  return scores;
}

// Get winner (lowest score wins)
export function getWinner(G, variants) {
  const scores = calculateFinalScores(G, variants);
  let minScore = Infinity;
  let winner = 0;

  for (const [idx, score] of Object.entries(scores)) {
    if (score < minScore) {
      minScore = score;
      winner = parseInt(idx, 10);
    }
  }

  return { winner, scores };
}

// Transition to next year
export function transitionToNextYear(G, variants, random) {
  // Handle unclaimed job rewards (52-card deck only)
  if (variants?.deckType !== 36 && !variants?.northernStyle && G.revealedJobs) {
    for (const suit of SUITS) {
      if (!G.claimedJobs?.includes(suit)) {
        const revealed = G.revealedJobs[suit];
        if (!revealed) continue;

        const jobRewards = Array.isArray(revealed) ? revealed : [revealed];

        if (variants.accumulateJobs) {
          // Accumulate for next year
          if (!G.accumulatedJobCards[suit]) {
            G.accumulatedJobCards[suit] = [];
          }
          G.accumulatedJobCards[suit].push(...jobRewards.filter(Boolean));
        } else {
          // Send unclaimed rewards to gulag
          if (!G.exiled[G.year]) {
            G.exiled[G.year] = [];
          }
          for (const card of jobRewards) {
            if (card) {
              G.exiled[G.year].push(`${card.suit}-${card.value}`);
            }
          }
        }
      }
    }
  }

  G.year++;

  // Check if game is over
  if (G.year > MAX_YEARS) {
    return true; // Game over
  }

  G.trickCount = 0;
  G.currentTrick = [];
  G.trump = null; // Reset trump for new year - will be set in planning phase

  // Reset work hours
  for (const suit of SUITS) {
    G.workHours[suit] = 0;
  }

  // Reveal new jobs and check for famine (Ace of Clubs)
  const { jobs, isFamine } = revealJobs(G.jobPiles, G.accumulatedJobCards, variants);
  G.revealedJobs = jobs;
  G.isFamine = isFamine;

  // Handle ordenNachalniku variant: move revealed cards from stacks to plot
  if (variants.ordenNachalniku && variants.deckType === 36) {
    for (const p of G.players) {
      if (p.plot.stacks) {
        for (const stack of p.plot.stacks) {
          if (stack.revealed && stack.revealed.length > 0) {
            p.plot.revealed.push(...stack.revealed);
          }
        }
        p.plot.stacks = [];
      }
    }
  }

  // Clear job buckets and claimed jobs
  for (const suit of SUITS) {
    G.jobBuckets[suit] = [];
  }
  G.claimedJobs = [];

  // Reset player flags
  for (const p of G.players) {
    p.hand = [];
    if (variants.medalsCount && p.medals > 0) {
      p.plot.medals = (p.plot.medals || 0) + p.medals;
    }
    p.medals = 0;
    p.hasWonTrickThisYear = false;
    p.brigadeLeader = false;
  }

  // Rotate trump selector for next year
  G.trumpSelector = (G.trumpSelector + 1) % G.numPlayers;

  // Prepare new deck and deal cards
  G.workersDeck = prepareWorkersDeck(
    G.players,
    G.jobBuckets,
    G.exiled,
    variants,
    random
  );
  dealHands(G.players, G.workersDeck, G.isFamine);

  return false; // Game continues
}

// Set trump suit (randomly from available)
export function setRandomTrump(G, random) {
  const availableSuits = SUITS.filter((s) => G.jobPiles[s].length > 0);
  if (availableSuits.length > 0) {
    const index = random.Die(availableSuits.length) - 1;
    G.trump = availableSuits[index];
  }
}
