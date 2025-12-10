// RandomAI - ported from ai.py:4-24

import { AIPlayer } from './AIPlayer.js';

export class RandomAI extends AIPlayer {
  constructor(playerIdx) {
    super(playerIdx);
  }

  play(gameState) {
    const hand = gameState.players[this.playerIdx].hand;

    // Follow suit if required
    if (gameState.currentTrick.length > 0) {
      const leadSuit = gameState.currentTrick[0][1].suit;
      const candidates = hand
        .map((card, idx) => ({ card, idx }))
        .filter(({ card }) => card.suit === leadSuit)
        .map(({ idx }) => idx);

      if (candidates.length > 0) {
        return candidates[Math.floor(Math.random() * candidates.length)];
      }
    }

    // Play any card
    return Math.floor(Math.random() * hand.length);
  }

  assignTrick(gameState) {
    const mapping = new Map();
    const validJobs = Array.from(new Set(
      gameState.lastTrick.map(([_, card]) => card.suit)
    ));

    for (const [playerId, card] of gameState.lastTrick) {
      const assignedSuit = validJobs[Math.floor(Math.random() * validJobs.length)];
      mapping.set(card, assignedSuit);
    }

    return mapping;
  }

  swap(gameState) {
    const player = gameState.players[this.playerIdx];
    
    // Only swap if player has both hidden cards and hand cards
    if (player.plot.hidden.length === 0 || player.hand.length === 0) {
      return null;  // Skip swap
    }

    // Randomly choose one hidden card and one hand card to swap
    const hiddenIndex = Math.floor(Math.random() * player.plot.hidden.length);
    const handIndex = Math.floor(Math.random() * player.hand.length);

    return { hiddenIndex, handIndex };
  }

  selectPlotCard(gameState) {
    const player = gameState.players[this.playerIdx];
    if (player.hand.length === 0) {
      return null; // No cards to select
    }
    // Randomly choose one card from hand
    return Math.floor(Math.random() * player.hand.length);
  }
}
