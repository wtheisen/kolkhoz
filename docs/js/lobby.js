// Lobby entry point - handles game creation

import { GameState } from './core/GameState.js';
import { GameStorage } from './storage/GameStorage.js';

window.addEventListener('DOMContentLoaded', () => {
  // Check if localStorage is supported
  if (!GameStorage.isSupported()) {
    alert('Your browser does not support game saving. Progress will not be saved.');
  }

  // Show continue button if saved game exists
  const continueBtn = document.getElementById('continue-game');
  if (GameStorage.exists()) {
    continueBtn.style.display = 'inline-block';
  }

  // Start new game
  document.getElementById('start-game').addEventListener('click', () => {
    const game = new GameState();
    game.setTrump();
    GameStorage.save(game);
    window.location.href = 'game.html';
  });

  // Continue existing game
  continueBtn.addEventListener('click', () => {
    window.location.href = 'game.html';
  });
});
