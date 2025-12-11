// GameScene - main game scene

import { LayoutManager } from '../utils/LayoutManager.js';
import { AnimationManager } from '../managers/AnimationManager.js';
import { InputManager } from '../managers/InputManager.js';
import { UIManager } from '../managers/UIManager.js';
import { TooltipManager } from '../utils/TooltipManager.js';
import { PlayerArea } from '../objects/PlayerArea.js';
import { JobPile } from '../objects/JobPile.js';
import { TrickArea } from '../objects/TrickArea.js';
import { GulagArea } from '../objects/GulagArea.js';
import { SUITS } from '../../core/constants.js';
import { RandomAI } from '../../ai/RandomAI.js';
import { TextureLoader } from '../utils/TextureLoader.js';

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
    this.tooltipManager = new TooltipManager(this);
    
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
      
      // Check for game over first
      if (this.gameState.phase === 'game_over') {
        this.scene.switch('GameOverScene', { gameState: this.gameState });
        return;
      }
      
      // After nextYear(), call planningPhase() to handle trump selection and phase transitions
      this.gameState.planningPhase();
      this.saveGame();
      this.renderGame();
      
      // Handle the phase that planningPhase() set
      if (this.gameState.phase === 'trump_selection') {
        this.handleTrumpSelectionPhase();
      } else if (this.gameState.phase === 'swap') {
        this.handleSwapPhase();
      } else if (this.gameState.phase === 'planning') {
        // AI dealer or famine year - proceed to trick
        this.gameState.phase = 'trick';
        this.saveGame();
        this.renderGame();
        if (this.shouldPlayAI()) {
          this.time.delayedCall(500, () => this.playAISequence());
        } else {
          this.updateInputHandlers();
        }
      }
    }

    // Initialize input manager
    this.inputManager = new InputManager(
      this,
      this.gameState,
      (cardIndex) => this.handleCardPlay(cardIndex),
      (mapping) => this.handleAssignment(mapping)
    );
    
    // Initialize trump selection icons array
    this.trumpSelectionIcons = null;
    
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

    // Handle phase transitions after render
    if (this.gameState.phase === 'trump_selection') {
      this.handleTrumpSelectionPhase();
    } else if (this.gameState.phase === 'swap') {
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
    const titleFontSize = `${Math.max(14, Math.min(22, baseSize * 0.018))}px`;
    const buttonFontSize = `${Math.max(11, Math.min(18, baseSize * 0.014))}px`;
    
    // Calculate center position above job piles
    // Job piles are positioned: leftMargin (120) + suitIndex * horizontalSpacing (140)
    // For 4 jobs: positions are 120, 260, 400, 540
    // Center X = (120 + 540) / 2 = 330
    const jobPileLeftMargin = 120;
    const jobPileHorizontalSpacing = 140;
    const totalJobs = 4;
    const jobPileCenterX = jobPileLeftMargin + (totalJobs - 1) * jobPileHorizontalSpacing / 2;
    const jobPileY = this.layoutManager.centerY - 80; // Job pile Y position
    const textY = jobPileY - height * 0.20; // Position text higher above job piles to prevent overlap
    
    // Year display - centered above job piles
    const yearText = this.add.text(jobPileCenterX, textY, `года ${this.gameState.year}`, {
      fontSize: yearFontSize,
      fill: '#c9a961',
      fontStyle: 'bold'
    });
    yearText.setOrigin(0.5, 0.5); // Center horizontally
    this.tooltipManager.addAutoTooltip(yearText, 'года');
    this.yearText = yearText;

    // Title "поля" - centered above job piles
    const titleText = this.add.text(jobPileCenterX, textY + height * 0.035, 'поля', {
      fontSize: titleFontSize,
      fill: '#c9a961'
    });
    titleText.setOrigin(0.5, 0.5); // Center horizontally
    this.tooltipManager.addAutoTooltip(titleText, 'поля');
    this.titleText = titleText;

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
        // During famine year, all jobs are valid (workers may be added to any job)
        const validJobs = this.gameState.isFamine
          ? ['hearts', 'diamonds', 'clubs', 'spades'] // All suits during famine year
          : Array.from(new Set(
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
    } else if (this.gameState.phase === 'swap') {
      // Setup swap phase - enable dragging between plot and hand
      this.setupSwapPhase();
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
    if (this.gameState.phase === 'swap') {
      // During swap, ensure trick area shows trump
      // displaySwapPhase() will be called in showSwapModal(), which recreates the trick area with trump
      // But we also ensure trump is visible here
      if (this.trickArea && this.gameState.trump) {
        // Trick area should already show trump from displaySwapPhase(), but ensure it's updated
        if (!this.trickArea.trumpSuitIndicator) {
          this.trickArea.updateTrumpDisplay();
        }
      }
    } else if (this.gameState.phase === 'trump_selection') {
      // Don't update trick area during trump selection - suit icons are displayed
    } else {
      const trickToShow = this.gameState.phase === 'assignment' 
        ? this.gameState.lastTrick 
        : this.gameState.currentTrick;
      this.trickArea.displayTrick(trickToShow, this.gameState.players);
    }

    // Update gulag
    this.gulagArea.updateGulagDisplay();

    // Update UI
    if (this.yearText) {
      const baseSize = Math.min(this.cameras.main.width, this.cameras.main.height);
      const yearFontSize = `${Math.max(18, Math.min(30, baseSize * 0.024))}px`;
      this.yearText.setText(`года ${this.gameState.year}`);
      this.yearText.setStyle({ fontSize: yearFontSize });
      
      // Maintain centered position above job piles
      const jobPileLeftMargin = 120;
      const jobPileHorizontalSpacing = 140;
      const totalJobs = 4;
      const jobPileCenterX = jobPileLeftMargin + (totalJobs - 1) * jobPileHorizontalSpacing / 2;
      const jobPileY = this.layoutManager.centerY - 80;
      const textY = jobPileY - this.cameras.main.height * 0.20; // Higher to prevent overlap
      this.yearText.setPosition(jobPileCenterX, textY);
    }

    // Update title text position
    if (this.titleText) {
      const baseSize = Math.min(this.cameras.main.width, this.cameras.main.height);
      const titleFontSize = `${Math.max(14, Math.min(22, baseSize * 0.018))}px`;
      this.titleText.setStyle({ fontSize: titleFontSize });
      
      // Maintain centered position above job piles
      const jobPileLeftMargin = 120;
      const jobPileHorizontalSpacing = 140;
      const totalJobs = 4;
      const jobPileCenterX = jobPileLeftMargin + (totalJobs - 1) * jobPileHorizontalSpacing / 2;
      const jobPileY = this.layoutManager.centerY - 80;
      const textY = jobPileY - this.cameras.main.height * 0.20; // Higher to prevent overlap
      this.titleText.setPosition(jobPileCenterX, textY + this.cameras.main.height * 0.035);
    }
    

    // Reattach input handlers after sprites are recreated
    // (renderHand destroys and recreates card sprites, so drag handlers are lost)
    if (this.gameState.phase === 'trick' || this.gameState.phase === 'assignment' || this.gameState.phase === 'swap') {
      // For swap phase, use a small delay to ensure sprites are fully created
      // For trick and assignment phases, set up immediately
      if (this.gameState.phase === 'swap') {
        this.time.delayedCall(10, () => {
          this.updateInputHandlers();
        });
      } else {
        this.updateInputHandlers();
      }
    } else {
      // Update card highlights if not in a phase that handles it in updateInputHandlers
      this.updateCardHighlights();
    }

    // Clear highlights when leaving swap phase (only for phases that don't handle their own highlights)
    // Don't clear for 'trick' or 'assignment' phases as they handle highlights themselves
    if (this.gameState.phase !== 'swap' && 
        this.gameState.phase !== 'trick' && 
        this.gameState.phase !== 'assignment') {
      const humanPlayerArea = this.playerAreas[0];
      if (humanPlayerArea && humanPlayerArea.player.isHuman) {
        // Clear highlights from hand cards
        const handCardSprites = humanPlayerArea.getCardSprites();
        handCardSprites.forEach(cardSprite => {
          cardSprite.setValidHighlight(false);
        });
        // Clear highlights from plot cards
        const plotSprites = humanPlayerArea.getPlotSprites();
        plotSprites.forEach(cardSprite => {
          cardSprite.setValidHighlight(false);
        });
      }
    }
    
    // Handle phase transitions that require UI (trump selection, swap)
    // This ensures they're handled even if not explicitly checked after nextYear()
    if (this.gameState.phase === 'trump_selection') {
      const dealer = this.gameState.players[this.gameState.dealer];
      // Only show modal if dealer is human and icons aren't already showing
      if (dealer && dealer.isHuman && !this.trumpSelectionIcons) {
        // Use a small delay to ensure render is complete
        this.time.delayedCall(50, () => {
          if (this.gameState.phase === 'trump_selection' && !this.trumpSelectionIcons) {
            this.handleTrumpSelectionPhase();
          }
        });
      }
    }
  }

  updateCardHighlights() {
    // Only highlight if it's the human player's turn
    if (this.gameState.phase !== 'trick') {
      // Clear all highlights if not in trick phase
      const humanPlayerArea = this.playerAreas[0];
      if (humanPlayerArea && humanPlayerArea.player.isHuman) {
        const cardSprites = humanPlayerArea.getCardSprites();
        cardSprites.forEach(cardSprite => {
          cardSprite.setValidHighlight(false);
        });
      }
      return;
    }

    // Check if it's the human player's turn
    const nextPlayer = this.getNextPlayer();
    if (nextPlayer !== 0) {
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

    // It's the human player's turn - highlight valid cards
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
      
      // Check for game over first
      if (this.gameState.phase === 'game_over') {
        this.scene.switch('GameOverScene', { gameState: this.gameState });
        return;
      }
      
      if (this.gameState.phase === 'trump_selection') {
        this.handleTrumpSelectionPhase();
        return;
      } else if (this.gameState.phase === 'swap') {
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
          
          // Check for game over first
          if (this.gameState.phase === 'game_over') {
            this.scene.stop();
            this.scene.start('GameOverScene', { gameState: this.gameState });
            return;
          }
          
          if (this.gameState.phase === 'trump_selection') {
            this.handleTrumpSelectionPhase();
            return;
          } else if (this.gameState.phase === 'swap') {
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
      this.scene.stop();
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
        
        // Check for game over first
        if (this.gameState.phase === 'game_over') {
          this.scene.stop();
          this.scene.start('GameOverScene', { gameState: this.gameState });
          return;
        }
        
        if (this.gameState.phase === 'trump_selection') {
          this.handleTrumpSelectionPhase();
          return;
        } else if (this.gameState.phase === 'swap') {
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
      this.scene.stop();
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
      
      // Check for game over first
      if (this.gameState.phase === 'game_over') {
        this.scene.switch('GameOverScene', { gameState: this.gameState });
        return;
      }
      
      if (this.gameState.phase === 'trump_selection') {
        this.handleTrumpSelectionPhase();
        return;
      } else if (this.gameState.phase === 'swap') {
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
      this.scene.stop();
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

  handleTrumpSelectionPhase() {
    // This should only be called when phase is 'trump_selection',
    // which means planningPhase() already determined the dealer is human.
    // Just show the trump selection UI.
    this.showTrumpSelectionModal();
  }

  showTrumpSelectionModal() {
    const availableSuits = SUITS.filter(s => this.gameState.jobPiles[s].length > 0);
    
    if (availableSuits.length === 0) {
      // No suits available (shouldn't happen), proceed to next phase
      if (this.gameState.gameVariants.allowSwap) {
        this.gameState.phase = 'swap';
        this.gameState.currentSwapPlayer = 0;
        this.saveGame();
        this.renderGame();
        this.handleSwapPhase();
      } else {
        // No swap variant: proceed directly to trick phase
        this.gameState.phase = 'trick';
        this.saveGame();
        this.renderGame();
        if (this.shouldPlayAI()) {
          this.time.delayedCall(500, () => this.playAISequence());
        } else {
          this.updateInputHandlers();
        }
      }
      return;
    }

    // Clear any existing trump selection icons
    if (this.trumpSelectionIcons) {
      this.trumpSelectionIcons.forEach(icon => icon.destroy());
      this.trumpSelectionIcons = null;
    }

    const width = this.cameras.main.width;
    const height = this.cameras.main.height;
    const baseSize = Math.min(width, height);
    
    // Get trick area center position (where the suit icons will appear)
    const trickAreaPos = this.layoutManager.getTrickAreaCenter();
    const centerX = trickAreaPos.x;
    const centerY = trickAreaPos.y;
    
    // Suit icon size
    const iconSize = Math.max(60, Math.min(100, baseSize * 0.08));
    const iconSpacing = iconSize * 1.5;
    
    // Title text above icons
    const titleText = this.add.text(centerX, centerY - iconSize * 1.2, 'Select Trump Suit', {
      fontSize: `${Math.max(18, Math.min(28, baseSize * 0.022))}px`,
      fill: '#c9a961',
      fontStyle: 'bold'
    });
    titleText.setOrigin(0.5, 0.5);
    titleText.setDepth(10000);
    
    // Create suit icons in a row
    this.trumpSelectionIcons = [titleText];
    const startX = centerX - (availableSuits.length - 1) * iconSpacing / 2;
    
    availableSuits.forEach((suit, index) => {
      const iconX = startX + index * iconSpacing;
      
      // Create suit icon
      const suitIcon = this.add.image(iconX, centerY, TextureLoader.getSuitTextureKey(suit));
      suitIcon.setDisplaySize(iconSize, iconSize);
      suitIcon.setInteractive({ useHandCursor: true });
      suitIcon.setDepth(10000);
      
      // Add hover effect
      suitIcon.on('pointerover', () => {
        suitIcon.setScale(1.15);
        suitIcon.setTint(0xffffaa);
      });
      
      suitIcon.on('pointerout', () => {
        suitIcon.setScale(1.0);
        suitIcon.clearTint();
      });
      
      // Click handler
      suitIcon.on('pointerdown', () => {
        // Set trump
        this.gameState.setTrump(suit);
        
        // Clean up icons
        if (this.trumpSelectionIcons) {
          this.trumpSelectionIcons.forEach(icon => icon.destroy());
          this.trumpSelectionIcons = null;
        }
        
        // Continue with planning phase (handles swap/planning phase transition)
        this.gameState.planningPhase();
        this.saveGame();
        this.renderGame();
        
        // Handle the resulting phase
        if (this.gameState.phase === 'swap') {
          this.handleSwapPhase();
        } else if (this.gameState.phase === 'planning') {
          // No swap variant: proceed directly to trick phase
          this.gameState.phase = 'trick';
          this.saveGame();
          this.renderGame();
          this.updateInputHandlers();
          if (this.shouldPlayAI()) {
            this.time.delayedCall(500, () => this.playAISequence());
          }
        }
      });
      
      this.trumpSelectionIcons.push(suitIcon);
    });
  }

  handleSwapPhase() {
    if (this.gameState.currentSwapPlayer === null) return;
    
    // Ensure trump is displayed in trick area before swap
    if (this.trickArea && this.gameState.trump && !this.trickArea.trumpSuitIndicator) {
      this.trickArea.updateTrumpDisplay();
    }
    
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
        // Trump should already be set by the dealer before swap phase
        // Only set trump if it's not already set (shouldn't happen, but safety check)
        if (!this.gameState.trump && !this.gameState.isFamine) {
          this.gameState.setTrump();
        }
        this.gameState.phase = 'trick';
        this.saveGame();
        this.renderGame();
        
        // Update input handlers to ensure highlights are correct
        this.updateInputHandlers();
        
        // Check if AI should play after transitioning to trick phase
        if (this.shouldPlayAI()) {
          this.time.delayedCall(500, () => this.playAISequence());
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

    // Update trick area to show swap instruction and ensure trump is displayed
    if (this.trickArea) {
      this.trickArea.displaySwapPhase();
      // Ensure trump is visible (displaySwapPhase recreates the area, but double-check)
      if (this.gameState.trump && !this.trickArea.trumpSuitIndicator) {
        this.trickArea.updateTrumpDisplay();
      }
    }

    // Setup swap phase input handlers
    this.updateInputHandlers();
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
      
      // Check for game over first
      if (this.gameState.phase === 'game_over') {
        this.scene.switch('GameOverScene', { gameState: this.gameState });
        return;
      }
      
      // Call planningPhase() to handle trump selection and phase transitions
      this.gameState.planningPhase();
      this.saveGame();
      this.renderGame();
      
      // Handle the phase that planningPhase() set
      if (this.gameState.phase === 'trump_selection') {
        this.handleTrumpSelectionPhase();
        return;
      } else if (this.gameState.phase === 'swap') {
        this.handleSwapPhase();
        return;
      } else if (this.gameState.phase === 'planning') {
        // AI dealer or famine year - proceed to trick
        this.gameState.phase = 'trick';
        this.saveGame();
        this.renderGame();
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

  setupSwapPhase() {
    // Only setup for human player
    if (this.gameState.currentSwapPlayer !== 0 || 
        !this.gameState.players[0]?.isHuman) {
      return;
    }

    const player = this.gameState.players[0];
    if (player.plot.hidden.length === 0 || player.hand.length === 0) {
      // Can't swap, skip
      this.gameState.completeSwap(0);
      this.saveGame();
      this.renderGame();
      return;
    }

    const humanPlayerArea = this.playerAreas[0];
    if (!humanPlayerArea) return;

    // Clear any existing swap button
    if (this.completeSwapButton) {
      this.completeSwapButton.destroy();
      this.completeSwapButtonText.destroy();
      this.completeSwapButton = null;
      this.completeSwapButtonText = null;
    }

    // Enable dragging for hand cards and highlight them
    const handCardSprites = humanPlayerArea.getCardSprites();
    handCardSprites.forEach((cardSprite, index) => {
      // Store hand index on sprite
      cardSprite.swapHandIndex = index;
      cardSprite.swapIsHand = true;
      this.inputManager.enableCardDrag(cardSprite, index, 0);
      // Highlight to indicate it can be interacted with
      cardSprite.setValidHighlight(true);
    });

    // Enable dragging for plot hidden cards and highlight them
    const plotSprites = humanPlayerArea.getPlotSprites();
    const plotHidden = player.plot.hidden;
    
    plotSprites.forEach((cardSprite) => {
      // Check if this is a hidden card (face down) and match it to plot.hidden
      if (!cardSprite.faceUp && cardSprite.card && plotHidden) {
        // Find matching card in plot.hidden
        for (let i = 0; i < plotHidden.length; i++) {
          const hiddenCard = plotHidden[i];
          if (cardSprite.card.suit === hiddenCard.suit && 
              cardSprite.card.value === hiddenCard.value) {
            // Store the hidden index on the sprite
            cardSprite.swapHiddenIndex = i;
            cardSprite.swapIsHand = false;
            this.inputManager.enableCardDrag(cardSprite, i, 0);
            // Highlight to indicate it can be interacted with
            cardSprite.setValidHighlight(true);
            break;
          }
        }
      }
    });

    // Register each plot hidden card as a drop zone for hand cards
    plotSprites.forEach((plotCardSprite) => {
      if (!plotCardSprite.faceUp && plotCardSprite.swapHiddenIndex !== undefined) {
        const hiddenIndex = plotCardSprite.swapHiddenIndex;
        // Register this specific plot card as a drop zone
        const dropZoneKey = `plot-card-${hiddenIndex}`;
        this.inputManager.registerDropZone(dropZoneKey, plotCardSprite, (draggedCard, cardSprite) => {
          if (draggedCard && draggedCard.sprite && draggedCard.sprite.swapIsHand) {
            // Dragging from hand to this specific plot card - swap with this hidden card
            const handIndex = draggedCard.sprite.swapHandIndex;
            if (hiddenIndex < player.plot.hidden.length && handIndex < player.hand.length) {
              this.gameState.swapCard(0, hiddenIndex, handIndex);
              this.saveGame();
              this.renderGame();
              // Re-setup swap phase to restore highlights and drop zones
              this.setupSwapPhase();
            }
          }
        });
      }
    });

    // Register each hand card as a drop zone for plot cards
    handCardSprites.forEach((handCardSprite, handIndex) => {
      // Register this specific hand card as a drop zone
      const dropZoneKey = `hand-card-${handIndex}`;
      this.inputManager.registerDropZone(dropZoneKey, handCardSprite, (draggedCard, cardSprite) => {
        if (draggedCard && draggedCard.sprite && !draggedCard.sprite.swapIsHand && 
            draggedCard.sprite.swapHiddenIndex !== undefined) {
          // Dragging from plot to this specific hand card - swap with this hand card
          const hiddenIndex = draggedCard.sprite.swapHiddenIndex;
          if (hiddenIndex < player.plot.hidden.length && handIndex < player.hand.length) {
              this.gameState.swapCard(0, hiddenIndex, handIndex);
              this.saveGame();
              this.renderGame();
              // Re-setup swap phase to restore highlights and drop zones
              this.setupSwapPhase();
          }
        }
      });
    });

    // Show complete button initially (player can skip swap)
    this.showCompleteSwapButton();
  }

  showCompleteSwapButton() {
    // Remove existing button if present
    if (this.completeSwapButton) {
      this.completeSwapButton.destroy();
      this.completeSwapButtonText.destroy();
    }

    // Position button under the trick area text
    const trickCenter = this.layoutManager.getTrickAreaCenter();
    const baseSize = Math.min(this.cameras.main.width, this.cameras.main.height);
    const buttonY = trickCenter.y + baseSize * 0.08; // Position below the swap text
    
    const button = this.add.rectangle(trickCenter.x, buttonY, 200, 40, 0xc9a961);
    button.setInteractive({ useHandCursor: true });
    const buttonText = this.add.text(trickCenter.x, buttonY, 'Complete Swap', {
      fontSize: '18px',
      fill: '#000000',
      fontStyle: 'bold'
    });
    buttonText.setOrigin(0.5, 0.5);

    button.on('pointerdown', () => {
      this.gameState.completeSwap(0);
      this.saveGame();
      this.renderGame();
      
      if (this.completeSwapButton) {
        this.completeSwapButton.destroy();
        this.completeSwapButtonText.destroy();
        this.completeSwapButton = null;
        this.completeSwapButtonText = null;
      }
      
      // Continue with next player or transition to planning
      if (this.gameState.phase === 'trump_selection') {
        this.handleTrumpSelectionPhase();
      } else if (this.gameState.phase === 'swap') {
        this.time.delayedCall(500, () => this.handleSwapPhase());
      } else if (this.gameState.phase === 'planning') {
        this.gameState.setTrump();
        this.gameState.phase = 'trick';
        this.saveGame();
        this.renderGame();
        
        if (this.shouldPlayAI()) {
          this.time.delayedCall(500, () => this.playAISequence());
        } else {
          this.updateInputHandlers();
        }
      }
    });

    button.on('pointerover', () => {
      button.setFillStyle(0xd4b870);
    });

    button.on('pointerout', () => {
      button.setFillStyle(0xc9a961);
    });

    this.completeSwapButton = button;
    this.completeSwapButtonText = buttonText;
  }

  shouldPlayAI() {
    if (this.gameState.phase !== 'trick') return false;
    if (this.gameState.currentTrick.length >= this.gameState.numPlayers) return false;
    const nextPlayer = this.getNextPlayer();
    return nextPlayer !== 0;
  }

  getNextPlayer() {
    // lead is the player who leads the current trick
    // dealer is the dealer for the current year
    const trickLength = this.gameState.currentTrick.length;
    
    if (trickLength === 0) {
      // Start of new trick: lead is already set to the correct player
      return this.gameState.lead;
    } else {
      // Trick in progress: next player is (lead + number of cards played)
      return (this.gameState.lead + trickLength) % this.gameState.numPlayers;
    }
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
