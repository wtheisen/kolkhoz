import React, { useState, useEffect, useRef, useMemo } from 'react';
import { CardSVG } from './components/CardSVG.jsx';
import { Hand } from './components/Hand.jsx';
import { TrickArea } from './components/TrickArea.jsx';
import { JobPilesArea } from './components/JobPilesArea.jsx';
import { PlayerArea } from './components/PlayerArea.jsx';
import { RightSidebar } from './components/RightSidebar.jsx';
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

  // Mobile panel toggles
  const [showJobsPanel, setShowJobsPanel] = useState(false);
  const [showInfoPanel, setShowInfoPanel] = useState(false);
  const [showMenuPanel, setShowMenuPanel] = useState(false);
  const [showRules, setShowRules] = useState(false);

  // Track if user has confirmed swap locally (to prevent modal reappearing due to race conditions)
  const [swapConfirmedLocally, setSwapConfirmedLocally] = useState(false);
  const lastYearRef = useRef(G.year);

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
  const playCenterY = 460;

  // Player positions - align with top button row
  // Buttons are at CSS top:10px with 44px height, center at ~32px viewport
  // Map to SVG: ~75 units at typical viewport, scaled for different widths
  const playerY = 80;
  const playerSpacing = 320 * scaleFactor;
  const getPlayerPosition = (idx, total) => {
    const positions = [
      { x: playCenterX, y: 800 },                     // Bottom (human) - not rendered
      { x: playCenterX - playerSpacing, y: playerY }, // Top-left
      { x: playCenterX, y: playerY },                 // Top-center
      { x: playCenterX + playerSpacing, y: playerY }, // Top-right
    ];
    return positions[idx] || positions[0];
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
      <svg viewBox="0 0 1920 1080" className="board-svg">
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

        {/* Trick Area (center) */}
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
        />

        {/* Other players */}
        {G.players.map((player, idx) => {
          if (idx === currentPlayer) return null;
          const pos = getPlayerPosition(idx, G.numPlayers);
          return (
            <PlayerArea
              key={idx}
              player={player}
              position={pos}
              isActive={parseInt(ctx.currentPlayer, 10) === idx}
              isBrigadeLeader={player.brigadeLeader}
              playerIndex={idx}
              scale={scaleFactor}
            />
          );
        })}

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

      {/* Mobile toggle buttons - Jobs on left, Gulag and menu on right */}
      <div className="mobile-toggles mobile-toggles-left">
        <button
          className={`mobile-toggle-btn ${showJobsPanel ? 'active' : ''}`}
          onClick={() => { setShowJobsPanel(!showJobsPanel); setShowInfoPanel(false); setShowMenuPanel(false); }}
          title="Jobs"
        >
          Работы
        </button>
      </div>
      <div className="mobile-toggles mobile-toggles-right">
        <button
          className={`mobile-toggle-btn ${showInfoPanel ? 'active' : ''}`}
          onClick={() => { setShowInfoPanel(!showInfoPanel); setShowJobsPanel(false); setShowMenuPanel(false); }}
          title="The North (Gulag)"
        >
          Север
        </button>
        <button
          className={`mobile-toggle-btn menu-btn ${showMenuPanel ? 'active' : ''}`}
          onClick={() => { setShowMenuPanel(!showMenuPanel); setShowJobsPanel(false); setShowInfoPanel(false); }}
        >
          ☰
        </button>
      </div>

      {/* Mobile Jobs Panel - horizontal layout like lobby */}
      {showJobsPanel && (
        <div className="mobile-panel jobs-panel" onClick={() => setShowJobsPanel(false)}>
          <div className="mobile-panel-content jobs-content" onClick={(e) => e.stopPropagation()}>
            <button className="mobile-panel-close" onClick={() => setShowJobsPanel(false)}>×</button>
            <div className="jobs-layout">
              {/* Title on left */}
              <div className="jobs-title-section">
                <h3 className="jobs-title" title="Jobs">РАБОТЫ</h3>
                <div className="jobs-subtitle" title="Jobs completed">
                  {G.claimedJobs?.length || 0}/4 готово
                </div>
              </div>
              {/* Job columns */}
              <div className="mobile-jobs-row">
                {SUITS.map((suit) => {
                  const hours = G.workHours?.[suit] || 0;
                  const isClaimed = G.claimedJobs?.includes(suit);
                  const isTrump = suit === G.trump;
                  const bucket = G.jobBuckets?.[suit] || [];
                  const jobCard = G.revealedJobs?.[suit];
                  const jobCards = Array.isArray(jobCard) ? jobCard : jobCard ? [jobCard] : [];
                  const progressPct = Math.min(100, (hours / 40) * 100);

                  return (
                    <div key={suit} className={`mobile-job-column ${isTrump ? 'trump' : ''} ${isClaimed ? 'claimed' : ''}`}>
                      {/* Compact header: icon + progress inline */}
                      <div className="job-header-row">
                        <span className={`suit-symbol ${suit.toLowerCase()}`}>{getSuitSymbol(suit)}</span>
                        <div className="progress-bar-container">
                          <div
                            className={`progress-bar-fill ${isClaimed ? 'complete' : ''}`}
                            style={{ width: `${progressPct}%` }}
                          />
                          <span className="progress-text">
                            {isClaimed ? '✓' : `${hours}/40`}
                          </span>
                        </div>
                      </div>

                      {/* Cards stack */}
                      <div className="job-cards-stack">
                        {/* Reward card */}
                        {isClaimed ? (
                          <img src="assets/cards/back.svg" alt="claimed" className="job-card" />
                        ) : (
                          jobCards.map((card, idx) => (
                            <img
                              key={`reward-${idx}`}
                              src={getCardImagePath(card)}
                              alt={`${card.value} of ${card.suit}`}
                              className="job-card reward"
                            />
                          ))
                        )}
                        {/* Assigned cards stacked below */}
                        {bucket.slice(0, 12).map((card, idx) => (
                          <img
                            key={`assigned-${idx}`}
                            src={getCardImagePath(card)}
                            alt={`${card.value} of ${card.suit}`}
                            className="job-card"
                            style={{ marginTop: '-45px' }}
                          />
                        ))}
                        {bucket.length > 12 && (
                          <div className="more-cards">+{bucket.length - 12}</div>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Mobile Gulag Panel - horizontal layout like lobby */}
      {showInfoPanel && (
        <div className="mobile-panel gulag-panel" onClick={() => setShowInfoPanel(false)}>
          <div className="mobile-panel-content gulag-content" onClick={(e) => e.stopPropagation()}>
            <button className="mobile-panel-close" onClick={() => setShowInfoPanel(false)}>×</button>
            <div className="gulag-layout">
              {/* Title on left */}
              <div className="gulag-title-section">
                <h3 className="gulag-title" title="The North (Gulag)">СЕВЕР</h3>
                <div className="gulag-subtitle" title="Cards exiled">
                  {Object.values(G.exiled || {}).flat().length} сослано
                </div>
              </div>
              {/* Year columns */}
              <div className="mobile-gulag-years">
                {[1, 2, 3, 4, 5].map((year) => {
                  const yearCards = G.exiled?.[year] || [];
                  const isCurrent = year === G.year;
                  const isPast = year < G.year;

                  // Parse card keys like "Hearts-11" into card objects
                  const parseCardKey = (cardKey) => {
                    const [suit, value] = cardKey.split('-');
                    return { suit, value: parseInt(value, 10) };
                  };

                  return (
                    <div key={year} className={`gulag-year-column ${isCurrent ? 'current' : ''} ${isPast ? 'past' : ''}`}>
                      <div className="year-header">
                        <span className="year-number">{year}</span>
                        {yearCards.length > 0 && (
                          <span className="year-badge">{yearCards.length}</span>
                        )}
                      </div>
                      <div className="year-cards">
                        {yearCards.length > 0 ? (
                          yearCards.slice(0, 10).map((cardKey, idx) => {
                            const card = parseCardKey(cardKey);
                            return (
                              <img
                                key={idx}
                                src={getCardImagePath(card)}
                                alt={cardKey}
                                className="gulag-card"
                                style={{ marginTop: idx > 0 ? '-40px' : '0' }}
                              />
                            );
                          })
                        ) : (
                          <div className="empty-slot" />
                        )}
                        {yearCards.length > 10 && (
                          <div className="more-cards">+{yearCards.length - 10}</div>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Mobile Menu Panel */}
      {showMenuPanel && (
        <div className="mobile-panel" onClick={() => setShowMenuPanel(false)}>
          <div className="mobile-panel-content menu-panel" onClick={(e) => e.stopPropagation()}>
            <button className="mobile-panel-close" onClick={() => setShowMenuPanel(false)}>×</button>
            <h3>Menu</h3>
            <div className="menu-options">
              <button className="menu-option" onClick={() => { setShowRules(true); setShowMenuPanel(false); }}>
                📖 Rules
              </button>
              <button className="menu-option" onClick={() => window.location.reload()}>
                🔄 New Game
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Rules Panel */}
      {showRules && (
        <div className="mobile-panel rules-panel" onClick={() => setShowRules(false)}>
          <div className="mobile-panel-content rules-content" onClick={(e) => e.stopPropagation()}>
            <button className="mobile-panel-close" onClick={() => setShowRules(false)}>×</button>
            <h3>Kolkhoz Rules</h3>
            <div className="rules-text">
              <h4>Objective</h4>
              <p>Complete collective farm jobs while protecting your private plot. Lowest score wins!</p>

              <h4>Gameplay</h4>
              <p>• Play cards to tricks - must follow lead suit if able</p>
              <p>• Trick winner assigns cards to matching job suits</p>
              <p>• Jobs need 40 work hours to complete</p>
              <p>• Face cards (J/Q/K) of trump have special powers</p>

              <h4>Trump Face Cards</h4>
              <p>• <strong>Jack (Пьяница)</strong>: Worth 0 hours, gets exiled instead of your cards</p>
              <p>• <strong>Queen (Доносчик)</strong>: All players become vulnerable to requisition</p>
              <p>• <strong>King (Чиновник)</strong>: Exiles two cards instead of one</p>

              <h4>Requisition</h4>
              <p>At year end, failed jobs trigger requisition - your highest matching card goes to the Gulag!</p>

              <h4>Scoring</h4>
              <p>Cards in your plot = penalty points. Protect your plot to win!</p>
            </div>
          </div>
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
      />

      {/* Assignment phase UI */}
      {phase === 'assignment' && G.lastWinner === currentPlayer && (() => {
        // Get all suits represented in the trick
        const suitsInTrick = [...new Set(G.lastTrick.map(([, c]) => c.suit))];
        return (
          <div className="assignment-ui">
            <h3>Assign cards to jobs</h3>
            <p>Assign each card to a job from this trick</p>
            <div className="assignment-cards">
              {G.lastTrick.map(([pid, card], idx) => {
                const cardKey = `${card.suit}-${card.value}`;
                const assigned = G.pendingAssignments?.[cardKey];
                return (
                  <div key={idx} className="assignment-card">
                    <CardSVG card={card} width={80} />
                    <select
                      value={assigned || card.suit}
                      onChange={(e) => handleAssign(cardKey, e.target.value)}
                    >
                      {suitsInTrick.map((s) => (
                        <option key={s} value={s}>{s}</option>
                      ))}
                    </select>
                  </div>
                );
              })}
            </div>
            <button
              onClick={handleSubmitAssignments}
              disabled={Object.keys(G.pendingAssignments || {}).length !== G.lastTrick.length}
            >
              Submit Assignments
            </button>
          </div>
        );
      })()}

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
