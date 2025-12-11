// CardSprite - Phaser sprite for playing cards

import { TextureLoader } from '../utils/TextureLoader.js';

export class CardSprite extends Phaser.GameObjects.Sprite {
  constructor(scene, x, y, card, faceUp = true) {
    const textureKey = faceUp ? TextureLoader.getCardTextureKey(card) : 'card_back';
    super(scene, x, y, textureKey);
    
    this.card = card;
    this.faceUp = faceUp;
    this.originalX = x;
    this.originalY = y;
    this.originalRotation = 0;
    this.isDragging = false;
    this.isHighlighted = false;
    
    // Set interactive
    this.setInteractive({ useHandCursor: true });
    
    // Add to scene
    scene.add.existing(this);
    
    // Set origin to center for rotation
    this.setOrigin(0.5, 0.5);
    
    // Set initial size - responsive based on scene dimensions
    const gameWidth = scene.cameras?.main?.width || 1920;
    const gameHeight = scene.cameras?.main?.height || 1080;
    const baseSize = Math.min(gameWidth, gameHeight);
    const defaultWidth = Math.max(60, Math.min(100, baseSize * 0.08));
    const defaultHeight = Math.max(84, Math.min(140, baseSize * 0.11));
    this.setDisplaySize(defaultWidth, defaultHeight);
  }

  flip() {
    // Store current display size to preserve it after texture change
    const currentWidth = this.displayWidth;
    const currentHeight = this.displayHeight;
    
    this.faceUp = !this.faceUp;
    const textureKey = this.faceUp ? TextureLoader.getCardTextureKey(this.card) : 'card_back';
    this.setTexture(textureKey);
    
    // Restore display size after texture change
    this.setDisplaySize(currentWidth, currentHeight);
  }

  setFaceUp(faceUp) {
    if (this.faceUp !== faceUp) {
      this.flip();
    }
  }

  highlight(highlight = true) {
    if (highlight && !this.isHighlighted) {
      this.isHighlighted = true;
      this.setTint(0xffff00);
      this.setScale(1.1);
    } else if (!highlight && this.isHighlighted) {
      this.isHighlighted = false;
      this.clearTint();
      this.setScale(1.0);
    }
  }

  setValidHighlight(isValid = true) {
    // Clear any existing effects
    if (this.validGlow) {
      this.preFX.remove(this.validGlow);
      this.validGlow = null;
    }
    
    // Reset tint and alpha
    this.clearTint();
    this.setAlpha(1.0);
    
    if (isValid) {
      // Add glow effect for valid cards
      // Green glow with smaller distance for sharper appearance
      this.validGlow = this.preFX.addGlow(0x4caf50, 8);
    } else {
      // Darken invalid cards using tint and alpha
      this.setTint(0x555555); // Dark gray tint
      this.setAlpha(0.6); // 60% opacity
    }
  }

  enableDrag() {
    this.setInteractive({ draggable: true, useHandCursor: true });
    this.scene.input.setDraggable(this);
  }

  disableDrag() {
    this.disableInteractive();
  }

  resetPosition() {
    this.scene.tweens.add({
      targets: this,
      x: this.originalX,
      y: this.originalY,
      rotation: this.originalRotation,
      duration: 300,
      ease: 'Power2'
    });
  }

  moveTo(x, y, rotation = 0, duration = 300, onComplete = null) {
    this.originalX = x;
    this.originalY = y;
    this.originalRotation = rotation;
    
    return this.scene.tweens.add({
      targets: this,
      x: x,
      y: y,
      rotation: rotation,
      duration: duration,
      ease: 'Power2',
      onComplete: onComplete
    });
  }

  // Get bounds for drop zone detection (in world coordinates)
  getBounds() {
    // Get world position of this sprite
    // Use Phaser's getWorldTransformMatrix to get accurate world coordinates
    // This works for sprites in containers too
    const matrix = this.getWorldTransformMatrix();
    const worldX = matrix.tx;
    const worldY = matrix.ty;
    
    const halfWidth = this.displayWidth / 2;
    const halfHeight = this.displayHeight / 2;
    
    return {
      x: worldX - halfWidth,
      y: worldY - halfHeight,
      width: this.displayWidth,
      height: this.displayHeight
    };
  }

  destroy() {
    // Clean up effects if they exist
    if (this.validGlow) {
      this.preFX.remove(this.validGlow);
      this.validGlow = null;
    }
    this.disableInteractive();
    super.destroy();
  }
}
