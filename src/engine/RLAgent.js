/**
 * RL Agent for Kolkhoz
 *
 * Lightweight neural network inference for the trained PPO model.
 * Uses a simple custom implementation to avoid TensorFlow.js overhead.
 */

import { SUITS } from '../game/constants.js';

/**
 * Simple feedforward neural network for inference only.
 * No dependencies required - just matrix operations.
 */
class SimpleNN {
  constructor(meta) {
    this.obsDim = meta.obs_dim;
    this.actionDim = meta.action_dim;
    this.hiddenSizes = meta.hidden_sizes;
    this.weights = {};
    this.loaded = false;
  }

  /**
   * Load weights from JSON
   */
  loadWeights(weights) {
    this.weights = weights;
    this.loaded = true;
  }

  /**
   * ReLU activation
   */
  relu(x) {
    return x.map(v => Math.max(0, v));
  }

  /**
   * Matrix-vector multiplication: y = Wx + b
   */
  linear(x, weightKey, biasKey) {
    const W = this.weights[weightKey];
    const b = this.weights[biasKey];

    if (!W || !b) {
      throw new Error(`Missing weights: ${weightKey} or ${biasKey}`);
    }

    const out = new Array(W.length).fill(0);
    for (let i = 0; i < W.length; i++) {
      out[i] = b[i];
      for (let j = 0; j < x.length; j++) {
        out[i] += W[i][j] * x[j];
      }
    }
    return out;
  }

  /**
   * Forward pass through the network
   */
  forward(observation) {
    if (!this.loaded) {
      throw new Error('Model weights not loaded');
    }

    let x = observation;

    // Pass through MLP extractor layers
    // sb3 naming: mlp_extractor.policy_net.0.weight, .bias, etc.
    let layerIdx = 0;
    for (const size of this.hiddenSizes) {
      const wKey = `mlp_extractor.policy_net.${layerIdx}.weight`;
      const bKey = `mlp_extractor.policy_net.${layerIdx}.bias`;
      x = this.linear(x, wKey, bKey);
      x = this.relu(x);
      layerIdx += 2; // Skip ReLU layer in indexing
    }

    // Action head
    const logits = this.linear(x, 'action_net.weight', 'action_net.bias');
    return logits;
  }

  /**
   * Sample action from logits with masking
   */
  sampleAction(logits, validActionIndices, deterministic = true) {
    if (validActionIndices.length === 0) {
      return null;
    }

    if (deterministic) {
      // Greedy: pick highest logit among valid actions
      let bestIdx = validActionIndices[0];
      let bestLogit = logits[bestIdx];
      for (const idx of validActionIndices) {
        if (logits[idx] > bestLogit) {
          bestLogit = logits[idx];
          bestIdx = idx;
        }
      }
      return bestIdx;
    } else {
      // Stochastic: softmax over valid actions, then sample
      const validLogits = validActionIndices.map(i => logits[i]);
      const maxLogit = Math.max(...validLogits);
      const expLogits = validLogits.map(l => Math.exp(l - maxLogit));
      const sumExp = expLogits.reduce((a, b) => a + b, 0);
      const probs = expLogits.map(e => e / sumExp);

      // Sample from distribution
      const r = Math.random();
      let cumProb = 0;
      for (let i = 0; i < probs.length; i++) {
        cumProb += probs[i];
        if (r <= cumProb) {
          return validActionIndices[i];
        }
      }
      return validActionIndices[validActionIndices.length - 1];
    }
  }
}

/**
 * Feature extraction for RL model.
 * Must match training/engine_wrapper.js exactly.
 */
function extractFeatures(state, playerIdx = 0) {
  const features = [];
  const player = state.players[playerIdx];

  // Phase encoding (one-hot, 6 phases)
  const phases = ['planning', 'trick', 'assignment', 'aiAssignment', 'swap', 'requisition'];
  for (const p of phases) {
    features.push(state.phase === p ? 1 : 0);
  }

  // Year (normalized 0-1)
  features.push(state.year / 5);

  // Trump suit (one-hot, 4 suits + null)
  for (const suit of SUITS) {
    features.push(state.trump === suit ? 1 : 0);
  }
  features.push(state.trump === null ? 1 : 0);

  // Is famine year
  features.push(state.isFamine ? 1 : 0);

  // Work hours per suit (normalized 0-1, max ~60)
  for (const suit of SUITS) {
    features.push((state.workHours[suit] || 0) / 60);
  }

  // Claimed jobs per suit
  for (const suit of SUITS) {
    features.push(state.claimedJobs.includes(suit) ? 1 : 0);
  }

  // Current trick length
  features.push((state.currentTrick?.length || 0) / 4);

  // Cards in current trick (suit one-hot + normalized value)
  for (let i = 0; i < 4; i++) {
    if (state.currentTrick && i < state.currentTrick.length) {
      const [, card] = state.currentTrick[i];
      for (const suit of SUITS) {
        features.push(card.suit === suit ? 1 : 0);
      }
      features.push(card.value / 14);
    } else {
      features.push(0, 0, 0, 0, 0);
    }
  }

  // Player's hand (up to 13 cards)
  const maxHand = 13;
  for (let i = 0; i < maxHand; i++) {
    if (player.hand && i < player.hand.length) {
      const card = player.hand[i];
      for (const suit of SUITS) {
        features.push(card.suit === suit ? 1 : 0);
      }
      features.push(card.value / 14);
    } else {
      features.push(0, 0, 0, 0, 0);
    }
  }

  // Player plot sizes (all players)
  for (let i = 0; i < state.numPlayers; i++) {
    const p = state.players[i];
    features.push((p.plot?.revealed?.length || 0) / 10);
    features.push((p.plot?.hidden?.length || 0) / 10);
  }

  // Has won trick this year (all players)
  for (let i = 0; i < state.numPlayers; i++) {
    features.push(state.players[i].hasWonTrickThisYear ? 1 : 0);
  }

  // Is current player
  features.push(state.currentPlayer === playerIdx ? 1 : 0);

  // Is my turn (duplicate for compatibility)
  features.push(state.currentPlayer === playerIdx ? 1 : 0);

  // Trick count (normalized)
  features.push((state.trickCount || 0) / 13);

  return features;
}

