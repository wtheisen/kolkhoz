// YearManager - handles year transitions and scoring

import { SUITS, MAX_YEARS } from './constants.js';

export class YearManager {
  constructor(gameVariants) {
    this.gameVariants = gameVariants;
  }

  nextYear(gameState, deckManager) {
    // Store accumulated cards for unclaimed jobs
    if (this.gameVariants.accumulateUnclaimedJobs &&
        this.gameVariants.deckType !== '36' &&
        !this.gameVariants.northernStyle) {
      for (const suit of SUITS) {
        if (!gameState.claimedJobs.has(suit)) {
          const jobRewards = Array.isArray(gameState.revealedJobs[suit])
            ? gameState.revealedJobs[suit]
            : [gameState.revealedJobs[suit]];
          gameState.accumulatedJobCards[suit].push(...jobRewards);
        }
      }
    }

    gameState.year++;
    
    // Check if we've completed all years (after incrementing, so year 5 can complete)
    if (gameState.year > MAX_YEARS) {
      gameState.phase = 'game_over';
      return;
    }
    gameState.phase = 'planning';
    gameState.trickCount = 0; // Reset trick count for new year
    gameState.currentTrick = []; // Clear current trick for new year

    // Reset work hours
    for (const suit of SUITS) {
      gameState.workHours[suit] = 0;
    }

    // Reveal new jobs
    gameState.revealedJobs = deckManager.revealJobs(
      gameState.jobPiles,
      gameState.accumulatedJobCards
    );

    // Handle ordenNachalniku variant: at start of next year, only keep the lowest card (revealed)
    // All other cards (hidden) from stacks go back to the deck
    if (this.gameVariants.ordenNachalniku && this.gameVariants.deckType === '36') {
      for (const p of gameState.players) {
        if (p.plot.stacks) {
          for (const stack of p.plot.stacks) {
            // Only keep the revealed card (lowest card, face-up on top)
            if (stack.revealed && stack.revealed.length > 0) {
              p.plot.revealed.push(...stack.revealed);
            }
            // Hidden cards are NOT moved to plot - they will be available for the deck
            // since they're not in any excluded location (not in plot, not in hand, not in jobBuckets)
          }
          // Clear stacks - hidden cards are now available for deck preparation
          p.plot.stacks = [];
        }
      }
    }

    // Clear job buckets and claimed jobs
    for (const suit of SUITS) {
      gameState.jobBuckets[suit] = [];
    }
    gameState.claimedJobs.clear();

    // Reset player flags and accumulate medals
    for (const p of gameState.players) {
      // Clear hand before dealing new cards
      p.hand = [];
      // Accumulate medals earned this year into plot medals (only if variant is enabled)
      if (this.gameVariants.medalsCount && p.medals > 0) {
        p.plot.medals = (p.plot.medals || 0) + p.medals;
        p.medals = 0;
      } else {
        // Reset medals if variant is disabled
        p.medals = 0;
      }
      p.hasWonTrickThisYear = false;
      p.brigadeLeader = false;
    }

    // Prepare new deck and deal cards
    gameState.workersDeck = deckManager.prepareWorkersDeck(
      gameState.players,
      gameState.jobBuckets,
      gameState.exiled,
      this.gameVariants.ordenNachalniku
    );
    gameState.isFamine = deckManager.dealHands(gameState.players, gameState.workersDeck);

    // Handle swap phase
    if (this.gameVariants.allowSwap) {
      gameState.phase = 'swap';
      gameState.currentSwapPlayer = 0;
    } else {
      this._setTrump(gameState);
      gameState.phase = 'planning';
    }
  }

  calculateScores(gameState) {
    const scores = {};

    for (const [idx, p] of gameState.players.entries()) {
      let score = 0;

      // Count revealed cards
      for (const c of p.plot.revealed) {
        score += c.value;
      }

      // Count medals if variant enabled (use plot.medals for accumulated total)
      if (this.gameVariants.medalsCount) {
        score += (p.plot.medals || 0) + (p.medals || 0); // Include both accumulated and current year medals
      }

      // Count stacks (ordenNachalniku variant)
      // Only count the revealed card (lowest, face-up on top) from each stack
      // Hidden cards in stacks are shuffled back into the deck at the start of next year
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

  calculateFinalScores(gameState) {
    const scores = this.calculateScores(gameState);

    // Add hidden cards (rules say to sum all cards in Личный Участок, including hidden workers)
    for (const [idx, p] of gameState.players.entries()) {
      for (const c of p.plot.hidden) {
        scores[idx] += c.value;
      }
    }

    return scores;
  }

  _setTrump(gameState) {
    const availableSuits = SUITS.filter(s => gameState.jobPiles[s].length > 0);
    if (availableSuits.length > 0) {
      const randomIndex = Math.floor(Math.random() * availableSuits.length);
      gameState.trump = availableSuits[randomIndex];
    }
  }
}
