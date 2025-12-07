// Main entry point for game page

import { GameState } from './core/GameState.js';
import { GameStorage } from './storage/GameStorage.js';
import { GameController } from './controller.js';
import { GameRenderer } from './ui/GameRenderer.js';

window.addEventListener('DOMContentLoaded', () => {
  let game = GameStorage.load();

  if (!game) {
    // No saved game, redirect to lobby
    window.location.href = 'index.html';
    return;
  }

  console.log('[main.js] Game loaded, phase:', game.phase, 'Player 0 hand size:', game.players[0].hand.length);

  // Handle phase transitions (from Flask logic in kolkhoz.py:42-52)
  if (game.phase === 'planning') {
    console.log('[main.js] Phase is planning, setting trump');
    game.setTrump();
    game.phase = 'trick';
    GameStorage.save(game);
  }

  if (game.phase === 'requisition') {
    console.log('[main.js] Phase is requisition, calling nextYear()');
    game.nextYear();
    console.log('[main.js] After nextYear(), phase:', game.phase, 'Player 0 hand size:', game.players[0].hand.length);
    GameStorage.save(game);
  }

  console.log('[main.js] Before render, Player 0 hand size:', game.players[0].hand.length);
  const renderer = new GameRenderer(document.getElementById('app'));
  const controller = new GameController(game, renderer, GameStorage);
  controller.start();
});
