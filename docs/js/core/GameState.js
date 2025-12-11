// GameState - main game orchestrator (refactored to use manager classes)

import { Card } from './Card.js';
import { Player } from './Player.js';
import { SUITS, VALUES, THRESHOLD, MAX_YEARS, PLAYER_NAMES } from './constants.js';
import { DeckManager } from './DeckManager.js';
import { TrickPhaseManager } from './TrickPhaseManager.js';
import { RequisitionManager } from './RequisitionManager.js';
import { YearManager } from './YearManager.js';

export class GameState {
  static THRESHOLD = THRESHOLD;
  static MAX_YEARS = MAX_YEARS;

  constructor(numPlayers = 4, gameVariants = {}) {
    // Initialize players
    const names = [...PLAYER_NAMES];
    this.numPlayers = numPlayers;
    this.players = Array.from({ length: numPlayers }, (_, i) => {
      if (i === 0) {
        return new Player(0, true, 'игрок');
      } else {
        const randomIndex = Math.floor(Math.random() * names.length);
        const name = names.splice(randomIndex, 1)[0];
        return new Player(i, false, name);
      }
    });

    // Initialize game variants
    this.gameVariants = {
      deckType: '36',
      northernStyle: false,
      nomenclature: true,
      miceVariant: false,
      ordenNachalniku: true,
      medalsCount: false,
      accumulateUnclaimedJobs: true,
      allowSwap: false,
      ...gameVariants
    };

    // Initialize managers
    this.deckManager = new DeckManager(this.gameVariants);
    this.trickManager = new TrickPhaseManager(this.gameVariants);
    this.requisitionManager = new RequisitionManager(this.gameVariants);
    this.yearManager = new YearManager(this.gameVariants);

    // Initialize game state
    this.dealer = Math.floor(Math.random() * numPlayers);
    this.lead = null; // Will be set when first trick starts (dealer + 1)
    this.year = 1;
    this.trump = null;
    this.jobPiles = {};
    this.revealedJobs = {};
    this.claimedJobs = new Set();
    this.accumulatedJobCards = {};
    this.workHours = {};
    this.jobBuckets = {};

    for (const suit of SUITS) {
      this.accumulatedJobCards[suit] = [];
      this.workHours[suit] = 0;
      this.jobBuckets[suit] = [];
    }

    this.currentTrick = [];
    this.lastTrick = [];
    this.lastWinner = null;
    this.trickHistory = [];
    this.requisitionLog = {};
    this.phase = 'planning';
    this.trickCount = 0;
    this.exiled = {};
    this.currentSwapPlayer = null;
    this.currentPlotSelectionPlayer = null;
    this.workersDeck = [];
    this.isFamine = false;
    this.startingHandSize = 5; // Default hand size (normal year)

    // Initialize game
    this.jobPiles = this.deckManager.prepareJobPiles();
    
    // Use consolidated year setup method from YearManager
    this.yearManager.setupYear(this, this.deckManager);
  }

  setTrump(suit = null) {
    // During famine year, there is no trump
    if (this.isFamine) {
      this.trump = null;
      return;
    }
    
    if (suit) {
      this.trump = suit;
    } else {
      const availableSuits = SUITS.filter(s => this.jobPiles[s].length > 0);
      if (availableSuits.length > 0) {
        const randomIndex = Math.floor(Math.random() * availableSuits.length);
        this.trump = availableSuits[randomIndex];
      }
    }
  }

  swapCard(playerId, hiddenCardIndex, handCardIndex) {
    const player = this.players[playerId];

    if (hiddenCardIndex < 0 || handCardIndex < 0) {
      return;
    }

    if (hiddenCardIndex >= player.plot.hidden.length ||
        handCardIndex >= player.hand.length) {
      throw new Error('Invalid card indices for swap');
    }

    const temp = player.plot.hidden[hiddenCardIndex];
    player.plot.hidden[hiddenCardIndex] = player.hand[handCardIndex];
    player.hand[handCardIndex] = temp;
  }

