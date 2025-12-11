// RequisitionManager - handles all requisition logic and variants

import { THRESHOLD, SUITS } from './constants.js';

export class RequisitionManager {
  constructor(gameVariants) {
    this.gameVariants = gameVariants;
  }

  performRequisition(gameState) {
    // Log work hours
    gameState.trickHistory.push({
      type: 'jobs',
      year: gameState.year,
      jobs: { ...gameState.workHours }
    });

    // Log requisition events
    gameState.trickHistory.push({
      type: 'requisition',
      year: gameState.year,
      requisitions: []
    });

    // Check if all four поля (jobs) are un-farmed (failed)
    const allJobsFailed = SUITS.every(
      suit => gameState.workHours[suit] < THRESHOLD
    );

    // Check if any players are vulnerable to requisition
    const hasVulnerablePlayers = this._hasVulnerablePlayers(gameState);

    // If all four jobs failed and no players are vulnerable, use mice variant logic
    const useMiceVariantFallback = allJobsFailed && !hasVulnerablePlayers;

    for (const [suit, bucket] of Object.entries(gameState.jobBuckets)) {
      if (gameState.workHours[suit] >= THRESHOLD) {
        continue;
      }

      // Use mice variant if explicitly enabled OR if fallback condition is met
      if (this.gameVariants.miceVariant || useMiceVariantFallback) {
        this._performMiceVariant(gameState, suit, bucket);
      } else {
        // Standard and 36-card variants are now handled by the same function
        this._performStandard(gameState, suit, bucket);
      }
    }
  }

  _performMiceVariant(gameState, suit, bucket) {
    // Check for drunkard
    if (this._handleDrunkard(gameState, bucket)) {
      return;
    }

    // Check special effects
    const informant = this._hasInformant(bucket, gameState.trump);
    const partyOfficial = this._hasPartyOfficial(bucket, gameState.trump);

    // All players reveal matching cards
    const allRevealedCards = this._revealMatchingCards(gameState, suit, informant, null);
    if (allRevealedCards.length === 0) return;

    // Sort and exile highest
    allRevealedCards.sort((a, b) => b[1].value - a[1].value);
    this._exileCard(gameState, allRevealedCards[0]);

    // Party official exiles second card
    if (partyOfficial && allRevealedCards.length > 1) {
      const [player, card] = allRevealedCards[1];
      const cardIndex = player.plot.revealed.findIndex(
        c => c.suit === card.suit && c.value === card.value
      );
      if (cardIndex !== -1) {
        player.plot.revealed.splice(cardIndex, 1);
        this._addToExiled(gameState, `${card.suit}-${card.value}`);
        gameState.trickHistory[gameState.trickHistory.length - 1].requisitions.push(
          `партийец: ${player.name} отправить на Север ${card.toString()}`
        );
      }
    }
  }

  _performStandard(gameState, suit, bucket) {
    if (this._handleDrunkard(gameState, bucket)) {
      return;
    }

    const informant = this._hasInformant(bucket, gameState.trump);
    const partyOfficial = this._hasPartyOfficial(bucket, gameState.trump);

    // Determine vulnerability filter based on variant
    const is36Card = this.gameVariants.deckType === '36';
    const isOrdenNachalniku = this.gameVariants.ordenNachalniku && is36Card;
    
    const vulnerabilityFilter = (p) => {
      if (isOrdenNachalniku) {
        // For ordenNachalniku: only players who closed a job (have any stack) are vulnerable
        const hasStacks = p.plot.stacks && p.plot.stacks.length > 0;
        return informant || hasStacks;
      } else {
        // Standard: vulnerable if won a trick or informant present
        // (northernStyle uses mice variant, so not possible here)
        return p.hasWonTrickThisYear || informant;
      }
    };

    // Step 1: Reveal face-down cards for vulnerable players
    for (const p of gameState.players) {
      if (!vulnerabilityFilter(p)) {
        continue;
      }

      const matchingHidden = p.plot.hidden.filter(c => c.suit === suit);
      
      if (matchingHidden.length > 0) {
        // All variants: reveal only highest hidden card
        const highestHidden = matchingHidden.reduce((max, card) =>
          card.value > max.value ? card : max
        );
        const cardIndex = p.plot.hidden.findIndex(
          c => c.suit === highestHidden.suit && c.value === highestHidden.value
        );
        p.plot.hidden.splice(cardIndex, 1);
        p.plot.revealed.push(highestHidden);
      }
    }

    // Step 2: Exile cards - each vulnerable player exiles their own highest
    // (mice variant uses _performMiceVariant which exiles single highest overall)
    // Deck type (52 vs 36) only affects vulnerability determination via vulnerabilityFilter, not exile logic
    for (const p of gameState.players) {
      if (!vulnerabilityFilter(p)) {
        continue;
      }
      
      const faceUpMatching = p.plot.revealed.filter(c => c.suit === suit);
      if (faceUpMatching.length === 0) continue;
      
      faceUpMatching.sort((a, b) => b.value - a.value);
      const highestCard = faceUpMatching[0];
      this._exileCard(gameState, [p, highestCard]);
      
      // Party official exiles second highest from this player
      if (partyOfficial && faceUpMatching.length > 1) {
        const secondCard = faceUpMatching[1];
        this._exileCard(gameState, [p, secondCard]);
        const requisitions = gameState.trickHistory[gameState.trickHistory.length - 1].requisitions;
        if (requisitions.length > 0) {
          requisitions[requisitions.length - 1] = `партийец: ${requisitions[requisitions.length - 1]}`;
        }
      }
    }
  }

