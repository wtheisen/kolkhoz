// GameScene - main game scene

import { LayoutManager } from '../utils/LayoutManager.js';
import { AnimationManager } from '../managers/AnimationManager.js';
import { InputManager } from '../managers/InputManager.js';
import { UIManager } from '../managers/UIManager.js';
import { PlayerArea } from '../objects/PlayerArea.js';
import { JobPile } from '../objects/JobPile.js';
import { TrickArea } from '../objects/TrickArea.js';
import { GulagArea } from '../objects/GulagArea.js';
import { SUITS } from '../../core/constants.js';
import { RandomAI } from '../../ai/RandomAI.js';

export class GameScene extends Phaser.Scene {
  constructor() {
    super({ key: 'GameScene' });
  }

  init(data) {
    this.gameState = data.gameState;
  }

  async create() {
    // Initialize managers
    this.layoutManager = new LayoutManager(this.cameras.main.width, this.cameras.main.height);
    this.animationManager = new AnimationManager(this);
    this.uiManager = new UIManager(this);
    
    // Ensure camera rounds pixels for crisp rendering
    this.cameras.main.setRoundPixels(true);
    
    // Ensure all textures use proper filtering for crisp rendering
    const textures = this.textures.list;
    for (const key in textures) {
      const texture = textures[key];
      if (texture && texture.setFilter) {
        // Use LINEAR for smooth but crisp SVG rendering
        texture.setFilter(Phaser.Textures.FilterMode.LINEAR);
      }
    }
    
    // Set background
    this.add.rectangle(
      this.cameras.main.width / 2,
      this.cameras.main.height / 2,
      this.cameras.main.width,
      this.cameras.main.height,
      0x000000
    );

    // Load game state if not provided
    if (!this.gameState) {
      const { GameStorage } = await import('../../storage/GameStorage.js');
      this.gameState = GameStorage.load();
      
      if (!this.gameState) {
        // No saved game, redirect to lobby
        window.location.href = 'index.html';
        return;
      }
    }

    // Handle phase transitions
    if (this.gameState.phase === 'planning') {
      this.gameState.setTrump();
      this.gameState.phase = 'trick';
      this.saveGame();
    }

    if (this.gameState.phase === 'requisition') {
      this.gameState.nextYear();
      this.saveGame();
      
      // After nextYear(), handle transition to trick phase if needed
      if (this.gameState.phase === 'planning') {
        this.gameState.setTrump();
        this.gameState.phase = 'trick';
        this.saveGame();
      }
    }

    // Initialize input manager
    this.inputManager = new InputManager(
      this,
      this.gameState,
      (cardIndex) => this.handleCardPlay(cardIndex),
      (mapping) => this.handleAssignment(mapping)
    );
    
    // Setup assignment change callback
    this.inputManager.onAssignmentChanged = () => {
      this.checkAssignmentComplete();
    };

    // Create game objects
    this.createGameObjects();

    // Setup input handlers
    this.setupInputHandlers();

    // Render initial state
    this.renderGame();

    // Handle AI turns
    if (this.shouldPlayAI()) {
      this.time.delayedCall(500, () => this.playAISequence());
    }

    // Handle swap phase
    if (this.gameState.phase === 'swap') {
      this.handleSwapPhase();
    }
  }

  createGameObjects() {
    // Create player areas
    this.playerAreas = [];
    for (let i = 0; i < this.gameState.numPlayers; i++) {
      const pos = this.layoutManager.getPlayerPosition(i, this.gameState.numPlayers);
      const playerArea = new PlayerArea(
        this,
        pos.x,
        pos.y,
        this.gameState.players[i],
        i,
        this.layoutManager
      );
      this.playerAreas.push(playerArea);
    }

    // Create job piles
    this.jobPiles = new Map();
    SUITS.forEach((suit, index) => {
      const pos = this.layoutManager.getJobPilePosition(index);
      const jobPile = new JobPile(this, pos.x, pos.y, suit, this.gameState, this.layoutManager);
      this.jobPiles.set(suit, jobPile);
    });

    // Create trick area
    const trickCenter = this.layoutManager.getTrickAreaCenter();
    this.trickArea = new TrickArea(this, trickCenter.x, trickCenter.y, this.gameState, this.layoutManager);

    // Create gulag area
    const gulagPos = this.layoutManager.getGulagAreaPosition();
    this.gulagArea = new GulagArea(this, gulagPos.x, gulagPos.y, this.gameState, this.layoutManager);

    // Create UI controls
    this.createUIControls();
  }

