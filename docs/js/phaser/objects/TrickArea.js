// TrickArea - central area for trick-taking

import { CardSprite } from './CardSprite.js';

export class TrickArea extends Phaser.GameObjects.Container {
  constructor(scene, x, y, gameState, layoutManager) {
    super(scene, x, y);
    
    this.gameState = gameState;
    this.layoutManager = layoutManager;
    this.trickCardSprites = [];
    this.leadSuitIndicator = null;
    this.trumpSuitIndicator = null;
    
    scene.add.existing(this);
    
    this.createTrickArea();
  }

  getResponsiveSizes() {
    const gameWidth = this.scene.cameras.main.width;
    const gameHeight = this.scene.cameras.main.height;
    const baseSize = Math.min(gameWidth, gameHeight);
    
    // Table circle radius
    const tableRadius = Math.max(120, Math.min(180, baseSize * 0.15));
    
    return {
      // Table circle radius
      tableRadius: tableRadius,
      
      // Card sizes
      trickCardWidth: Math.max(56, Math.min(84, baseSize * 0.07)),
      trickCardHeight: Math.max(78, Math.min(117, baseSize * 0.098)),
      
      // Card positioning
      cardRadius: Math.max(64, Math.min(96, baseSize * 0.08)),
      
      // Font sizes
      waitingFontSize: `${Math.max(12, Math.min(20, baseSize * 0.016))}px`,
      leadFontSize: `${Math.max(11, Math.min(18, baseSize * 0.014))}px`,
      trumpFontSize: `${Math.max(14, Math.min(22, baseSize * 0.018))}px`,
      playerNameFontSize: `${Math.max(9, Math.min(15, baseSize * 0.012))}px`,
      
      // Positions
      leadTextY: tableRadius + baseSize * 0.03, // Position below the circle
      trumpTextY: -(tableRadius + baseSize * 0.03), // Position above the circle
      playerNameOffsetY: baseSize * 0.06
    };
  }

  createTrickArea() {
    const sizes = this.getResponsiveSizes();
    // Background circle/table
    const tableBg = this.scene.add.circle(0, 0, sizes.tableRadius, 0x1a1a1a, 0.5);
    tableBg.setStrokeStyle(2, 0xc9a961);
    this.add(tableBg);
    
    // Show trump suit indicator or famine year indicator (always visible)
    if (this.gameState.isFamine) {
      // During famine year, show "Год неурожая" instead of trump
      const famineText = this.scene.add.text(0, sizes.trumpTextY, 'Год неурожая', {
        fontSize: sizes.trumpFontSize,
        fill: '#c9a961'
      });
      famineText.setOrigin(0.5, 0.5);
      this.add(famineText);
      // Add tooltip for Russian text
      if (this.scene.tooltipManager) {
        this.scene.tooltipManager.addAutoTooltip(famineText, 'Год неурожая');
      }
      this.trumpSuitIndicator = famineText;
    } else if (this.gameState.trump) {
      const trumpText = this.scene.add.text(0, sizes.trumpTextY, `Наша главная задача: ${this.gameState.trump}`, {
        fontSize: sizes.trumpFontSize,
        fill: '#c9a961'
      });
      trumpText.setOrigin(0.5, 0.5);
      this.add(trumpText);
      // Add tooltip for Russian text
      if (this.scene.tooltipManager) {
        this.scene.tooltipManager.addAutoTooltip(trumpText, 'Наша главная задача:');
      }
      this.trumpSuitIndicator = trumpText;
    }
  }

  // Update trump display (useful when trump changes)
  updateTrumpDisplay() {
    // Remove old trump indicator if it exists
    if (this.trumpSuitIndicator) {
      this.trumpSuitIndicator.destroy();
      this.trumpSuitIndicator = null;
    }
    
    // Add new trump indicator
    const sizes = this.getResponsiveSizes();
    if (this.gameState.isFamine) {
      // During famine year, show "Год неурожая" instead of trump
      const famineText = this.scene.add.text(0, sizes.trumpTextY, 'Год неурожая', {
        fontSize: sizes.trumpFontSize,
        fill: '#c9a961'
      });
      famineText.setOrigin(0.5, 0.5);
      this.add(famineText);
      // Add tooltip for Russian text
      if (this.scene.tooltipManager) {
        this.scene.tooltipManager.addAutoTooltip(famineText, 'Год неурожая');
      }
      this.trumpSuitIndicator = famineText;
    } else if (this.gameState.trump) {
      const trumpText = this.scene.add.text(0, sizes.trumpTextY, `Наша главная задача: ${this.gameState.trump}`, {
        fontSize: sizes.trumpFontSize,
        fill: '#c9a961'
      });
      trumpText.setOrigin(0.5, 0.5);
      this.add(trumpText);
      // Add tooltip for Russian text
      if (this.scene.tooltipManager) {
        this.scene.tooltipManager.addAutoTooltip(trumpText, 'Наша главная задача:');
      }
      this.trumpSuitIndicator = trumpText;
    }
  }

