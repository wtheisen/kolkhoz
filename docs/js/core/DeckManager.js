// DeckManager - handles all deck preparation, shuffling, and dealing operations

import { Card } from './Card.js';
import { SUITS, VALUES, MAX_YEARS } from './constants.js';

export class DeckManager {
  constructor(gameVariants) {
    this.gameVariants = gameVariants;
  }

  prepareJobPiles() {
    const jobPiles = {};

    if (this.gameVariants.deckType === '36') {
      // For 36-card deck: just set out the 4 Aces to indicate job piles
      for (const suit of SUITS) {
        jobPiles[suit] = [new Card(suit, 1)];
      }
    } else {
      // Standard 52-card deck: Ace-5 for each suit
      for (const suit of SUITS) {
        const pile = Array.from({ length: MAX_YEARS }, (_, i) =>
          new Card(suit, i + 1)
        );
        this.shuffle(pile);
        jobPiles[suit] = pile;
      }
    }

    return jobPiles;
  }

  revealJobs(jobPiles, accumulatedJobCards) {
    const revealedJobs = {};

    for (const suit of SUITS) {
      if (this.gameVariants.deckType === '36') {
        // For 36-card deck, no job rewards - just show the Ace
        revealedJobs[suit] = jobPiles[suit][0];
      } else if (this.gameVariants.accumulateUnclaimedJobs) {
        // Reveal next card and combine with accumulated cards
        const nextCard = jobPiles[suit].pop();
        const accumulated = accumulatedJobCards[suit] || [];
        revealedJobs[suit] = [...accumulated, nextCard];
      } else {
        // Standard: just reveal next card
        revealedJobs[suit] = jobPiles[suit].pop();
      }
    }

    return revealedJobs;
  }

  prepareWorkersDeck(players, jobBuckets, exiled, ordenNachalniku) {
    // Generate all worker cards
    // 52-card deck: 6-10, J, Q, K (8 cards per suit × 4 = 32 cards)
    // 36-card deck: 6-10, J, Q, K (8 cards per suit × 4 = 32 cards)
    // Note: In 36-card mode, Aces are used only as job pile indicators, not playable cards
    const allCards = [];
    
    // Both deck types use the same worker cards: 6-10, Jack, Queen, King
    for (const suit of SUITS) {
      for (let val = 6; val <= 13; val++) {
        allCards.push(new Card(suit, val));
      }
    }

    // Track used cards
    const used = new Set();

    // Exclude cards in player hands and plots
    for (const p of players) {
      for (const c of p.hand) {
        if (this._isValidCard(c.value)) {
          used.add(`${c.suit}-${c.value}`);
        }
      }
      for (const c of p.plot.revealed) {
        if (this._isValidCard(c.value)) {
          used.add(`${c.suit}-${c.value}`);
        }
      }
      for (const c of p.plot.hidden) {
        if (this._isValidCard(c.value)) {
          used.add(`${c.suit}-${c.value}`);
        }
      }
    }

    // Exclude exiled cards unless ordenNachalniku variant is enabled
    if (!ordenNachalniku) {
      for (const yearCards of Object.values(exiled)) {
        for (const cardKey of yearCards) {
          const [, valueStr] = cardKey.split('-');
          const value = parseInt(valueStr, 10);
          if (this._isValidCard(value)) {
            used.add(cardKey);
          }
        }
      }
    }

    // Filter and shuffle
    const workersDeck = allCards.filter(c =>
      this._isValidCard(c.value) && !used.has(`${c.suit}-${c.value}`)
    );

    this.shuffle(workersDeck);
    return workersDeck;
  }

  dealHands(players, workersDeck) {
    const numPlayers = players.length;
    const cardsPerPlayer = 5;
    const requiredCards = numPlayers * cardsPerPlayer;
    
    // Only do normal dealing if we have at least the required number of cards
    // If we have less, treat as famine year and deal equally
    if (workersDeck.length >= requiredCards) {
      // Normal dealing: 5 cards to each player
      // Deal in rounds: each round, give one card to each player
      for (let round = 0; round < cardsPerPlayer; round++) {
        for (const p of players) {
          p.hand.push(workersDeck.pop());
        }
      }
      return false; // Not a famine year
    } else {
      // Famine year: deal equal amounts to all players
      const cardsPerPlayerFamine = Math.floor(workersDeck.length / numPlayers);
      
      // Deal equal amounts to all players
      for (let i = 0; i < cardsPerPlayerFamine; i++) {
        for (const p of players) {
          if (workersDeck.length > 0) {
            p.hand.push(workersDeck.pop());
          }
        }
      }
      
      // Any remaining cards are left in the deck (not dealt to maintain equality)
      return true; // This is a famine year
    }
  }

  shuffle(array) {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
  }

  _isValidCard(value) {
    return this.gameVariants.deckType !== '36' || (value < 2 || value > 5);
  }
}
