// InputManager - handles drag/drop, click, and touch interactions

export class InputManager {
  constructor(scene, gameState, onCardPlayed, onAssignmentSubmitted) {
    this.scene = scene;
    this.gameState = gameState;
    this.onCardPlayed = onCardPlayed;
    this.onAssignmentSubmitted = onAssignmentSubmitted;

    this.draggedCard = null;
    this.dropZones = new Map();
    this.assignmentMap = new Map();
    this.debugMode = false; // Set to true to see debug info
  }

  // Enable card dragging
  enableCardDrag(cardSprite, cardIndex, playerIndex) {
    // Remove existing drag event listeners to prevent duplicates
    cardSprite.off('dragstart');
    cardSprite.off('drag');
    cardSprite.off('dragend');
    cardSprite.off('pointerup');
    
    // Clean up any existing drag preview that might be lingering
    if (cardSprite._dragPreview) {
      cardSprite._dragPreview.destroy();
      cardSprite._dragPreview = null;
    }
    
    cardSprite.setInteractive({ draggable: true, useHandCursor: true });
    this.scene.input.setDraggable(cardSprite);

    cardSprite.on('dragstart', (pointer) => {
      // Check if it's the player's turn before allowing drag
      if (!this.isPlayerTurn(playerIndex)) {
        // Don't create preview or allow drag when it's not the player's turn
        // The drag will still technically start, but we won't show anything
        return;
      }

      // Clean up any existing preview first (safety check)
      if (cardSprite._dragPreview) {
        cardSprite._dragPreview.destroy();
        cardSprite._dragPreview = null;
      }

      this.draggedCard = { sprite: cardSprite, index: cardIndex, playerIndex };

      // Use pointer world coordinates for initial preview position
      const startX = pointer.worldX;
      const startY = pointer.worldY;

      // Create a visual clone for dragging at pointer position
      const dragPreview = this.scene.add.sprite(startX, startY, cardSprite.texture.key);
      dragPreview.setDisplaySize(cardSprite.displayWidth, cardSprite.displayHeight);
      dragPreview.setOrigin(cardSprite.originX, cardSprite.originY);
      dragPreview.setRotation(cardSprite.rotation);
      dragPreview.setAlpha(0.8);
      dragPreview.setDepth(10000); // Ensure it's on top of everything

      // Store drag preview on the card sprite for cleanup
      cardSprite._dragPreview = dragPreview;

      // Make original card semi-transparent to show where it came from
      cardSprite.setAlpha(0.3);

      this.scene.children.bringToTop(dragPreview);
    });

    cardSprite.on('drag', (pointer, dragX, dragY) => {
      // Only move preview if it exists (which means dragstart allowed it)
      if (cardSprite._dragPreview) {
        cardSprite._dragPreview.x = pointer.worldX;
        cardSprite._dragPreview.y = pointer.worldY;
      }
    });

    cardSprite.on('dragend', (pointer) => {
      // Always clean up drag preview if it exists
      if (cardSprite._dragPreview) {
        cardSprite._dragPreview.destroy();
        cardSprite._dragPreview = null;
      }

      // Restore original card alpha
      cardSprite.setAlpha(1.0);

      // Only process drop if we actually had a valid drag (preview was created)
      if (!this.draggedCard) {
        // If no valid drag occurred (e.g., not player's turn), ensure card is in original position
        if (cardSprite.x !== cardSprite.originalX || cardSprite.y !== cardSprite.originalY) {
          this.scene.tweens.add({
            targets: cardSprite,
            x: cardSprite.originalX,
            y: cardSprite.originalY,
            duration: 200,
            ease: 'Power2'
          });
        }
        return;
      }

      // Use pointer world coordinates for drop detection
      const dragX = pointer.worldX;
      const dragY = pointer.worldY;

      if (this.debugMode) {
        console.log('Card dropped at:', dragX, dragY);
      }

      // Check for drop zones
      let dropped = false;
      this.dropZones.forEach((zone, key) => {
        const bounds = zone.getBounds();
        if (this.debugMode) {
          console.log(`Checking drop zone '${key}':`, bounds);
        }
        if (bounds && dragX >= bounds.x && dragX <= bounds.x + bounds.width &&
            dragY >= bounds.y && dragY <= bounds.y + bounds.height) {
          if (this.debugMode) {
            console.log(`Card dropped in zone '${key}'`);
          }
          this.handleDrop(cardSprite, zone, key);
          dropped = true;
        }
      });

      if (!dropped) {
        if (this.debugMode) {
          console.log('Card not dropped in any zone, returning to original position');
        }
        // Return to original position with animation
        this.scene.tweens.add({
          targets: cardSprite,
          x: cardSprite.originalX,
          y: cardSprite.originalY,
          duration: 200,
          ease: 'Power2'
        });
      }

      this.draggedCard = null;
    });

    // Also handle pointerup to clean up if dragstart fired but dragend didn't
    cardSprite.on('pointerup', () => {
      // Small delay to let dragend fire first if it's going to
      this.scene.time.delayedCall(50, () => {
        if (cardSprite._dragPreview) {
          cardSprite._dragPreview.destroy();
          cardSprite._dragPreview = null;
          cardSprite.setAlpha(1.0);
        }
      });
    });
  }

