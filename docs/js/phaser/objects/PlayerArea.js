// PlayerArea - container for player hand and personal plot

import { CardSprite } from './CardSprite.js';
import { LayoutManager } from '../utils/LayoutManager.js';

export class PlayerArea extends Phaser.GameObjects.Container {
  constructor(scene, x, y, player, playerIndex, layoutManager) {
    super(scene, x, y);
    
    this.player = player;
    this.playerIndex = playerIndex;
    this.layoutManager = layoutManager;
    this.cardSprites = [];
    this.plotSprites = [];
    
    scene.add.existing(this);
    
    // Create player name and score display
    this.createPlayerInfo();
    
    // Create hand area
    this.handContainer = scene.add.container(0, 0);
    this.add(this.handContainer);
    
    // Create plot area
    this.plotContainer = scene.add.container(0, 0);
    this.add(this.plotContainer);
  }

  getResponsiveSizes() {
    const gameWidth = this.scene.cameras.main.width;
    const gameHeight = this.scene.cameras.main.height;
    const baseSize = Math.min(gameWidth, gameHeight);
    
    return {
      // Font sizes
      playerInfoFontSize: `${Math.max(16, Math.min(24, baseSize * 0.02))}px`,
      emblemFontSize: `${Math.max(12, Math.min(20, baseSize * 0.016))}px`,
      turnIndicatorFontSize: `${Math.max(18, Math.min(30, baseSize * 0.024))}px`,
      
      // Positions (percentages of screen height)
      playerInfoY: -gameHeight * 0.08,
      emblemY: -gameHeight * 0.1,
      turnIndicatorY: -gameHeight * 0.06,
      
      // Fan radius
      fanRadius: Math.max(100, Math.min(140, baseSize * 0.12)),
      
      // Plot card sizes
      plotCardWidth: Math.max(32, Math.min(48, baseSize * 0.04)),
      plotCardHeight: Math.max(45, Math.min(67, baseSize * 0.056)),
      
      // Plot spacing
      plotStackSpacingX: Math.max(48, Math.min(72, baseSize * 0.06)),
      plotStackSpacingY: Math.max(64, Math.min(96, baseSize * 0.08)),
      plotCardOverlap: 3,
      plotCardSpacingX: Math.max(20, Math.min(30, baseSize * 0.025)),
      plotCardSpacingY: Math.max(24, Math.min(36, baseSize * 0.03)),
      plotBaseY: gameHeight * 0.1,
      plotStackStartY: gameHeight * 0.1
    };
  }

  createPlayerInfo() {
    const sizes = this.getResponsiveSizes();
    const isHuman = this.player.isHuman;
    const isCentralPlanner = this.playerIndex === this.scene.gameState?.lead;
    const isCurrentTurn = this.scene.gameState?.phase === 'trick' && 
                          this.scene.gameState?.currentTrick.length < this.scene.gameState?.numPlayers &&
                          this.playerIndex === (this.scene.gameState?.lead + this.scene.gameState?.currentTrick.length) % this.scene.gameState?.numPlayers;
    
    // Player name and score
    const score = this.scene.gameState?.scores?.[this.playerIndex] || 0;
    let infoText = `${this.player.name}: ${score}`;
    // Always show medals if player has won tricks this year (display only)
    // Count shown is p.medals (tricks won this year) + plot.medals (if variant enabled)
    if (this.player.hasWonTrickThisYear || (this.player.medals || 0) > 0) {
      const currentYearMedals = this.player.medals || 0;
      const plotMedals = this.scene.gameState?.gameVariants?.medalsCount ? (this.player.plot?.medals || 0) : 0;
      const medalsToShow = currentYearMedals + plotMedals;
      if (medalsToShow > 0) {
        infoText += ` 🏅${medalsToShow}`;
      }
    }
    const info = this.scene.add.text(0, sizes.playerInfoY, infoText, {
      fontSize: sizes.playerInfoFontSize,
      fill: isHuman ? '#c9a961' : '#ffffff'
    });
    info.setOrigin(0.5, 0.5);
    this.add(info);
    this.playerInfo = info;
    
    // Indicators
    if (isCentralPlanner) {
      const emblem = this.scene.add.text(0, sizes.emblemY, '👑', { fontSize: sizes.emblemFontSize });
      emblem.setOrigin(0.5, 0.5);
      this.add(emblem);
    }
    
    if (isCurrentTurn) {
      const turnIndicator = this.scene.add.text(0, sizes.turnIndicatorY, '→', { fontSize: sizes.turnIndicatorFontSize, fill: '#4CAF50' });
      turnIndicator.setOrigin(0.5, 0.5);
      this.add(turnIndicator);
    }
  }

