/**
 * React hook for Kolkhoz game integration.
 * Replaces boardgame.io client with custom engine.
 */

import { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { KolkhozEngine } from '../../engine/KolkhozEngine.js';

const SAVE_KEY = 'kolkhoz-save';

/**
 * Hook for managing Kolkhoz game state and interactions.
 *
 * @param {Object} options - Game options
 * @param {Object} options.variants - Game variant settings
 * @returns {Object} Game state and controls (similar to boardgame.io interface)
 */
export function useKolkhozGame(options = {}) {
  const engineRef = useRef(null);
  const [state, setState] = useState(null);
  const [animationQueue, setAnimationQueue] = useState([]);
  const [isReady, setIsReady] = useState(false);

  // Initialize engine
  useEffect(() => {
    let savedSnapshot = null;
    try {
      savedSnapshot = JSON.parse(localStorage.getItem(SAVE_KEY));
    } catch {
      localStorage.removeItem(SAVE_KEY);
    }

    const engine = new KolkhozEngine({ ...options, savedSnapshot });
    engineRef.current = engine;

    // Subscribe to state changes
    const unsubState = engine.on('stateChange', (newState) => {
      setState({ ...newState });
      localStorage.setItem(SAVE_KEY, JSON.stringify(engine.getSnapshot()));
    });

    // Subscribe to animations
    const unsubAnim = engine.on('animation', (anim) => {
      setAnimationQueue((q) => [...q, anim]);
    });

    // Set initial state
    setState(engine.getState());
    setIsReady(true);
    localStorage.setItem(SAVE_KEY, JSON.stringify(engine.getSnapshot()));

    // Start the game (processes initial AI if needed)
    engine.start();

    return () => {
      unsubState();
      unsubAnim();
    };
  }, []); // Only run once on mount

  // Process animation queue
  const currentAnimation = animationQueue[0] || null;

  // Signal animation complete
  const completeAnimation = useCallback(() => {
    if (engineRef.current && animationQueue.length > 0) {
      engineRef.current.completeAnimation();
      setAnimationQueue((q) => q.slice(1));
    }
  }, [animationQueue.length]);

  // Create moves object (similar to boardgame.io)
  const moves = useMemo(() => ({
    setTrump: (suit) => {
      if (engineRef.current) {
        engineRef.current.dispatch({
          type: 'setTrump',
          playerIdx: 0,
          payload: { suit },
        });
      }
    },

    playCard: (cardIndex) => {
      if (engineRef.current) {
        engineRef.current.dispatch({
          type: 'playCard',
          playerIdx: 0,
          payload: { cardIndex },
        });
      }
    },

    assignCard: (cardKey, targetSuit) => {
      if (engineRef.current) {
        engineRef.current.dispatch({
          type: 'assignCard',
          playerIdx: 0,
          payload: { cardKey, targetSuit },
        });
      }
    },

    submitAssignments: () => {
      if (engineRef.current) {
        engineRef.current.dispatch({
          type: 'submitAssignments',
          playerIdx: 0,
          payload: {},
        });
      }
    },

    swapCard: (plotIndex, handIndex, plotType) => {
      if (engineRef.current) {
        engineRef.current.dispatch({
          type: 'swapCard',
          playerIdx: 0,
          payload: { plotIndex, handIndex, plotType },
        });
      }
    },

    confirmSwap: () => {
      if (engineRef.current) {
        engineRef.current.dispatch({
          type: 'confirmSwap',
          playerIdx: 0,
          payload: {},
        });
      }
    },

    undoSwap: () => {
      if (engineRef.current) {
        engineRef.current.dispatch({
          type: 'undoSwap',
          playerIdx: 0,
          payload: {},
        });
      }
    },

    continueToNextYear: () => {
      if (engineRef.current) {
        engineRef.current.dispatch({
          type: 'continueToNextYear',
          playerIdx: 0,
          payload: {},
        });
      }
    },

    applySingleAssignment: (cardKey, targetSuit) => {
      if (engineRef.current) {
        engineRef.current.dispatch({
          type: 'applySingleAssignment',
          playerIdx: 0,
          payload: { cardKey, targetSuit },
        });
      }
    },
  }), []);

  // Compute derived state (similar to boardgame.io ctx)
  const ctx = useMemo(() => {
    if (!state) return null;
    return {
      phase: state.phase,
      currentPlayer: String(state.currentPlayer),
      numPlayers: state.numPlayers,
      gameover: state.gameover,
    };
  }, [state?.phase, state?.currentPlayer, state?.numPlayers, state?.gameover]);

  const isMyTurn = state?.currentPlayer === 0;

  return {
    // State (G in boardgame.io)
    G: state,
    // Context
    ctx,
    // Moves
    moves,
    // Player ID (always 0 for human)
    playerID: '0',
    // Convenience
    isMyTurn,
    isReady,
    // Animation
    currentAnimation,
    animationQueue,
    completeAnimation,
  };
}

export default useKolkhozGame;
