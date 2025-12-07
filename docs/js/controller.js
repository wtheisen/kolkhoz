// GameController - orchestrates game flow
// Ported from kolkhoz.py:36-133

import { RandomAI } from './ai/RandomAI.js';
import { CardAnimator } from './ui/CardAnimator.js';
import { NotificationManager } from './ui/NotificationManager.js';

export class GameController {
  constructor(gameState, renderer, storage) {
    this.game = gameState;
    this.renderer = renderer;
    this.storage = storage;

    // Bind event handlers
    this.renderer.onCardPlayed = (idx) => this.handleCardPlay(idx);
    this.renderer.onAssignmentSubmitted = (mapping) => this.handleAssignment(mapping);
    this.renderer.onNewGame = () => this.handleNewGame();
  }

  start() {
    this.render();

    // If AI turn, play immediately
    if (this.shouldPlayAI()) {
      setTimeout(() => this.playAISequence(), 500);
    }
  }

  render() {
    this.renderer.renderGame(this.game);
  }

  handleCardPlay(cardIndex) {
    // Validate follow-suit
    if (!this.isValidPlay(cardIndex)) {
      NotificationManager.show('Please follow suit', 'error');
      return;
    }

    // Play card
    this.game.playCard(0, cardIndex);
    this.storage.save(this.game);
    this.render();

    // Check if we need AI assignment (after trick resolution)
    if (this.game.phase === 'assignment' && !this.game.players[this.game.lastWinner].isHuman) {
      // AI auto-assigns
      const ai = new RandomAI(this.game.lastWinner);
      const mapping = ai.assignTrick(this.game);
      this.game.applyAssignments(mapping);

      // Check if year is over (requisition phase)
      if (this.game.phase === 'requisition') {
        console.log('[Controller] Year complete (AI), transitioning to next year');
        this.game.nextYear();

        // After nextYear(), phase becomes 'planning'
        if (this.game.phase === 'planning') {
          this.game.setTrump();
          this.game.phase = 'trick';
        }
      }

      this.storage.save(this.game);
      this.render();
    }

    // Continue with AI
    if (this.shouldPlayAI()) {
      setTimeout(() => this.playAISequence(), 500);
    }
  }

  async playAISequence() {
    while (this.shouldPlayAI()) {
      const playerId = this.getNextPlayer();
      const ai = new RandomAI(playerId);
      const cardIdx = ai.play(this.game);
      const card = this.game.players[playerId].hand[cardIdx];

      // Animate AI card
      await CardAnimator.animateAICard(playerId, card.toJSON());

      // Play card
      this.game.playCard(playerId, cardIdx);

      // Update trick area
      CardAnimator.updateTrickArea(
        this.game.currentTrick,
        this.game.players
      );

      await this.delay(300);
    }

    // Check if we need AI assignment
    if (this.game.phase === 'assignment' && !this.game.players[this.game.lastWinner].isHuman) {
      // AI auto-assigns
      const ai = new RandomAI(this.game.lastWinner);
      const mapping = ai.assignTrick(this.game);
      this.game.applyAssignments(mapping);

      // Check if year is over (requisition phase)
      if (this.game.phase === 'requisition') {
        console.log('[Controller] Year complete (AI), transitioning to next year');
        this.game.nextYear();

        // After nextYear(), phase becomes 'planning'
        if (this.game.phase === 'planning') {
          this.game.setTrump();
          this.game.phase = 'trick';
        }
      }
    }

    this.storage.save(this.game);
    this.render();

    // Continue if still AI turn
    if (this.shouldPlayAI()) {
      setTimeout(() => this.playAISequence(), 500);
    }
  }

  handleAssignment(mapping) {
    this.game.applyAssignments(mapping);

    // Check if year is over (requisition phase)
    if (this.game.phase === 'requisition') {
      console.log('[Controller] Year complete, transitioning to next year');
      this.game.nextYear();

      // After nextYear(), phase becomes 'planning'
      if (this.game.phase === 'planning') {
        this.game.setTrump();
        this.game.phase = 'trick';
      }
    }

    this.storage.save(this.game);
    this.render();

    // Continue with AI if needed
    if (this.shouldPlayAI()) {
      setTimeout(() => this.playAISequence(), 500);
    }
  }

  handleNewGame() {
    this.storage.clear();
    window.location.href = 'index.html';
  }

  isValidPlay(cardIndex) {
    // Check follow-suit rule
    if (this.game.currentTrick.length === 0) return true;
    if (this.game.lead === 0) return true;

    const leadSuit = this.game.currentTrick[0][1].suit;
    const playedCard = this.game.players[0].hand[cardIndex];
    const canFollow = this.game.players[0].hand.some(c => c.suit === leadSuit);

    return !canFollow || playedCard.suit === leadSuit;
  }

  shouldPlayAI() {
    if (this.game.phase !== 'trick') return false;
    if (this.game.currentTrick.length >= this.game.numPlayers) return false;

    const nextPlayer = this.getNextPlayer();
    return nextPlayer !== 0;
  }

  getNextPlayer() {
    return (this.game.lead + this.game.currentTrick.length) % this.game.numPlayers;
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