  _handleDrunkard(gameState, bucket) {
    if (!this.gameVariants.nomenclature) return false;

    for (const c of bucket) {
      if (c.value === 11 && c.suit === gameState.trump) {
        gameState.trickHistory[gameState.trickHistory.length - 1].requisitions.push(
          "Пьяница отправить на Север"
        );
        this._addToExiled(gameState, `${c.suit}-${c.value}`);
        return true;
      }
    }
    return false;
  }

  _hasInformant(bucket, trump) {
    if (!this.gameVariants.nomenclature) return false;
    return bucket.some(c => c.value === 12 && c.suit === trump);
  }

  _hasPartyOfficial(bucket, trump) {
    if (!this.gameVariants.nomenclature) return false;
    return bucket.some(c => c.value === 13 && c.suit === trump);
  }

  _revealMatchingCards(gameState, suit, informant, vulnerabilityFilter) {
    const allRevealedCards = [];

    for (const p of gameState.players) {
      if (vulnerabilityFilter && !vulnerabilityFilter(p)) {
        continue;
      }

      // Collect matching cards from hidden plot cards only
      // Hidden cards in stacks are just markers and aren't considered for requisition
      const matchingHidden = p.plot.hidden.filter(c => c.suit === suit);
      
      // For ordenNachalniku variant, check stacks for revealed cards only (not hidden)
      const matchingFromStacks = [];
      if (this.gameVariants.ordenNachalniku && this.gameVariants.deckType === '36' && p.plot.stacks) {
        for (const stack of p.plot.stacks) {
          // Only check revealed cards in stack (hidden cards are just markers)
          for (const card of stack.revealed || []) {
            if (card.suit === suit) {
              matchingFromStacks.push({ card, stack });
            }
          }
        }
      }

      // Combine all matching cards (only from plot.hidden and stack.revealed, not stack.hidden)
      const allMatching = [...matchingHidden, ...matchingFromStacks.map(m => m.card)];
      if (allMatching.length === 0) continue;

      if (informant) {
        // Reveal all matching cards from hidden plot
        for (const card of matchingHidden) {
          const cardIndex = p.plot.hidden.findIndex(
            c => c.suit === card.suit && c.value === card.value
          );
          p.plot.hidden.splice(cardIndex, 1);
          p.plot.revealed.push(card);
          allRevealedCards.push([p, card]);
        }
        // Move all matching revealed cards from stacks to plot.revealed
        for (const { card, stack } of matchingFromStacks) {
          const cardIndex = stack.revealed.findIndex(
            c => c.suit === card.suit && c.value === card.value
          );
          if (cardIndex !== -1) {
            stack.revealed.splice(cardIndex, 1);
            p.plot.revealed.push(card);
            allRevealedCards.push([p, card]);
          }
        }
      } else {
        // Reveal only highest card overall (from hidden plot or revealed in stacks)
        const highestCard = allMatching.reduce((max, card) =>
          card.value > max.value ? card : max
        );
        
        // Check if highest is from hidden plot or from stacks
        const isFromHidden = matchingHidden.some(c => 
          c.suit === highestCard.suit && c.value === highestCard.value
        );
        
        if (isFromHidden) {
          const cardIndex = p.plot.hidden.findIndex(
            c => c.suit === highestCard.suit && c.value === highestCard.value
          );
          p.plot.hidden.splice(cardIndex, 1);
          p.plot.revealed.push(highestCard);
          allRevealedCards.push([p, highestCard]);
        } else {
          // Find which stack contains this card (must be revealed)
          const stackEntry = matchingFromStacks.find(m => 
            m.card.suit === highestCard.suit && m.card.value === highestCard.value
          );
          if (stackEntry) {
            const { stack } = stackEntry;
            const cardIndex = stack.revealed.findIndex(
              c => c.suit === highestCard.suit && c.value === highestCard.value
            );
            if (cardIndex !== -1) {
              stack.revealed.splice(cardIndex, 1);
              p.plot.revealed.push(highestCard);
              allRevealedCards.push([p, highestCard]);
            }
          }
        }
      }
      
      // Clean up empty stacks after removing cards
      if (p.plot.stacks) {
        p.plot.stacks = p.plot.stacks.filter(stack => 
          (stack.revealed && stack.revealed.length > 0) || 
          (stack.hidden && stack.hidden.length > 0)
        );
      }
    }

    return allRevealedCards;
  }

