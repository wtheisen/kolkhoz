/**
 * KolkhozEngine - Custom game engine replacing boardgame.io
 * Manages game state, phases, moves, and AI players.
 */

import { SUITS, PLAYER_NAMES, DEFAULT_VARIANTS, MAX_YEARS } from '../game/constants.js';
import { prepareJobPiles, revealJobs, prepareWorkersDeck, dealHands } from '../game/utils/deckUtils.js';
import {
  isValidPlay,
  resolveTrick,
  applyTrickResult,
  applyAssignments,
  generateAutoAssignment,
  isYearComplete,
} from '../game/utils/trickUtils.js';
import { performRequisition, applyExiledCards } from '../game/utils/requisitionUtils.js';
import { getWinner, transitionToNextYear, setRandomTrump } from '../game/utils/scoringUtils.js';
import { getPrioritizedMoves } from '../game/utils/aiUtils.js';
import { getRLAgent } from './RLAgent.js';

// Simple seeded random number generator
class SeededRandom {
  constructor(seed = Date.now()) {
    this.seed = seed;
  }

  Number() {
    this.seed = (this.seed * 1103515245 + 12345) & 0x7fffffff;
    return this.seed / 0x7fffffff;
  }

  Shuffle(array) {
    const result = [...array];
    for (let i = result.length - 1; i > 0; i--) {
      const j = Math.floor(this.Number() * (i + 1));
      [result[i], result[j]] = [result[j], result[i]];
    }
    return result;
  }
}

// Initialize a player
function createPlayer(idx, isHuman, name) {
  return {
    idx,
    isHuman,
    name,
    hand: [],
    plot: {
      revealed: [],
      hidden: [],
      medals: 0,
      stacks: [],
    },
    brigadeLeader: false,
    hasWonTrickThisYear: false,
    medals: 0,
  };
}

export class KolkhozEngine {
  constructor(options = {}) {
    this.options = options;
    this.random = new SeededRandom(options.seed);
    this.listeners = {};
    this.state = null;
    this.restored = false;
    this.isProcessing = false;

    // Animation handling
    this.animationResolver = null;
    this.animationQueue = [];

    // RL Agent for AI decisions (optional)
    this.rlAgent = options.useRLAgent ? getRLAgent() : null;

    // Initialize or restore the game
    if (options.savedSnapshot?.state) {
      this.state = options.savedSnapshot.state;
      if (typeof options.savedSnapshot.randomSeed === 'number') {
        this.random.seed = options.savedSnapshot.randomSeed;
      }
      this.restored = true;
    } else {
      this._setup();
    }
  }

  // ─────────────────────────────────────────────────────────
  // SETUP
  // ─────────────────────────────────────────────────────────

  _setup() {
    const variants = { ...DEFAULT_VARIANTS, ...(this.options.variants || {}) };
    const numPlayers = 4;

    // Create players
    const availableNames = [...PLAYER_NAMES];
    const players = [];
    // trainingPlayer: index of player controlled by training loop (not human, not auto-AI)
    const trainingPlayer = this.options.trainingPlayer;

    for (let i = 0; i < numPlayers; i++) {
      if (i === 0 && trainingPlayer === undefined) {
        // Normal mode: player 0 is human
        players.push(createPlayer(0, true, 'Игрок'));
      } else if (i === trainingPlayer) {
        // Training mode: training player is not human but controlled externally
        players.push(createPlayer(i, false, 'TrainingAgent'));
      } else {
        const nameIndex = Math.floor(this.random.Number() * availableNames.length);
        const name = availableNames.splice(nameIndex, 1)[0];
        players.push(createPlayer(i, false, name));
      }
    }

    // Initialize game state
    this.state = {
      numPlayers,
      players,
      lead: Math.floor(this.random.Number() * numPlayers),
      year: 1,
      trump: null,
      jobPiles: prepareJobPiles(variants, this.random),
      revealedJobs: {},
      claimedJobs: [],
      accumulatedJobCards: {},
      workHours: {},
      jobBuckets: {},
      currentTrick: [],
      lastTrick: [],
      lastWinner: null,
      trickHistory: [],
      trickCount: 0,
      exiled: {},
      workersDeck: [],
      isFamine: false,
      variants,
      pendingAssignments: {},
      needsManualAssignment: false,
      pendingAIAssignments: null,
      trumpSelector: Math.floor(this.random.Number() * numPlayers),
      phase: 'planning',
      currentPlayer: 0,
      gameover: null,
    };

    // Initialize per-suit state
    for (const suit of SUITS) {
      this.state.accumulatedJobCards[suit] = [];
      this.state.workHours[suit] = 0;
      this.state.jobBuckets[suit] = [];
    }

    // Reveal jobs for year 1
    const { jobs } = revealJobs(this.state.jobPiles, this.state.accumulatedJobCards, variants);
    this.state.revealedJobs = jobs;
    this.state.isFamine = (this.state.year === MAX_YEARS);

    // Initialize drunkard replacements
    this.state.drunkardReplacements = [];

    // Prepare deck and deal hands
    this.state.workersDeck = prepareWorkersDeck(
      this.state.players,
      this.state.jobBuckets,
      this.state.exiled,
      variants,
      this.random,
      this.state.drunkardReplacements
    );
    dealHands(this.state.players, this.state.workersDeck, this.state.isFamine);

    // Set initial current player for planning phase
    this.state.currentPlayer = this.state.trumpSelector;
  }

