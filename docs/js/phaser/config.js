// Phaser game configuration

export const phaserConfig = {
  type: Phaser.AUTO,
  width: window.innerWidth,
  height: window.innerHeight,
  parent: 'app',
  backgroundColor: '#000000',
  // Match the canvas resolution to the device pixel ratio to avoid blur on HiDPI screens
  resolution: Math.max(1, window.devicePixelRatio || 1),
  pixelArt: false, // Allow smooth scaling for non-pixel art
  scale: {
    mode: Phaser.Scale.RESIZE,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    autoRound: false, // Allow fractional positions to avoid jagged edges
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
    antialias: true, // Smooth edges on hi-DPI devices
    roundPixels: false, // Keep sub-pixel positioning for smoother rendering
    powerPreference: 'high-performance' // Use high-performance GPU rendering
  }
};
