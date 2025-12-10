// Main entry point for game page - Phaser version

import { phaserConfig } from './phaser/config.js';
import { PreloadScene } from './phaser/scenes/PreloadScene.js';
import { GameScene } from './phaser/scenes/GameScene.js';
import { GameOverScene } from './phaser/scenes/GameOverScene.js';
import { GameState } from './core/GameState.js';
import { GameStorage } from './storage/GameStorage.js';

// Make GameStorage globally available for scenes
window.GameStorage = GameStorage;

window.addEventListener('DOMContentLoaded', () => {
  try {
    // Check if there's a saved game
    let game = GameStorage.load();

    if (!game) {
      // No saved game, redirect to lobby
      window.location.href = 'index.html';
      return;
    }

    console.log('[main.js] Game loaded, phase:', game.phase);

    // Configure Phaser scenes
    phaserConfig.scene = [PreloadScene, GameScene, GameOverScene];

    // Store game state globally for PreloadScene to access
    window.__phaserGameState = game;

    // Initialize Phaser game
    const gameInstance = new Phaser.Game(phaserConfig);

    // Handle window resize
    window.addEventListener('resize', () => {
      // Update game size to match window
      gameInstance.scale.resize(window.innerWidth, window.innerHeight);
      gameInstance.scale.refresh();
    });

  } catch (error) {
    console.error('[main.js] Fatal error:', error);
    console.error('[main.js] Stack:', error.stack);
    document.body.innerHTML = `
      <div style="color: white; padding: 20px; font-family: sans-serif; background: #000;">
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