  createUIControls() {
    const width = this.cameras.main.width;
    const height = this.cameras.main.height;
    const baseSize = Math.min(width, height);
    
    // Responsive sizes
    const topMargin = height * 0.03;
    const leftMargin = width * 0.015;
    const buttonWidth = Math.max(60, Math.min(100, width * 0.08));
    const buttonHeight = Math.max(24, Math.min(40, height * 0.04));
    const buttonSpacing = height * 0.05;
    const yearFontSize = `${Math.max(18, Math.min(30, baseSize * 0.024))}px`;
    const trumpFontSize = `${Math.max(14, Math.min(22, baseSize * 0.018))}px`;
    const buttonFontSize = `${Math.max(11, Math.min(18, baseSize * 0.014))}px`;
    
    // Year and trump display - positioned at top but with some margin
    const yearText = this.add.text(leftMargin, topMargin, `Year ${this.gameState.year}`, {
      fontSize: yearFontSize,
      fill: '#c9a961',
      fontStyle: 'bold'
    });
    this.yearText = yearText;

    if (this.gameState.trump) {
      const trumpText = this.add.text(leftMargin, topMargin + height * 0.035, `Trump: ${this.gameState.trump}`, {
        fontSize: trumpFontSize,
        fill: '#c9a961'
      });
      this.trumpText = trumpText;
    }

    // Rules button - positioned at top with margin
    const rulesButton = this.add.rectangle(width - width * 0.08, topMargin, buttonWidth, buttonHeight, 0xc9a961);
    rulesButton.setInteractive({ useHandCursor: true });
    const rulesText = this.add.text(width - width * 0.08, topMargin, 'Rules', {
      fontSize: buttonFontSize,
      fill: '#000000',
      fontStyle: 'bold'
    });
    rulesText.setOrigin(0.5, 0.5);

    rulesButton.on('pointerdown', () => {
      this.uiManager.showModal('Game Rules', 'Rules will be displayed here', [
        { label: 'Close', primary: true, onClick: () => {} }
      ]);
    });

    // New game button
    const newGameButton = this.add.rectangle(width - width * 0.08, topMargin + buttonSpacing, buttonWidth, buttonHeight, 0x666666);
    newGameButton.setInteractive({ useHandCursor: true });
    const newGameText = this.add.text(width - width * 0.08, topMargin + buttonSpacing, 'New Game', {
      fontSize: buttonFontSize,
      fill: '#ffffff',
      fontStyle: 'bold'
    });
    newGameText.setOrigin(0.5, 0.5);

    newGameButton.on('pointerdown', () => {
      if (window.GameStorage) {
        window.GameStorage.clear();
      }
      window.location.href = 'index.html';
    });
  }

  setupInputHandlers() {
    // Setup will be done per phase
    this.updateInputHandlers();
  }

