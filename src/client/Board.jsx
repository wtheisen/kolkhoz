import React, { useState, useEffect, useLayoutEffect, useRef, useCallback } from 'react';
import { useEffectListener } from 'bgio-effects/react';
import { TrickAreaHTML } from './components/TrickAreaHTML.jsx';
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
    // Sort players by score descending for standings display
    const rankedPlayers = G.players
      .map((p, idx) => ({ ...p, idx, score: scores[idx], medals: medals?.[idx] || 0 }))
      .sort((a, b) => b.score - a.score);

    return (
      <div className="game-over">
        {/* Decorative background burst */}
        <div className="victory-burst" />

        {/* Left column: Title + Winner + Button */}
        <div className="game-over-left">
          <div className="game-over-title">
            <div className="victory-star">★</div>
            <h1>{t(translations, language, 'gameOver')}</h1>
            <h2>{t(translations, language, 'winner')}</h2>
          </div>
          <div className="winner-spotlight">
            <div className="winner-medal">
              <span className="medal-star">★</span>
              <span className="medal-rank">1</span>
            </div>
            <div className="winner-info">
              <span className="winner-name">{G.players[winner].name}</span>
              <span className="winner-score">{scores[winner]} {t(translations, language, 'pts')}</span>
            </div>
          </div>
          <div className="game-over-buttons">
            <button className="new-game-btn" onClick={onNewGame}>
              {t(translations, language, 'newGame')}
            </button>
          </div>
        </div>

        {/* Right column: Final standings */}
        <div className="game-over-right">
          <div className="final-standings">
            <div className="standings-header">
              <span className="header-rank">#</span>
              <span className="header-name">{t(translations, language, 'brigade')}</span>
              <span className="header-medals">🏅</span>
              <span className="header-score">{t(translations, language, 'pts')}</span>
            </div>
            {rankedPlayers.map((p, idx) => (
              <div
                key={p.idx}
                className={`standing-row ${p.idx === winner ? 'winner' : ''}`}
                style={{ '--delay': `${idx * 0.1}s` }}
              >
                <span className="standing-rank">{idx + 1}</span>
                <span className="standing-name">{p.name}</span>
                <span className="standing-medals">{p.medals}</span>
                <span className="standing-score">{p.score}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  // Calculate display mode
  const displayMode =
    phase === 'requisition' ? 'plot' :  // Force plot view during requisition
    phase === 'assignment' && G.lastWinner === currentPlayer ? 'jobs' :
    phase === 'swap' ? 'plot' :
    activePanel === 'jobs' ? 'jobs' :
    activePanel === 'gulag' ? 'gulag' :
    activePanel === 'plot' ? 'plot' :
    'game';

  return (
    <div className="game-board">
      {/* Navigation bar - vertical on left side */}
      <div className="mobile-nav-bar">
        <button
          className={`nav-btn ${activePanel === 'options' ? 'active' : ''}`}
          onClick={() => togglePanel('options')}
          title={t(translations, language, 'menu')}
        >
          <span className="nav-icon">☰</span>
          <span className="nav-label">{t(translations, language, 'menu')}</span>
        </button>
        <button
          className={`nav-btn ${displayMode === 'game' && activePanel !== 'options' ? 'active' : ''}`}
          onClick={() => setActivePanel(null)}
          title={t(translations, language, 'brigade')}
        >
          <span className="nav-icon">👥</span>
          <span className="nav-label">{t(translations, language, 'brigade')}</span>
        </button>
        <button
          className={`nav-btn ${displayMode === 'jobs' ? 'active' : ''}`}
          onClick={() => togglePanel('jobs')}
          title={t(translations, language, 'jobs')}
        >
          <span className="nav-icon">⚒</span>
          <span className="nav-label">{t(translations, language, 'jobs')}</span>
        </button>
        <button
          className={`nav-btn ${displayMode === 'gulag' ? 'active' : ''}`}
          onClick={() => togglePanel('gulag')}
          title={t(translations, language, 'theNorth')}
          data-nav="gulag"
        >
          <span className="nav-icon">❄</span>
          <span className="nav-label">{t(translations, language, 'theNorth')}</span>
        </button>
        <button
          className={`nav-btn ${displayMode === 'plot' ? 'active' : ''}`}
          onClick={() => togglePanel('plot')}
          title={t(translations, language, 'plot')}
        >
          <span className="nav-icon">🌱</span>
          <span className="nav-label">{t(translations, language, 'plot')}</span>
        </button>
        <button
          className="nav-btn lang-toggle"
          onClick={toggleLanguage}
          title={t(translations, language, 'toggleLanguage')}
        >
          <span className="nav-icon">{language === 'en' ? '🇷🇺' : '🇬🇧'}</span>
          <span className="nav-label">{language === 'en' ? 'Русский' : 'English'}</span>
        </button>
      </div>

      {/* Panel content - only shows for options panel */}
      {activePanel === 'options' && (
        <div className="mobile-panel-content">
          <div className="options-panel">
            <h3>{t(translations, language, 'menu')}</h3>
            <div className="menu-options">
              <div className="rules-section">
                <h4>{t(translations, language, 'rules')}</h4>
                <div className="rules-text">
                  <h5>{t(translations, language, 'objective')}</h5>
                  <p>{t(translations, language, 'objectiveText')}</p>
                  <h5>{t(translations, language, 'gameplay')}</h5>
                  <p>• {t(translations, language, 'gameplayRule1')}</p>
                  <p>• {t(translations, language, 'gameplayRule2')}</p>
                  <p>• {t(translations, language, 'gameplayRule3')}</p>
                  <h5>{t(translations, language, 'trumpFaceCards')}</h5>
                  <p>• <strong>Jack ({t(translations, language, 'jackName')})</strong>: {t(translations, language, 'jackDesc')}</p>
                  <p>• <strong>Queen ({t(translations, language, 'queenName')})</strong>: {t(translations, language, 'queenDesc')}</p>
                  <p>• <strong>King ({t(translations, language, 'kingName')})</strong>: {t(translations, language, 'kingDesc')}</p>
                </div>
              </div>
              <button className="menu-btn-action" onClick={() => window.location.reload()}>
                🔄 {t(translations, language, 'newGame')}
              </button>
            </div>
          </div>
        </div>
      )}

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
          <div className="requisition-continue-overlay">
            <div className="requisition-summary">
              <h3>{t(translations, language, 'yearComplete', { year: G.year })}</h3>
              {G.requisitionData?.failedJobs?.length > 0 && (
                <p className="failed-jobs">
                  {t(translations, language, 'failed')} {G.requisitionData.failedJobs.map(suit => {
                    const suitSymbols = { Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' };
                    return suitSymbols[suit] || suit;
                  }).join(' ')}
                </p>
              )}
              {G.requisitionData?.exiledCards?.length > 0 && (
                <p className="exiled-count">{t(translations, language, 'cardsToNorth')} {G.requisitionData.exiledCards.length}</p>
              )}
              {(!G.requisitionData?.failedJobs?.length && !G.requisitionData?.exiledCards?.length) && (
                <p className="no-exile">{t(translations, language, 'allJobsComplete')}</p>
              )}
            </div>
            <button
              className="continue-btn"
              onClick={() => moves.continueToNextYear()}
            >
              {t(translations, language, 'continueToYear', { year: G.year + 1 })}
            </button>
          </div>
        )}

        {/* Player's hand with plot cards */}
        <div className={`player-hand-area ${phase === 'assignment' ? 'assignment-mode' : ''} ${phase === 'swap' ? 'swap-mode' : ''}`}>
          {/* ZONE 1: Plot cards (hidden during swap phase - shown in panel instead) */}
          {phase !== 'swap' && (G.players[currentPlayer]?.plot?.revealed?.length > 0 || G.players[currentPlayer]?.plot?.hidden?.length > 0) && (
            <div className="plot-cards-section">
              {G.players[currentPlayer]?.plot?.revealed?.map((card, idx) => {
                const isSwapDragging = swapDragState?.sourceType === 'plot-revealed' && swapDragState?.sourceIndex === idx;
                const isSwapTarget = phase === 'swap' && swapDragState?.sourceType === 'hand';
                const isSwapHover = swapDragState?.dropTarget?.type === 'plot-revealed' && swapDragState?.dropTarget?.index === idx;

                return (
                  <div
                    key={`revealed-${card.suit}-${card.value}`}
                    ref={(el) => { plotCardRefs.current[`revealed-${idx}`] = el; }}
                    className={`plot-card revealed ${phase === 'trick' ? 'dimmed' : ''} ${phase === 'swap' ? 'swappable' : ''} ${isSwapDragging ? 'swap-dragging' : ''} ${isSwapTarget ? 'swap-target' : ''} ${isSwapHover ? 'swap-hover' : ''}`}
                    style={{ '--index': idx }}
                    onMouseDown={(e) => handleSwapDragStart('plot-revealed', idx, card, e)}
                    onTouchStart={(e) => handleSwapDragStart('plot-revealed', idx, card, e)}
                  >
                    <img
                      src={getCardImagePath(card)}
                      alt={`${card.value} of ${card.suit}`}
                      draggable={false}
                    />
                  </div>
                );
              })}
              {G.players[currentPlayer]?.plot?.hidden?.map((card, idx) => {
                const isSwapDragging = swapDragState?.sourceType === 'plot-hidden' && swapDragState?.sourceIndex === idx;
                const isSwapTarget = phase === 'swap' && swapDragState?.sourceType === 'hand';
                const isSwapHover = swapDragState?.dropTarget?.type === 'plot-hidden' && swapDragState?.dropTarget?.index === idx;
                // Total index accounts for revealed cards before hidden
                const totalIdx = (G.players[currentPlayer]?.plot?.revealed?.length || 0) + idx;

                return (
                  <div
                    key={`hidden-${card.suit}-${card.value}`}
                    ref={(el) => { plotCardRefs.current[`hidden-${idx}`] = el; }}
                    className={`plot-card hidden ${phase === 'trick' ? 'dimmed' : ''} ${phase === 'swap' ? 'swappable' : ''} ${isSwapDragging ? 'swap-dragging' : ''} ${isSwapTarget ? 'swap-target' : ''} ${isSwapHover ? 'swap-hover' : ''}`}
                    style={{ '--index': totalIdx }}
                    onMouseDown={(e) => handleSwapDragStart('plot-hidden', idx, card, e)}
                    onTouchStart={(e) => handleSwapDragStart('plot-hidden', idx, card, e)}
                  >
                    <img
                      src={getCardImagePath(card)}
                      alt={`${card.value} of ${card.suit}`}
                      draggable={false}
                    />
                  </div>
                );
              })}
            </div>
          )}

          {/* Divider between plot and hand (non-swap phases) */}
          {phase !== 'swap' && (G.players[currentPlayer]?.plot?.revealed?.length > 0 || G.players[currentPlayer]?.plot?.hidden?.length > 0) && (
            <div className="hand-divider" />
          )}

          {/* Hand cards */}
          <div className="hand-cards-section">
            {G.players[currentPlayer]?.hand.map((card, idx) => {
              const isValid = getValidIndices(G, currentPlayer, phase)?.includes(idx);
              const canPlay = phase === 'trick' && isMyTurn;
              const isDragging = dragState?.index === idx;
              const isSwapDragging = swapDragState?.sourceType === 'hand' && swapDragState?.sourceIndex === idx;
              const isSwapTarget = phase === 'swap' && swapDragState?.sourceType?.startsWith('plot-');
              const isSwapHover = swapDragState?.dropTarget?.type === 'hand' && swapDragState?.dropTarget?.index === idx;

              const handleCardDrag = (e) => {
                if (phase === 'swap') {
                  handleSwapDragStart('hand', idx, card, e);
                } else {
                  handleDragStart(idx, card, e);
                }
              };

              return (
                <div
                  key={`${card.suit}-${card.value}`}
                  ref={(el) => { handCardRefs.current[idx] = el; }}
                  className={`hand-card ${canPlay && isValid ? 'playable' : ''} ${canPlay && !isValid ? 'invalid' : ''} ${isDragging ? 'dragging' : ''} ${phase === 'swap' ? 'swappable' : ''} ${isSwapDragging ? 'swap-dragging' : ''} ${isSwapTarget ? 'swap-target' : ''} ${isSwapHover ? 'swap-hover' : ''}`}
                  onMouseDown={handleCardDrag}
                  onTouchStart={handleCardDrag}
                >
                  <img
                    src={getCardImagePath(card)}
                    alt={`${card.value} of ${card.suit}`}
                    draggable={false}
                  />
                </div>
              );
            })}
          </div>

          {/* Assignment phase: trick cards to the right of hand (only for the player doing the assignment) */}
          {phase === 'assignment' && G.lastWinner === currentPlayer && G.lastTrick?.length > 0 && (() => {
            const allAssigned = G.lastTrick.every(([, card]) => {
              const cardKey = `${card.suit}-${card.value}`;
              return G.pendingAssignments?.[cardKey];
            });

            // Only show unassigned cards in hand area
            const unassignedCards = G.lastTrick.filter(([, card]) => {
              const cardKey = `${card.suit}-${card.value}`;
              return !G.pendingAssignments?.[cardKey];
            });

            return (
              <>
                <div className="hand-divider" />
                {unassignedCards.length > 0 && (
                  <div className="assign-cards-section">
                    {unassignedCards.map(([, card]) => {
                      const cardKey = `${card.suit}-${card.value}`;
                      const isDragging = assignDragState?.cardKey === cardKey;

                      return (
                        <div
                          key={cardKey}
                          className={`hand-card assign-draggable ${isDragging ? 'dragging' : ''}`}
                          onMouseDown={(e) => handleAssignDragStart(cardKey, card, e)}
                          onTouchStart={(e) => handleAssignDragStart(cardKey, card, e)}
                        >
                          <img
                            src={getCardImagePath(card)}
                            alt={`${card.value} of ${card.suit}`}
                            draggable={false}
                          />
                        </div>
                      );
                    })}
                  </div>
                )}
                {allAssigned && (
                  <button className="confirm-assign-btn" onClick={handleSubmitAssignments}>
                    {t(translations, language, 'confirm')}
                  </button>
                )}
              </>
            );
          })()}

          {/* Swap phase: undo and confirm buttons to the right of hand */}
          {phase === 'swap' && currentSwapPlayer === 0 && !G.swapConfirmed?.[currentPlayer] && !swapConfirmedLocally && (
            <div className="swap-buttons">
              {G.swapCount?.[currentPlayer] && (
                <button className="undo-swap-btn" onClick={() => moves.undoSwap()}>
                  {t(translations, language, 'undo')}
                </button>
              )}
              <button className="confirm-swap-btn" onClick={handleConfirmSwap}>
                {t(translations, language, 'confirm')}
              </button>
            </div>
          )}
        </div>

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

// Flying Card Component - uses Web Animations API
function FlyingCard({ card, playerIdx, targetSuit, cardValue, onComplete }) {
  const cardRef = useRef(null);
  const animationRef = useRef(null);
  const onCompleteRef = useRef(onComplete);
  const [showValue, setShowValue] = useState(false);

  // Keep the ref updated with the latest callback
  useEffect(() => {
    onCompleteRef.current = onComplete;
  }, [onComplete]);

  useEffect(() => {
    const slotClasses = ['left', 'center-left', 'center-right', 'right'];
    const slotOrder = [3, 0, 1, 2];
    const slotClass = slotClasses[slotOrder[playerIdx]];

    const sourceSlot = document.querySelector(`.player-column.${slotClass} .card-slot`);
    const targetJob = document.querySelector(`.job-indicator .suit-symbol.${targetSuit.toLowerCase()}`);

    if (!sourceSlot || !targetJob || !cardRef.current) {
      onCompleteRef.current();
      return;
    }

    const sourceRect = sourceSlot.getBoundingClientRect();
    const targetRect = targetJob.getBoundingClientRect();

    const cardRect = cardRef.current.getBoundingClientRect();
    const startScale = sourceRect.width / cardRect.width;
    const endScale = targetRect.width / cardRect.width;

    // Set initial position immediately to prevent jump
    cardRef.current.style.left = `${sourceRect.left + sourceRect.width / 2}px`;
    cardRef.current.style.top = `${sourceRect.top + sourceRect.height / 2}px`;
    cardRef.current.style.transform = `translate(-50%, -50%) scale(${startScale})`;

    const animation = cardRef.current.animate([
      {
        left: `${sourceRect.left + sourceRect.width / 2}px`,
        top: `${sourceRect.top + sourceRect.height / 2}px`,
        transform: `translate(-50%, -50%) scale(${startScale})`
      },
      {
        left: `${targetRect.left + targetRect.width / 2}px`,
        top: `${targetRect.top + targetRect.height / 2}px`,
        transform: `translate(-50%, -50%) scale(${endScale})`
      }
    ], { duration: 650, fill: 'forwards', easing: 'ease-in-out' });

    animationRef.current = animation;

    // Show +X value as card lands
    const valueTimeout = setTimeout(() => setShowValue(true), 570);

    // Delay completion to let the +X number persist
    let completionTimeout;
    animation.onfinish = () => {
      completionTimeout = setTimeout(() => onCompleteRef.current(), 800);
    };

    // Cleanup function
    return () => {
      clearTimeout(valueTimeout);
      clearTimeout(completionTimeout);
      if (animationRef.current) {
        animationRef.current.cancel();
      }
    };
  }, [playerIdx, targetSuit]);  // onComplete removed from deps - using ref instead

  return (
    <div ref={cardRef} className="flying-card-html">
      <img src={getCardImagePath(card)} alt={`${card.value} of ${card.suit}`} />
      {showValue && <span className="flying-value">+{cardValue}</span>}
    </div>
  );
}

// AI Play Card Component - animates AI card from hand area to slot
// Uses CSS transitions with transform-only for GPU acceleration
function AIPlayCard({ card, playerIdx }) {
  const cardRef = useRef(null);

  useLayoutEffect(() => {
    const slotClasses = ['left', 'center-left', 'center-right', 'right'];
    const slotOrder = [3, 0, 1, 2];
    const slotClass = slotClasses[slotOrder[playerIdx]];

    const playerPanel = document.querySelector(`.player-column.${slotClass} .player-panel`);
    const targetSlot = document.querySelector(`.player-column.${slotClass} .card-slot`);

    if (!playerPanel || !targetSlot || !cardRef.current) return;

    const sourceRect = playerPanel.getBoundingClientRect();
    const targetRect = targetSlot.getBoundingClientRect();
    const cardRect = cardRef.current.getBoundingClientRect();

    const startScale = (sourceRect.width * 0.3) / cardRect.width;
    const targetScale = targetRect.width / cardRect.width;

    // Calculate positions - target top-left of the slot
    const startX = sourceRect.left + sourceRect.width / 2;
    const startY = sourceRect.top + sourceRect.height / 2;
    const endX = targetRect.left;
    const endY = targetRect.top;

    // Disable transition, set start position
    cardRef.current.style.transition = 'none';
    cardRef.current.style.transform = `translate(${startX}px, ${startY}px) scale(${startScale})`;

    // Force reflow, then enable transition and animate to target
    cardRef.current.offsetHeight;
    cardRef.current.style.transition = '';
    cardRef.current.style.transform = `translate(${endX}px, ${endY}px) scale(${targetScale})`;
  }, [playerIdx, card.suit, card.value]);

  return (
    <div ref={cardRef} className="ai-play-card">
      <img src={getCardImagePath(card)} alt={`${card.value} of ${card.suit}`} />
    </div>
  );
}

// Flying Exile Card Component - animates cards flying to gulag during requisition
function FlyingExileCard({ card, playerIdx, delay, onComplete }) {
  const cardRef = useRef(null);
  const pointLossRef = useRef(null);
  const animationRef = useRef(null);
  const onCompleteRef = useRef(onComplete);

  // Keep the ref updated with the latest callback
  useEffect(() => {
    onCompleteRef.current = onComplete;
  }, [onComplete]);

  useEffect(() => {
    // Delay start based on stagger
    const delayTimeout = setTimeout(() => {
      // Source: find the card in the plot view by data attribute
      // For player 0, look in the player's plot section
      // For bots, look in the swap-bot-section
      let sourceCard;
      if (playerIdx === 0) {
        sourceCard = document.querySelector(
          `.swap-player-box .swap-card-slot[data-card="${card.suit}-${card.value}"], ` +
          `.swap-player-box .swap-mini-card[data-card="${card.suit}-${card.value}"]`
        );
      } else {
        sourceCard = document.querySelector(
          `.swap-bot-section[data-player="${playerIdx}"] .swap-mini-card[data-card="${card.suit}-${card.value}"]`
        );
      }

      // Target: gulag nav button
      const gulagButton = document.querySelector('.nav-btn[data-nav="gulag"]');

      if (!sourceCard || !gulagButton || !cardRef.current) {
        onCompleteRef.current();
        return;
      }

      const sourceRect = sourceCard.getBoundingClientRect();
      const targetRect = gulagButton.getBoundingClientRect();

      const cardRect = cardRef.current.getBoundingClientRect();
      const startScale = sourceRect.width / cardRect.width;
      const endScale = Math.min(targetRect.width, targetRect.height) / cardRect.width * 0.6;

      // Set initial position
      cardRef.current.style.left = `${sourceRect.left + sourceRect.width / 2}px`;
      cardRef.current.style.top = `${sourceRect.top + sourceRect.height / 2}px`;
      cardRef.current.style.transform = `translate(-50%, -50%) scale(${startScale})`;
      cardRef.current.style.opacity = '1';

      // Position and animate point loss indicator
      if (pointLossRef.current) {
        const pointEl = pointLossRef.current;
        pointEl.style.left = `${sourceRect.left + sourceRect.width / 2}px`;
        pointEl.style.top = `${sourceRect.top}px`;

        // Animate point loss floating up and fading
        pointEl.animate([
          {
            transform: 'translate(-50%, 0) scale(0.5)',
            opacity: 0
          },
          {
            transform: 'translate(-50%, -20px) scale(1.3)',
            opacity: 1,
            offset: 0.15
          },
          {
            transform: 'translate(-50%, -60px) scale(1)',
            opacity: 1,
            offset: 0.5
          },
          {
            transform: 'translate(-50%, -100px) scale(0.9)',
            opacity: 0
          }
        ], { duration: 1200, fill: 'forwards', easing: 'ease-out' });
      }

      const animation = cardRef.current.animate([
        {
          left: `${sourceRect.left + sourceRect.width / 2}px`,
          top: `${sourceRect.top + sourceRect.height / 2}px`,
          transform: `translate(-50%, -50%) scale(${startScale})`,
          opacity: 1
        },
        {
          left: `${targetRect.left + targetRect.width / 2}px`,
          top: `${targetRect.top + targetRect.height / 2}px`,
          transform: `translate(-50%, -50%) scale(${endScale})`,
          opacity: 0.3
        }
      ], { duration: 800, fill: 'forwards', easing: 'ease-in' });

      animationRef.current = animation;
      animation.onfinish = () => onCompleteRef.current();
    }, delay);

    return () => {
      clearTimeout(delayTimeout);
      if (animationRef.current) {
        animationRef.current.cancel();
      }
    };
  }, [card, playerIdx, delay]);  // onComplete removed from deps - using ref instead

  return (
    <>
      <div ref={cardRef} className="flying-exile-card">
        <img src={getCardImagePath(card)} alt={`${card.value} of ${card.suit}`} />
      </div>
      <div ref={pointLossRef} className="exile-point-loss">
        -{card.value}
      </div>
    </>
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
