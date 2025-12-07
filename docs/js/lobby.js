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

  // Get modal elements
  const modal = document.getElementById('variant-modal');
  const startGameBtn = document.getElementById('start-game');
  const modalClose = document.getElementById('modal-close');
  const modalCancel = document.getElementById('modal-cancel');
  const variantForm = document.getElementById('variant-form');

  // Show modal when Start Game is clicked
  startGameBtn.addEventListener('click', () => {
    modal.style.display = 'flex';
  });

  // Close modal handlers
  const closeModal = () => {
    modal.style.display = 'none';
  };

  modalClose.addEventListener('click', closeModal);
  modalCancel.addEventListener('click', closeModal);

  // Close modal when clicking backdrop
  modal.querySelector('.modal-backdrop').addEventListener('click', closeModal);

  // Handle form submission
  variantForm.addEventListener('submit', (e) => {
    e.preventDefault();

    // Read variant selections
    const specialEffects = document.getElementById('special-effects').checked;

    // Create game with selected variants
    const game = new GameState(4, {
      specialEffects: specialEffects
    });
    game.setTrump();
    GameStorage.save(game);
    
    // Close modal and navigate to game
    closeModal();
    window.location.href = 'game.html';
  });

  // Continue existing game
  continueBtn.addEventListener('click', () => {
    window.location.href = 'game.html';
  });
});
