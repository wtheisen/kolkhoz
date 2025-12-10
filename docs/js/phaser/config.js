// Phaser game configuration

export const phaserConfig = {
  type: Phaser.AUTO,
  width: window.innerWidth,
  height: window.innerHeight,
  parent: 'app',
  backgroundColor: '#000000',
  pixelArt: false, // Allow smooth scaling for non-pixel art
  scale: {
    mode: Phaser.Scale.RESIZE,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    autoRound: true, // Round pixels for crisp rendering
    min: {
      width: 800,
      height: 600
    },
    max: {
      width: 1920,
      height: 1080
    }
  },
  physics: {
    default: 'arcade',
    arcade: {
      gravity: { y: 0 },
      debug: false
    }
  },
  scene: [], // Scenes will be added dynamically
  dom: {
    createContainer: true
  },
  render: {
    antialias: false, // Disable antialiasing for crisp, sharp rendering
    roundPixels: true, // Round pixels for crisp rendering
    powerPreference: 'high-performance' // Use high-performance GPU rendering
  }
};