  updateInputHandlers() {
    // Clear existing handlers
    this.inputManager.clear();

    if (this.gameState.phase === 'trick') {
      // Enable card playing for human player (drag only)
      const humanPlayerArea = this.playerAreas[0];
      if (humanPlayerArea && humanPlayerArea.player.isHuman) {
        const cardSprites = humanPlayerArea.getCardSprites();
        cardSprites.forEach((cardSprite, index) => {
          this.inputManager.enableCardDrag(cardSprite, index, 0);
        });

        // Register trick area as drop zone
        this.inputManager.registerDropZone('trick', this.trickArea, (draggedCard, cardSprite) => {
          if (!draggedCard || draggedCard.index === undefined) {
            console.warn('Drop callback called with invalid draggedCard:', draggedCard);
            return;
          }
          this.handleCardPlay(draggedCard.index);
        });

        // Update card highlights based on validity
        this.updateCardHighlights();
      }
    } else if (this.gameState.phase === 'assignment') {
      // Setup assignment phase
      if (this.gameState.players[this.gameState.lastWinner]?.isHuman) {
        const trickCards = this.trickArea.getTrickCardSprites();
        this.inputManager.setupAssignmentPhase(trickCards, this.jobPiles);

        // Add glow effect to visible trick cards to indicate they should be dragged
        trickCards.forEach(cardSprite => {
          if (cardSprite.visible) {
            cardSprite.setValidHighlight(true);
          }
        });

        // Calculate valid jobs from the trick (suits represented in the trick)
        const validJobs = Array.from(new Set(
          this.gameState.lastTrick.map(([_, card]) => card.suit)
        ));

        // Create and show drop zones on valid job piles for the entire assignment phase
        this.jobPiles.forEach((pile, suit) => {
          if (validJobs.includes(suit)) {
            pile.createDropZone();
            pile.showDropZone(); // Show them immediately for the assignment phase
          }
        });

        // Setup assignment preview callback
        this.inputManager.onAssignmentChanged = () => {
          // Update preview on all job piles
          this.jobPiles.forEach((pile, suit) => {
            pile.setAssignmentPreview(this.inputManager.assignmentMap, this.gameState.lastTrick);
          });
          this.checkAssignmentComplete();
        };

        // Show complete assignment button when all cards assigned
        this.checkAssignmentComplete();
      }
    } else if (this.gameState.phase === 'plot_selection') {
      // Setup plot selection phase
      this.handlePlotSelectionPhase();
    }
  }

  renderGame() {
    // Update player areas
    this.playerAreas.forEach(area => {
      area.renderHand();
      area.renderPlot();
      area.updatePlayerInfo();
    });

    // Update job piles
    this.jobPiles.forEach(pile => {
      pile.updateWorkHours();
      pile.updateJobDisplay();
      pile.updateAssignedCards(); // Refresh assigned cards display
    });

    // Update trick area
    const trickToShow = this.gameState.phase === 'assignment' 
      ? this.gameState.lastTrick 
      : this.gameState.currentTrick;
    this.trickArea.displayTrick(trickToShow, this.gameState.players);

    // Update gulag
    this.gulagArea.updateGulagDisplay();

    // Update UI
    if (this.yearText) {
      const baseSize = Math.min(this.cameras.main.width, this.cameras.main.height);
      const yearFontSize = `${Math.max(18, Math.min(30, baseSize * 0.024))}px`;
      this.yearText.setText(`Year ${this.gameState.year}`);
      this.yearText.setStyle({ fontSize: yearFontSize });
    }

    // Reattach input handlers after sprites are recreated
    // (renderHand destroys and recreates card sprites, so drag handlers are lost)
    if (this.gameState.phase === 'trick' || this.gameState.phase === 'assignment') {
      this.updateInputHandlers();
    } else {
      // Update card highlights if not in a phase that handles it in updateInputHandlers
      this.updateCardHighlights();
    }
  }

  updateCardHighlights() {
    // Only highlight if it's the human player's turn
    if (this.gameState.phase !== 'trick' || this.getNextPlayer() !== 0) {
      // Clear all highlights if it's not the player's turn
      const humanPlayerArea = this.playerAreas[0];
      if (humanPlayerArea && humanPlayerArea.player.isHuman) {
        const cardSprites = humanPlayerArea.getCardSprites();
        cardSprites.forEach(cardSprite => {
          cardSprite.setValidHighlight(false);
        });
      }
      return;
    }

    const humanPlayerArea = this.playerAreas[0];
    if (humanPlayerArea && humanPlayerArea.player.isHuman) {
      const cardSprites = humanPlayerArea.getCardSprites();
      cardSprites.forEach((cardSprite, index) => {
        const isValid = this.inputManager.isValidPlay(index);
        cardSprite.setValidHighlight(isValid);
      });
    }
  }

