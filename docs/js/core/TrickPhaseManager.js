// TrickPhaseManager - handles trick playing and resolution

export class TrickPhaseManager {
  constructor(gameVariants) {
    this.gameVariants = gameVariants;
  }

  playCard(gameState, pid, idx) {
    const player = gameState.players[pid];
    if (idx < 0 || idx >= player.hand.length) {
      throw new Error(`Invalid card index ${idx} for player ${pid}`);
    }

    const card = player.hand.splice(idx, 1)[0];
    gameState.currentTrick.push([pid, card]);

    if (gameState.currentTrick.length === gameState.numPlayers) {
      this.resolveTrick(gameState);
    }

    return card;
  }

  resolveTrick(gameState) {
    // Filter out any undefined cards
    gameState.currentTrick = gameState.currentTrick.filter(([pid, c]) => {
      if (!c) {
        console.warn('[GameState] Filtering out undefined card from player', pid);
        return false;
      }
      return true;
    });

    if (gameState.currentTrick.length < gameState.numPlayers) {
      console.error('[GameState] Not enough cards in trick after filtering');
      return;
    }

    const leadSuit = gameState.currentTrick[0][1].suit;
    // During famine year, there's no trump, so trumpCards will be empty
    const trumpCards = gameState.trump 
      ? gameState.currentTrick.filter(([pid, c]) => c.suit === gameState.trump)
      : [];

    // Find winner
    let bestPid, bestCard;
    // If there are trump cards, they win. Otherwise, highest lead suit wins.
    // During famine year (no trump), only lead suit cards are checked.
    const cardsToCheck = trumpCards.length > 0 ? trumpCards :
                         gameState.currentTrick.filter(([pid, c]) => c.suit === leadSuit);

    let maxValue = -1;
    for (const [pid, card] of cardsToCheck) {
      if (card.value > maxValue) {
        maxValue = card.value;
        bestPid = pid;
        bestCard = card;
      }
    }

    // Record winner
    gameState.lastWinner = bestPid;
    gameState.lastTrick = [...gameState.currentTrick];
    gameState.currentTrick = [];
    gameState.trickCount++;
    gameState.lead = gameState.lastWinner;

    // Clear brigade leader flags and set new one
    for (const p of gameState.players) {
      p.brigadeLeader = false;
    }
    gameState.players[bestPid].brigadeLeader = true;
    gameState.players[bestPid].hasWonTrickThisYear = true;

    // Always track medals for display (shows tricks won), but only count toward score if variant enabled
    gameState.players[bestPid].medals++;

    // Check for auto-assignment
    if (gameState.players[gameState.lastWinner].isHuman) {
      const allCardsSameSuit = gameState.lastTrick.every(
        ([pid, card]) => card.suit === gameState.lastTrick[0][1].suit
      );

      if (allCardsSameSuit) {
        const commonSuit = gameState.lastTrick[0][1].suit;
        const mapping = new Map();
        for (const [pid, card] of gameState.lastTrick) {
          mapping.set(card, commonSuit);
        }
        this.applyAssignments(gameState, mapping);
        return;
      }

      gameState.phase = 'assignment';
    } else {
      gameState.phase = 'assignment';
    }
  }

  applyAssignments(gameState, mapping) {
    for (const [card, suit] of mapping.entries()) {
      gameState.jobBuckets[suit].push(card);

      let workValue = card.value;

      // Special effects for nomenclature variant
      if (this.gameVariants.nomenclature && card.suit === gameState.trump && card.value === 11) {
        workValue = 0; // Drunkard contributes 0 hours
      }

      gameState.workHours[suit] += workValue;
    }

    // Check for completed jobs
    for (const suit of Object.keys(gameState.workHours)) {
      if (gameState.workHours[suit] >= 40 && !gameState.claimedJobs.has(suit)) {
        this._handleCompletedJob(gameState, suit);
      }
    }

    // Check if this was the final trick of the year
    const tricksPerYear = this._getTricksPerYear(gameState);
    if (gameState.trickCount >= tricksPerYear) {
      // All tricks played - transition to plot selection
      gameState.phase = 'plot_selection';
      gameState.currentPlotSelectionPlayer = 0;
    } else {
      // Continue with next trick
      gameState.phase = 'trick';
    }
  }

  _getTricksPerYear(gameState) {
    // Always play one fewer trick than starting hand size
    // For normal years: startingHandSize is 5, so 4 tricks
    // For famine years: startingHandSize is < 5, so (startingHandSize - 1) tricks
    return gameState.startingHandSize - 1;
  }

  _handleCompletedJob(gameState, suit) {
    gameState.claimedJobs.add(suit);

    if (this.gameVariants.deckType === '36' && this.gameVariants.ordenNachalniku) {
      // Create a stack for the winner's plot
      // When a работа is closed, the Бригадир that closes it immediately adds 
      // the workers assigned to the работа in a singular stack to their подвал 
      // with the lowest card face-up on top.
      const bucket = [...gameState.jobBuckets[suit]]; // Copy to avoid mutation during reduce
      if (bucket.length === 0) return;
      
      const lowestCard = bucket.reduce((lowest, card) =>
        card.value < lowest.value ? card : lowest
      );

      // Sort other cards from smallest to largest for proper stacking
      const otherCards = bucket
        .filter(c => c !== lowestCard)
        .sort((a, b) => a.value - b.value);

      const winner = gameState.players[gameState.lastWinner];
      if (!winner.plot.stacks) {
        winner.plot.stacks = [];
      }

      // Add stack to winner's plot (подвал)
      winner.plot.stacks.push({
        suit: suit,  // Track which job this stack corresponds to
        revealed: [lowestCard],
        hidden: otherCards
      });
      
      // Remove cards from jobBuckets since they're now in the player's plot
      gameState.jobBuckets[suit] = [];
    } else if (this.gameVariants.deckType !== '36') {
      // Award job rewards to winner
      const winner = gameState.players[gameState.lastWinner];
      const rewards = Array.isArray(gameState.revealedJobs[suit])
        ? gameState.revealedJobs[suit]
        : [gameState.revealedJobs[suit]];

      for (const card of rewards) {
        winner.plot.revealed.push(card);
      }

      // Clear accumulated cards for this job
      if (this.gameVariants.accumulateUnclaimedJobs) {
        gameState.accumulatedJobCards[suit] = [];
      }
    }
  }
}
