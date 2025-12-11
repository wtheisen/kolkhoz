// TooltipManager - handles translation tooltips for Russian text in Phaser

import { getTranslation } from '../../translations.js';

export class TooltipManager {
  constructor(scene) {
    this.scene = scene;
    this.activeTooltip = null;
  }

  /**
   * Add a tooltip to a Phaser text object containing Russian text
   * @param {Phaser.GameObjects.Text} textObject - The text object to add tooltip to
   * @param {string} translation - The English translation
   */
  addTooltip(textObject, translation) {
    if (!textObject || !translation) return;

    // Make text interactive
    textObject.setInteractive({ useHandCursor: false });
    
    // Create tooltip container (initially hidden)
    const tooltipContainer = this.scene.add.container(0, 0);
    tooltipContainer.setVisible(false);
    tooltipContainer.setDepth(10000); // High depth to appear above everything
    
    // Create tooltip background
    const padding = 8;
    const fontSize = Math.max(10, Math.min(14, this.scene.cameras.main.height * 0.015));
    const tooltipText = this.scene.add.text(0, 0, translation, {
      fontSize: `${fontSize}px`,
      fill: '#ffffff',
      backgroundColor: '#1a1a1a',
      padding: { x: padding, y: padding }
    });
    tooltipText.setOrigin(0.5, 0.5);
    
    // Add border
    const bgWidth = tooltipText.width + padding * 2;
    const bgHeight = tooltipText.height + padding * 2;
    const bg = this.scene.add.rectangle(0, 0, bgWidth, bgHeight, 0x1a1a1a);
    bg.setStrokeStyle(2, 0xc9a961);
    bg.setOrigin(0.5, 0.5);
    
    tooltipContainer.add([bg, tooltipText]);
    
    // Position tooltip above the text
    const updateTooltipPosition = () => {
      // Get world position of text object (accounts for container transforms)
      const worldMatrix = textObject.getWorldTransformMatrix();
      const worldX = worldMatrix.tx;
      const worldY = worldMatrix.ty;
      
      // Position tooltip above the text
      const tooltipY = worldY - bgHeight / 2 - 10;
      const tooltipX = worldX;
      tooltipContainer.setPosition(tooltipX, tooltipY);
    };
    
    // Show tooltip on hover
    textObject.on('pointerover', () => {
      updateTooltipPosition();
      tooltipContainer.setVisible(true);
      this.activeTooltip = tooltipContainer;
      
      // Fade in
      tooltipContainer.setAlpha(0);
      this.scene.tweens.add({
        targets: tooltipContainer,
        alpha: 1,
        duration: 200,
        ease: 'Power2'
      });
    });
    
    // Hide tooltip on pointer out
    textObject.on('pointerout', () => {
      this.scene.tweens.add({
        targets: tooltipContainer,
        alpha: 0,
        duration: 150,
        ease: 'Power2',
        onComplete: () => {
          tooltipContainer.setVisible(false);
          if (this.activeTooltip === tooltipContainer) {
            this.activeTooltip = null;
          }
        }
      });
    });
    
    // Store reference for cleanup
    textObject.tooltipContainer = tooltipContainer;
  }

  /**
   * Add tooltip to text that contains Russian phrases
   * Automatically detects and translates known Russian phrases
   * @param {Phaser.GameObjects.Text} textObject - The text object
   * @param {string} originalText - The original text content
   */
  addAutoTooltip(textObject, originalText) {
    // Check if text contains any Russian phrases we know
    const translation = getTranslation(originalText);
    if (translation !== originalText) {
      this.addTooltip(textObject, translation);
    }
  }

  /**
   * Clean up tooltips
   */
  destroy() {
    if (this.activeTooltip) {
      this.activeTooltip.destroy();
      this.activeTooltip = null;
    }
  }
}
