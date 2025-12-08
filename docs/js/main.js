// Main entry point for game page

import { GameState } from './core/GameState.js';
import { GameStorage } from './storage/GameStorage.js';
import { GameController } from './controller.js';
import { GameRenderer } from './ui/GameRenderer.js';

window.addEventListener('DOMContentLoaded', () => {
  try {
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

    if (game.phase === 'swap') {
      console.log('[main.js] Phase is swap, waiting for player swaps');
      // Swap phase will be handled by the controller
    }

    console.log('[main.js] Before render, Player 0 hand size:', game.players[0].hand.length);
    const appElement = document.getElementById('app');
    if (!appElement) {
      console.error('[main.js] App element not found!');
      return;
    }
    const renderer = new GameRenderer(appElement);
    const controller = new GameController(game, renderer, GameStorage);
    controller.start();
  } catch (error) {
    console.error('[main.js] Fatal error:', error);
    console.error('[main.js] Stack:', error.stack);
    document.body.innerHTML = `
      <div style="color: white; padding: 20px; font-family: sans-serif;">
        <h1>Error Loading Game</h1>
        <p>An error occurred while loading the game. Please check the browser console for details.</p>
        <p>Error: ${error.message}</p>
        <button onclick="window.location.href='index.html'" style="padding: 10px 20px; margin-top: 10px; cursor: pointer;">
          Return to Lobby
        </button>
      </div>
    `;
  }
});
