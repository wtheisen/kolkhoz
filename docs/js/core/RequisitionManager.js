// RequisitionManager - handles all requisition logic and variants

import { THRESHOLD } from './constants.js';

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

    for (const [suit, bucket] of Object.entries(gameState.jobBuckets)) {
      if (gameState.workHours[suit] >= THRESHOLD) {
        continue;
      }

      if (this.gameVariants.miceVariant) {
        this._performMiceVariant(gameState, suit, bucket);
      } else if (this.gameVariants.deckType === '36') {
        this._perform36Card(gameState, suit, bucket);
      } else {
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
          `Партийный чиновник: ${player.name} отправить на Север ${card.toString()}`
        );
      }
    }
  }

  _perform36Card(gameState, suit, bucket) {
    if (this._handleDrunkard(gameState, bucket)) {
      return;
    }

    const informant = this._hasInformant(bucket, gameState.trump);
    const partyOfficial = this._hasPartyOfficial(bucket, gameState.trump);

    // For ordenNachalniku: only players with stacks are vulnerable
    const vulnerabilityFilter = (p) => {
      if (!this.gameVariants.ordenNachalniku) return true;
      const hasStacks = p.plot.stacks && p.plot.stacks.length > 0;
      return informant || hasStacks;
    };

    const allRevealedCards = this._revealMatchingCards(
      gameState, suit, informant, vulnerabilityFilter
    );
    
    // Also check plot.revealed for vulnerable players only (cards may have been moved there
    // from stacks at the start of the year, or from other sources like winning jobs)
    // This ensures cards already revealed are still considered for exile, but only for vulnerable players
    for (const p of gameState.players) {
      // Only process vulnerable players
      if (!vulnerabilityFilter(p)) {
        continue;
      }
      
      const revealedMatching = p.plot.revealed.filter(c => c.suit === suit);
      for (const card of revealedMatching) {
        // Only add if not already in allRevealedCards (avoid duplicates from _revealMatchingCards)
        const alreadyAdded = allRevealedCards.some(
          ([player, c]) => player === p && c.suit === card.suit && c.value === card.value
        );
        if (!alreadyAdded) {
          allRevealedCards.push([p, card]);
        }
      }
    }
    
    // Group revealed cards by player, then exile each player's highest card
    // (Each player must exile their own highest matching card, not just the overall highest)
    const cardsByPlayer = new Map();
    for (const [player, card] of allRevealedCards) {
      if (!cardsByPlayer.has(player)) {
        cardsByPlayer.set(player, []);
      }
      cardsByPlayer.get(player).push(card);
    }
    
    // For each player, find and exile their highest matching card
    for (const [player, cards] of cardsByPlayer.entries()) {
      if (cards.length === 0) continue;
      
      // Sort player's cards by value (highest first)
      cards.sort((a, b) => b.value - a.value);
      const highestCard = cards[0];
      
      // Exile the player's highest card
      this._exileCard(gameState, [player, highestCard]);
      
      // Party official exiles second highest card from this player
      if (partyOfficial && cards.length > 1) {
        const secondHighestCard = cards[1];
        // Use the same exile logic that handles both plot.revealed and stacks
        let cardIndex = player.plot.revealed.findIndex(
          c => c.suit === secondHighestCard.suit && c.value === secondHighestCard.value
        );
        
        if (cardIndex !== -1) {
          player.plot.revealed.splice(cardIndex, 1);
          this._addToExiled(gameState, `${secondHighestCard.suit}-${secondHighestCard.value}`);
          gameState.trickHistory[gameState.trickHistory.length - 1].requisitions.push(
            `Партийный чиновник: ${player.name} отправить на Север ${secondHighestCard.toString()}`
          );
        } else {
          // Card might be in a stack (shouldn't happen after reveal, but check anyway)
          let removedFromStack = false;
          if (player.plot.stacks) {
            for (const stack of player.plot.stacks) {
              cardIndex = stack.revealed.findIndex(
                c => c.suit === secondHighestCard.suit && c.value === secondHighestCard.value
              );
              if (cardIndex !== -1) {
                stack.revealed.splice(cardIndex, 1);
                removedFromStack = true;
                this._addToExiled(gameState, `${secondHighestCard.suit}-${secondHighestCard.value}`);
                gameState.trickHistory[gameState.trickHistory.length - 1].requisitions.push(
                  `Партийный чиновник: ${player.name} отправить на Север ${secondHighestCard.toString()}`
                );
                break;
              }
              cardIndex = stack.hidden.findIndex(
                c => c.suit === secondHighestCard.suit && c.value === secondHighestCard.value
              );
              if (cardIndex !== -1) {
                stack.hidden.splice(cardIndex, 1);
                removedFromStack = true;
                this._addToExiled(gameState, `${secondHighestCard.suit}-${secondHighestCard.value}`);
                gameState.trickHistory[gameState.trickHistory.length - 1].requisitions.push(
                  `Партийный чиновник: ${player.name} отправить на Север ${secondHighestCard.toString()}`
                );
                break;
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
        }
      }
    }
  }

  _performStandard(gameState, suit, bucket) {
    if (this._handleDrunkard(gameState, bucket)) {
      return;
    }

    const informant = this._hasInformant(bucket, gameState.trump);
    const partyOfficial = this._hasPartyOfficial(bucket, gameState.trump);

    for (const p of gameState.players) {
      const isVulnerable = this.gameVariants.northernStyle ||
                          p.hasWonTrickThisYear ||
                          informant;

      // Only process requisitions for vulnerable players
      if (!isVulnerable) {
        continue;
      }

      // Reveal matching cards from hidden plot if player is vulnerable
      const toReveal = p.plot.hidden.filter(c => c.suit === suit);
      p.plot.revealed.push(...toReveal);
      p.plot.hidden = p.plot.hidden.filter(c => c.suit !== suit);

      // Check for matching cards in revealed plot
      // Cards may already be in revealed from previous actions (winning jobs, etc.)
      const suitCards = p.plot.revealed
        .filter(c => c.suit === suit)
        .sort((a, b) => b.value - a.value);

      if (suitCards.length === 0) continue;

      // Exile highest
      const card = suitCards[0];
      const cardIndex = p.plot.revealed.findIndex(
        c => c.suit === card.suit && c.value === card.value
      );
      p.plot.revealed.splice(cardIndex, 1);
      this._addToExiled(gameState, `${card.suit}-${card.value}`);
      gameState.trickHistory[gameState.trickHistory.length - 1].requisitions.push(
        `${p.name} отправить на Север ${card.toString()}`
      );

      // Party official exiles second card
      if (partyOfficial && suitCards.length > 1) {
        const card2 = suitCards[1];
        const card2Index = p.plot.revealed.findIndex(
          c => c.suit === card2.suit && c.value === card2.value
        );
        p.plot.revealed.splice(card2Index, 1);
        this._addToExiled(gameState, `${card2.suit}-${card2.value}`);
        gameState.trickHistory[gameState.trickHistory.length - 1].requisitions.push(
          `Партийный чиновник: ${p.name} отправить на Север ${card2.toString()}`
        );
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

      // Collect matching cards from hidden plot cards
      const matchingHidden = p.plot.hidden.filter(c => c.suit === suit);
      
      // For ordenNachalniku variant, also check stacks for matching cards
      const matchingFromStacks = [];
      if (this.gameVariants.ordenNachalniku && this.gameVariants.deckType === '36' && p.plot.stacks) {
        for (const stack of p.plot.stacks) {
          // Check revealed cards in stack
          for (const card of stack.revealed || []) {
            if (card.suit === suit) {
              matchingFromStacks.push({ card, stack, location: 'revealed' });
            }
          }
          // Check hidden cards in stack
          for (const card of stack.hidden || []) {
            if (card.suit === suit) {
              matchingFromStacks.push({ card, stack, location: 'hidden' });
            }
          }
        }
      }

      // Combine all matching cards
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
        // Reveal all matching cards from stacks (move to plot.revealed)
        for (const { card, stack, location } of matchingFromStacks) {
          if (location === 'hidden') {
            const cardIndex = stack.hidden.findIndex(
              c => c.suit === card.suit && c.value === card.value
            );
            if (cardIndex !== -1) {
              stack.hidden.splice(cardIndex, 1);
              p.plot.revealed.push(card);
              allRevealedCards.push([p, card]);
            }
          } else {
            // Already revealed in stack, just move to plot.revealed
            const cardIndex = stack.revealed.findIndex(
              c => c.suit === card.suit && c.value === card.value
            );
            if (cardIndex !== -1) {
              stack.revealed.splice(cardIndex, 1);
              p.plot.revealed.push(card);
              allRevealedCards.push([p, card]);
            }
          }
        }
      } else {
        // Reveal only highest card overall (from both hidden plot and stacks)
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
          // Find which stack contains this card
          const stackEntry = matchingFromStacks.find(m => 
            m.card.suit === highestCard.suit && m.card.value === highestCard.value
          );
          if (stackEntry) {
            const { stack, location } = stackEntry;
            if (location === 'hidden') {
              const cardIndex = stack.hidden.findIndex(
                c => c.suit === highestCard.suit && c.value === highestCard.value
              );
              if (cardIndex !== -1) {
                stack.hidden.splice(cardIndex, 1);
                p.plot.revealed.push(highestCard);
                allRevealedCards.push([p, highestCard]);
              }
            } else {
              // Already revealed in stack, just move to plot.revealed
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
}
