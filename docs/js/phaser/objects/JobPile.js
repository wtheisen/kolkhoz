// JobPile - displays job cards and work hours

import { CardSprite } from './CardSprite.js';
import { TextureLoader } from '../utils/TextureLoader.js';
import { SUITS } from '../../core/constants.js';

export class JobPile extends Phaser.GameObjects.Container {
  constructor(scene, x, y, suit, gameState, layoutManager) {
    super(scene, x, y);
    
    this.suit = suit;
    this.gameState = gameState;
    this.layoutManager = layoutManager;
    this.jobCardSprites = [];
    this.assignedCardSprites = [];
    this.dropZone = null;
    this.assignmentPreviewMap = null; // Map for preview assignments during assignment phase
    
    scene.add.existing(this);
    
    this.createJobDisplay();
    this.createWorkHoursDisplay();
    this.createAssignedCardsArea();
  }

  getResponsiveSizes() {
    const gameWidth = this.scene.cameras.main.width;
    const gameHeight = this.scene.cameras.main.height;
    const baseSize = Math.min(gameWidth, gameHeight);
    
    // Get card size from layout manager
    const cardSize = this.layoutManager ? this.layoutManager.getCardSize() : {
      width: Math.max(40, Math.min(60, baseSize * 0.05)),
      height: Math.max(56, Math.min(84, baseSize * 0.07))
    };
    
    return {
      // Job card sizes (fan display)
      jobCardWidth: cardSize.width * 0.625, // ~50px at default
      jobCardHeight: cardSize.height * 0.625, // ~70px at default
      
      // Assigned card sizes (stack display)
      assignedCardWidth: cardSize.width * 0.625,
      assignedCardHeight: cardSize.height * 0.625,
      cardOverlap: cardSize.height * 0.357, // ~25px overlap at default
      
      // Font sizes
      hoursFontSize: `${Math.max(14, Math.min(22, baseSize * 0.018))}px`,
      
      // Suit icon size
      suitIconSize: Math.max(24, Math.min(36, baseSize * 0.03)),
      
      // Fan layout parameters
      fanAngleStep: 5, // degrees per card
      fanOffsetX: baseSize * 0.0175, // ~17.5px at default
      fanOffsetY: -gameHeight * 0.04, // -40px at default
      
      // Drop zone
      dropZoneWidth: Math.max(80, Math.min(120, gameWidth * 0.1)),
      dropZoneHeight: Math.max(60, Math.min(100, gameHeight * 0.08)),
      dropZoneY: gameHeight * 0.05, // 50px at default
      
      // Assigned cards container position
      assignedCardsY: gameHeight * 0.05
    };
  }

  createJobDisplay() {
    const sizes = this.getResponsiveSizes();
    const jobRewards = this.gameState.revealedJobs[this.suit];
    const isArray = Array.isArray(jobRewards);
    const rewardCards = isArray ? jobRewards : [jobRewards];
    const remainingCards = this.gameState.jobPiles[this.suit]?.length || 0;
    const isClaimed = (this.gameState.workHours[this.suit] || 0) >= 40;

    // Display job reward cards in a fan layout
    if (isClaimed && remainingCards > 0) {
      // Show face-down cards for claimed jobs in a fan
      for (let i = 0; i < Math.min(remainingCards, 7); i++) {
        // Create a dummy card for the back
        const dummyCard = { suit: this.suit, value: 1 };
        const angle = (i * sizes.fanAngleStep - 10) * (Math.PI / 180); // Fan angle
        const offsetX = (i * sizes.fanOffsetX - sizes.fanOffsetX * 2) * 0.7; // Fan offset
        const cardSprite = new CardSprite(this.scene, offsetX, sizes.fanOffsetY, dummyCard, false);
        cardSprite.setDisplaySize(sizes.jobCardWidth, sizes.jobCardHeight);
        cardSprite.setRotation(angle);
        cardSprite.setOrigin(0.5, 1); // Origin at bottom for fan
        cardSprite.setDepth(i + 1);
        this.jobCardSprites.push(cardSprite);
        this.add(cardSprite);
      }
    } else if (rewardCards.length > 0) {
      // Show revealed job cards in a fan
      // If there are accumulated unclaimed job cards, show them first
      const totalCards = rewardCards.length + (this.gameState.gameVariants.accumulateUnclaimedJobs ? remainingCards : 0);
      
      // Show face-down accumulated cards first if applicable
      if (this.gameState.gameVariants.accumulateUnclaimedJobs && remainingCards > 0) {
        for (let i = 0; i < remainingCards; i++) {
          const dummyCard = { suit: this.suit, value: 1 };
          const angle = (i * sizes.fanAngleStep - 10) * (Math.PI / 180);
          const offsetX = (i * sizes.fanOffsetX - sizes.fanOffsetX * 2) * 0.7;
          const cardSprite = new CardSprite(this.scene, offsetX, sizes.fanOffsetY, dummyCard, false);
          cardSprite.setDisplaySize(sizes.jobCardWidth, sizes.jobCardHeight);
          cardSprite.setRotation(angle);
          cardSprite.setOrigin(0.5, 1);
          cardSprite.setDepth(i + 1);
          this.jobCardSprites.push(cardSprite);
          this.add(cardSprite);
        }
      }
      
      // Show revealed reward cards in a fan (continuing from face-down cards)
      rewardCards.forEach((card, index) => {
        const fanIndex = (this.gameState.gameVariants.accumulateUnclaimedJobs ? remainingCards : 0) + index;
        const angle = (fanIndex * sizes.fanAngleStep - 10) * (Math.PI / 180);
        const offsetX = (fanIndex * sizes.fanOffsetX - sizes.fanOffsetX * 2) * 0.7;
        const cardSprite = new CardSprite(this.scene, offsetX, sizes.fanOffsetY, card, true);
        cardSprite.setDisplaySize(sizes.jobCardWidth, sizes.jobCardHeight);
        cardSprite.setRotation(angle);
        cardSprite.setOrigin(0.5, 1);
        cardSprite.setDepth(fanIndex + 1);
        this.jobCardSprites.push(cardSprite);
        this.add(cardSprite);
      });
    }
  }

