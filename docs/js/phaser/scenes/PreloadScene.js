// PreloadScene - handles loading all game assets

import { TextureLoader } from '../utils/TextureLoader.js';

export class PreloadScene extends Phaser.Scene {
  constructor() {
    super({ key: 'PreloadScene' });
  }

  preload() {
    // Show loading text
    const width = this.cameras.main.width;
    const height = this.cameras.main.height;
    
    const loadingText = this.add.text(width / 2, height / 2 - 50, 'Loading...', {
      fontSize: '32px',
      fill: '#c9a961'
    });
    loadingText.setOrigin(0.5, 0.5);

    const progressBar = this.add.graphics();
    const progressBox = this.add.graphics();
    progressBox.fillStyle(0x222222, 0.8);
    progressBox.fillRect(width / 2 - 160, height / 2, 320, 50);

    this.load.on('progress', (value) => {
      progressBar.clear();
      progressBar.fillStyle(0xc9a961, 1);
      progressBar.fillRect(width / 2 - 150, height / 2 + 10, 300 * value, 30);
    });

    this.load.on('complete', () => {
      progressBar.destroy();
      progressBox.destroy();
      loadingText.destroy();
    });

    // Load all card textures
    TextureLoader.loadCardTextures(this);
  }

  create() {
    // Get game state from global
    const gameState = window.__phaserGameState;
    
    // Start GameScene with game state
    this.scene.start('GameScene', { gameState: gameState });
  }
}
