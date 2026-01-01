import React, { useState, useEffect, useRef } from 'react';
import { CardSVG } from './components/CardSVG.jsx';
import { TrickArea } from './components/TrickArea.jsx';
import { AssignmentDragDrop } from './components/AssignmentDragDrop.jsx';
import { SwapDragDrop } from './components/SwapDragDrop.jsx';
import { PlayCardDragDrop } from './components/PlayCardDragDrop.jsx';
import { SUITS } from '../game/constants.js';
import { getCardImagePath } from '../game/Card.js';

export function Board({ G, ctx, moves, playerID }) {
  const currentPlayer = parseInt(playerID, 10);
  const isMyTurn = ctx.currentPlayer === playerID;
  const phase = ctx.phase;

  // State for swap phase
  const [selectedHandCard, setSelectedHandCard] = useState(null);
  const [selectedPlotCard, setSelectedPlotCard] = useState(null);
  const [selectedPlotType, setSelectedPlotType] = useState(null); // 'hidden' or 'revealed'

  // State for tap-to-reveal on touch devices
  const [revealedHiddenCard, setRevealedHiddenCard] = useState(null);

  // Mobile panel toggle - null = game board, 'options' | 'jobs' | 'gulag'
  const [activePanel, setActivePanel] = useState(null);
  const togglePanel = (panel) => setActivePanel(activePanel === panel ? null : panel);

  // Track if user has confirmed swap locally (to prevent modal reappearing due to race conditions)
  const [swapConfirmedLocally, setSwapConfirmedLocally] = useState(false);
  const lastYearRef = useRef(G.year);

  // Ref to SVG element for coordinate conversion in drag-drop
  const svgRef = useRef(null);

  // SVG uses full width - no sidebars, nav bar is separate HTML element
  const scaleFactor = 1;

  // AI Assignment Animation state
  const [flyingCards, setFlyingCards] = useState([]);
  const prevJobBucketsRef = useRef(null);
  const prevPhaseRef = useRef(phase);
  const lastTrickSnapshotRef = useRef(null);

  // AI Card Play Animation state - temporarily disabled
  // const [aiPlayingCard, setAiPlayingCard] = useState(null);
  // const prevTrickLengthRef = useRef(G.currentTrick?.length || 0);

  // Snapshot the trick when entering assignment phase
  useEffect(() => {
    if (phase === 'assignment' && prevPhaseRef.current !== 'assignment') {
      // Just entered assignment phase - snapshot the trick for potential animation
      lastTrickSnapshotRef.current = {
        trick: G.lastTrick,
        winner: G.lastWinner,
        jobBuckets: JSON.parse(JSON.stringify(G.jobBuckets)),
      };
    }
    prevPhaseRef.current = phase;
  }, [phase, G.lastTrick, G.lastWinner, G.jobBuckets]);

  // Detect AI assignment completion and trigger animation
  useEffect(() => {
    // Only animate if AI won (not the human player)
    if (G.lastWinner === currentPlayer) {
      prevJobBucketsRef.current = G.jobBuckets;
      return;
    }

    // Check if jobBuckets changed (cards were assigned)
    const snapshot = lastTrickSnapshotRef.current;
    if (!snapshot || !prevJobBucketsRef.current) {
      prevJobBucketsRef.current = G.jobBuckets;
      return;
    }

    // Find newly assigned cards by comparing bucket sizes
    const newCards = [];
    for (const suit of SUITS) {
      const prevCount = prevJobBucketsRef.current[suit]?.length || 0;
      const newCount = G.jobBuckets[suit]?.length || 0;
      if (newCount > prevCount) {
        // Cards were added to this suit's bucket
        const addedCards = G.jobBuckets[suit].slice(prevCount);
        addedCards.forEach(card => {
          newCards.push({ card, targetSuit: suit });
        });
      }
    }

    // If cards were assigned by AI, animate them
    if (newCards.length > 0 && snapshot.trick && svgRef.current) {
      const svgRect = svgRef.current.getBoundingClientRect();
      const viewBoxWidth = 1920;
      const viewBoxHeight = 1080;
      const scaleX = svgRect.width / viewBoxWidth;
      const scaleY = svgRect.height / viewBoxHeight;

      // TrickArea dimensions (must match TrickArea.jsx)
      const centerX = 960;
      const centerY = 470;
      const width = 1100;
      const height = 540;
      const cardSpacing = 265;

      // Calculate card source positions (trick card slots)
      const getCardPosition = (playerIdx) => {
        const slotOrder = [3, 0, 1, 2];
        const slot = slotOrder[playerIdx];
        const startX = -1.5 * cardSpacing;
        return { x: centerX + startX + slot * cardSpacing, y: centerY + 85 };
      };

      // Calculate job icon target positions (info bar)
      const leftEdge = centerX - width / 2 + 20;
      const infoY = centerY - height / 2 + 38;
      const jobStartX = leftEdge + 320;
      const jobSpacing = 70;
      const suitIndex = { Hearts: 0, Diamonds: 1, Clubs: 2, Spades: 3 };

      const getJobPosition = (suit) => {
        const idx = suitIndex[suit];
        return { x: jobStartX + idx * jobSpacing, y: infoY };
      };

      // Create flying card animations
      const animations = newCards.map((item, index) => {
        // Find which player played this card in the trick
        const trickEntry = snapshot.trick.find(([, c]) =>
          c.suit === item.card.suit && c.value === item.card.value
        );
        const playerIdx = trickEntry ? trickEntry[0] : 0;

        const sourcePos = getCardPosition(playerIdx);
        const targetPos = getJobPosition(item.targetSuit);

        // Convert SVG coords to screen coords
        const fromX = svgRect.left + sourcePos.x * scaleX;
        const fromY = svgRect.top + sourcePos.y * scaleY;
        const toX = svgRect.left + targetPos.x * scaleX;
        const toY = svgRect.top + targetPos.y * scaleY;

        return {
          id: `${item.card.suit}-${item.card.value}-${Date.now()}-${index}`,
          card: item.card,
          fromX,
          fromY,
          toX,
          toY,
          delay: index * 100, // Stagger animations
        };
      });

      setFlyingCards(animations);

      // Clear animations after they complete
      const maxDelay = animations.length * 100;
      setTimeout(() => {
        setFlyingCards([]);
        lastTrickSnapshotRef.current = null;
      }, 500 + maxDelay);
    }

    prevJobBucketsRef.current = G.jobBuckets;
  }, [G.jobBuckets, G.lastWinner, currentPlayer]);

  // Reset local swap confirmation when year changes
  useEffect(() => {
    if (G.year !== lastYearRef.current) {
      setSwapConfirmedLocally(false);
      lastYearRef.current = G.year;
    }
  }, [G.year]);

  // AI card play animation - temporarily disabled for debugging
  // TODO: Re-enable after fixing infinite loop issue

  // Handle card play
  const handlePlayCard = (cardIndex) => {
    if (phase === 'trick' && isMyTurn) {
      moves.playCard(cardIndex);
    }
  };

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

  // Handle swap phase
  const handleSwap = () => {
    if (selectedHandCard !== null && selectedPlotCard !== null && selectedPlotType !== null) {
      moves.swapCard(selectedPlotCard, selectedHandCard, selectedPlotType);
      setSelectedHandCard(null);
      setSelectedPlotCard(null);
      setSelectedPlotType(null);
    }
  };

  // Handle plot card selection for swap
  const handleSelectPlotCard = (idx, type) => {
    if (selectedPlotCard === idx && selectedPlotType === type) {
      // Deselect
      setSelectedPlotCard(null);
      setSelectedPlotType(null);
    } else {
      setSelectedPlotCard(idx);
      setSelectedPlotType(type);
    }
  };

  const handleConfirmSwap = () => {
    setSwapConfirmedLocally(true);
    moves.confirmSwap();
  };

  // Center of play area - full width SVG
  const playCenterX = 960; // Center of 1920
  const playCenterY = 450; // Centered between top and hand

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
        {/* SVG container - scales to fill available space */}
        <div className="svg-container">
          <svg ref={svgRef} viewBox="0 0 1920 1080" className="board-svg" preserveAspectRatio="xMidYMid slice">
            {/* Trick Area (center) - includes bot player areas and info */}
            <TrickArea
              trick={phase === 'assignment' ? G.lastTrick : G.currentTrick}
              numPlayers={G.numPlayers}
              lead={G.lead}
              centerX={playCenterX}
              centerY={playCenterY}
              scale={scaleFactor}
              year={G.year}
              trump={G.trump}
              phase={phase}
              isMyTurn={isMyTurn}
              currentPlayerName={G.players[ctx.currentPlayer]?.name}
              showInfo={true}
              players={G.players}
              currentPlayer={parseInt(ctx.currentPlayer, 10)}
              brigadeLeader={G.players.findIndex(p => p.brigadeLeader)}
              displayMode={
                phase === 'assignment' ? 'jobs' :
                phase === 'swap' ? 'plot' :
                activePanel === 'jobs' ? 'jobs' :
                activePanel === 'gulag' ? 'gulag' :
                activePanel === 'plot' ? 'plot' :
                'game'
              }
              workHours={G.workHours}
              claimedJobs={G.claimedJobs}
              jobBuckets={G.jobBuckets}
              revealedJobs={G.revealedJobs}
              exiled={G.exiled}
              playerPlot={G.players[currentPlayer]?.plot}
              onSetTrump={handleSetTrump}
            />
          </svg>

          {/* Assignment phase UI - Drag and Drop */}
          {phase === 'assignment' && G.lastWinner === currentPlayer && (
            <AssignmentDragDrop
              lastTrick={G.lastTrick}
              pendingAssignments={G.pendingAssignments}
              onAssign={handleAssign}
              onSubmit={handleSubmitAssignments}
              svgRef={svgRef}
              centerY={playCenterY}
              scale={scaleFactor}
            />
          )}

          {/* Swap phase UI - Drag and Drop */}
          {phase === 'swap' && !G.swapConfirmed?.[currentPlayer] && !swapConfirmedLocally && (
            <SwapDragDrop
              hand={G.players[currentPlayer]?.hand || []}
              plot={G.players[currentPlayer]?.plot}
              onSwap={(plotIdx, handIdx, plotType) => moves.swapCard(plotIdx, handIdx, plotType)}
              onConfirm={handleConfirmSwap}
              svgRef={svgRef}
              centerY={playCenterY}
              scale={scaleFactor}
              year={G.year}
            />
          )}

          {/* Waiting for others during swap */}
          {phase === 'swap' && (G.swapConfirmed?.[currentPlayer] || swapConfirmedLocally) && (
            <div className="swap-ui">
              <h3>Waiting for other players...</h3>
            </div>
          )}

          {/* Player's hand - always shown via drag-drop component */}
          <PlayCardDragDrop
            hand={G.players[currentPlayer]?.hand || []}
            onPlayCard={handlePlayCard}
            canPlay={phase === 'trick' && isMyTurn}
            validIndices={getValidIndices(G, currentPlayer, phase)}
            svgRef={svgRef}
            centerX={playCenterX}
            centerY={playCenterY}
            cardWidth={280}
            cardSpacing={350}
          />

          {/* Player's plot - desktop only */}
          <div className="player-plot">
            <h4 title="Your Plot (Cellar)">Подвал</h4>
            <div className="plot-cards">
              {G.players[currentPlayer]?.plot.revealed.map((card, idx) => (
                <CardSVG key={`r-${idx}`} card={card} width={60} />
              ))}
              {G.players[currentPlayer]?.plot.hidden.map((card, idx) => (
                <div
                  key={`h-${idx}`}
                  className={`hidden-plot-card ${revealedHiddenCard === idx ? 'revealed' : ''}`}
                  title="Tap to reveal"
                  onClick={() => setRevealedHiddenCard(revealedHiddenCard === idx ? null : idx)}
                >
                  <CardSVG card={card} width={60} faceDown className="card-back" />
                  <CardSVG card={card} width={60} className="card-front" />
                </div>
              ))}
            </div>
          </div>

          {/* AI Assignment Flying Cards Animation */}
          {flyingCards.map((fc) => (
            <div
              key={fc.id}
              className="ai-flying-card"
              style={{
                '--from-x': `${fc.fromX}px`,
                '--from-y': `${fc.fromY}px`,
                '--to-x': `${fc.toX}px`,
                '--to-y': `${fc.toY}px`,
                '--delay': `${fc.delay}ms`,
              }}
            >
              <img
                src={getCardImagePath(fc.card)}
                alt={`${fc.card.value} of ${fc.card.suit}`}
                width={80}
                height={112}
              />
            </div>
          ))}

          {/* AI Card Play Animation - temporarily disabled */}
        </div>

      </div>
    </div>
  );
}

// Helper to get suit symbol
function getSuitSymbol(suit) {
  const symbols = {
    Hearts: '♥',
    Diamonds: '♦',
    Clubs: '♣',
    Spades: '♠',
  };
  return symbols[suit] || suit;
}

// Helper to get valid card indices
function getValidIndices(G, playerIdx, phase) {
  if (phase !== 'trick') return null;

  const player = G.players[playerIdx];
  if (!player || !player.hand) return [];

  if (G.currentTrick.length === 0) {
    // First card - all valid
    return player.hand.map((_, i) => i);
  }

  const leadSuit = G.currentTrick[0][1].suit;
  const hasLeadSuit = player.hand.some((c) => c.suit === leadSuit);

  if (hasLeadSuit) {
    return player.hand
      .map((c, i) => (c.suit === leadSuit ? i : -1))
      .filter((i) => i >= 0);
  }

  // Can't follow suit - all valid
  return player.hand.map((_, i) => i);
}