  _exileCard(gameState, [player, card]) {
    // First try to find in plot.revealed
    let cardIndex = player.plot.revealed.findIndex(
      c => c.suit === card.suit && c.value === card.value
    );
    
    let removedFromStack = false;
    if (cardIndex !== -1) {
      player.plot.revealed.splice(cardIndex, 1);
    } else {
      // Card might be in a stack (shouldn't happen after reveal, but check anyway)
      if (player.plot.stacks) {
        for (const stack of player.plot.stacks) {
          cardIndex = stack.revealed.findIndex(
            c => c.suit === card.suit && c.value === card.value
          );
          if (cardIndex !== -1) {
            stack.revealed.splice(cardIndex, 1);
            removedFromStack = true;
            break;
          }
          cardIndex = stack.hidden.findIndex(
            c => c.suit === card.suit && c.value === card.value
          );
          if (cardIndex !== -1) {
            stack.hidden.splice(cardIndex, 1);
            removedFromStack = true;
            break;
          }
        }
      }
    }
    
    // Clean up empty stacks if we removed from a stack
    if (removedFromStack && player.plot.stacks) {
      player.plot.stacks = player.plot.stacks.filter(stack => 
        (stack.revealed && stack.revealed.length > 0) || 
        (stack.hidden && stack.hidden.length > 0)
      );
    }
    
    this._addToExiled(gameState, `${card.suit}-${card.value}`);
    gameState.trickHistory[gameState.trickHistory.length - 1].requisitions.push(
      `${player.name} отправить на Север ${card.toString()}`
    );
  }

  _addToExiled(gameState, cardKey) {
    if (!gameState.exiled[gameState.year]) {
      gameState.exiled[gameState.year] = [];
    }
    gameState.exiled[gameState.year].push(cardKey);
  }

  _hasVulnerablePlayers(gameState) {
    // Check if any players are vulnerable to requisition
    // This depends on the variant being used
    
    if (this.gameVariants.deckType === '36' && this.gameVariants.ordenNachalniku) {
      // For ordenNachalniku variant: players with stacks are vulnerable
      // Also check if any job has an informant (makes everyone vulnerable for that job)
      for (const [suit, bucket] of Object.entries(gameState.jobBuckets)) {
        if (gameState.workHours[suit] >= THRESHOLD) {
          continue; // Skip completed jobs
        }
        const informant = this._hasInformant(bucket, gameState.trump);
        if (informant) {
          return true; // Informant makes everyone vulnerable
        }
      }
      // Check if any player has stacks
      return gameState.players.some(p => 
        p.plot.stacks && p.plot.stacks.length > 0
      );
    } else {
      // Standard variant: check northernStyle, hasWonTrickThisYear, or informant
      if (this.gameVariants.northernStyle) {
        return true; // Everyone is vulnerable in northern style
      }
      
      // Check if any player won a trick this year
      if (gameState.players.some(p => p.hasWonTrickThisYear)) {
        return true;
      }
      
      // Check if any failed job has an informant
      for (const [suit, bucket] of Object.entries(gameState.jobBuckets)) {
        if (gameState.workHours[suit] >= THRESHOLD) {
          continue; // Skip completed jobs
        }
        if (this._hasInformant(bucket, gameState.trump)) {
          return true; // Informant makes everyone vulnerable
        }
      }
      
      return false;
    }
  }
}