  // ─────────────────────────────────────────────────────────
  // EVENT SYSTEM
  // ─────────────────────────────────────────────────────────

  on(event, callback) {
    if (!this.listeners[event]) {
      this.listeners[event] = [];
    }
    this.listeners[event].push(callback);
    return () => {
      this.listeners[event] = this.listeners[event].filter(cb => cb !== callback);
    };
  }

  emit(event, data) {
    if (this.listeners[event]) {
      for (const callback of this.listeners[event]) {
        callback(data);
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────

  getState() {
    return this.state;
  }

  getSnapshot() {
    return {
      state: this.state,
      randomSeed: this.random.seed,
    };
  }

  async start() {
    if (!this.options.headless) {
      console.log('[Engine] start() called, trumpSelector:', this.state.trumpSelector, 'currentPlayer:', this.state.currentPlayer);
    }
    // Restored snapshots already include phase setup mutations.
    if (!this.restored) {
      this._runPhaseOnBegin();
    }
    if (!this.options.headless) {
      console.log('[Engine] After onBegin, currentPlayer:', this.state.currentPlayer, 'phase:', this.state.phase);
    }
    this.emit('stateChange', this.state);

    // Process AI turns if needed
    await this._processAI();
  }

  async dispatch(action) {
    if (!this.options.headless) {
      console.log('[Engine] dispatch called:', action.type, 'playerIdx:', action.playerIdx);
    }
    if (this.isProcessing) {
      if (!this.options.headless) console.warn('[Engine] Already processing, ignoring');
      return;
    }

    this.isProcessing = true;
    try {
      await this._processAction(action);
      if (!this.options.headless) console.log('[Engine] Action processed, now processing AI...');
      // Process AI turns after human action
      await this._processAI();
    } finally {
      this.isProcessing = false;
      if (!this.options.headless) console.log('[Engine] dispatch complete');
    }
  }

  /**
   * Signal that an animation has completed.
   */
  completeAnimation() {
    if (this.animationResolver) {
      this.animationResolver();
      this.animationResolver = null;
    }
  }

  isGameOver() {
    return this.state.gameover !== null;
  }

  getResult() {
    return this.state.gameover;
  }

  // ─────────────────────────────────────────────────────────
  // MOVE HANDLERS
  // ─────────────────────────────────────────────────────────

  _handleSetTrump(playerIdx, suit) {
    if (this.state.phase !== 'planning') return false;
    if (playerIdx !== this.state.currentPlayer) return false;

    if (suit && SUITS.includes(suit)) {
      this.state.trump = suit;
    } else {
      setRandomTrump(this.state, this.random);
    }
    return true;
  }

  _handlePlayCard(playerIdx, cardIndex) {
    if (this.state.phase !== 'trick') return { success: false };
    if (playerIdx !== this.state.currentPlayer) return { success: false };
    if (!isValidPlay(this.state, playerIdx, cardIndex)) return { success: false };

    const player = this.state.players[playerIdx];
    const card = player.hand.splice(cardIndex, 1)[0];
    this.state.currentTrick.push([playerIdx, card]);

    // Return animation data for AI players
    const animation = playerIdx !== 0 ? {
      type: 'cardPlayed',
      playerIdx,
      card: { suit: card.suit, value: card.value },
    } : null;

    return { success: true, animation };
  }

  _handleAssignCard(playerIdx, cardKey, targetSuit) {
    if (this.state.phase !== 'assignment') return false;
    if (playerIdx !== this.state.lastWinner) return false;

    this.state.pendingAssignments[cardKey] = targetSuit;
    return true;
  }

  _handleSubmitAssignments(playerIdx) {
    if (this.state.phase !== 'assignment') {
      console.error(`[SubmitAssignments] Phase mismatch: ${this.state.phase}`);
      return false;
    }
    if (playerIdx !== this.state.lastWinner) {
      console.error(`[SubmitAssignments] Player mismatch: ${playerIdx} != ${this.state.lastWinner}`);
      return false;
    }

    // Validate all cards assigned
    if (Object.keys(this.state.pendingAssignments).length !== this.state.lastTrick.length) {
      console.error(`[SubmitAssignments] Assignments mismatch: ${Object.keys(this.state.pendingAssignments).length} != ${this.state.lastTrick.length}`);
      return false;
    }

    // Validate suits match
    const suitsInTrick = new Set(this.state.lastTrick.map(([, card]) => card.suit));
    for (const [, targetSuit] of Object.entries(this.state.pendingAssignments)) {
      if (!suitsInTrick.has(targetSuit)) {
        return false;
      }
    }

    // Apply assignments
    applyAssignments(this.state, this.state.pendingAssignments, this.state.variants);
    this.state.pendingAssignments = {};
    this.state.needsManualAssignment = false;  // Clear flag after assignments complete

    return true;
  }

  _handleSwapCard(playerIdx, plotIndex, handIndex, plotType) {
    if (this.state.phase !== 'swap') return false;

    const player = this.state.players[playerIdx];
    if (!this.state.swapCount) this.state.swapCount = {};
    if (this.state.swapCount[playerIdx]) return false;

    const plotArray = plotType === 'revealed' ? player.plot.revealed : player.plot.hidden;
    if (plotIndex >= plotArray.length || handIndex >= player.hand.length) return false;

    // Swap
    const temp = plotArray[plotIndex];
    plotArray[plotIndex] = player.hand[handIndex];
    player.hand[handIndex] = temp;

    this.state.lastSwap = { playerIdx, plotType, plotIndex, handIndex };
    this.state.swapCount[playerIdx] = true;
    return true;
  }

  _handleConfirmSwap(playerIdx) {
    if (this.state.phase !== 'swap') return false;

    if (!this.state.swapConfirmed) this.state.swapConfirmed = {};
    this.state.swapConfirmed[playerIdx] = true;
    return true;
  }

  _handleUndoSwap(playerIdx) {
    if (this.state.phase !== 'swap') return false;
    if (!this.state.swapCount?.[playerIdx] || !this.state.lastSwap) return false;
    if (this.state.lastSwap.playerIdx !== playerIdx) return false;

    const player = this.state.players[playerIdx];
    const { plotType, plotIndex, handIndex } = this.state.lastSwap;
    const plotArray = plotType === 'revealed' ? player.plot.revealed : player.plot.hidden;

    // Swap back
    const temp = plotArray[plotIndex];
    plotArray[plotIndex] = player.hand[handIndex];
    player.hand[handIndex] = temp;

    delete this.state.swapCount[playerIdx];
    delete this.state.lastSwap;
    return true;
  }

  _handleContinueToNextYear(playerIdx) {
    if (this.state.phase !== 'requisition') return false;

    applyExiledCards(this.state);
    this.state.requisitionData = null;
    transitionToNextYear(this.state, this.state.variants, this.random);

    if (this.state.year > 5) {
      this.state.gameover = getWinner(this.state, this.state.variants);
    }
    return true;
  }

  _handleApplySingleAssignment(playerIdx, cardKey, targetSuit) {
    if (this.state.phase !== 'aiAssignment') return false;
    if (!this.state.pendingAIAssignments) return false;

    // Apply single card
    const [suit, valueStr] = cardKey.split('-');
    const value = parseInt(valueStr, 10);
    const card = { suit, value };

    this.state.jobBuckets[targetSuit].push(card);

    // Calculate work value
    let workValue = value;
    if (this.state.variants.nomenclature && suit === this.state.trump && value === 11) {
      workValue = 0;
    }
    this.state.workHours[targetSuit] += workValue;

    // Check for completed job
    const THRESHOLD = 40;
    if (this.state.workHours[targetSuit] >= THRESHOLD && !this.state.claimedJobs.includes(targetSuit)) {
      this.state.claimedJobs.push(targetSuit);

      if (this.state.variants.deckType === 36 && this.state.variants.ordenNachalniku) {
        const bucket = [...this.state.jobBuckets[targetSuit]];
        if (bucket.length > 0) {
          const lowestCard = bucket.reduce((l, c) => c.value < l.value ? c : l);
          const otherCards = bucket.filter(c => !(c.suit === lowestCard.suit && c.value === lowestCard.value))
            .sort((a, b) => a.value - b.value);
          const winner = this.state.players[this.state.pendingAIAssignments.winner];
          if (!winner.plot.stacks) winner.plot.stacks = [];
          winner.plot.stacks.push({ revealed: [lowestCard], hidden: otherCards });
          this.state.jobBuckets[targetSuit] = [];
        }
      } else if (this.state.variants.deckType !== 36) {
        const winner = this.state.players[this.state.pendingAIAssignments.winner];
        const rewards = Array.isArray(this.state.revealedJobs[targetSuit])
          ? this.state.revealedJobs[targetSuit]
          : [this.state.revealedJobs[targetSuit]];
        for (const c of rewards) {
          if (c) winner.plot.revealed.push(c);
        }
        this.state.revealedJobs[targetSuit] = null;
        if (this.state.variants.accumulateJobs) {
          this.state.accumulatedJobCards[targetSuit] = [];
        }
      }
    }

    // Remove from pending
    delete this.state.pendingAIAssignments.assignments[cardKey];

    // Check if done
    if (Object.keys(this.state.pendingAIAssignments.assignments).length === 0) {
      this.state.pendingAIAssignments = null;
    }

    return true;
  }

  // ─────────────────────────────────────────────────────────
  // ACTION PROCESSING
  // ─────────────────────────────────────────────────────────

  async _processAction(action) {
    const { type, playerIdx, payload } = action;
    let success = false;
    let animation = null;

    switch (type) {
      case 'setTrump':
        success = this._handleSetTrump(playerIdx, payload?.suit);
        break;

      case 'playCard': {
        const result = this._handlePlayCard(playerIdx, payload?.cardIndex);
        success = result.success;
        animation = result.animation;
        break;
      }

      case 'assignCard':
        success = this._handleAssignCard(playerIdx, payload?.cardKey, payload?.targetSuit);
        break;

      case 'submitAssignments':
        success = this._handleSubmitAssignments(playerIdx);
        break;

      case 'swapCard':
        success = this._handleSwapCard(playerIdx, payload?.plotIndex, payload?.handIndex, payload?.plotType);
        break;

      case 'confirmSwap':
        success = this._handleConfirmSwap(playerIdx);
        break;

      case 'undoSwap':
        success = this._handleUndoSwap(playerIdx);
        break;

      case 'continueToNextYear':
        success = this._handleContinueToNextYear(playerIdx);
        break;

      case 'applySingleAssignment':
        success = this._handleApplySingleAssignment(playerIdx, payload?.cardKey, payload?.targetSuit);
        break;

      default:
        console.warn('Unknown action type:', type);
    }

    if (!success) {
      console.error(`Action failed: ${type}`);
      return;
    }

    // Emit animation if any
    if (animation) {
      this.emit('animation', animation);
      await this._waitForAnimation();
    }

    // Check for phase transitions
    this._checkPhaseTransition();

    // Emit state change
    this.emit('stateChange', this.state);

    // Note: AI processing is handled by the caller (dispatch or _processAI loop)
  }

  async _waitForAnimation() {
    if (this.options.headless) return;

    return new Promise((resolve) => {
      this.animationResolver = resolve;
      // Timeout fallback
      setTimeout(() => {
        if (this.animationResolver === resolve) {
          console.warn('Animation timeout');
          resolve();
          this.animationResolver = null;
        }
      }, 3000);
    });
  }

  // ─────────────────────────────────────────────────────────
  // PHASE MANAGEMENT
  // ─────────────────────────────────────────────────────────

  _runPhaseOnBegin() {
    const phase = this.state.phase;

    switch (phase) {
      case 'planning':
        if (this.state.isFamine) {
          this.state.trump = null;
        }
        this.state.currentPlayer = this.state.trumpSelector;
        break;

      case 'trick':
        this.state.currentPlayer = this.state.lead;
        this.state.needsManualAssignment = false;
        break;

      case 'assignment':
        this.state.pendingAssignments = {};
        this.state.currentPlayer = this.state.lastWinner;
        break;

      case 'aiAssignment':
        this.state.currentPlayer = 0; // Human controls animation
        break;

      case 'swap':
        this.state.swapConfirmed = {};
        this.state.swapCount = {};
        this.state.currentPlayer = 0;
        // Auto-confirm swap for all AI players (except training player)
        for (let i = 0; i < this.state.numPlayers; i++) {
          if (!this.state.players[i].isHuman && i !== this.options.trainingPlayer) {
            this.state.swapConfirmed[i] = true;
          }
        }
        break;

      case 'plotSelection':
        // Auto-add all cards to plot
        for (const player of this.state.players) {
          while (player.hand.length > 0) {
            const card = player.hand.pop();
            player.plot.hidden.push(card);
          }
        }
        // Immediately transition
        this.state.phase = 'requisition';
        this._runPhaseOnBegin();
        break;

      case 'requisition':
        performRequisition(this.state, this.state.variants);
        break;
    }
  }

  _checkPhaseTransition() {
    const phase = this.state.phase;

    switch (phase) {
      case 'planning':
        if (this.state.isFamine || this.state.trump !== null) {
          if (!this.state.isFamine && !this.state.trump) {
            setRandomTrump(this.state, this.random);
          }
          this.state.phase = (this.state.variants.allowSwap && this.state.year > 1) ? 'swap' : 'trick';
          this._runPhaseOnBegin();
        }
        break;

      case 'trick':
        // Check if trick complete
        if (this.state.currentTrick.length === this.state.numPlayers) {
          const winner = resolveTrick(this.state);
          if (winner !== null) {
            applyTrickResult(this.state, winner);

            // Check for auto-assignment
            const autoAssign = generateAutoAssignment(this.state.lastTrick);
            if (autoAssign && winner !== 0) {
              // AI won with same-suit trick
              this.state.pendingAIAssignments = {
                trick: JSON.parse(JSON.stringify(this.state.lastTrick)),
                assignments: { ...autoAssign },
                winner,
                trump: this.state.trump,
              };
              this.state.needsManualAssignment = false;
              this.state.phase = 'aiAssignment';
              this._runPhaseOnBegin();
            } else {
              // Human won or mixed suits
              this.state.needsManualAssignment = true;
              this.state.phase = 'assignment';
              this._runPhaseOnBegin();
            }
          }
        } else {
          // Advance to next player
          this.state.currentPlayer = (this.state.currentPlayer + 1) % this.state.numPlayers;
        }
        break;

      case 'assignment':
        // Transition happens when submitAssignments succeeds
        if (Object.keys(this.state.pendingAssignments).length === 0 && !this.state.needsManualAssignment) {
          if (isYearComplete(this.state)) {
            this.state.phase = 'plotSelection';
          } else {
            this.state.phase = 'trick';
          }
          this._runPhaseOnBegin();
        }
        break;

      case 'aiAssignment':
        if (!this.state.pendingAIAssignments) {
          if (isYearComplete(this.state)) {
            this.state.phase = 'plotSelection';
          } else {
            this.state.phase = 'trick';
          }
          this._runPhaseOnBegin();
        }
        break;

      case 'swap':
        // Check if all confirmed
        if (this.state.swapConfirmed) {
          let allConfirmed = true;
          for (let i = 0; i < this.state.numPlayers; i++) {
            if (!this.state.swapConfirmed[i]) {
              allConfirmed = false;
              break;
            }
          }
          if (allConfirmed) {
            delete this.state.swapConfirmed;
            delete this.state.swapCount;
            this.state.phase = 'trick';
            this._runPhaseOnBegin();
          }
        }
        break;

      case 'requisition':
        // Transition happens when continueToNextYear is called
        if (this.state.gameover) {
          // Game over
        } else if (!this.state.requisitionData) {
          this.state.phase = 'planning';
          this._runPhaseOnBegin();
        }
        break;
    }
  }

  // ─────────────────────────────────────────────────────────
  // AI
  // ─────────────────────────────────────────────────────────

  async _processAI() {
    if (this.isGameOver()) {
      return;
    }

    // Loop while current player is AI and can act
    while (this._shouldAIAct()) {
      const action = this._getAIAction();
      if (!action) break;

      await this._processAction(action);
      if (!this.options.headless) await this._delay(100);
    }

    // In headless mode, auto-complete AI assignment animations AFTER AI turns
    let aiAssignLoopCount = 0;
    const maxAiAssignLoops = 20;
    while (this.options.headless && this.state.phase === 'aiAssignment' && this.state.pendingAIAssignments) {
      aiAssignLoopCount++;
      if (aiAssignLoopCount > maxAiAssignLoops) {
        console.error('[Engine] Breaking out of aiAssignment loop - too many iterations');
        this.state.pendingAIAssignments = null;
        break;
      }

      // Apply all pending AI assignments at once
      const assignments = { ...this.state.pendingAIAssignments.assignments };
      const winnerIdx = this.state.pendingAIAssignments.winner;

      // Safety check - if no assignments, clear and break
      if (Object.keys(assignments).length === 0) {
        this.state.pendingAIAssignments = null;
        this._checkPhaseTransition();
        break;
      }

      for (const [cardKey, targetSuit] of Object.entries(assignments)) {
        this._handleApplySingleAssignment(winnerIdx, cardKey, targetSuit);
      }
      this._checkPhaseTransition();

      // After transitioning out of aiAssignment, continue AI processing if needed
      while (this._shouldAIAct()) {
        const action = this._getAIAction();
        if (!action) break;
        await this._processAction(action);
        if (!this.options.headless) await this._delay(100);
      }
    }
  }

  _shouldAIAct() {
    if (this.isGameOver()) return false;

    const playerIdx = this.state.currentPlayer;
    const player = this.state.players[playerIdx];
    if (!player || player.isHuman) return false;

    // Don't auto-play for training player - they're controlled externally
    if (this.options.trainingPlayer !== undefined && playerIdx === this.options.trainingPlayer) {
      return false;
    }

    // In selfPlay mode, ALL players are controlled externally
    if (this.options.selfPlay) {
      return false;
    }

    // Check phase allows AI action
    const phase = this.state.phase;
    if (phase === 'planning') return true;
    if (phase === 'trick') return true;
    if (phase === 'assignment') return this.state.lastWinner !== 0;
    if (phase === 'swap') return true;

    return false;
  }

  _getAIAction() {
    const playerIdx = this.state.currentPlayer;
    const phase = this.state.phase;

    // Try RL agent first if available
    if (this.rlAgent?.isReady()) {
      const rlAction = this.rlAgent.getAction(this.state, playerIdx);
      if (rlAction) {
        return { ...rlAction, playerIdx };
      }
      // Fall through to heuristics if RL agent returns null
    }

    switch (phase) {
      case 'planning': {
        // Pick a random trump
        const suit = SUITS[Math.floor(this.random.Number() * SUITS.length)];
        return { type: 'setTrump', playerIdx, payload: { suit } };
      }

      case 'trick': {
        // Use AI heuristics
        const ctx = {
          currentPlayer: String(playerIdx),
          numPlayers: this.state.numPlayers,
          phase: 'trick'
        };
        const moves = getPrioritizedMoves(this.state, ctx, playerIdx);
        if (moves.length > 0) {
          const best = moves[0];
          if (best.move === 'playCard') {
            return { type: 'playCard', playerIdx, payload: { cardIndex: best.args[0] } };
          }
        }
        return null;
      }

      case 'assignment': {
        // AI winner assigns cards
        // First try auto-assignment for same-suit tricks
        const autoAssign = generateAutoAssignment(this.state.lastTrick);
        if (autoAssign) {
          for (const [cardKey, targetSuit] of Object.entries(autoAssign)) {
            this.state.pendingAssignments[cardKey] = targetSuit;
          }
          return { type: 'submitAssignments', playerIdx, payload: {} };
        }

        // Mixed suits - use AI heuristics
        const ctx = {
          currentPlayer: String(playerIdx),
          numPlayers: this.state.numPlayers,
          phase: 'assignment'
        };
        const moves = getPrioritizedMoves(this.state, ctx, playerIdx);

        if (moves.length > 0) {
          const best = moves[0];
          if (best.move === 'assignCard') {
            return { type: 'assignCard', playerIdx, payload: { cardKey: best.args[0], targetSuit: best.args[1] } };
          } else if (best.move === 'submitAssignments') {
            return { type: 'submitAssignments', playerIdx, payload: {} };
          }
        }

        // Fallback: assign each card to its own suit
        for (const [, card] of this.state.lastTrick) {
          const cardKey = `${card.suit}-${card.value}`;
          if (!this.state.pendingAssignments[cardKey]) {
            this.state.pendingAssignments[cardKey] = card.suit;
            return { type: 'assignCard', playerIdx, payload: { cardKey, targetSuit: card.suit } };
          }
        }

        // All assigned, submit
        if (Object.keys(this.state.pendingAssignments).length === this.state.lastTrick.length) {
          return { type: 'submitAssignments', playerIdx, payload: {} };
        }

        return null;
      }

      case 'swap': {
        // AI confirms immediately (no swap)
        return { type: 'confirmSwap', playerIdx, payload: {} };
      }

      default:
        return null;
    }
  }

  _delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