  handleCardPlay(cardIndex) {
    // Validate the play
    if (!this.inputManager.isValidPlay(cardIndex)) {
      // Check if it's because we need to follow suit
      if (this.gameState.currentTrick && this.gameState.currentTrick.length > 0) {
        this.uiManager.showNotification('Please follow suit', 'error');
      } else {
        // This shouldn't happen, but provide a generic error
        this.uiManager.showNotification('Invalid card play', 'error');
      }
      return;
    }

    // Play card
    this.gameState.playCard(0, cardIndex);
    this.saveGame();
    this.renderGame();

    // Check for phase transitions
    if (this.gameState.phase === 'requisition') {
      this.gameState.nextYear();
      this.saveGame();
      this.renderGame();
      
      if (this.gameState.phase === 'swap') {
        this.handleSwapPhase();
        return;
      } else if (this.gameState.phase === 'planning') {
        this.gameState.setTrump();
        this.gameState.phase = 'trick';
        this.saveGame();
        this.renderGame();
      }
    }

    // Check for assignment phase
    if (this.gameState.phase === 'assignment') {
      if (!this.gameState.players[this.gameState.lastWinner]?.isHuman) {
        // AI auto-assigns
        const ai = new RandomAI(this.gameState.lastWinner);
        const mapping = ai.assignTrick(this.gameState);
        this.gameState.applyAssignments(mapping);
        this.saveGame();
        this.renderGame();
        
        // Check if year is over (plot selection or requisition)
        if (this.gameState.phase === 'plot_selection') {
          this.handlePlotSelectionPhase();
          return;
        } else if (this.gameState.phase === 'requisition') {
          this.gameState.nextYear();
          this.saveGame();
          this.renderGame();
          
          if (this.gameState.phase === 'swap') {
            this.handleSwapPhase();
            return;
          } else if (this.gameState.phase === 'planning') {
            this.gameState.setTrump();
            this.gameState.phase = 'trick';
            this.saveGame();
            this.renderGame();
            
            // Check if AI should play after transitioning to trick phase
            if (this.shouldPlayAI()) {
              this.time.delayedCall(500, () => this.playAISequence());
              return;
            } else {
              this.updateInputHandlers();
              return;
            }
          }
        }
      } else {
        // Human assignment - setup input
        this.updateInputHandlers();
      }
    }

    // Check for game over
    if (this.gameState.phase === 'game_over') {
      this.scene.start('GameOverScene', { gameState: this.gameState });
      return;
    }

    // Continue with AI
    if (this.shouldPlayAI()) {
      this.time.delayedCall(500, () => this.playAISequence());
    } else {
      this.updateInputHandlers();
    }
  }