  reorderHand(playerId, fromIndex, toIndex) {
    const player = this.players[playerId];

    if (fromIndex < 0 || fromIndex >= player.hand.length ||
        toIndex < 0 || toIndex >= player.hand.length) {
      throw new Error('Invalid indices for reorder');
    }

    const [card] = player.hand.splice(fromIndex, 1);
    player.hand.splice(toIndex, 0, card);
  }

  completeSwap(playerId) {
    if (this.currentSwapPlayer === playerId) {
      this.currentSwapPlayer++;

      if (this.currentSwapPlayer >= this.numPlayers) {
        // Trump should already be set by the dealer before swap phase
        // Only set trump if it's not already set (shouldn't happen, but safety check)
        if (!this.trump && !this.isFamine) {
          this.setTrump();
        }
        this.phase = 'planning';
        this.currentSwapPlayer = null;
      }
    }
  }

  playCard(pid, idx) {
    return this.trickManager.playCard(this, pid, idx);
  }

  applyAssignments(mapping) {
    this.trickManager.applyAssignments(this, mapping);
  }

  selectPlotCard(pid, cardIdx) {
    const player = this.players[pid];
    if (cardIdx < 0 || cardIdx >= player.hand.length) {
      throw new Error(`Invalid card index ${cardIdx} for player ${pid}`);
    }
    const card = player.hand.splice(cardIdx, 1)[0];
    player.plot.hidden.push(card);
  }

  performRequisition() {
    this.requisitionManager.performRequisition(this);
  }

  nextYear() {
    this.yearManager.nextYear(this, this.deckManager);
  }

  /**
   * Handles the planning phase: trump selection and card swapping.
   * Sets the appropriate phase based on whether the dealer is human/AI and if swap is enabled.
   * Can be called after trump is selected to continue the flow.
   */
  planningPhase() {
    // Handle trump selection - dealer always picks trump (if not famine year and not already set)
    if (!this.isFamine && !this.trump) {
      const dealerPlayer = this.players[this.dealer];
      if (dealerPlayer.isHuman) {
        // Human dealer: set phase to trump_selection so they can pick
        this.phase = 'trump_selection';
        return; // Wait for human to select trump
      } else {
        // AI dealer: automatically pick trump
        this.setTrump();
      }
    } else if (this.isFamine) {
      // Famine year: no trump
      this.trump = null;
    }

    // After trump selection, handle swap phase if enabled
    if (this.gameVariants.allowSwap) {
      this.phase = 'swap';
      this.currentSwapPlayer = 0;
    } else {
      // No swap variant: proceed to planning phase
      this.phase = 'planning';
    }
  }

  get scores() {
    return this.yearManager.calculateScores(this);
  }

  get finalScores() {
    return this.yearManager.calculateFinalScores(this);
  }

  toJSON() {
    return {
      numPlayers: this.numPlayers,
      players: this.players.map(p => p.toJSON()),
      dealer: this.dealer,
      lead: this.lead,
      year: this.year,
      trump: this.trump,
      jobPiles: Object.fromEntries(
        Object.entries(this.jobPiles).map(([suit, pile]) => [
          suit,
          pile.map(c => ({ suit: c.suit, value: c.value }))
        ])
      ),
      revealedJobs: Object.fromEntries(
        Object.entries(this.revealedJobs).map(([suit, job]) => [
          suit,
          Array.isArray(job)
            ? job.map(c => ({ suit: c.suit, value: c.value }))
            : { suit: job.suit, value: job.value }
        ])
      ),
      claimedJobs: Array.from(this.claimedJobs),
      accumulatedJobCards: Object.fromEntries(
        Object.entries(this.accumulatedJobCards).map(([suit, cards]) => [
          suit,
          cards.map(c => ({ suit: c.suit, value: c.value }))
        ])
      ),
      workHours: this.workHours,
      jobBuckets: Object.fromEntries(
        Object.entries(this.jobBuckets).map(([suit, bucket]) => [
          suit,
          bucket.map(c => ({ suit: c.suit, value: c.value }))
        ])
      ),
      currentTrick: this.currentTrick.map(([pid, c]) => [
        pid,
        { suit: c.suit, value: c.value }
      ]),
      lastTrick: this.lastTrick.map(([pid, c]) => [
        pid,
        { suit: c.suit, value: c.value }
      ]),
      lastWinner: this.lastWinner,
      trickHistory: this.trickHistory,
      requisitionLog: this.requisitionLog,
      phase: this.phase,
      trickCount: this.trickCount,
      exiled: this.exiled,
      gameVariants: this.gameVariants,
      currentSwapPlayer: this.currentSwapPlayer,
      currentPlotSelectionPlayer: this.currentPlotSelectionPlayer,
      workersDeck: this.workersDeck.map(c => ({ suit: c.suit, value: c.value })),
      isFamine: this.isFamine,
      startingHandSize: this.startingHandSize
    };
  }

