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
    if (allRevealedCards.length === 0) return;

    allRevealedCards.sort((a, b) => b[1].value - a[1].value);
    this._exileCard(gameState, allRevealedCards[0]);

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

      if (isVulnerable) {
        const toReveal = p.plot.hidden.filter(c => c.suit === suit);
        p.plot.revealed.push(...toReveal);
        p.plot.hidden = p.plot.hidden.filter(c => c.suit !== suit);
      }

      if (!isVulnerable) continue;

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

      const matchingHidden = p.plot.hidden.filter(c => c.suit === suit);
      if (matchingHidden.length === 0) continue;

      if (informant) {
        // Reveal all matching cards
        for (const card of matchingHidden) {
          const cardIndex = p.plot.hidden.findIndex(
            c => c.suit === card.suit && c.value === card.value
          );
          p.plot.hidden.splice(cardIndex, 1);
          p.plot.revealed.push(card);
          allRevealedCards.push([p, card]);
        }
      } else {
        // Reveal only highest
        const highestCard = matchingHidden.reduce((max, card) =>
          card.value > max.value ? card : max
        );
        const cardIndex = p.plot.hidden.findIndex(
          c => c.suit === highestCard.suit && c.value === highestCard.value
        );
        p.plot.hidden.splice(cardIndex, 1);
        p.plot.revealed.push(highestCard);
        allRevealedCards.push([p, highestCard]);
      }
    }

    return allRevealedCards;
  }

  _exileCard(gameState, [player, card]) {
    const cardIndex = player.plot.revealed.findIndex(
      c => c.suit === card.suit && c.value === card.value
    );
    player.plot.revealed.splice(cardIndex, 1);
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