  async playAISequence() {
    while (this.shouldPlayAI()) {
      const playerId = this.getNextPlayer();
      const ai = new RandomAI(playerId);
      const cardIdx = ai.play(this.gameState);
      const card = this.gameState.players[playerId].hand[cardIdx];

      // Animate AI card play
      const playerArea = this.playerAreas[playerId];
      const cardSprites = playerArea.getCardSprites();
      if (cardSprites[cardIdx]) {
        await this.animateAICardPlay(cardSprites[cardIdx], playerId);
      }

      // Play card
      this.gameState.playCard(playerId, cardIdx);
      this.saveGame();
      this.renderGame();

      await this.delay(300);
    }

    // Check for assignment phase
    if (this.gameState.phase === 'assignment' && !this.gameState.players[this.gameState.lastWinner]?.isHuman) {
      const ai = new RandomAI(this.gameState.lastWinner);
      const mapping = ai.assignTrick(this.gameState);
      this.gameState.applyAssignments(mapping);
      this.saveGame();
      this.renderGame();
      
      // Check if year is over (plot selection or requisition)
      if (this.gameState.phase === 'plot_selection') {
        this.handlePlotSelectionPhase();
        return;
      } else if (this.gameState.phase === 'requisition') {
        this.gameState.nextYear();
        this.saveGame();
        this.renderGame();
        
        if (this.gameState.phase === 'swap') {
          this.handleSwapPhase();
          return;
        } else if (this.gameState.phase === 'planning') {
          this.gameState.setTrump();
          this.gameState.phase = 'trick';
          this.saveGame();
          this.renderGame();
          
          // Check if AI should play after transitioning to trick phase
          if (this.shouldPlayAI()) {
            this.time.delayedCall(500, () => this.playAISequence());
            return;
          } else {
            this.updateInputHandlers();
            return;
          }
        }
      }
    }

    // Check for game over
    if (this.gameState.phase === 'game_over') {
      this.scene.start('GameOverScene', { gameState: this.gameState });
      return;
    }

    if (this.shouldPlayAI()) {
      this.time.delayedCall(500, () => this.playAISequence());
    } else {
      this.updateInputHandlers();
    }
  }

  async animateAICardPlay(cardSprite, playerId) {
    const trickCenter = this.layoutManager.getTrickAreaCenter();
    return new Promise(resolve => {
      this.animationManager.moveCard(
        cardSprite,
        trickCenter.x,
        trickCenter.y,
        0,
        300,
        resolve
      );
    });
  }

  handleAssignment(mapping) {
    // Remove drop zones
    this.jobPiles.forEach(pile => {
      pile.removeDropZone();
      pile.clearAssignmentPreview(); // Clear preview, show actual assignments
    });

    // Remove glow from trick cards
    const trickCards = this.trickArea.getTrickCardSprites();
    trickCards.forEach(cardSprite => {
      cardSprite.setValidHighlight(false);
    });

    this.gameState.applyAssignments(mapping);
    this.saveGame();
    this.renderGame();

    // Check for phase transitions
    if (this.gameState.phase === 'requisition') {
      this.gameState.nextYear();
      this.saveGame();
      this.renderGame();
      
      if (this.gameState.phase === 'swap') {
        this.handleSwapPhase();
        return;
      } else if (this.gameState.phase === 'planning') {
        this.gameState.setTrump();
        this.gameState.phase = 'trick';
        this.saveGame();
        this.renderGame();
        
        // Check if AI should play after transitioning to trick phase
        if (this.shouldPlayAI()) {
          this.time.delayedCall(500, () => this.playAISequence());
          return;
        } else {
          this.updateInputHandlers();
          return;
        }
      }
    }

    // Check for game over
    if (this.gameState.phase === 'game_over') {
      this.scene.start('GameOverScene', { gameState: this.gameState });
      return;
    }

    if (this.shouldPlayAI()) {
      this.time.delayedCall(500, () => this.playAISequence());
    } else {
      this.updateInputHandlers();
    }
  }

