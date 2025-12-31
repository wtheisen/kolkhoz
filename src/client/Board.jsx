import React, { useState, useEffect, useRef, useMemo } from 'react';
import { CardSVG } from './components/CardSVG.jsx';
import { Hand } from './components/Hand.jsx';
import { TrickArea } from './components/TrickArea.jsx';
import { JobPilesArea } from './components/JobPilesArea.jsx';
import { RightSidebar } from './components/RightSidebar.jsx';
import { AssignmentDragDrop } from './components/AssignmentDragDrop.jsx';
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

  // Track window size for responsive scaling
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // Calculate layout dynamically based on sidebar visibility
  // Sidebars are hidden when viewport <= 1024px (matches CSS media query)
  const sidebarsVisible = windowWidth > 1024;

  // SVG coordinate space: 1920x1080
  // Left sidebar (jobs): 0-350, Right sidebar: 1570-1920
  const leftBound = sidebarsVisible ? 350 : 0;
  const rightBound = sidebarsVisible ? 1570 : 1920;
  const availableWidth = rightBound - leftBound;

  // Scale factor: how much larger the play area is compared to desktop baseline
  const desktopPlayWidth = 1220; // 1570 - 350
  const scaleFactor = availableWidth / desktopPlayWidth;

  // Reset local swap confirmation when year changes
  useEffect(() => {
    if (G.year !== lastYearRef.current) {
      setSwapConfirmedLocally(false);
      lastYearRef.current = G.year;
    }
  }, [G.year]);

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

  // Center of play area - calculated from visible bounds
  const playCenterX = (leftBound + rightBound) / 2;
  const playCenterY = 470; // Moved down so top border fully visible

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
      {/* Trump selection UI */}
      {phase === 'planning' && !G.trump && (
        <div className="trump-selection">
          <h3 title="Select Trump Suit">Выберите главную задачу</h3>
          <div className="suit-buttons">
            {SUITS.map((suit) => {
              const suitNames = {
                Hearts: { ru: 'Пшеница', en: 'Hearts (Wheat)' },
                Diamonds: { ru: 'Свёкла', en: 'Diamonds (Beets)' },
                Clubs: { ru: 'Картофель', en: 'Clubs (Potatoes)' },
                Spades: { ru: 'Подсолнечник', en: 'Spades (Sunflowers)' },
              };
              return (
                <button
                  key={suit}
                  onClick={() => handleSetTrump(suit)}
                  className={`suit-btn ${suit.toLowerCase()}`}
                  title={suitNames[suit].en}
                >
                  {getSuitSymbol(suit)} {suitNames[suit].ru}
                </button>
              );
            })}
          </div>
        </div>
      )}

      {/* Main SVG board */}
      <svg ref={svgRef} viewBox="0 0 1920 1080" className="board-svg">
        {/* Job Piles (left side) */}
        <JobPilesArea
          revealedJobs={G.revealedJobs}
          workHours={G.workHours}
          jobBuckets={G.jobBuckets}
          claimedJobs={G.claimedJobs}
          trump={G.trump}
          phase={phase}
          pendingAssignments={G.pendingAssignments}
          onAssign={handleAssign}
          lastTrick={G.lastTrick}
        />

        {/* Trick Area (center) - includes bot player areas */}
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
          showInfo={!sidebarsVisible}
          players={G.players}
          currentPlayer={parseInt(ctx.currentPlayer, 10)}
          brigadeLeader={G.players.findIndex(p => p.brigadeLeader)}
          displayMode={phase === 'assignment' ? 'jobs' : !sidebarsVisible && activePanel === 'jobs' ? 'jobs' : !sidebarsVisible && activePanel === 'gulag' ? 'gulag' : 'game'}
          workHours={G.workHours}
          claimedJobs={G.claimedJobs}
          jobBuckets={G.jobBuckets}
          revealedJobs={G.revealedJobs}
          exiled={G.exiled}
        />

        {/* Right Sidebar with game info and gulag */}
        <RightSidebar
          year={G.year}
          trump={G.trump}
          phase={phase}
          currentPlayer={ctx.currentPlayer}
          players={G.players}
          isMyTurn={isMyTurn}
          exiled={G.exiled}
        />
      </svg>

      {/* Mobile navigation bar - vertical on left side */}
      {!sidebarsVisible && (
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
        </div>
      )}

      {/* Mobile panel content - only shows for options panel (jobs/gulag now in SVG) */}
      {!sidebarsVisible && activePanel === 'options' && (
        <div className="mobile-panel-content">
          {/* Options/Menu Panel */}
          {activePanel === 'options' && (
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
          )}

        </div>
      )}

      {/* Player's hand (HTML for interactivity) */}
      <Hand
        cards={G.players[currentPlayer]?.hand || []}
        onPlayCard={handlePlayCard}
        canPlay={phase === 'trick' && isMyTurn}
        leadSuit={G.currentTrick[0]?.[1]?.suit}
        trump={G.trump}
        validIndices={getValidIndices(G, currentPlayer, phase)}
        className={phase === 'assignment' ? 'shifted' : ''}
      />

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

      {/* Swap phase UI */}
      {phase === 'swap' && !G.swapConfirmed?.[currentPlayer] && !swapConfirmedLocally && (
        <div className="swap-ui">
          <h3>Swap Cards (Year {G.year})</h3>
          <p>Select a card from your hand and one from your plot to swap, or skip</p>

          <div className="swap-section">
            <h4>Your Hand</h4>
            <div className="swap-cards">
              {G.players[currentPlayer]?.hand.map((card, idx) => (
                <div
                  key={`hand-${idx}`}
                  className={`swap-card ${selectedHandCard === idx ? 'selected' : ''}`}
                  onClick={() => setSelectedHandCard(selectedHandCard === idx ? null : idx)}
                >
                  <CardSVG card={card} width={80} />
                </div>
              ))}
            </div>
          </div>

          {G.players[currentPlayer]?.plot.revealed.length > 0 && (
            <div className="swap-section">
              <h4>Your Revealed Cards (Rewards)</h4>
              <div className="swap-cards">
                {G.players[currentPlayer]?.plot.revealed.map((card, idx) => (
                  <div
                    key={`revealed-${idx}`}
                    className={`swap-card ${selectedPlotCard === idx && selectedPlotType === 'revealed' ? 'selected' : ''}`}
                    onClick={() => handleSelectPlotCard(idx, 'revealed')}
                  >
                    <CardSVG card={card} width={80} />
                  </div>
                ))}
              </div>
            </div>
          )}

          {G.players[currentPlayer]?.plot.hidden.length > 0 && (
            <div className="swap-section">
              <h4>Your Hidden Plot</h4>
              <div className="swap-cards">
                {G.players[currentPlayer]?.plot.hidden.map((card, idx) => (
                  <div
                    key={`hidden-${idx}`}
                    className={`swap-card ${selectedPlotCard === idx && selectedPlotType === 'hidden' ? 'selected' : ''}`}
                    onClick={() => handleSelectPlotCard(idx, 'hidden')}
                  >
                    <CardSVG card={card} width={80} />
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="swap-buttons">
            <button
              onClick={handleSwap}
              disabled={selectedHandCard === null || selectedPlotCard === null || selectedPlotType === null}
            >
              Swap Selected Cards
            </button>
            <button onClick={handleConfirmSwap}>
              Done Swapping
            </button>
          </div>
        </div>
      )}

      {/* Waiting for others during swap */}
      {phase === 'swap' && (G.swapConfirmed?.[currentPlayer] || swapConfirmedLocally) && (
        <div className="swap-ui">
          <h3>Waiting for other players...</h3>
        </div>
      )}

      {/* Player's plot */}
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