  updatePlayerInfo() {
    if (this.playerInfo) {
      const sizes = this.getResponsiveSizes();
      const score = this.scene.gameState?.scores?.[this.playerIndex] || 0;
      let infoText = `${this.player.name}: ${score}`;
      // Always show medals if player has won tricks this year (display only)
      // Count shown is p.medals (tricks won this year) + plot.medals (if variant enabled)
      if (this.player.hasWonTrickThisYear || (this.player.medals || 0) > 0) {
        const currentYearMedals = this.player.medals || 0;
        const plotMedals = this.scene.gameState?.gameVariants?.medalsCount ? (this.player.plot?.medals || 0) : 0;
        const medalsToShow = currentYearMedals + plotMedals;
        if (medalsToShow > 0) {
          infoText += ` 🏅${medalsToShow}`;
        }
      }
      this.playerInfo.setText(infoText);
      // Update font size if needed (responsive)
      this.playerInfo.setStyle({ fontSize: sizes.playerInfoFontSize });
    }
  }

  // Render player hand
  renderHand(faceUp = false) {
    // Clear existing cards
    this.cardSprites.forEach(card => card.destroy());
    this.cardSprites = [];
    this.handContainer.removeAll(true);

    if (!this.player.hand || this.player.hand.length === 0) return;

    const cardSize = this.layoutManager.getCardSize();
    const positions = this.calculateFanPositions(this.player.hand.length);

    this.player.hand.forEach((card, index) => {
      const pos = positions[index];
      const cardSprite = new CardSprite(
        this.scene,
        pos.x,
        pos.y,
        card,
        faceUp || this.player.isHuman
      );
      cardSprite.setDisplaySize(cardSize.width, cardSize.height);
      cardSprite.originalX = pos.x;
      cardSprite.originalY = pos.y;
      cardSprite.originalRotation = pos.rotation;
      
      this.cardSprites.push(cardSprite);
      this.handContainer.add(cardSprite);
    });
  }

  // Calculate fan positions for cards
  calculateFanPositions(count) {
    const sizes = this.getResponsiveSizes();
    const positions = [];
    const spreadAngle = Math.min(1.2, count * 0.15);
    const startAngle = -spreadAngle / 2;
    const radius = sizes.fanRadius;
    
    for (let i = 0; i < count; i++) {
      const angle = startAngle + (spreadAngle * i) / Math.max(1, count - 1);
      positions.push({
        x: radius * Math.sin(angle),
        y: radius * (1 - Math.cos(angle)),
        rotation: angle
      });
    }
    
    return positions;
  }