  checkAssignmentComplete() {
    const width = this.cameras.main.width;
    const height = this.cameras.main.height;
    
    if (this.inputManager.areAllCardsAssigned()) {
      // Show complete button
      if (!this.completeAssignmentButton) {
        const button = this.add.rectangle(width / 2, height - 50, 200, 40, 0xc9a961);
        button.setInteractive({ useHandCursor: true });
        const buttonText = this.add.text(width / 2, height - 50, 'Complete Assignment', {
          fontSize: '18px',
          fill: '#000000',
          fontStyle: 'bold'
        });
        buttonText.setOrigin(0.5, 0.5);

        button.on('pointerdown', () => {
          const mapping = this.inputManager.getAssignmentMapping(this.gameState);
          this.handleAssignment(mapping);
          if (this.completeAssignmentButton) {
            this.completeAssignmentButton.destroy();
            this.completeAssignmentButtonText.destroy();
            this.completeAssignmentButton = null;
            this.completeAssignmentButtonText = null;
          }
        });

        button.on('pointerover', () => {
          button.setFillStyle(0xd4b870);
        });

        button.on('pointerout', () => {
          button.setFillStyle(0xc9a961);
        });

        this.completeAssignmentButton = button;
        this.completeAssignmentButtonText = buttonText;
      }
    } else {
      // Hide button if not all assigned
      if (this.completeAssignmentButton) {
        this.completeAssignmentButton.destroy();
        this.completeAssignmentButtonText.destroy();
        this.completeAssignmentButton = null;
        this.completeAssignmentButtonText = null;
      }
    }
  }

  handleSwapPhase() {
    if (this.gameState.currentSwapPlayer === null) return;
    
    if (this.gameState.currentSwapPlayer !== 0 || 
        !this.gameState.players[this.gameState.currentSwapPlayer].isHuman) {
      // AI swap
      const player = this.gameState.players[this.gameState.currentSwapPlayer];
      if (player.plot.hidden.length > 0 && player.hand.length > 0) {
        const ai = new RandomAI(this.gameState.currentSwapPlayer);
        const swap = ai.swap(this.gameState);
        if (swap) {
          this.gameState.swapCard(this.gameState.currentSwapPlayer, swap.hiddenIndex, swap.handIndex);
        }
      }
      this.gameState.completeSwap(this.gameState.currentSwapPlayer);
      this.saveGame();
      this.renderGame();
      
      if (this.gameState.phase === 'swap') {
        this.time.delayedCall(500, () => this.handleSwapPhase());
      } else if (this.gameState.phase === 'planning') {
        this.gameState.setTrump();
        this.gameState.phase = 'trick';
        this.saveGame();
        this.renderGame();
        
        // Check if AI should play after transitioning to trick phase
        if (this.shouldPlayAI()) {
          this.time.delayedCall(500, () => this.playAISequence());
        } else {
          this.updateInputHandlers();
        }
      }
    } else {
      // Human swap - show modal
      this.showSwapModal();
    }
  }

  showSwapModal() {
    const player = this.gameState.players[0];
    if (player.plot.hidden.length === 0 || player.hand.length === 0) {
      this.gameState.completeSwap(0);
      this.saveGame();
      this.renderGame();
      return;
    }

    // Create swap UI
    // This is simplified - full implementation would show card selection
    this.uiManager.showModal(
      'Swap Cards',
      'Select one hidden card and one hand card to swap',
      [
        { label: 'Skip', onClick: () => {
          this.gameState.completeSwap(0);
          this.saveGame();
          this.renderGame();
        }},
        { label: 'Swap', primary: true, onClick: () => {
          // Swap logic would go here
          this.gameState.completeSwap(0);
          this.saveGame();
          this.renderGame();
        }}
      ]
    );
  }

