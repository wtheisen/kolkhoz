import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useEffectListener } from 'bgio-effects/react';
import { TrickAreaHTML } from './components/TrickAreaHTML.jsx';
import { FlyingCard, AIPlayCard, FlyingExileCard } from './components/animations/index.js';
import { NavBar, OptionsPanel, PlayerHandArea } from './components/layout/index.js';
import { RequisitionOverlay, GameOverScreen } from './components/overlays/index.js';
import { getCardImagePath } from '../game/Card.js';
import { translations, t } from './translations.js';

export function Board({ G, ctx, moves, playerID, onNewGame }) {
  const currentPlayer = parseInt(playerID, 10);
  const isMyTurn = ctx.currentPlayer === playerID;
  const phase = ctx.phase;
  const currentSwapPlayer = phase === 'swap' ? parseInt(ctx.currentPlayer, 10) : null;

  // Mobile panel toggle
  const [activePanel, setActivePanel] = useState(null);
  const togglePanel = (panel) => setActivePanel(activePanel === panel ? null : panel);

  // Language toggle (persisted to localStorage)
  const [language, setLanguage] = useState(() => localStorage.getItem('kolkhoz-lang') || 'ru');
  const toggleLanguage = () => setLanguage(lang => {
    const newLang = lang === 'en' ? 'ru' : 'en';
    localStorage.setItem('kolkhoz-lang', newLang);
    return newLang;
  });

  // Track if user has confirmed swap locally
  const [swapConfirmedLocally, setSwapConfirmedLocally] = useState(false);
  const lastYearRef = useRef(G.year);

  // Ref to trick area for getting card slot positions
  const trickAreaRef = useRef(null);

  // Drag state for playing cards
  const [dragState, setDragState] = useState(null);

  // Swap drag state (for swap phase)
  const [swapDragState, setSwapDragState] = useState(null);
  const plotCardRefs = useRef({});  // For plot cards in hand area (non-swap phases)
  const handCardRefs = useRef({});
  const plotDropRefs = useRef({});  // For plot cards in panel (swap phase drop targets)

  // Assignment drag state (for assignment phase)
  const [assignDragState, setAssignDragState] = useState(null);
  const assignCardRefs = useRef({});
  const jobDropRefs = useRef({});

  // AI card play animation state - use queue to handle rapid-fire bot moves
  const [animationQueue, setAnimationQueue] = useState([]);
  const [currentAiAnimation, setCurrentAiAnimation] = useState(null);

  // Listen for cardPlayed effects from bgio-effects
  // When bots play after human, multiple effects fire rapidly - we queue them
  useEffectListener(
    'cardPlayed',
    useCallback(({ playerIdx, card }) => {
      const key = `${card.suit}-${card.value}`;
      setAnimationQueue(q => [...q, { playerIdx, card, key }]);
    }, []),
    [],
    useCallback(() => {
      // Effect duration expired - clear current animation to trigger next in queue
      setCurrentAiAnimation(null);
    }, []),
    []
  );

  // Process animation queue - start next animation when current completes
  useEffect(() => {
    if (animationQueue.length > 0 && !currentAiAnimation) {
      const [next, ...rest] = animationQueue;
      setAnimationQueue(rest);
      setCurrentAiAnimation(next);
    }
  }, [animationQueue, currentAiAnimation]);

  // Timeout fallback - ensure animation clears even if bgio-effects onEnd doesn't fire
  useEffect(() => {
    if (currentAiAnimation) {
      const timer = setTimeout(() => {
        setCurrentAiAnimation(null);
      }, 750); // Slightly longer than CSS animation (600ms)
      return () => clearTimeout(timer);
    }
  }, [currentAiAnimation]);

  // Requisition animation state
  const [requisitionStage, setRequisitionStage] = useState('idle');
  // 'idle' | 'processing' | 'waiting'
  const [currentJobIndex, setCurrentJobIndex] = useState(0);
  const [currentJobStage, setCurrentJobStage] = useState('header');
  // 'header' | 'revealing' | 'exiling'
  const [flyingExileCards, setFlyingExileCards] = useState([]);

  // Reset local swap confirmation when year changes
  useEffect(() => {
    if (G.year !== lastYearRef.current) {
      setSwapConfirmedLocally(false);
      lastYearRef.current = G.year;
    }
  }, [G.year]);

  // Requisition animation sequence - process job by job
  useEffect(() => {
    if (phase !== 'requisition' || !G.requisitionData) {
      setRequisitionStage('idle');
      setCurrentJobIndex(0);
      setCurrentJobStage('header');
      setFlyingExileCards([]);
      return;
    }

    const failedJobs = G.requisitionData.failedJobs || [];

    // If no failed jobs, go straight to waiting
    if (failedJobs.length === 0) {
      setRequisitionStage('waiting');
      return;
    }

    // Start processing
    setRequisitionStage('processing');
    setCurrentJobIndex(0);
    setCurrentJobStage('header');
  }, [phase, G.requisitionData]);

  // Job-by-job animation state machine
  useEffect(() => {
    if (requisitionStage !== 'processing' || !G.requisitionData) return;

    const failedJobs = G.requisitionData.failedJobs || [];
    if (currentJobIndex >= failedJobs.length) {
      // All jobs processed, show continue button
      setRequisitionStage('waiting');
      return;
    }

    const currentSuit = failedJobs[currentJobIndex];
    let timeout;

    if (currentJobStage === 'header') {
      // Show header for 800ms, then move to revealing
      timeout = setTimeout(() => {
        setCurrentJobStage('revealing');
      }, 800);
    } else if (currentJobStage === 'revealing') {
      // Show revealed cards for 1200ms, then move to exiling
      timeout = setTimeout(() => {
        setCurrentJobStage('exiling');
        // Set up flying cards for this suit
        const suitExiledCards = (G.requisitionData.exiledCards || [])
          .filter(ec => ec.card.suit === currentSuit)
          .map((ec, idx) => ({
            ...ec,
            id: `${ec.card.suit}-${ec.card.value}-${currentJobIndex}-${idx}`,
            delay: idx * 300,  // Stagger by 300ms
          }));
        setFlyingExileCards(suitExiledCards);
      }, 1200);
    } else if (currentJobStage === 'exiling') {
      // Wait for exile animations to complete, then next job
      const suitExiledCount = (G.requisitionData.exiledCards || [])
        .filter(ec => ec.card.suit === currentSuit).length;
      const exileTime = suitExiledCount > 0 ? suitExiledCount * 300 + 800 : 500;

      timeout = setTimeout(() => {
        setFlyingExileCards([]);
        setCurrentJobIndex(prev => prev + 1);
        setCurrentJobStage('header');
      }, exileTime);
    }

    return () => {
      if (timeout) clearTimeout(timeout);
    };
  }, [requisitionStage, currentJobIndex, currentJobStage, G.requisitionData]);

  // Get current requisition suit for highlighting
  const currentRequisitionSuit = requisitionStage === 'processing' && G.requisitionData?.failedJobs
    ? G.requisitionData.failedJobs[currentJobIndex]
    : null;

  // AI Assignment Animation - compute flying card data
  const pending = G.pendingAIAssignments;
  let flyingCard = null;

  if (phase === 'aiAssignment' && pending) {
    const entries = Object.entries(pending.assignments);
    if (entries.length > 0) {
      const [cardKey, targetSuit] = entries[0];
      const [suit, valueStr] = cardKey.split('-');
      const card = { suit, value: parseInt(valueStr, 10) };

      // Find which player played this card
      const trickEntry = pending.trick.find(([, c]) => c.suit === card.suit && c.value === card.value);
      const playerIdx = trickEntry ? trickEntry[0] : 0;

      flyingCard = { cardKey, targetSuit, card, playerIdx };
    }
  }

  // Get highlighted suits for job icons - during trick phase, show suits in current trick
  const highlightedSuits = phase === 'trick' && G.currentTrick.length > 0
    ? [...new Set(G.currentTrick.map(([, card]) => card.suit))]
    : pending
      ? [...new Set(Object.values(pending.assignments))]
      : [];

  // Compute which trick to show
  let trickToShow;
  if (phase === 'assignment') {
    trickToShow = G.lastTrick;
  } else if (phase === 'aiAssignment' && pending) {
    const pendingKeys = new Set(Object.keys(pending.assignments));
    trickToShow = pending.trick.filter(([, card]) => {
      const cardKey = `${card.suit}-${card.value}`;
      if (flyingCard && cardKey === flyingCard.cardKey) return false;
      return pendingKeys.has(cardKey);
    });
  } else {
    // Filter out the card that is currently animating
    if (currentAiAnimation) {
      trickToShow = G.currentTrick.filter(([, card]) =>
        `${card.suit}-${card.value}` !== currentAiAnimation.key
      );
    } else {
      trickToShow = G.currentTrick;
    }
  }

  // Handle card play
  const handlePlayCard = (cardIndex) => {
    if (phase === 'trick' && isMyTurn) {
      moves.playCard(cardIndex);
    }
  };

  // Drag handlers for playing cards
  const getEventPosition = (e) => {
    if (e.touches && e.touches.length > 0) {
      return { x: e.touches[0].clientX, y: e.touches[0].clientY };
    }
    return { x: e.clientX, y: e.clientY };
  };

  const isOverDropZone = (x, y) => {
    // Find player 0's card slot (the rightmost one)
    const slot = document.querySelector('.player-column.right .card-slot');
    if (!slot) return false;
    const rect = slot.getBoundingClientRect();
    return x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom;
  };

  const handleDragStart = (cardIndex, card, e) => {
    if (phase !== 'trick' || !isMyTurn) return;
    const validIndices = getValidIndices(G, currentPlayer, phase);
    if (!validIndices?.includes(cardIndex)) return;

    e.preventDefault();
    const pos = getEventPosition(e);
    const cardEl = e.currentTarget;
    const cardRect = cardEl.getBoundingClientRect();

    setDragState({
      index: cardIndex,
      card,
      position: pos,
      offset: {
        x: pos.x - (cardRect.left + cardRect.width / 2),
        y: pos.y - (cardRect.top + cardRect.height / 2),
      },
      isOverTarget: false,
    });
  };

  // Handle drag movement and drop
  useEffect(() => {
    if (!dragState) return;

    const handleMove = (e) => {
      const pos = getEventPosition(e);
      const isOverTarget = isOverDropZone(pos.x, pos.y);
      setDragState((prev) => ({ ...prev, position: pos, isOverTarget }));
    };

    const handleEnd = (e) => {
      const pos = e.changedTouches ?
        { x: e.changedTouches[0].clientX, y: e.changedTouches[0].clientY } :
        { x: e.clientX, y: e.clientY };

      if (isOverDropZone(pos.x, pos.y)) {
        handlePlayCard(dragState.index);
      }
      setDragState(null);
    };

    document.addEventListener('mousemove', handleMove);
    document.addEventListener('mouseup', handleEnd);
    document.addEventListener('touchmove', handleMove, { passive: false });
    document.addEventListener('touchend', handleEnd);

    return () => {
      document.removeEventListener('mousemove', handleMove);
      document.removeEventListener('mouseup', handleEnd);
      document.removeEventListener('touchmove', handleMove);
      document.removeEventListener('touchend', handleEnd);
    };
  }, [dragState]);

  // Swap drag handlers
  const findSwapDropTarget = (x, y, sourceType) => {
    // Check plot cards in panel (plotDropRefs - used during swap phase)
    for (const [key, ref] of Object.entries(plotDropRefs.current)) {
      if (!ref) continue;
      const rect = ref.getBoundingClientRect();
      if (x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom) {
        const [type, indexStr] = key.split('-');
        const index = parseInt(indexStr, 10);
        // Only valid if dragging from hand
        if (sourceType === 'hand') {
          return { type: `plot-${type}`, index };
        }
      }
    }
    // Check plot cards in hand area (plotCardRefs - fallback for non-panel mode)
    for (const [key, ref] of Object.entries(plotCardRefs.current)) {
      if (!ref) continue;
      const rect = ref.getBoundingClientRect();
      if (x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom) {
        const [type, indexStr] = key.split('-');
        const index = parseInt(indexStr, 10);
        // Only valid if dragging from hand
        if (sourceType === 'hand') {
          return { type: `plot-${type}`, index };
        }
      }
    }
    // Check hand cards
    for (const [key, ref] of Object.entries(handCardRefs.current)) {
      if (!ref) continue;
      const rect = ref.getBoundingClientRect();
      if (x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom) {
        const index = parseInt(key, 10);
        // Only valid if dragging from plot
        if (sourceType.startsWith('plot-')) {
          return { type: 'hand', index };
        }
      }
    }
    return null;
  };

  const handleSwapDragStart = (sourceType, index, card, e) => {
    if (phase !== 'swap') return;
    e.preventDefault();
    const pos = getEventPosition(e);
    const cardEl = e.currentTarget;
    const rect = cardEl.getBoundingClientRect();

    setSwapDragState({
      sourceType,
      sourceIndex: index,
      card,
      position: pos,
      offset: {
        x: pos.x - (rect.left + rect.width / 2),
        y: pos.y - (rect.top + rect.height / 2),
      },
      dropTarget: null,
    });
  };

  // Handle swap drag movement and drop
  useEffect(() => {
    if (!swapDragState) return;

    const handleMove = (e) => {
      e.preventDefault();
      const pos = getEventPosition(e);
      const dropTarget = findSwapDropTarget(pos.x, pos.y, swapDragState.sourceType);
      setSwapDragState((prev) => ({ ...prev, position: pos, dropTarget }));
    };

    const handleEnd = (e) => {
      const pos = e.changedTouches
        ? { x: e.changedTouches[0].clientX, y: e.changedTouches[0].clientY }
        : { x: e.clientX, y: e.clientY };

      const dropTarget = findSwapDropTarget(pos.x, pos.y, swapDragState.sourceType);

      if (dropTarget) {
        let plotIndex, handIndex, plotType;

        if (swapDragState.sourceType === 'hand') {
          handIndex = swapDragState.sourceIndex;
          plotIndex = dropTarget.index;
          plotType = dropTarget.type === 'plot-revealed' ? 'revealed' : 'hidden';
        } else {
          plotIndex = swapDragState.sourceIndex;
          handIndex = dropTarget.index;
          plotType = swapDragState.sourceType === 'plot-revealed' ? 'revealed' : 'hidden';
        }

        moves.swapCard(plotIndex, handIndex, plotType);
      }

      setSwapDragState(null);
    };

    document.addEventListener('mousemove', handleMove);
    document.addEventListener('mouseup', handleEnd);
    document.addEventListener('touchmove', handleMove, { passive: false });
    document.addEventListener('touchend', handleEnd);

    return () => {
      document.removeEventListener('mousemove', handleMove);
      document.removeEventListener('mouseup', handleEnd);
      document.removeEventListener('touchmove', handleMove);
      document.removeEventListener('touchend', handleEnd);
    };
  }, [swapDragState, moves]);

  // Assignment drag handlers
  const findAssignDropTarget = (x, y) => {
    for (const [suit, ref] of Object.entries(jobDropRefs.current)) {
      if (!ref) continue;
      const rect = ref.getBoundingClientRect();
      if (x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom) {
        return suit;
      }
    }
    return null;
  };

  const handleAssignDragStart = (cardKey, card, e) => {
    if (phase !== 'assignment') return;
    e.preventDefault();
    const pos = getEventPosition(e);
    const cardEl = e.currentTarget;
    const rect = cardEl.getBoundingClientRect();

    setAssignDragState({
      cardKey,
      card,
      position: pos,
      offset: {
        x: pos.x - (rect.left + rect.width / 2),
        y: pos.y - (rect.top + rect.height / 2),
      },
      dropTarget: null,
    });
  };

  // Handle assignment drag movement and drop
  useEffect(() => {
    if (!assignDragState) return;

    const handleMove = (e) => {
      e.preventDefault();
      const pos = getEventPosition(e);
      const dropTarget = findAssignDropTarget(pos.x, pos.y);
      setAssignDragState((prev) => ({ ...prev, position: pos, dropTarget }));
    };

    const handleEnd = (e) => {
      const pos = e.changedTouches
        ? { x: e.changedTouches[0].clientX, y: e.changedTouches[0].clientY }
        : { x: e.clientX, y: e.clientY };

      const dropTarget = findAssignDropTarget(pos.x, pos.y);

      if (dropTarget) {
        moves.assignCard(assignDragState.cardKey, dropTarget);
      }

      setAssignDragState(null);
    };

    document.addEventListener('mousemove', handleMove);
    document.addEventListener('mouseup', handleEnd);
    document.addEventListener('touchmove', handleMove, { passive: false });
    document.addEventListener('touchend', handleEnd);

    return () => {
      document.removeEventListener('mousemove', handleMove);
      document.removeEventListener('mouseup', handleEnd);
      document.removeEventListener('touchmove', handleMove);
      document.removeEventListener('touchend', handleEnd);
    };
  }, [assignDragState, moves]);

  // Handle trump selection
  const handleSetTrump = (suit) => {
    if (phase === 'planning') {
      moves.setTrump(suit);
    }
  };

  // Handle assignment
  const handleAssign = (cardKey, targetSuit) => {
    moves.assignCard(cardKey, targetSuit);
  };

  const handleSubmitAssignments = () => {
    moves.submitAssignments();
  };

  const handleConfirmSwap = () => {
    setSwapConfirmedLocally(true);
    moves.confirmSwap();
  };

  // Render game over screen
  if (ctx.gameover) {
    const { winner, scores, medals } = ctx.gameover;
    return (
      <GameOverScreen
        players={G.players}
        winner={winner}
        scores={scores}
        medals={medals}
        language={language}
        onNewGame={onNewGame}
      />
    );
  }

  // Calculate which view has the current action (for indicator)
  const actionView =
    phase === 'requisition' ? 'plot' :
    phase === 'assignment' && G.lastWinner === currentPlayer ? 'jobs' :
    phase === 'swap' ? 'plot' :
    (phase === 'planning' || phase === 'trick') ? 'game' :
    null;

  // Calculate display mode - respect user's panel choice, default to action view
  // When no panel is selected (null), use actionView if there's an action, otherwise 'game'
  const displayMode =
    activePanel === 'jobs' ? 'jobs' :
    activePanel === 'gulag' ? 'gulag' :
    activePanel === 'plot' ? 'plot' :
    activePanel === null ? (actionView || 'game') :
    actionView || 'game';

  return (
    <div className="game-board">
      {/* Navigation bar */}
      <NavBar
        activePanel={activePanel}
        displayMode={displayMode}
        actionView={actionView}
        language={language}
        onTogglePanel={togglePanel}
        onSetActivePanel={setActivePanel}
        onToggleLanguage={toggleLanguage}
      />

      {/* Panel content - only shows for options panel */}
      {activePanel === 'options' && <OptionsPanel language={language} />}

      {/* Main content area */}
      <div className="game-content">
        {/* Trick Area - now HTML instead of SVG */}
        <TrickAreaHTML
          ref={trickAreaRef}
          trick={trickToShow}
          numPlayers={G.numPlayers}
          year={G.year}
          trump={G.trump}
          phase={phase}
          isMyTurn={isMyTurn}
          currentPlayerName={G.players[ctx.currentPlayer]?.name}
          players={G.players}
          currentPlayer={parseInt(ctx.currentPlayer, 10)}
          brigadeLeader={G.players.findIndex(p => p.brigadeLeader)}
          displayMode={displayMode}
          workHours={G.workHours}
          claimedJobs={G.claimedJobs}
          jobBuckets={G.jobBuckets}
          revealedJobs={G.revealedJobs}
          exiled={G.exiled}
          variants={G.variants}
          isFamine={G.isFamine}
          playerPlot={G.players[currentPlayer]?.plot}
          onSetTrump={handleSetTrump}
          highlightedSuits={highlightedSuits}
          lastTrick={G.lastTrick}
          pendingAssignments={G.pendingAssignments}
          assignDragState={assignDragState}
          onAssignDragStart={handleAssignDragStart}
          jobDropRefs={jobDropRefs}
          onSubmitAssignments={handleSubmitAssignments}
          // Swap phase props
          swapDragState={swapDragState}
          onSwapDragStart={handleSwapDragStart}
          plotDropRefs={plotDropRefs}
          swapConfirmed={G.swapConfirmed || {}}
          currentSwapPlayer={phase === 'swap' ? parseInt(ctx.currentPlayer, 10) : null}
          lastSwap={G.lastSwap}
          // Requisition phase props
          requisitionData={G.requisitionData}
          requisitionStage={requisitionStage}
          currentRequisitionSuit={currentRequisitionSuit}
          currentJobStage={currentJobStage}
          flyingExileCards={flyingExileCards}
          // Language
          language={language}
        />

        {/* Flying Card Animation */}
        {flyingCard && (
          <FlyingCard
            key={flyingCard.cardKey}
            card={flyingCard.card}
            playerIdx={flyingCard.playerIdx}
            targetSuit={flyingCard.targetSuit}
            cardValue={flyingCard.card.value}
            onComplete={() => {
              const cardKey = flyingCard.cardKey;
              const targetSuit = flyingCard.targetSuit;
              moves.applySingleAssignment(cardKey, targetSuit);
            }}
          />
        )}

        {/* AI Card Play Animation - bgio-effects handles timing */}
        {currentAiAnimation && (
          <AIPlayCard
            key={currentAiAnimation.key}
            card={currentAiAnimation.card}
            playerIdx={currentAiAnimation.playerIdx}
          />
        )}

        {/* Requisition Flying Exile Cards */}
        {currentJobStage === 'exiling' && flyingExileCards.map((ec) => (
          <FlyingExileCard
            key={ec.id}
            card={ec.card}
            playerIdx={ec.playerIdx}
            delay={ec.delay}
            onComplete={() => {
              setFlyingExileCards(prev => prev.filter(c => c.id !== ec.id));
            }}
          />
        ))}

        {/* Requisition Continue Overlay */}
        {phase === 'requisition' && requisitionStage === 'waiting' && (
          <RequisitionOverlay
            requisitionData={G.requisitionData}
            year={G.year}
            language={language}
            onContinue={() => moves.continueToNextYear()}
          />
        )}

        {/* Player's hand with plot cards */}
        <PlayerHandArea
          phase={phase}
          playerData={G.players[currentPlayer]}
          currentPlayer={currentPlayer}
          isMyTurn={isMyTurn}
          lastWinner={G.lastWinner}
          lastTrick={G.lastTrick}
          pendingAssignments={G.pendingAssignments}
          swapCount={G.swapCount}
          swapConfirmed={G.swapConfirmed}
          currentSwapPlayer={currentSwapPlayer}
          swapConfirmedLocally={swapConfirmedLocally}
          dragState={dragState}
          swapDragState={swapDragState}
          assignDragState={assignDragState}
          plotCardRefs={plotCardRefs}
          handCardRefs={handCardRefs}
          getValidIndices={() => getValidIndices(G, currentPlayer, phase)}
          onDragStart={handleDragStart}
          onSwapDragStart={handleSwapDragStart}
          onAssignDragStart={handleAssignDragStart}
          onSubmitAssignments={handleSubmitAssignments}
          onConfirmSwap={handleConfirmSwap}
          onUndoSwap={() => moves.undoSwap()}
          language={language}
        />

        {/* Drag ghost card */}
        {dragState && (
          <div
            className="drag-ghost"
            style={{
              position: 'fixed',
              left: dragState.position.x - dragState.offset.x,
              top: dragState.position.y - dragState.offset.y,
              transform: 'translate(-50%, -50%)',
              pointerEvents: 'none',
              zIndex: 1000,
            }}
          >
            <img
              src={getCardImagePath(dragState.card)}
              alt="dragging"
              style={{ width: '80px', height: 'auto' }}
            />
          </div>
        )}

        {/* Drop zone highlight */}
        {dragState && (
          <div
            className={`drop-zone-highlight ${dragState.isOverTarget ? 'active' : ''}`}
            style={{
              position: 'fixed',
              ...(() => {
                const slot = document.querySelector('.player-column.right .card-slot');
                if (!slot) return { display: 'none' };
                const rect = slot.getBoundingClientRect();
                return {
                  left: rect.left,
                  top: rect.top,
                  width: rect.width,
                  height: rect.height,
                };
              })(),
              pointerEvents: 'none',
              zIndex: 999,
              border: dragState.isOverTarget ? '3px solid #4CAF50' : '3px dashed #d4a857',
              borderRadius: '8px',
              backgroundColor: dragState.isOverTarget ? 'rgba(76, 175, 80, 0.2)' : 'rgba(212, 168, 87, 0.1)',
            }}
          />
        )}

        {/* Swap drag ghost */}
        {swapDragState && (
          <div
            className="swap-drag-ghost"
            style={{
              position: 'fixed',
              left: swapDragState.position.x - swapDragState.offset.x,
              top: swapDragState.position.y - swapDragState.offset.y,
              transform: 'translate(-50%, -50%) rotate(3deg)',
              pointerEvents: 'none',
              zIndex: 1000,
            }}
          >
            <img
              src={getCardImagePath(swapDragState.card)}
              alt="swapping"
              style={{ width: '90px', height: 'auto', filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.5))' }}
            />
          </div>
        )}

        {/* Assignment drag ghost */}
        {assignDragState && (
          <div
            className="assign-drag-ghost"
            style={{
              position: 'fixed',
              left: assignDragState.position.x - assignDragState.offset.x,
              top: assignDragState.position.y - assignDragState.offset.y,
              transform: 'translate(-50%, -50%) rotate(3deg)',
              pointerEvents: 'none',
              zIndex: 1000,
            }}
          >
            <img
              src={getCardImagePath(assignDragState.card)}
              alt="assigning"
              style={{ width: '90px', height: 'auto', filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.5))' }}
            />
          </div>
        )}

        {/* Swap waiting indicator */}
        {phase === 'swap' && (G.swapConfirmed?.[currentPlayer] || swapConfirmedLocally) && (
          <div className="swap-waiting">
            <span>{t(translations, language, 'waitingForOthers')}</span>
          </div>
        )}
      </div>
    </div>
  );
}

// Helper to get valid card indices
function getValidIndices(G, playerIdx, phase) {
  if (phase !== 'trick') return null;

  const player = G.players[playerIdx];
  if (!player || !player.hand) return [];

  if (G.currentTrick.length === 0) {
    return player.hand.map((_, i) => i);
  }

  const leadSuit = G.currentTrick[0][1].suit;
  const hasLeadSuit = player.hand.some((c) => c.suit === leadSuit);

  if (hasLeadSuit) {
    return player.hand
      .map((c, i) => (c.suit === leadSuit ? i : -1))
      .filter((i) => i >= 0);
  }

  return player.hand.map((_, i) => i);
}