  createWorkHoursDisplay() {
    const sizes = this.getResponsiveSizes();
    const gameHeight = this.scene.cameras.main.height;
    const workHours = this.gameState.workHours[this.suit] || 0;
    const threshold = 40;
    const color = workHours >= threshold ? '#4CAF50' : '#ffffff';
    
    const hoursText = this.scene.add.text(0, -gameHeight * 0.01, `${workHours}/${threshold}`, {
      fontSize: sizes.hoursFontSize,
      fill: color,
      fontStyle: 'bold'
    });
    hoursText.setOrigin(0.5, 0.5);
    this.add(hoursText);
    this.hoursText = hoursText;

    // Suit icon
    const suitIcon = this.scene.add.image(0, -gameHeight * 0.06, TextureLoader.getSuitTextureKey(this.suit));
    suitIcon.setDisplaySize(sizes.suitIconSize, sizes.suitIconSize);
    this.add(suitIcon);
  }

  createAssignedCardsArea() {
    const sizes = this.getResponsiveSizes();
    // Area where assigned worker cards will be displayed in a stack
    this.assignedCardsContainer = this.scene.add.container(0, sizes.assignedCardsY);
    this.add(this.assignedCardsContainer);
    this.updateAssignedCards();
  }

  // Set assignment preview map (for showing assignments during assignment phase)
  setAssignmentPreview(assignmentMap, lastTrick) {
    this.assignmentPreviewMap = assignmentMap;
    this.lastTrickForPreview = lastTrick;
    this.updateAssignedCards();
    this.updateWorkHours(); // Update work hours immediately when assignment changes
  }

  // Clear assignment preview
  clearAssignmentPreview() {
    this.assignmentPreviewMap = null;
    this.lastTrickForPreview = null;
    this.updateAssignedCards();
    this.updateWorkHours(); // Update work hours back to actual values
  }

  // Update assigned cards display in a vertical stack
  updateAssignedCards() {
    const sizes = this.getResponsiveSizes();
    
    // Clear existing assigned card sprites
    this.assignedCardSprites.forEach(card => card.destroy());
    this.assignedCardSprites = [];

    // Get assigned cards - either from preview or from actual jobBuckets
    let assignedCards = [];
    
    if (this.assignmentPreviewMap && this.lastTrickForPreview) {
      // During assignment phase: combine existing assignments with new preview
      // Start with cards already assigned to this job from previous tricks
      const existingCards = this.gameState.jobBuckets[this.suit] || [];
      assignedCards = [...existingCards];
      
      // Add cards from current trick that are assigned to this job
      const newAssignments = this.lastTrickForPreview
        .filter(([_pid, card]) => {
          const cardKey = `${card.suit}-${card.value}`;
          return this.assignmentPreviewMap.get(cardKey) === this.suit;
        })
        .map(([_pid, card]) => card);
      
      assignedCards.push(...newAssignments);
    } else {
      // Show actual assigned cards from jobBuckets
      assignedCards = this.gameState.jobBuckets[this.suit] || [];
    }
    
    if (assignedCards.length === 0) {
      return;
    }

    // Create vertical stack for assigned cards
    const cardWidth = sizes.assignedCardWidth;
    const cardHeight = sizes.assignedCardHeight;
    const cardOverlap = sizes.cardOverlap;
    const stackOffsetY = 0; // Start position for stack
    
    assignedCards.forEach((card, index) => {
      // Calculate vertical stack position
      const offsetX = 0; // Cards are centered horizontally
      const offsetY = stackOffsetY + index * (cardHeight - cardOverlap); // Stack vertically
      
      // Create card sprite
      const cardSprite = new CardSprite(this.scene, offsetX, offsetY, card, true);
      cardSprite.setDisplaySize(cardWidth, cardHeight); // Size for assigned cards
      cardSprite.setRotation(0); // No rotation for stack
      cardSprite.setOrigin(0.5, 0.5); // Origin at center
      
      // Set z-index (Phaser uses depth) - later cards on top
      cardSprite.setDepth(index + 1);
      
      this.assignedCardSprites.push(cardSprite);
      this.assignedCardsContainer.add(cardSprite);
    });
  }