  handlePlotSelectionPhase() {
    if (this.gameState.currentPlotSelectionPlayer === null) {
      // All players have selected - transition to requisition
      this.gameState.phase = 'requisition';
      this.gameState.performRequisition();
      this.saveGame();
      this.renderGame();
      
      // After requisition, move to next year
      this.gameState.nextYear();
      this.saveGame();
      this.renderGame();
      
      if (this.gameState.phase === 'swap') {
        this.handleSwapPhase();
        return;
      } else if (this.gameState.phase === 'planning') {
        this.gameState.setTrump();
        this.gameState.phase = 'trick';
        this.saveGame();
        this.renderGame();
        
        // Check if AI should play after transitioning to trick phase
        if (this.shouldPlayAI()) {
          this.time.delayedCall(500, () => this.playAISequence());
        } else {
          this.updateInputHandlers();
        }
      }
      return;
    }
    
    const currentPlayer = this.gameState.players[this.gameState.currentPlotSelectionPlayer];
    
    if (!currentPlayer.isHuman) {
      // AI selects a card
      if (currentPlayer.hand.length > 0) {
        const ai = new RandomAI(this.gameState.currentPlotSelectionPlayer);
        const cardIdx = ai.selectPlotCard(this.gameState);
        if (cardIdx !== null) {
          this.gameState.selectPlotCard(this.gameState.currentPlotSelectionPlayer, cardIdx);
        }
      }
      
      // Move to next player
      this.gameState.currentPlotSelectionPlayer++;
      if (this.gameState.currentPlotSelectionPlayer >= this.gameState.numPlayers) {
        this.gameState.currentPlotSelectionPlayer = null;
      }
      
      this.saveGame();
      this.renderGame();
      
      // Continue with next player
      this.time.delayedCall(500, () => this.handlePlotSelectionPhase());
    } else {
      // Human player - check if only one card left
      if (currentPlayer.hand.length === 1) {
        // Only one card left - automatically select it
        this.gameState.selectPlotCard(this.gameState.currentPlotSelectionPlayer, 0);
        this.gameState.currentPlotSelectionPlayer++;
        if (this.gameState.currentPlotSelectionPlayer >= this.gameState.numPlayers) {
          this.gameState.currentPlotSelectionPlayer = null;
        }
        
        this.saveGame();
        this.renderGame();
        this.handlePlotSelectionPhase();
      } else {
        // Multiple cards - enable card selection
        const humanPlayerArea = this.playerAreas[this.gameState.currentPlotSelectionPlayer];
        if (humanPlayerArea) {
          const cardSprites = humanPlayerArea.getCardSprites();
          cardSprites.forEach((cardSprite, index) => {
            cardSprite.setInteractive({ useHandCursor: true });
            cardSprite.off('pointerdown');
            cardSprite.on('pointerdown', () => {
              // Remove all click handlers to prevent multiple selections
              cardSprites.forEach(sprite => {
                sprite.off('pointerdown');
                sprite.disableInteractive();
              });
              
              this.gameState.selectPlotCard(this.gameState.currentPlotSelectionPlayer, index);
              this.gameState.currentPlotSelectionPlayer++;
              if (this.gameState.currentPlotSelectionPlayer >= this.gameState.numPlayers) {
                this.gameState.currentPlotSelectionPlayer = null;
              }
              // Clean up instruction text
              if (this.plotSelectionText) {
                this.plotSelectionText.destroy();
                this.plotSelectionText = null;
              }
              
              this.saveGame();
              this.renderGame();
              this.handlePlotSelectionPhase();
            });
          });
          
          // Show instruction text
          if (!this.plotSelectionText) {
            const width = this.cameras.main.width;
            const height = this.cameras.main.height;
            this.plotSelectionText = this.add.text(width / 2, height - 100, 
              'Select a card to keep for your Personal Plot', {
              fontSize: '20px',
              fill: '#ffffff',
              fontStyle: 'bold',
              backgroundColor: '#000000',
              padding: { x: 10, y: 5 }
            });
            this.plotSelectionText.setOrigin(0.5, 0.5);
          }
        }
      }
    }
  }

  shouldPlayAI() {
    if (this.gameState.phase !== 'trick') return false;
    if (this.gameState.currentTrick.length >= this.gameState.numPlayers) return false;
    const nextPlayer = this.getNextPlayer();
    return nextPlayer !== 0;
  }

  getNextPlayer() {
    return (this.gameState.lead + this.gameState.currentTrick.length) % this.gameState.numPlayers;
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  saveGame() {
    if (window.GameStorage) {
      window.GameStorage.save(this.gameState);
    }
  }

  resize() {
    // Handle window resize
    this.layoutManager.updateDimensions(this.cameras.main.width, this.cameras.main.height);
    this.renderGame();
  }
}
