// Deck utility functions for boardgame.io
// Adapted from DeckManager.js - uses ctx.random for deterministic shuffling

import { SUITS, VALUES, MAX_YEARS } from '../constants.js';

// Prepare job piles at game start
export function prepareJobPiles(variants, random) {
  const jobPiles = {};

  if (variants.deckType === 36) {
    // For 36-card deck: just set out the 4 Aces to indicate job piles
    for (const suit of SUITS) {
      jobPiles[suit] = [{ suit, value: 1 }];
    }
  } else {
    // Standard 52-card deck: Ace-5 for each suit
    for (const suit of SUITS) {
      const pile = Array.from({ length: MAX_YEARS }, (_, i) => ({
        suit,
        value: i + 1,
      }));
      jobPiles[suit] = random.Shuffle(pile);
    }
  }

  return jobPiles;
}

// Reveal jobs for the current year
// Returns { jobs } - famine is now determined by year (always Year 5)
export function revealJobs(jobPiles, accumulatedJobCards, variants) {
  const revealedJobs = {};

  // Safety check
  if (!jobPiles) {
    console.error('revealJobs called with undefined jobPiles');
    return { jobs: revealedJobs };
  }

  for (const suit of SUITS) {
    const pile = jobPiles[suit];
    if (!pile || pile.length === 0) {
      // No cards left in this pile
      revealedJobs[suit] = null;
      continue;
    }

    if (variants?.deckType === 36) {
      // For 36-card deck, no job rewards - just show the Ace
      revealedJobs[suit] = pile[0];
    } else if (variants?.accumulateJobs && accumulatedJobCards?.[suit]?.length > 0) {
      // Reveal next card and combine with accumulated cards
      const nextCard = pile.pop();
      const accumulated = accumulatedJobCards[suit] || [];
      revealedJobs[suit] = [...accumulated, nextCard].filter(Boolean);
    } else {
      // Standard: just reveal next card
      revealedJobs[suit] = pile.pop();
    }
  }

  return { jobs: revealedJobs };
}

// Check if a card value is valid for the deck type
function isValidCard(value, variants) {
  return variants.deckType !== 36 || (value < 2 || value > 5);
}

// Prepare workers deck for dealing
export function prepareWorkersDeck(players, jobBuckets, exiled, variants, random) {
  // Generate all worker cards (6-13 for each suit = 32 cards)
  const allCards = [];
  for (const suit of SUITS) {
    for (let val = 6; val <= 13; val++) {
      allCards.push({ suit, value: val });
    }
  }

  // Track used cards
  const used = new Set();

  // Exclude cards in player hands and plots
  for (const p of players) {
    for (const c of p.hand || []) {
      if (isValidCard(c.value, variants)) {
        used.add(`${c.suit}-${c.value}`);
      }
    }
    for (const c of p.plot.revealed || []) {
      if (isValidCard(c.value, variants)) {
        used.add(`${c.suit}-${c.value}`);
      }
    }
    for (const c of p.plot.hidden || []) {
      if (isValidCard(c.value, variants)) {
        used.add(`${c.suit}-${c.value}`);
      }
    }
  }

  // Exclude exiled cards unless ordenNachalniku variant is enabled
  if (!variants.ordenNachalniku) {
    for (const yearCards of Object.values(exiled || {})) {
      for (const cardKey of yearCards) {
        used.add(cardKey);
      }
    }
  }

  // Filter and shuffle
  const workersDeck = allCards.filter(
    (c) => isValidCard(c.value, variants) && !used.has(`${c.suit}-${c.value}`)
  );

  return random.Shuffle(workersDeck);
}

// Deal hands to players
// During famine (Ace of Clubs revealed), deal 4 cards instead of 5
export function dealHands(players, workersDeck, isFamine = false) {
  const numPlayers = players.length;
  const cardsPerPlayer = isFamine ? 4 : 5;

  // Clear existing hands
  for (const p of players) {
    p.hand = [];
  }

  // Deal cards
  for (let round = 0; round < cardsPerPlayer; round++) {
    for (const p of players) {
      if (workersDeck.length > 0) {
        p.hand.push(workersDeck.pop());
      }
    }
  }
}