  // Render personal plot
  renderPlot() {
    const sizes = this.getResponsiveSizes();
    
    // Clear existing plot cards
    this.plotSprites.forEach(card => card.destroy());
    this.plotSprites = [];
    this.plotContainer.removeAll(true);

    const gameVariants = this.scene.gameState?.gameVariants;
    const isOrdenNachalniku = gameVariants?.ordenNachalniku && gameVariants?.deckType === '36';

    // Render stacks for ordenNachalniku variant (36-card deck only)
    if (isOrdenNachalniku && this.player.plot.stacks) {
      this.player.plot.stacks.forEach((stack, stackIndex) => {
        const stackStartX = (stackIndex % 3) * sizes.plotStackSpacingX - sizes.plotStackSpacingX;
        const stackStartY = sizes.plotStackStartY + Math.floor(stackIndex / 3) * sizes.plotStackSpacingY;
        const cardOverlap = sizes.plotCardOverlap; // Vertical overlap between stacked cards
        
        // Calculate total stack height
        const hiddenCount = stack.hidden ? stack.hidden.length : 0;
        const revealedCount = stack.revealed ? stack.revealed.length : 0;
        
        // Render hidden cards (face-down) first - these go below the revealed card
        // Cards are sorted smallest to largest, so smallest is just below revealed, largest is at bottom
        if (stack.hidden && stack.hidden.length > 0) {
          stack.hidden.forEach((card, cardIndex) => {
            // Position: smallest cards closer to revealed (higher up), larger cards further down
            const cardSprite = new CardSprite(
              this.scene,
              stackStartX,
              stackStartY + (cardIndex + 1) * cardOverlap, // Stack below revealed card
              card,
              false
            );
            cardSprite.setDisplaySize(sizes.plotCardWidth, sizes.plotCardHeight);
            cardSprite.setDepth(50 + cardIndex); // Lower depth = behind revealed card
            
            // Add hover reveal for human player's plot cards
            if (this.player.isHuman) {
              cardSprite.setInteractive({ useHandCursor: true });
              cardSprite.on('pointerover', () => {
                cardSprite.setFaceUp(true);
              });
              cardSprite.on('pointerout', () => {
                cardSprite.setFaceUp(false);
              });
            }
            
            this.plotSprites.push(cardSprite);
            this.plotContainer.add(cardSprite);
          });
        }
        
        // Render revealed card (face-up) - lowest card on top, completely visible
        // This should be at the very top of the stack with highest depth
        if (stack.revealed && stack.revealed.length > 0) {
          stack.revealed.forEach((card, cardIndex) => {
            const cardSprite = new CardSprite(
              this.scene,
              stackStartX,
              stackStartY, // Top of stack (lowest Y = highest on screen)
              card,
              true
            );
            cardSprite.setDisplaySize(sizes.plotCardWidth, sizes.plotCardHeight);
            cardSprite.setDepth(200); // Highest depth = completely on top and visible
            this.plotSprites.push(cardSprite);
            this.plotContainer.add(cardSprite);
          });
        }
      });
    }

    // Render revealed cards (for non-ordenNachalniku or when stacks aren't used)
    if (this.player.plot.revealed) {
      const baseY = isOrdenNachalniku && this.player.plot.stacks?.length > 0 
        ? sizes.plotStackStartY * 2 + Math.floor((this.player.plot.stacks.length - 1) / 3) * sizes.plotStackSpacingY
        : sizes.plotBaseY;
      
      this.player.plot.revealed.forEach((card, index) => {
        const cardSprite = new CardSprite(
          this.scene,
          (index % 5) * sizes.plotCardSpacingX - sizes.plotCardSpacingX * 2,
          baseY + Math.floor(index / 5) * sizes.plotCardSpacingY,
          card,
          true
        );
        cardSprite.setDisplaySize(sizes.plotCardWidth, sizes.plotCardHeight);
        this.plotSprites.push(cardSprite);
        this.plotContainer.add(cardSprite);
      });
    }

    // Render hidden cards (face down)
    if (this.player.plot.hidden) {
      const baseY = isOrdenNachalniku && this.player.plot.stacks?.length > 0 
        ? sizes.plotStackStartY * 2.5 + Math.floor((this.player.plot.stacks.length - 1) / 3) * sizes.plotStackSpacingY
        : sizes.plotBaseY * 1.5;
      
      this.player.plot.hidden.forEach((card, index) => {
        const cardSprite = new CardSprite(
          this.scene,
          (index % 5) * sizes.plotCardSpacingX - sizes.plotCardSpacingX * 2,
          baseY + Math.floor(index / 5) * sizes.plotCardSpacingY,
          card,
          false
        );
        cardSprite.setDisplaySize(sizes.plotCardWidth, sizes.plotCardHeight);
        
        // Add hover reveal for human player's plot cards
        if (this.player.isHuman) {
          cardSprite.setInteractive({ useHandCursor: true });
          cardSprite.on('pointerover', () => {
            cardSprite.setFaceUp(true);
          });
          cardSprite.on('pointerout', () => {
            cardSprite.setFaceUp(false);
          });
        }
        
        this.plotSprites.push(cardSprite);
        this.plotContainer.add(cardSprite);
      });
    }
  }

  getCardSprites() {
    return this.cardSprites;
  }

  destroy() {
    this.cardSprites.forEach(card => card.destroy());
    this.plotSprites.forEach(card => card.destroy());
    super.destroy();
  }
}