  // Register a drop zone
  registerDropZone(key, zoneObject, onDrop) {
    this.dropZones.set(key, {
      object: zoneObject,
      onDrop: onDrop,
      getBounds: () => {
        if (zoneObject.getBounds) {
          return zoneObject.getBounds();
        } else if (zoneObject.getDropZoneBounds) {
          return zoneObject.getDropZoneBounds();
        } else {
          console.warn(`Drop zone ${key} has no getBounds() method`);
          return null;
        }
      }
    });
  }

  // Handle card drop
  handleDrop(cardSprite, zone, zoneKey) {
    const zoneData = this.dropZones.get(zoneKey);
    if (zoneData && zoneData.onDrop) {
      if (!this.draggedCard) {
        console.warn('handleDrop called but draggedCard is null');
        return;
      }
      zoneData.onDrop(this.draggedCard, cardSprite);
    }
  }

  // Enable click to play (alternative to drag)
  enableCardClick(cardSprite, cardIndex, playerIndex) {
    // Remove existing click listener to prevent duplicates
    cardSprite.off('pointerdown');
    
    cardSprite.on('pointerdown', () => {
      if (this.isValidPlay(cardIndex)) {
        this.onCardPlayed(cardIndex);
      }
    });
  }

  // Check if it's the player's turn
  isPlayerTurn(playerIndex) {
    if (this.gameState.phase !== 'trick') return false;
    if (this.gameState.currentTrick.length >= this.gameState.numPlayers) return false;
    const nextPlayer = (this.gameState.lead + this.gameState.currentTrick.length) % this.gameState.numPlayers;
    return nextPlayer === playerIndex;
  }

  // Validate card play (follow suit rule)
  isValidPlay(cardIndex) {
    if (this.gameState.phase !== 'trick') return false;
    
    // Check if it's the player's turn
    if (!this.isPlayerTurn(0)) return false;
    
    // Check if player exists and has cards
    if (!this.gameState.players[0] || !this.gameState.players[0].hand) return false;
    if (cardIndex < 0 || cardIndex >= this.gameState.players[0].hand.length) return false;
    
    // If leading (trick is empty), any card is valid
    if (!this.gameState.currentTrick || this.gameState.currentTrick.length === 0) {
      return true;
    }

    // Must follow suit if able
    const leadSuit = this.gameState.currentTrick[0][1].suit;
    const playedCard = this.gameState.players[0].hand[cardIndex];
    const canFollow = this.gameState.players[0].hand.some(c => c.suit === leadSuit);

    return !canFollow || playedCard.suit === leadSuit;
  }