/**
 * Get valid actions for current state (matches engine_wrapper.js)
 */
function getValidActions(state, playerIdx = 0) {
  const actions = [];
  const player = state.players[playerIdx];

  if (state.phase === 'planning' && state.currentPlayer === playerIdx) {
    for (let i = 0; i < SUITS.length; i++) {
      actions.push({
        type: 'setTrump',
        index: i,
        payload: { suit: SUITS[i] }
      });
    }
  } else if (state.phase === 'trick' && state.currentPlayer === playerIdx) {
    const leadSuit = state.currentTrick?.[0]?.[1]?.suit;
    const hasLeadSuit = leadSuit && player.hand.some(c => c.suit === leadSuit);

    for (let i = 0; i < player.hand.length; i++) {
      const card = player.hand[i];
      if (!leadSuit || !hasLeadSuit || card.suit === leadSuit) {
        actions.push({
          type: 'playCard',
          index: 100 + i,
          payload: { cardIndex: i }
        });
      }
    }
  } else if (state.phase === 'assignment' && state.lastWinner === playerIdx) {
    const suitsInTrick = [...new Set(state.lastTrick.map(([, c]) => c.suit))];

    for (const [, card] of state.lastTrick) {
      const cardKey = `${card.suit}-${card.value}`;
      if (!state.pendingAssignments?.[cardKey]) {
        for (let i = 0; i < suitsInTrick.length; i++) {
          actions.push({
            type: 'assignCard',
            index: 200 + suitsInTrick.indexOf(suitsInTrick[i]),
            payload: { cardKey, targetSuit: suitsInTrick[i] }
          });
        }
      }
    }

    if (Object.keys(state.pendingAssignments || {}).length === state.lastTrick?.length) {
      actions.push({
        type: 'submitAssignments',
        index: 300,
        payload: {}
      });
    }
  } else if (state.phase === 'swap' && !state.swapConfirmed?.[playerIdx]) {
    for (let h = 0; h < (player.hand?.length || 0); h++) {
      for (let p = 0; p < (player.plot?.hidden?.length || 0); p++) {
        actions.push({
          type: 'swapCard',
          index: 400 + h * 20 + p,
          payload: { plotIndex: p, handIndex: h, plotType: 'hidden' }
        });
      }
      for (let p = 0; p < (player.plot?.revealed?.length || 0); p++) {
        actions.push({
          type: 'swapCard',
          index: 500 + h * 20 + p,
          payload: { plotIndex: p, handIndex: h, plotType: 'revealed' }
        });
      }
    }

    actions.push({
      type: 'confirmSwap',
      index: 600,
      payload: {}
    });
  } else if (state.phase === 'requisition') {
    actions.push({
      type: 'continueToNextYear',
      index: 700,
      payload: {}
    });
  }

  return actions;
}

/**
 * RL Agent class for browser inference
 */
export class RLAgent {
  constructor() {
    this.model = null;
    this.loaded = false;
    this.loadPromise = null;
  }

  /**
   * Load the model from a JSON weights file
   */
  async load(modelPath = '/models/kolkhoz-rl/model.json') {
    if (this.loadPromise) {
      return this.loadPromise;
    }

    this.loadPromise = (async () => {
      try {
        const response = await fetch(modelPath);
        if (!response.ok) {
          throw new Error(`Failed to load model: ${response.status}`);
        }

        const data = await response.json();
        this.model = new SimpleNN(data.meta);
        this.model.loadWeights(data.weights);
        this.loaded = true;
        console.log('[RLAgent] Model loaded successfully');
        return true;
      } catch (error) {
        console.warn('[RLAgent] Failed to load model:', error.message);
        this.loaded = false;
        return false;
      }
    })();

    return this.loadPromise;
  }

  /**
   * Check if model is ready
   */
  isReady() {
    return this.loaded && this.model !== null;
  }

  /**
   * Get action for the current game state
   */
  getAction(state, playerIdx = 0, deterministic = true) {
    if (!this.isReady()) {
      return null;
    }

    try {
      // Extract features
      const features = extractFeatures(state, playerIdx);

      // Get valid actions
      const validActions = getValidActions(state, playerIdx);
      if (validActions.length === 0) {
        return null;
      }

      // Forward pass
      const logits = this.model.forward(features);

      // Sample action with masking
      const validIndices = validActions.map(a => a.index);
      const actionIndex = this.model.sampleAction(logits, validIndices, deterministic);

      if (actionIndex === null) {
        return null;
      }

      // Find the action with this index
      const action = validActions.find(a => a.index === actionIndex);
      return action;
    } catch (error) {
      console.error('[RLAgent] Error getting action:', error);
      return null;
    }
  }
}

// Singleton instance
let agentInstance = null;

/**
 * Get the shared RL agent instance
 */
export function getRLAgent() {
  if (!agentInstance) {
    agentInstance = new RLAgent();
  }
  return agentInstance;
}

/**
 * Initialize the RL agent (call early in app lifecycle)
 */
export async function initRLAgent(modelPath) {
  const agent = getRLAgent();
  return agent.load(modelPath);
}