  // Display swap phase text
  displaySwapPhase() {
    const sizes = this.getResponsiveSizes();
    
    // Clear existing cards
    this.trickCardSprites.forEach(card => card.destroy());
    this.trickCardSprites = [];
    this.removeAll(true);
    // Reset references since objects were removed
    this.leadSuitIndicator = null;
    this.trumpSuitIndicator = null;
    this.createTrickArea();

    // Show swap instruction text
    const swapText = this.scene.add.text(0, 0, 'Поменять шило на мыло', {
      fontSize: sizes.trumpFontSize,
      fill: '#c9a961'
    });
    swapText.setOrigin(0.5, 0.5);
    this.add(swapText);
    // Add tooltip for Russian text
    if (this.scene.tooltipManager) {
      this.scene.tooltipManager.addAutoTooltip(swapText, 'Поменять шило на мыло');
    }
    this.swapPhaseText = swapText;
    
    // Store position for button placement
    this.swapTextY = 0;
  }

  // Display current trick
  displayTrick(trick, players, highlightWinner = false) {
    const sizes = this.getResponsiveSizes();
    
    // Clear existing cards
    this.trickCardSprites.forEach(card => card.destroy());
    this.trickCardSprites = [];
    this.removeAll(true);
    // Reset references since objects were removed
    this.leadSuitIndicator = null;
    this.trumpSuitIndicator = null;
    this.swapPhaseText = null;
    this.createTrickArea();

    if (!trick || trick.length === 0) {
      const waitingText = this.scene.add.text(0, 0, 'Waiting for first card...', {
        fontSize: sizes.waitingFontSize,
        fill: '#ffffff'
      });
      waitingText.setOrigin(0.5, 0.5);
      this.add(waitingText);
      return;
    }

    // Show lead suit indicator below the trick area
    if (trick.length > 0) {
      const leadSuit = trick[0][1].suit;
      const leadText = this.scene.add.text(0, sizes.leadTextY, `Lead: ${leadSuit}`, {
        fontSize: sizes.leadFontSize,
        fill: '#c9a961'
      });
      leadText.setOrigin(0.5, 0.5);
      this.add(leadText);
      this.leadSuitIndicator = leadText;
    }

    // Position cards around circle
    const angleStep = (2 * Math.PI) / trick.length;
    const radius = sizes.cardRadius;

    trick.forEach(([playerId, card], index) => {
      const angle = (index * angleStep) - Math.PI / 2;
      const x = radius * Math.cos(angle);
      const y = radius * Math.sin(angle);
      
      const cardSprite = new CardSprite(this.scene, x, y, card, true);
      cardSprite.setDisplaySize(sizes.trickCardWidth, sizes.trickCardHeight);
      cardSprite.originalX = x;
      cardSprite.originalY = y;
      
      this.trickCardSprites.push(cardSprite);
      this.add(cardSprite);

      // Player name label
      const playerName = players[playerId]?.name || `Player ${playerId}`;
      const nameText = this.scene.add.text(x, y + sizes.playerNameOffsetY, playerName, {
        fontSize: sizes.playerNameFontSize,
        fill: '#ffffff'
      });
      nameText.setOrigin(0.5, 0.5);
      this.add(nameText);
    });

    // Highlight winner if specified
    if (highlightWinner && this.gameState.lastWinner !== null) {
      const winnerIndex = trick.findIndex(([pid]) => pid === this.gameState.lastWinner);
      if (winnerIndex >= 0 && this.trickCardSprites[winnerIndex]) {
        this.trickCardSprites[winnerIndex].highlight(true);
      }
    }
  }

  // Get trick card sprites for assignment phase
  getTrickCardSprites() {
    return this.trickCardSprites;
  }

  // Get bounds for drop zone detection (world coordinates)
  getBounds() {
    const sizes = this.getResponsiveSizes();
    // Return bounds of the central trick area (the table circle)
    const radius = sizes.tableRadius; // Same as tableBg circle radius
    return {
      x: this.x - radius,
      y: this.y - radius,
      width: radius * 2,
      height: radius * 2
    };
  }

  destroy() {
    this.trickCardSprites.forEach(card => card.destroy());
    super.destroy();
  }
}