  static fromJSON(data) {
    const game = Object.create(GameState.prototype);

    game.numPlayers = data.numPlayers;
    game.players = data.players.map(pData => Player.fromJSON(pData));
    game.dealer = data.dealer !== undefined ? data.dealer : data.lead; // Backward compatibility
    // For backward compatibility: if lead is not set, use dealer+1 for first trick, or lastWinner if available
    if (data.lead !== undefined) {
      game.lead = data.lead;
    } else if (data.lastWinner !== null && data.lastWinner !== undefined) {
      game.lead = data.lastWinner; // Subsequent tricks
    } else {
      game.lead = (game.dealer + 1) % game.numPlayers; // First trick
    }
    game.year = data.year;
    game.trump = data.trump;
    game.jobPiles = Object.fromEntries(
      Object.entries(data.jobPiles).map(([suit, pile]) => [
        suit,
        pile.map(cData => new Card(cData.suit, cData.value))
      ])
    );
    game.revealedJobs = Object.fromEntries(
      Object.entries(data.revealedJobs).map(([suit, job]) => [
        suit,
        Array.isArray(job)
          ? job.map(cData => new Card(cData.suit, cData.value))
          : new Card(job.suit, job.value)
      ])
    );
    game.claimedJobs = new Set(data.claimedJobs || []);
    game.accumulatedJobCards = Object.fromEntries(
      Object.entries(data.accumulatedJobCards || {}).map(([suit, cards]) => [
        suit,
        cards.map(cData => new Card(cData.suit, cData.value))
      ])
    );
    game.workHours = data.workHours;
    game.jobBuckets = Object.fromEntries(
      Object.entries(data.jobBuckets).map(([suit, bucket]) => [
        suit,
        bucket.map(cData => new Card(cData.suit, cData.value))
      ])
    );
    game.currentTrick = data.currentTrick.map(([pid, cData]) => [
      pid,
      new Card(cData.suit, cData.value)
    ]);
    game.lastTrick = data.lastTrick.map(([pid, cData]) => [
      pid,
      new Card(cData.suit, cData.value)
    ]);
    game.lastWinner = data.lastWinner;
    game.trickHistory = data.trickHistory;
    game.requisitionLog = data.requisitionLog;
    game.phase = data.phase;
    game.trickCount = data.trickCount;
    game.exiled = data.exiled || {};
    game.gameVariants = data.gameVariants;
    game.currentSwapPlayer = data.currentSwapPlayer;
    game.currentPlotSelectionPlayer = data.currentPlotSelectionPlayer || null;
    game.workersDeck = data.workersDeck.map(cData => new Card(cData.suit, cData.value));
    game.isFamine = data.isFamine || false;
    game.startingHandSize = data.startingHandSize || 5;

    // Reinitialize managers
    game.deckManager = new DeckManager(game.gameVariants);
    game.trickManager = new TrickPhaseManager(game.gameVariants);
    game.requisitionManager = new RequisitionManager(game.gameVariants);
    game.yearManager = new YearManager(game.gameVariants);

    return game;
  }
}
