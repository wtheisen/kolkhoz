import React, { useState, useEffect, useRef } from 'react';
import { TrickAreaHTML } from './components/TrickAreaHTML.jsx';
import { getCardImagePath } from '../game/Card.js';

export function Board({ G, ctx, moves, playerID }) {
  const currentPlayer = parseInt(playerID, 10);
  const isMyTurn = ctx.currentPlayer === playerID;
  const phase = ctx.phase;

  // Mobile panel toggle
  const [activePanel, setActivePanel] = useState(null);
  const togglePanel = (panel) => setActivePanel(activePanel === panel ? null : panel);

  // Track if user has confirmed swap locally
  const [swapConfirmedLocally, setSwapConfirmedLocally] = useState(false);
  const lastYearRef = useRef(G.year);

  // Ref to trick area for getting card slot positions
  const trickAreaRef = useRef(null);

  // Drag state for playing cards
  const [dragState, setDragState] = useState(null);

  // AI card play animation state
  const [aiPlayingCard, setAiPlayingCard] = useState(null);
  const prevTrickLengthRef = useRef(0);

  // Detect when AI plays a card and trigger animation
  useEffect(() => {
    if (phase !== 'trick') {
      prevTrickLengthRef.current = 0;
      return;
    }

    const currentLength = G.currentTrick.length;
    const prevLength = prevTrickLengthRef.current;

    // A new card was added
    if (currentLength > prevLength && currentLength > 0) {
      const [playerIdx, card] = G.currentTrick[currentLength - 1];

      // Only animate for AI players (not player 0)
      if (playerIdx !== 0) {
        setAiPlayingCard({ playerIdx, card, key: `${card.suit}-${card.value}` });
      }
    }

    prevTrickLengthRef.current = currentLength;
  }, [G.currentTrick, phase]);

  // Reset local swap confirmation when year changes
  useEffect(() => {
    if (G.year !== lastYearRef.current) {
      setSwapConfirmedLocally(false);
      lastYearRef.current = G.year;
    }
  }, [G.year]);

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
    // Filter out the card currently being animated
    trickToShow = aiPlayingCard
      ? G.currentTrick.filter(([, card]) =>
          `${card.suit}-${card.value}` !== aiPlayingCard.key
        )
      : G.currentTrick;
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
    const { winner, scores } = ctx.gameover;
    return (
      <div className="game-over">
        <h1>Game Over!</h1>
        <h2>Winner: {G.players[winner].name}</h2>
        <div className="final-scores">
          {G.players.map((p, idx) => (
            <div key={idx} className={idx === winner ? 'winner' : ''}>
              {p.name}: {scores[idx]} points
            </div>
          ))}
        </div>
        <p>(Lowest score wins)</p>
      </div>
    );
  }

  // Calculate display mode
  const displayMode =
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
          title="Menu"
        >
          <span className="nav-icon">☰</span>
          <span className="nav-label">Menu</span>
        </button>
        <button
          className={`nav-btn ${activePanel === null ? 'active' : ''}`}
          onClick={() => setActivePanel(null)}
          title="Brigade (Playing Area)"
        >
          <span className="nav-icon">👥</span>
          <span className="nav-label" title="Brigade">Бригада</span>
        </button>
        <button
          className={`nav-btn ${activePanel === 'jobs' ? 'active' : ''}`}
          onClick={() => togglePanel('jobs')}
          title="Jobs"
        >
          <span className="nav-icon">⚒</span>
          <span className="nav-label" title="Jobs">Работы</span>
        </button>
        <button
          className={`nav-btn ${activePanel === 'gulag' ? 'active' : ''}`}
          onClick={() => togglePanel('gulag')}
          title="The North (Gulag)"
        >
          <span className="nav-icon">❄</span>
          <span className="nav-label" title="The North">Север</span>
        </button>
        <button
          className={`nav-btn ${activePanel === 'plot' ? 'active' : ''}`}
          onClick={() => togglePanel('plot')}
          title="Your Plot (Cellar)"
        >
          <span className="nav-icon">🌱</span>
          <span className="nav-label" title="Plot">Подвал</span>
        </button>
      </div>

      {/* Panel content - only shows for options panel */}
      {activePanel === 'options' && (
        <div className="mobile-panel-content">
          <div className="options-panel">
            <h3 title="Menu">Меню</h3>
            <div className="menu-options">
              <div className="rules-section">
                <h4>Kolkhoz Rules</h4>
                <div className="rules-text">
                  <h5>Objective</h5>
                  <p>Complete collective farm jobs while protecting your private plot. Lowest score wins!</p>
                  <h5>Gameplay</h5>
                  <p>• Play cards to tricks - must follow lead suit if able</p>
                  <p>• Trick winner assigns cards to matching job suits</p>
                  <p>• Jobs need 40 work hours to complete</p>
                  <h5>Trump Face Cards</h5>
                  <p>• <strong>Jack (Пьяница)</strong>: Worth 0 hours, gets exiled instead of your cards</p>
                  <p>• <strong>Queen (Доносчик)</strong>: All players become vulnerable</p>
                  <p>• <strong>King (Чиновник)</strong>: Exiles two cards instead of one</p>
                </div>
              </div>
              <button className="menu-btn-action" onClick={() => window.location.reload()}>
                🔄 New Game
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
          playerPlot={G.players[currentPlayer]?.plot}
          onSetTrump={handleSetTrump}
          highlightedSuits={highlightedSuits}
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

        {/* AI Card Play Animation */}
        {aiPlayingCard && (
          <AIPlayCard
            key={aiPlayingCard.key}
            card={aiPlayingCard.card}
            playerIdx={aiPlayingCard.playerIdx}
            onComplete={() => setAiPlayingCard(null)}
          />
        )}

        {/* Player's hand with plot cards */}
        <div className="player-hand-area">
          {/* Plot cards on the left */}
          {(G.players[currentPlayer]?.plot?.revealed?.length > 0 || G.players[currentPlayer]?.plot?.hidden?.length > 0) && (
            <>
              <div className="plot-cards-section">
                {G.players[currentPlayer]?.plot?.revealed?.map((card, idx) => (
                  <div key={`revealed-${card.suit}-${card.value}`} className="plot-card revealed">
                    <img
                      src={getCardImagePath(card)}
                      alt={`${card.value} of ${card.suit}`}
                      draggable={false}
                    />
                  </div>
                ))}
                {G.players[currentPlayer]?.plot?.hidden?.map((card, idx) => (
                  <div key={`hidden-${card.suit}-${card.value}`} className="plot-card hidden">
                    <img
                      src={getCardImagePath(card)}
                      alt={`${card.value} of ${card.suit}`}
                      draggable={false}
                    />
                  </div>
                ))}
              </div>
              <div className="hand-divider" />
            </>
          )}

          {/* Hand cards */}
          <div className="hand-cards-section">
            {G.players[currentPlayer]?.hand.map((card, idx) => {
              const isValid = getValidIndices(G, currentPlayer, phase)?.includes(idx);
              const canPlay = phase === 'trick' && isMyTurn;
              const isDragging = dragState?.index === idx;

              return (
                <div
                  key={`${card.suit}-${card.value}`}
                  className={`hand-card ${canPlay && isValid ? 'playable' : ''} ${canPlay && !isValid ? 'invalid' : ''} ${isDragging ? 'dragging' : ''}`}
                  onMouseDown={(e) => handleDragStart(idx, card, e)}
                  onTouchStart={(e) => handleDragStart(idx, card, e)}
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

        {/* Swap phase UI */}
        {phase === 'swap' && !G.swapConfirmed?.[currentPlayer] && !swapConfirmedLocally && (
          <div className="swap-overlay">
            <button className="swap-confirm-btn" onClick={handleConfirmSwap}>
              Confirm (No Swap)
            </button>
          </div>
        )}

        {phase === 'swap' && (G.swapConfirmed?.[currentPlayer] || swapConfirmedLocally) && (
          <div className="swap-waiting">
            <h3>Waiting for other players...</h3>
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
  const [showValue, setShowValue] = useState(false);

  useEffect(() => {
    const slotClasses = ['left', 'center-left', 'center-right', 'right'];
    const slotOrder = [3, 0, 1, 2];
    const slotClass = slotClasses[slotOrder[playerIdx]];

    const sourceSlot = document.querySelector(`.player-column.${slotClass} .card-slot`);
    const targetJob = document.querySelector(`.job-indicator .suit-symbol.${targetSuit.toLowerCase()}`);

    if (!sourceSlot || !targetJob || !cardRef.current) {
      onComplete();
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
    ], { duration: 950, fill: 'forwards', easing: 'ease-in-out' });

    animationRef.current = animation;

    // Show +X value at 60% through
    const valueTimeout = setTimeout(() => setShowValue(true), 570);

    // Delay completion to let the +X number persist
    let completionTimeout;
    animation.onfinish = () => {
      completionTimeout = setTimeout(onComplete, 800);
    };

    // Cleanup function
    return () => {
      clearTimeout(valueTimeout);
      clearTimeout(completionTimeout);
      if (animationRef.current) {
        animationRef.current.cancel();
      }
    };
  }, [playerIdx, targetSuit, onComplete]);

  return (
    <div ref={cardRef} className="flying-card-html">
      <img src={getCardImagePath(card)} alt={`${card.value} of ${card.suit}`} />
      {showValue && <span className="flying-value">+{cardValue}</span>}
    </div>
  );
}

// AI Play Card Component - animates AI card from hand area to slot
function AIPlayCard({ card, playerIdx, onComplete }) {
  const cardRef = useRef(null);
  const animationRef = useRef(null);

  useEffect(() => {
    const slotClasses = ['left', 'center-left', 'center-right', 'right'];
    const slotOrder = [3, 0, 1, 2];
    const slotClass = slotClasses[slotOrder[playerIdx]];

    // Source: the mini card in the player's hand display
    const miniCard = document.querySelector(`.player-column.${slotClass} .player-panel .mini-card`);
    const playerPanel = document.querySelector(`.player-column.${slotClass} .player-panel`);
    // Target: the card slot
    const targetSlot = document.querySelector(`.player-column.${slotClass} .card-slot`);

    if (!playerPanel || !targetSlot || !cardRef.current) {
      // If elements not found, complete immediately
      onComplete();
      return;
    }

    const sourceRect = miniCard ? miniCard.getBoundingClientRect() : playerPanel.getBoundingClientRect();
    const targetRect = targetSlot.getBoundingClientRect();

    // Calculate scales based on source (mini card) and target (card slot) sizes
    const cardRect = cardRef.current.getBoundingClientRect();
    const startScale = (miniCard ? sourceRect.width : sourceRect.width * 0.3) / cardRect.width;
    const targetScale = targetRect.width / cardRect.width;

    // Set initial position immediately to prevent jump
    cardRef.current.style.left = `${sourceRect.left + sourceRect.width / 2}px`;
    cardRef.current.style.top = `${sourceRect.top + sourceRect.height / 2}px`;
    cardRef.current.style.transform = `translate(-50%, -50%) scale(${startScale})`;

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
        transform: `translate(-50%, -50%) scale(${targetScale})`,
        opacity: 1
      }
    ], { duration: 800, fill: 'forwards', easing: 'ease-out' });

    animationRef.current = animation;
    animation.onfinish = onComplete;

    // Cleanup function
    return () => {
      if (animationRef.current) {
        animationRef.current.cancel();
      }
    };
  }, [playerIdx, onComplete]);

  return (
    <div ref={cardRef} className="ai-play-card">
      <img src={getCardImagePath(card)} alt={`${card.value} of ${card.suit}`} />
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
