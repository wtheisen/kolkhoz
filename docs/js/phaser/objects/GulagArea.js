// GulagArea - displays exiled cards

import { CardSprite } from './CardSprite.js';
import { MAX_YEARS } from '../../core/constants.js';

export class GulagArea extends Phaser.GameObjects.Container {
  constructor(scene, x, y, gameState, layoutManager) {
    super(scene, x, y);
    
    this.gameState = gameState;
    this.layoutManager = layoutManager;
    this.exiledCardSprites = [];
    this.deckCardSprite = null;
    this.deckCountText = null;
    this.yearLabels = [];
    
    scene.add.existing(this);
    
    this.createGulagDisplay();
  }

  getResponsiveSizes() {
    // Get screen dimensions
    const gameWidth = this.scene.cameras.main.width;
    const gameHeight = this.scene.cameras.main.height;
    const baseSize = Math.min(gameWidth, gameHeight);
    
    // Calculate responsive sizes as percentages of screen dimensions
    return {
      // Deck card size - responsive based on screen size
      deckCardWidth: Math.max(40, Math.min(60, baseSize * 0.05)),
      deckCardHeight: Math.max(56, Math.min(84, baseSize * 0.07)),
      
      // Deck count font size - responsive
      deckCountFontSize: `${Math.max(12, Math.min(18, baseSize * 0.015))}px`,
      
      // Title font size - responsive
      titleFontSize: `${Math.max(16, Math.min(24, baseSize * 0.02))}px`,
      
      // Year label font size - responsive
      yearLabelFontSize: `${Math.max(11, Math.min(16, baseSize * 0.015))}px`,
      
      // Card sizes for exiled cards - smaller than normal cards (similar to job piles)
      cardSize: (() => {
        const fullSize = this.layoutManager ? this.layoutManager.getCardSize() : {
          width: Math.max(40, Math.min(60, baseSize * 0.05)),
          height: Math.max(56, Math.min(84, baseSize * 0.07))
        };
        // Use 62.5% of full size (same as job piles)
        return {
          width: fullSize.width * 0.625,
          height: fullSize.height * 0.625
        };
      })(),
      
      // Spacing - responsive based on screen width, increased for better readability
      columnSpacing: Math.max(50, Math.min(90, gameWidth * 0.06)),
      
      // Vertical spacing - responsive based on screen height
      deckOffsetY: -gameHeight * 0.12, // Deck position above gulag
      titleOffsetY: -gameHeight * 0.025, // Title position
      yearLabelY: -gameHeight * 0.005, // Year labels position (moved up to prevent overlap)
      cardStackStartY: gameHeight * 0.08, // Card stack start position (moved down to prevent overlap)
      
      // Card overlap - percentage of card height
      cardOverlapPercent: 0.24 // 24% overlap (similar to job piles)
    };
  }

  createGulagDisplay() {
    const sizes = this.getResponsiveSizes();
    
    // Deck display (above gulag)
    const deckY = sizes.deckOffsetY;
    
    // Face-down card sprite for deck
    this.deckCardSprite = this.scene.add.sprite(0, deckY, 'card_back');
    this.deckCardSprite.setOrigin(0.5, 0.5);
    this.deckCardSprite.setDisplaySize(sizes.deckCardWidth, sizes.deckCardHeight);
    this.add(this.deckCardSprite);
    
    // Deck count text
    const deckCount = this.gameState.workersDeck ? this.gameState.workersDeck.length : 0;
    this.deckCountText = this.scene.add.text(0, deckY + sizes.deckCardHeight * 0.65, `${deckCount}`, {
      fontSize: sizes.deckCountFontSize,
      fill: '#ffffff',
      fontStyle: 'bold'
    });
    this.deckCountText.setOrigin(0.5, 0.5);
    this.add(this.deckCountText);
    
    // Create gulag content
    this.createGulagContent();
  }
  