  // Create drop zone for assignment phase (but keep it hidden initially)
  createDropZone() {
    if (this.dropZone) return; // Already created
    const sizes = this.getResponsiveSizes();
    const dropZoneBg = this.scene.add.rectangle(0, sizes.dropZoneY, sizes.dropZoneWidth, sizes.dropZoneHeight, 0x4CAF50, 0.3);
    dropZoneBg.setStrokeStyle(2, 0x4CAF50);
    this.add(dropZoneBg);
    this.dropZone = dropZoneBg;
    // Start hidden - will be shown when dragging starts
    this.dropZone.setVisible(false);
  }

  // Show drop zone
  showDropZone() {
    if (this.dropZone) {
      this.dropZone.setVisible(true);
    }
  }

  // Hide drop zone
  hideDropZone() {
    if (this.dropZone) {
      this.dropZone.setVisible(false);
    }
  }

  // Remove drop zone
  removeDropZone() {
    if (this.dropZone) {
      this.dropZone.destroy();
      this.dropZone = null;
    }
  }

  // Get drop zone bounds (in world coordinates)
  getDropZoneBounds() {
    if (!this.dropZone) return null;

    const sizes = this.getResponsiveSizes();
    // Drop zone dimensions (from createDropZone)
    const dropZoneWidth = sizes.dropZoneWidth;
    const dropZoneHeight = sizes.dropZoneHeight;
    const dropZoneLocalY = sizes.dropZoneY; // Local Y position within container

    // Get world position of this container
    const worldX = this.x;
    const worldY = this.y;

    // Calculate world bounds (drop zone is centered at container.x, container.y + dropZoneLocalY)
    return {
      x: worldX - dropZoneWidth / 2,
      y: worldY + dropZoneLocalY - dropZoneHeight / 2,
      width: dropZoneWidth,
      height: dropZoneHeight
    };
  }

  // Update assigned cards display (called when assignments change)
  refreshAssignedCards() {
    this.updateAssignedCards();
  }

  // Calculate work hours from a card (applying special rules)
  calculateWorkValue(card) {
    let workValue = card.value;

    // Special effects for nomenclature variant
    if (this.gameState.gameVariants?.nomenclature && card.suit === this.gameState.trump && card.value === 11) {
      workValue = 0; // Drunkard contributes 0 hours
    }

    return workValue;
  }

  // Update work hours display
  updateWorkHours() {
    const sizes = this.getResponsiveSizes();
    let workHours = this.gameState.workHours[this.suit] || 0;
    
    // If we're in assignment preview phase, add work hours from preview assignments
    if (this.assignmentPreviewMap && this.lastTrickForPreview) {
      const previewWorkHours = this.lastTrickForPreview
        .filter(([_pid, card]) => {
          const cardKey = `${card.suit}-${card.value}`;
          return this.assignmentPreviewMap.get(cardKey) === this.suit;
        })
        .reduce((sum, [_pid, card]) => sum + this.calculateWorkValue(card), 0);
      
      workHours += previewWorkHours;
    }
    
    const threshold = 40;
    const color = workHours >= threshold ? '#4CAF50' : '#ffffff';
    
    if (this.hoursText) {
      this.hoursText.setText(`${workHours}/${threshold}`);
      this.hoursText.setFill(color);
      // Update font size if needed (responsive)
      this.hoursText.setStyle({ fontSize: sizes.hoursFontSize });
    }
  }

  // Update job display
  updateJobDisplay() {
    // Clear existing job cards
    this.jobCardSprites.forEach(card => card.destroy());
    this.jobCardSprites = [];
    
    // Recreate job display
    this.createJobDisplay();
    
    // Also update assigned cards
    this.updateAssignedCards();
  }

  destroy() {
    this.jobCardSprites.forEach(card => card.destroy());
    this.assignedCardSprites.forEach(card => card.destroy());
    super.destroy();
  }
}
