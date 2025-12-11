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
    this.crownEmblem = null;
    this.turnIndicator = null;
    
    scene.add.existing(this);
    
    // Containers are non-interactive by default, but explicitly disable to ensure
    // pointer events pass through to child sprites and scene elements
    this.disableInteractive();
    
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
      
      // Plot card sizes (larger for single row layout)
      plotCardWidth: Math.max(48, Math.min(72, baseSize * 0.06)),
      plotCardHeight: Math.max(67, Math.min(101, baseSize * 0.084)),
      
      // Plot spacing
      plotStackSpacingX: Math.max(48, Math.min(72, baseSize * 0.06)),
      plotStackSpacingY: Math.max(64, Math.min(96, baseSize * 0.08)),
      plotCardOverlap: 3,
      // Spacing should be card width + gap to prevent overlap
      plotCardSpacingX: Math.max(54, Math.min(80, baseSize * 0.067)), // Card width + small gap
      plotCardSpacingY: Math.max(24, Math.min(36, baseSize * 0.03)),
      plotBaseY: gameHeight * 0.1,
      plotStackStartY: gameHeight * 0.1
    };
  }

  createPlayerInfo() {
    const sizes = this.getResponsiveSizes();
    const isHuman = this.player.isHuman;
    const isCentralPlanner = this.playerIndex === this.scene.gameState?.dealer;
    const isCurrentTurn = this.scene.gameState?.phase === 'trick' && 
                          this.scene.gameState?.currentTrick.length < this.scene.gameState?.numPlayers &&
                          this.playerIndex === this.scene.getNextPlayer();
    
    // Player name and score
    const score = this.scene.gameState?.scores?.[this.playerIndex] || 0;
    let infoText = `${this.player.name}: ${score}`;
    
    // Medal display logic
    const isOrdenNachalniku = this.scene.gameState?.gameVariants?.ordenNachalniku && 
                              this.scene.gameState?.gameVariants?.deckType === '36';
    
    if (isOrdenNachalniku) {
      // For ordenNachalniku variant: only show medals if player completed jobs (has stacks)
      const stacksCount = (this.player.plot?.stacks?.length || 0);
      if (stacksCount > 0) {
        infoText += ` 🏅${stacksCount}`;
      }
    } else {
      // Standard behavior: show medals for tricks won this year (display only)
      // Count shown is p.medals (tricks won this year) + plot.medals (if variant enabled)
      if (this.player.hasWonTrickThisYear || (this.player.medals || 0) > 0) {
        const currentYearMedals = this.player.medals || 0;
        const plotMedals = this.scene.gameState?.gameVariants?.medalsCount ? (this.player.plot?.medals || 0) : 0;
        const medalsToShow = currentYearMedals + plotMedals;
        if (medalsToShow > 0) {
          infoText += ` 🏅${medalsToShow}`;
        }
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
      this.crownEmblem = this.scene.add.text(0, sizes.emblemY, '👑', { fontSize: sizes.emblemFontSize });
      this.crownEmblem.setOrigin(0.5, 0.5);
      this.add(this.crownEmblem);
    }
    
    if (isCurrentTurn) {
      this.turnIndicator = this.scene.add.text(0, sizes.turnIndicatorY, '→', { fontSize: sizes.turnIndicatorFontSize, fill: '#4CAF50' });
      this.turnIndicator.setOrigin(0.5, 0.5);
      this.add(this.turnIndicator);
    }
  }

  updatePlayerInfo() {
    if (this.playerInfo) {
      const sizes = this.getResponsiveSizes();
      const score = this.scene.gameState?.scores?.[this.playerIndex] || 0;
      let infoText = `${this.player.name}: ${score}`;
      
      // Medal display logic
      const isOrdenNachalniku = this.scene.gameState?.gameVariants?.ordenNachalniku && 
                                this.scene.gameState?.gameVariants?.deckType === '36';
      
      if (isOrdenNachalniku) {
        // For ordenNachalniku variant: only show medals if player completed jobs (has stacks)
        const stacksCount = (this.player.plot?.stacks?.length || 0);
        if (stacksCount > 0) {
          infoText += ` 🏅${stacksCount}`;
        }
      } else {
        // Standard behavior: show medals for tricks won this year (display only)
        // Count shown is p.medals (tricks won this year) + plot.medals (if variant enabled)
        if (this.player.hasWonTrickThisYear || (this.player.medals || 0) > 0) {
          const currentYearMedals = this.player.medals || 0;
          const plotMedals = this.scene.gameState?.gameVariants?.medalsCount ? (this.player.plot?.medals || 0) : 0;
          const medalsToShow = currentYearMedals + plotMedals;
          if (medalsToShow > 0) {
            infoText += ` 🏅${medalsToShow}`;
          }
        }
      }
      this.playerInfo.setText(infoText);
      // Update font size if needed (responsive)
      this.playerInfo.setStyle({ fontSize: sizes.playerInfoFontSize });
    }
    
    // Update indicators based on current game state
    const isCentralPlanner = this.playerIndex === this.scene.gameState?.dealer;
    // Turn indicator: show arrow if it's the trick phase and this player should play next
    let isCurrentTurn = false;
    if (this.scene.gameState?.phase === 'trick' && 
        this.scene.gameState?.currentTrick.length < this.scene.gameState?.numPlayers) {
      const nextPlayer = this.scene.getNextPlayer();
      isCurrentTurn = this.playerIndex === nextPlayer;
    }
    
    const sizes = this.getResponsiveSizes();
    
    // Update crown (dealer indicator)
    if (isCentralPlanner && !this.crownEmblem) {
      // Need to show crown
      this.crownEmblem = this.scene.add.text(0, sizes.emblemY, '👑', { fontSize: sizes.emblemFontSize });
      this.crownEmblem.setOrigin(0.5, 0.5);
      this.add(this.crownEmblem);
    } else if (!isCentralPlanner && this.crownEmblem) {
      // Need to hide crown
      this.crownEmblem.destroy();
      this.crownEmblem = null;
    }
    
    // Update turn indicator (lead arrow)
    if (isCurrentTurn && !this.turnIndicator) {
      // Need to show turn indicator
      this.turnIndicator = this.scene.add.text(0, sizes.turnIndicatorY, '→', { fontSize: sizes.turnIndicatorFontSize, fill: '#4CAF50' });
      this.turnIndicator.setOrigin(0.5, 0.5);
      this.add(this.turnIndicator);
    } else if (!isCurrentTurn && this.turnIndicator) {
      // Need to hide turn indicator
      this.turnIndicator.destroy();
      this.turnIndicator = null;
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
    
    // Check if this is a top player (Y position above center)
    const centerY = this.scene.cameras.main.height / 2;
    const isTopPlayer = this.y < centerY;
    
    // Adjust hand Y offset based on player position
    // Top players: hand slightly below center, bottom players: hand at center
    const handYOffset = isTopPlayer ? sizes.fanRadius * 0.3 : 0;
    
    for (let i = 0; i < count; i++) {
      const angle = startAngle + (spreadAngle * i) / Math.max(1, count - 1);
      positions.push({
        x: radius * Math.sin(angle),
        y: handYOffset + radius * (1 - Math.cos(angle)),
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
      // Check if this is a top player (Y position above center)
      const centerY = this.scene.cameras.main.height / 2;
      const isTopPlayer = this.y < centerY;
      
      // For top players: stacks above hand (negative Y), for bottom players: stacks below hand (positive Y)
      const stackBaseY = isTopPlayer ? -sizes.plotStackStartY : sizes.plotStackStartY;
      
      this.player.plot.stacks.forEach((stack, stackIndex) => {
        const stackStartX = (stackIndex % 3) * sizes.plotStackSpacingX - sizes.plotStackSpacingX;
        const stackStartY = stackBaseY + Math.floor(stackIndex / 3) * sizes.plotStackSpacingY;
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

    // Render all plot cards in a single row (revealed + hidden)
    // Check if this is a top player (Y position above center)
    const centerY = this.scene.cameras.main.height / 2;
    const isTopPlayer = this.y < centerY;
    
    // For top players: plot above hand (negative Y), for bottom players: plot below hand (positive Y)
    // Add slight downward offset for both
    const plotYOffset = isTopPlayer ? -sizes.plotBaseY * 1.5 + 20 : sizes.plotBaseY + 20;
    
    const baseY = isOrdenNachalniku && this.player.plot.stacks?.length > 0 
      ? (isTopPlayer ? -sizes.plotStackStartY * 2 : sizes.plotStackStartY * 2) + Math.floor((this.player.plot.stacks.length - 1) / 3) * sizes.plotStackSpacingY + 20
      : plotYOffset;
    
    // Combine all plot cards (revealed first, then hidden) into a single array
    const allPlotCards = [];
    if (this.player.plot.revealed) {
      this.player.plot.revealed.forEach(card => {
        allPlotCards.push({ card, faceUp: true });
      });
    }
    if (this.player.plot.hidden) {
      this.player.plot.hidden.forEach(card => {
        allPlotCards.push({ card, faceUp: false });
      });
    }
    
    // Render all cards in a single row with proper spacing
    if (allPlotCards.length > 0) {
      const totalCards = allPlotCards.length;
      // Spacing should be card width + small gap (8px) to prevent overlap
      const cardSpacing = sizes.plotCardWidth + 8;
      const totalWidth = (totalCards - 1) * cardSpacing;
      const startX = -totalWidth / 2;
      
      allPlotCards.forEach((plotCard, index) => {
        const cardSprite = new CardSprite(
          this.scene,
          startX + index * cardSpacing,
          baseY,
          plotCard.card,
          plotCard.faceUp
        );
        cardSprite.setDisplaySize(sizes.plotCardWidth, sizes.plotCardHeight);
        
        // Add hover reveal for human player's hidden plot cards
        if (this.player.isHuman && !plotCard.faceUp) {
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

  getPlotSprites() {
    return this.plotSprites;
  }

  // Get bounds for plot container (for drop zone detection)
  getPlotBounds() {
    if (this.plotSprites.length === 0) {
      // No plot cards, return a default area
      const sizes = this.getResponsiveSizes();
      return {
        x: this.x - sizes.plotCardSpacingX * 2.5,
        y: this.y + sizes.plotBaseY,
        width: sizes.plotCardSpacingX * 5,
        height: sizes.plotBaseY * 2
      };
    }
    
    // Calculate bounds from actual card positions
    let minX = Infinity, maxX = -Infinity;
    let minY = Infinity, maxY = -Infinity;
    
    this.plotSprites.forEach(sprite => {
      // Get world position of sprite
      const worldX = this.x + this.plotContainer.x + sprite.x;
      const worldY = this.y + this.plotContainer.y + sprite.y;
      const halfWidth = sprite.displayWidth / 2;
      const halfHeight = sprite.displayHeight / 2;
      
      minX = Math.min(minX, worldX - halfWidth);
      maxX = Math.max(maxX, worldX + halfWidth);
      minY = Math.min(minY, worldY - halfHeight);
      maxY = Math.max(maxY, worldY + halfHeight);
    });
    
    // Add padding
    const padding = 20;
    return {
      x: minX - padding,
      y: minY - padding,
      width: (maxX - minX) + padding * 2,
      height: (maxY - minY) + padding * 2
    };
  }

  // Get bounds for hand container (for drop zone detection)
  getHandBounds() {
    if (this.cardSprites.length === 0) {
      // No hand cards, return a default area
      const sizes = this.getResponsiveSizes();
      return {
        x: this.x - sizes.fanRadius * 1.25,
        y: this.y - sizes.fanRadius * 0.75,
        width: sizes.fanRadius * 2.5,
        height: sizes.fanRadius * 1.5
      };
    }
    
    // Calculate bounds from actual card positions
    let minX = Infinity, maxX = -Infinity;
    let minY = Infinity, maxY = -Infinity;
    
    this.cardSprites.forEach(sprite => {
      // Get world position of sprite
      const worldX = this.x + this.handContainer.x + sprite.x;
      const worldY = this.y + this.handContainer.y + sprite.y;
      const halfWidth = sprite.displayWidth / 2;
      const halfHeight = sprite.displayHeight / 2;
      
      minX = Math.min(minX, worldX - halfWidth);
      maxX = Math.max(maxX, worldX + halfWidth);
      minY = Math.min(minY, worldY - halfHeight);
      maxY = Math.max(maxY, worldY + halfHeight);
    });
    
    // Add padding
    const padding = 20;
    return {
      x: minX - padding,
      y: minY - padding,
      width: (maxX - minX) + padding * 2,
      height: (maxY - minY) + padding * 2
    };
  }

  destroy() {
    this.cardSprites.forEach(card => card.destroy());
    this.plotSprites.forEach(card => card.destroy());
    super.destroy();
  }
}