  createGulagContent() {
    const sizes = this.getResponsiveSizes();
    const numYears = MAX_YEARS;
    
    // Calculate column positions - centered
    const totalWidth = (numYears - 1) * sizes.columnSpacing;
    const startX = -totalWidth / 2; // Center the columns around x=0
    
    // Card dimensions
    const cardWidth = sizes.cardSize.width;
    const cardHeight = sizes.cardSize.height;
    const cardOverlap = cardHeight * sizes.cardOverlapPercent;

    // Title - centered above the year columns
    const title = this.scene.add.text(0, sizes.titleOffsetY, 'ГУЛАГ:', {
      fontSize: sizes.titleFontSize,
      fill: '#c9a961',
      fontStyle: 'bold'
    });
    title.setOrigin(0.5, 0); // Centered horizontally
    this.add(title);

    // Create columns for all years (1-5)
    for (let year = 1; year <= numYears; year++) {
      const columnX = startX + (year - 1) * sizes.columnSpacing;
      
      // Year label (always visible, centered on its column)
      const yearLabel = this.scene.add.text(columnX, sizes.yearLabelY, `года ${year}`, {
        fontSize: sizes.yearLabelFontSize,
        fill: '#ffffff'
      });
      yearLabel.setOrigin(0.5, 0); // Centered horizontally on the column
      yearLabel.setDepth(0); // Behind cards
      this.add(yearLabel);
      this.yearLabels.push(yearLabel);

      // Get cards for this year
      const yearCards = (this.gameState.exiled && this.gameState.exiled[year]) 
        ? this.gameState.exiled[year] 
        : [];

      // Stack cards vertically in this column
      yearCards.forEach((key, index) => {
        // Parse card key (format: "suit-value")
        const parts = key.split('-');
        if (parts.length !== 2) {
          console.warn(`Invalid card key format in exiled: ${key}`);
          return;
        }
        
        const [suit, valueStr] = parts;
        const value = parseInt(valueStr, 10);
        
        if (isNaN(value)) {
          console.warn(`Invalid card value in exiled: ${key}`);
          return;
        }
        
        const card = { suit, value };
        
        // Calculate vertical stack position
        const offsetY = sizes.cardStackStartY + index * (cardHeight - cardOverlap);
        
        const cardSprite = new CardSprite(
          this.scene,
          columnX,
          offsetY,
          card,
          true
        );
        cardSprite.setDisplaySize(cardWidth, cardHeight);
        cardSprite.setAlpha(1.0); // Fully visible (not greyed out)
        cardSprite.setDepth(10 + index); // Cards above year labels (depth 0) and later cards on top
        
        this.exiledCardSprites.push(cardSprite);
        this.add(cardSprite);
      });
    }
  }

  updateGulagDisplay() {
    const sizes = this.getResponsiveSizes();
    
    // Update deck display sizes (responsive to screen size)
    if (this.deckCardSprite) {
      const deckY = sizes.deckOffsetY;
      this.deckCardSprite.setPosition(0, deckY);
      this.deckCardSprite.setDisplaySize(sizes.deckCardWidth, sizes.deckCardHeight);
    }
    
    // Update deck count text
    if (this.deckCountText) {
      const deckCount = this.gameState.workersDeck ? this.gameState.workersDeck.length : 0;
      const deckY = sizes.deckOffsetY;
      this.deckCountText.setPosition(0, deckY + sizes.deckCardHeight * 0.65);
      this.deckCountText.setStyle({ fontSize: sizes.deckCountFontSize });
      this.deckCountText.setText(`${deckCount}`);
    }
    
    // Clear existing cards and year labels
    this.exiledCardSprites.forEach(card => card.destroy());
    this.exiledCardSprites = [];
    this.yearLabels.forEach(label => label.destroy());
    this.yearLabels = [];
    
    // Remove all children except deck display
    const childrenToRemove = [];
    this.list.forEach(child => {
      if (child !== this.deckCardSprite && child !== this.deckCountText) {
        childrenToRemove.push(child);
      }
    });
    childrenToRemove.forEach(child => {
      this.remove(child, true);
    });
    
    // Recreate gulag content (but keep deck display)
    this.createGulagContent();
  }

  destroy() {
    this.exiledCardSprites.forEach(card => card.destroy());
    this.yearLabels.forEach(label => label.destroy());
    super.destroy();
  }
}