  // Setup assignment phase drag and drop
  setupAssignmentPhase(trickCards, jobPiles) {
    this.assignmentMap.clear();
    this.assignmentJobPiles = jobPiles; // Store reference for showing/hiding drop zones

    // Calculate valid jobs from the trick (suits represented in the trick)
    const validJobs = Array.from(new Set(
      this.gameState.lastTrick.map(([_, card]) => card.suit)
    ));

    // Helper function to check if a card can be assigned to a specific job
    const canAssignToJob = (card, targetSuit) => {
      // Any card can be assigned to any suit that was represented in the trick
      return validJobs.includes(targetSuit);
    };

    // Initialize assignment tracking
    trickCards.forEach((cardSprite, index) => {
      const cardKey = `${cardSprite.card.suit}-${cardSprite.card.value}`;
      this.assignmentMap.set(cardKey, null);

      // Remove existing drag event listeners to prevent duplicates
      cardSprite.off('dragstart');
      cardSprite.off('drag');
      cardSprite.off('dragend');
      cardSprite.off('pointerup');

      // Enable drag for each card
      cardSprite.setInteractive({ draggable: true, useHandCursor: true });
      this.scene.input.setDraggable(cardSprite);

      let dragPreview = null;

      cardSprite.on('dragstart', (pointer) => {
        // Clean up any existing preview first (safety check)
        if (dragPreview) {
          dragPreview.destroy();
          dragPreview = null;
        }

        // Use pointer world coordinates for initial preview position
        const startX = pointer.worldX;
        const startY = pointer.worldY;

        // Create a visual clone for dragging at pointer position
        dragPreview = this.scene.add.sprite(startX, startY, cardSprite.texture.key);
        dragPreview.setDisplaySize(cardSprite.displayWidth, cardSprite.displayHeight);
        dragPreview.setOrigin(cardSprite.originX, cardSprite.originY);
        dragPreview.setRotation(cardSprite.rotation);
        dragPreview.setAlpha(0.8);
        dragPreview.setDepth(10000); // Ensure it's on top of everything

        // Make original card semi-transparent
        cardSprite.setAlpha(0.3);

        this.scene.children.bringToTop(dragPreview);
      });

      cardSprite.on('drag', (pointer, dragX, dragY) => {
        // Move the preview clone using world coordinates to match pointer position
        if (dragPreview) {
          dragPreview.x = pointer.worldX;
          dragPreview.y = pointer.worldY;
        }
      });

      cardSprite.on('dragend', (pointer) => {
        // Destroy the drag preview
        if (dragPreview) {
          dragPreview.destroy();
          dragPreview = null;
        }

        // Use pointer world coordinates for drop detection
        const dragX = pointer.worldX;
        const dragY = pointer.worldY;

        // Check if dropped on a job pile
        let assigned = false;
        jobPiles.forEach((pile, suit) => {
          const bounds = pile.getDropZoneBounds();
          if (bounds && dragX >= bounds.x && dragX <= bounds.x + bounds.width &&
              dragY >= bounds.y && dragY <= bounds.y + bounds.height) {
            // Validate that this card can be assigned to this job
            if (canAssignToJob(cardSprite.card, suit)) {
              const cardKey = `${cardSprite.card.suit}-${cardSprite.card.value}`;
              if (!this.assignmentMap.get(cardKey)) {
                this.assignmentMap.set(cardKey, suit);
                assigned = true;

                // Hide the card visually
                cardSprite.setVisible(false);
                cardSprite.setAlpha(1.0); // Reset alpha for when it might be shown again
                // Remove glow from assigned card
                cardSprite.setValidHighlight(false);

                // Update the job pile to show preview of assigned cards
                // Note: This is a preview - actual assignment happens on submit
                // The preview will be shown by updating the scene's render
                if (this.onAssignmentChanged) {
                  this.onAssignmentChanged();
                }
              }
            }
          }
        });

        if (!assigned) {
          // Restore original card alpha
          cardSprite.setAlpha(1.0);

          // Return to original position with animation
          this.scene.tweens.add({
            targets: cardSprite,
            x: cardSprite.originalX,
            y: cardSprite.originalY,
            duration: 200,
            ease: 'Power2'
          });
        }
      });

      // Also handle pointerup to clean up if dragstart fired but dragend didn't
      cardSprite.on('pointerup', () => {
        // Small delay to let dragend fire first if it's going to
        this.scene.time.delayedCall(50, () => {
          if (dragPreview) {
            dragPreview.destroy();
            dragPreview = null;
            cardSprite.setAlpha(1.0);
          }
        });
      });
    });
  }

  // Get assignment mapping - needs actual Card instances from gameState
  getAssignmentMapping(gameState) {
    const mapping = new Map();
    // Use cards from lastTrick to get actual Card instances
    gameState.lastTrick.forEach(([pid, card]) => {
      const cardKey = `${card.suit}-${card.value}`;
      const assignedSuit = this.assignmentMap.get(cardKey);
      if (assignedSuit) {
        mapping.set(card, assignedSuit);
      }
    });
    return mapping;
  }

  // Check if all cards are assigned
  areAllCardsAssigned() {
    return Array.from(this.assignmentMap.values()).every(suit => suit !== null);
  }

  clear() {
    // Clean up any lingering drag previews
    this.scene.children.list.forEach(child => {
      if (child._dragPreview) {
        child._dragPreview.destroy();
        child._dragPreview = null;
      }
    });
    
    // Don't hide assignment drop zones here - they should remain visible
    // during the assignment phase. They'll be removed by the scene when
    // the assignment phase ends.
    
    this.dropZones.clear();
    this.assignmentMap.clear();
    this.draggedCard = null;
    this.assignmentJobPiles = null;
  }
}
