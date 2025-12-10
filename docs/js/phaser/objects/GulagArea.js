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
      
      // Card sizes for exiled cards - use LayoutManager's card size calculation
      cardSize: this.layoutManager ? this.layoutManager.getCardSize() : {
        width: Math.max(25, Math.min(35, baseSize * 0.03)),
        height: Math.max(35, Math.min(49, baseSize * 0.04))
      },
      
      // Spacing - responsive based on screen width, reduced to prevent clipping
      columnSpacing: Math.max(35, Math.min(65, gameWidth * 0.04)),
      
      // Vertical spacing - responsive based on screen height
      deckOffsetY: -gameHeight * 0.12, // Deck position above gulag
      titleOffsetY: -gameHeight * 0.025, // Title position
      yearLabelY: gameHeight * 0.025, // Year labels position
      cardStackStartY: gameHeight * 0.055, // Card stack start position
      
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
      const yearLabel = this.scene.add.text(columnX, sizes.yearLabelY, `Year ${year}`, {
        fontSize: sizes.yearLabelFontSize,
        fill: '#ffffff'
      });
      yearLabel.setOrigin(0.5, 0); // Centered horizontally on the column
      this.add(yearLabel);
      this.yearLabels.push(yearLabel);

      // Get cards for this year
      const yearCards = (this.gameState.exiled && this.gameState.exiled[year]) 
        ? this.gameState.exiled[year] 
        : [];

      // Stack cards vertically in this column
      yearCards.forEach((key, index) => {
        const [suit, value] = key.split('-');
        const card = { suit, value: parseInt(value) };
        
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
        cardSprite.setAlpha(0.7);
        cardSprite.setDepth(index + 1); // Later cards on top
        
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
