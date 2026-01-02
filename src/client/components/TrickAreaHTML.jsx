import React, { useState, useEffect, useRef } from 'react';
import { getCardImagePath } from '../../game/Card.js';
import './TrickAreaHTML.css';

const SUITS = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];
const SUIT_SYMBOLS = { Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' };

// Portrait paths for AI players
const PORTRAITS = [
  '/assets/portraits/worker1.svg',
  '/assets/portraits/worker2.svg',
  '/assets/portraits/worker3.svg',
  '/assets/portraits/worker4.svg',
];

export function TrickAreaHTML({
  trick,
  numPlayers,
  year,
  trump,
  phase,
  isMyTurn,
  currentPlayerName,
  players,
  currentPlayer,
  brigadeLeader,
  displayMode = 'game',
  workHours,
  claimedJobs,
  jobBuckets,
  revealedJobs,
  exiled,
  playerPlot,
  onSetTrump,
  highlightedSuits = [],
  lastTrick = [],
  pendingAssignments = {},
  assignDragState,
  onAssignDragStart,
  jobDropRefs = { current: {} },
  onSubmitAssignments,
}) {
  // Track point popups per suit
  const [pointPopups, setPointPopups] = useState({});
  const prevAssignments = useRef({});

  // Detect when cards are assigned/unassigned and show popup
  useEffect(() => {
    const prev = prevAssignments.current;
    const current = pendingAssignments || {};

    // Find newly assigned cards (show +X)
    Object.entries(current).forEach(([cardKey, targetSuit]) => {
      if (prev[cardKey] !== targetSuit && targetSuit) {
        // Card was just assigned to this suit - find its value
        const cardEntry = lastTrick.find(([, card]) => `${card.suit}-${card.value}` === cardKey);
        if (cardEntry) {
          const cardValue = cardEntry[1].value;
          // Show popup for this suit
          setPointPopups(p => ({ ...p, [targetSuit]: { value: cardValue, type: 'add', key: Date.now() } }));
          // Clear popup after animation
          setTimeout(() => {
            setPointPopups(p => {
              const copy = { ...p };
              delete copy[targetSuit];
              return copy;
            });
          }, 1200);
        }
      }
    });

    // Find cards that were removed from a suit (show -X)
    Object.entries(prev).forEach(([cardKey, oldSuit]) => {
      const newSuit = current[cardKey];
      if (oldSuit && oldSuit !== newSuit) {
        // Card was removed from oldSuit - find its value
        const cardEntry = lastTrick.find(([, card]) => `${card.suit}-${card.value}` === cardKey);
        if (cardEntry) {
          const cardValue = cardEntry[1].value;
          // Show negative popup for the old suit
          setPointPopups(p => ({ ...p, [oldSuit]: { value: cardValue, type: 'remove', key: Date.now() } }));
          // Clear popup after animation
          setTimeout(() => {
            setPointPopups(p => {
              const copy = { ...p };
              delete copy[oldSuit];
              return copy;
            });
          }, 1200);
        }
      }
    });

    prevAssignments.current = { ...current };
  }, [pendingAssignments, lastTrick]);

  // Map player index to slot position
  const slotOrder = [3, 0, 1, 2]; // player 0 -> slot 3 (right), player 1 -> slot 0 (left), etc.
  const slotClasses = ['left', 'center-left', 'center-right', 'right'];

  const getSlotClass = (playerIdx) => slotClasses[slotOrder[playerIdx]];

  const hasPlayerPlayed = (playerIdx) => trick.some(([pid]) => pid === playerIdx);

  const getCardForPlayer = (playerIdx) => {
    const entry = trick.find(([pid]) => pid === playerIdx);
    return entry ? entry[1] : null;
  };

  return (
    <div className="trick-area-html">
      {/* Info Bar */}
      <div className="info-bar">
        <div className="info-year">
          <span className="label">Год</span>
          <span className="value">{year}/5</span>
        </div>

        <div className="info-trump">
          <span className="label">Задача:</span>
          {trump ? (
            <span className={`suit-symbol ${trump.toLowerCase()}`}>
              {SUIT_SYMBOLS[trump]}
            </span>
          ) : (
            <span className="famine">Год неурожая</span>
          )}
        </div>

        {trick.length > 0 && (
          <div className="info-lead">
            <span className="label">Ведёт:</span>
            <span className={`suit-symbol ${trick[0][1].suit.toLowerCase()}`}>
              {SUIT_SYMBOLS[trick[0][1].suit]}
            </span>
          </div>
        )}

        <div className="info-jobs">
          {SUITS.map((suit) => {
            const hours = workHours?.[suit] || 0;
            const isClaimed = claimedJobs?.includes(suit);
            const isHighlighted = highlightedSuits.includes(suit);

            return (
              <div
                key={suit}
                className={`job-indicator ${isHighlighted ? 'highlighted' : ''} ${isClaimed ? 'claimed' : ''}`}
              >
                <span className={`suit-symbol ${suit.toLowerCase()}`}>
                  {SUIT_SYMBOLS[suit]}
                </span>
                <span className="progress">
                  {isClaimed ? '✓' : `${hours}/40`}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      {/* Main Content Area */}
      <div className="play-area">
        {displayMode === 'game' && (
          <div className="player-columns">
            {[1, 2, 3, 0].map((playerIdx) => {
              const player = players?.[playerIdx];
              const handSize = player?.hand?.length || 0;
              const revealedCards = player?.plot?.revealed || [];
              const hiddenCount = player?.plot?.hidden?.length || 0;
              const visibleScore = revealedCards.reduce((sum, c) => sum + c.value, 0) + hiddenCount;
              const isActive = currentPlayer === playerIdx;
              const isLeader = brigadeLeader === playerIdx;
              const card = getCardForPlayer(playerIdx);
              const hasPlayed = hasPlayerPlayed(playerIdx);
              const isCurrentTurn = currentPlayer === playerIdx && !hasPlayed;
              const isHumanTurn = isMyTurn && playerIdx === 0 && !hasPlayed;

              return (
                <div key={playerIdx} className={`player-column ${getSlotClass(playerIdx)}`}>
                  <div className={`player-panel ${isActive ? 'active' : ''} ${playerIdx === 0 ? 'human' : ''}`}>
                    {playerIdx !== 0 && (
                      <img
                        src={PORTRAITS[(playerIdx - 1) % PORTRAITS.length]}
                        alt={player?.name}
                        className="portrait"
                      />
                    )}
                    <div className="player-info">
                      <span className="player-name">
                        {playerIdx === 0 ? 'Вы' : (player?.name || `Player ${playerIdx}`)}
                        {isLeader && <span className="leader-star">★</span>}
                      </span>
                      <span className="player-score">
                        {visibleScore > 0 ? `${visibleScore} pts` : (playerIdx === 0 ? '' : `${handSize} cards`)}
                      </span>
                    </div>
                    {playerIdx !== 0 && (
                      <div className="player-hand-cards">
                        {Array.from({ length: Math.min(4, handSize) }).map((_, idx) => (
                          <img
                            key={idx}
                            src="assets/cards/back.svg"
                            alt="card"
                            className="mini-card"
                          />
                        ))}
                        {handSize > 4 && <span className="extra-cards">+{handSize - 4}</span>}
                      </div>
                    )}
                  </div>

                  <div
                    className={`card-slot ${getSlotClass(playerIdx)} ${isCurrentTurn ? 'current-turn' : ''} ${isHumanTurn ? 'human-turn' : ''}`}
                    data-player={playerIdx}
                  >
                    {card ? (
                      <img
                        src={getCardImagePath(card)}
                        alt={`${card.value} of ${card.suit}`}
                        className="played-card"
                      />
                    ) : (
                      <div className="empty-slot">
                        {isHumanTurn && <span className="turn-text">Ваш ход</span>}
                        {isCurrentTurn && playerIdx !== 0 && (
                          <span className="turn-text bot">{currentPlayerName}</span>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* Jobs View - 4-column tile layout (shared between view and assignment modes) */}
        {displayMode === 'jobs' && (
          <div className="assignment-view">
            <div className="assignment-grid">
              {(() => {
                const suitsInTrick = new Set(lastTrick.map(([, card]) => card.suit));
                const JOB_NAMES = {
                  Hearts: 'Пшеница',
                  Diamonds: 'Свёкла',
                  Clubs: 'Картофель',
                  Spades: 'Подсолнух',
                };

                return SUITS.map((suit) => {
                  const hours = workHours?.[suit] || 0;
                  const isClaimed = claimedJobs?.includes(suit);
                  const isTrump = suit === trump;
                  const bucket = jobBuckets?.[suit] || [];

                  // Is this suit a valid drop target? (only relevant in assignment phase)
                  const isAssignmentPhase = phase === 'assignment';
                  const isValidTarget = isAssignmentPhase && suitsInTrick.has(suit) && !isClaimed;
                  const isDropTarget = assignDragState && isValidTarget;
                  const isDropHover = assignDragState?.dropTarget === suit;

                  // Cards assigned to this job (only in assignment phase)
                  const assignedCards = isAssignmentPhase ? lastTrick.filter(([, card]) => {
                    const cardKey = `${card.suit}-${card.value}`;
                    return pendingAssignments[cardKey] === suit;
                  }) : [];

                  // Calculate pending hours from assigned cards
                  const pendingHours = assignedCards.reduce((sum, [, card]) => sum + card.value, 0);
                  const totalHours = hours + pendingHours;
                  const popup = pointPopups[suit];

                  // Get reward card for this job
                  const jobCard = revealedJobs?.[suit];
                  const rewardCards = Array.isArray(jobCard) ? jobCard : jobCard ? [jobCard] : [];

                  // Build class list - only add assignment classes when in assignment phase
                  const tileClasses = [
                    'assign-job-tile',
                    isTrump ? 'trump' : '',
                    isClaimed ? 'claimed' : '',
                    isAssignmentPhase && isValidTarget ? 'valid-target' : '',
                    isAssignmentPhase && !isValidTarget && suitsInTrick.size > 0 ? 'invalid-target' : '',
                    isDropTarget ? 'drop-target' : '',
                    isDropHover ? 'drop-hover' : '',
                  ].filter(Boolean).join(' ');

                  return (
                    <div
                      key={suit}
                      ref={(el) => { if (isValidTarget) jobDropRefs.current[suit] = el; }}
                      className={tileClasses}
                    >
                      {/* Header: left side (icon + progress + number) and right side (reward) */}
                      <div className="tile-header-row">
                        <div className="tile-header-left">
                          <div className="tile-header-top">
                            <span className={`suit-symbol ${suit.toLowerCase()}`}>{SUIT_SYMBOLS[suit]}</span>
                            {isTrump && <span className="trump-badge">★</span>}
                            <div className="progress-track">
                              <div className="progress-fill" style={{ width: `${Math.min(100, (totalHours/40)*100)}%` }} />
                            </div>
                          </div>
                          <div className="progress-text-wrapper">
                            <span className="progress-text">{isClaimed ? '✓' : `${totalHours}/40`}</span>
                            {popup && (
                              <span key={popup.key} className={`point-popup ${popup.type}`}>
                                {popup.type === 'add' ? '+' : '-'}{popup.value}
                              </span>
                            )}
                          </div>
                        </div>
                        <div className="tile-header-right">
                          {/* Reward card - show back if claimed or will be claimed (40+ hours) */}
                          <div className="tile-reward">
                            {rewardCards.length > 0 && !isClaimed && totalHours < 40 ? (
                              <img
                                src={getCardImagePath(rewardCards[0])}
                                alt="reward"
                                className="reward-card"
                              />
                            ) : (
                              <img
                                src="assets/cards/back.svg"
                                alt="reward"
                                className={`reward-card ${isClaimed || totalHours >= 40 ? 'claimed' : 'dimmed'}`}
                              />
                            )}
                          </div>
                        </div>
                      </div>

                      {/* Card stack - bucket cards + assigned cards */}
                      <div className={`tile-card-stack ${(bucket.length > 0 || assignedCards.length > 0) ? 'has-cards' : ''}`}>
                        {/* Bucket cards from previous tricks */}
                        {bucket.map((card, idx) => (
                          <img
                            key={`bucket-${idx}`}
                            src={getCardImagePath(card)}
                            alt={`${card.value} of ${card.suit}`}
                            className="stacked-card bucket"
                          />
                        ))}
                        {/* Assigned cards from current trick */}
                        {assignedCards.map(([, card]) => {
                          const cardKey = `${card.suit}-${card.value}`;
                          const isDragging = assignDragState?.cardKey === cardKey;
                          return (
                            <div
                              key={cardKey}
                              className={`assigned-card-wrapper ${isDragging ? 'dragging' : ''}`}
                              onMouseDown={(e) => onAssignDragStart(cardKey, card, e)}
                              onTouchStart={(e) => onAssignDragStart(cardKey, card, e)}
                            >
                              <img
                                src={getCardImagePath(card)}
                                alt={`${card.value} of ${card.suit}`}
                                className="stacked-card assigned"
                                draggable={false}
                              />
                            </div>
                          );
                        })}
                        {/* Drop hint - only show during assignment phase */}
                        {isAssignmentPhase && isValidTarget && (
                          <span className="drop-hint">Drop here</span>
                        )}
                      </div>
                    </div>
                  );
                });
              })()}
            </div>
          </div>
        )}

        {displayMode === 'gulag' && (
          <div className="gulag-view">
            <h2 className="view-title">Север</h2>
            {[1, 2, 3, 4, 5].map((yr) => {
              const yearCards = exiled?.[yr] || [];
              const isCurrent = yr === year;

              const parseCardKey = (cardKey) => {
                const [suit, value] = cardKey.split('-');
                return { suit, value: parseInt(value, 10) };
              };

              return (
                <div key={yr} className={`year-row ${isCurrent ? 'current' : ''}`}>
                  <div className="year-info">
                    <span className="year-number">{yr}</span>
                    {yearCards.length > 0 && <span className="card-count">{yearCards.length}</span>}
                  </div>
                  <div className="year-cards">
                    {yearCards.slice(0, 12).map((cardKey, idx) => {
                      const card = parseCardKey(cardKey);
                      return (
                        <img
                          key={idx}
                          src={getCardImagePath(card)}
                          alt={`${card.value} of ${card.suit}`}
                          className="exiled-card"
                        />
                      );
                    })}
                    {yearCards.length > 12 && <span className="more-cards">+{yearCards.length - 12}</span>}
                    {yearCards.length === 0 && <div className="empty-year" />}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {displayMode === 'plot' && (
          <div className="plot-view">
            <h2 className="view-title">Подвал</h2>
            <div className="plot-row revealed">
              <div className="row-label">
                <span className="title">Награды</span>
                <span className="subtitle">(Revealed)</span>
              </div>
              <div className="plot-cards">
                {(playerPlot?.revealed || []).map((card, idx) => (
                  <img
                    key={idx}
                    src={getCardImagePath(card)}
                    alt={`${card.value} of ${card.suit}`}
                    className="plot-card"
                  />
                ))}
                {(!playerPlot?.revealed || playerPlot.revealed.length === 0) && (
                  <div className="empty-plot" />
                )}
              </div>
            </div>
            <div className="plot-row hidden">
              <div className="row-label">
                <span className="title">Скрытые</span>
                <span className="subtitle">(Hidden)</span>
              </div>
              <div className="plot-cards">
                {(playerPlot?.hidden || []).map((card, idx) => (
                  <img
                    key={idx}
                    src={getCardImagePath(card)}
                    alt={`${card.value} of ${card.suit}`}
                    className="plot-card"
                  />
                ))}
                {(!playerPlot?.hidden || playerPlot.hidden.length === 0) && (
                  <div className="empty-plot" />
                )}
              </div>
            </div>
            <div className="plot-total">
              Total: {
                ((playerPlot?.revealed || []).reduce((sum, c) => sum + c.value, 0) +
                 (playerPlot?.hidden || []).reduce((sum, c) => sum + c.value, 0))
              } points
            </div>
          </div>
        )}

        {/* Trump Selection */}
        {phase === 'planning' && !trump && onSetTrump && (
          <div className="trump-selection">
            <h2 className="selection-title">Выберите главную задачу</h2>
            <div className="trump-buttons">
              {SUITS.map((suit) => (
                <button
                  key={suit}
                  className={`trump-btn ${suit.toLowerCase()}`}
                  onClick={() => onSetTrump(suit)}
                >
                  <span className="suit-symbol">{SUIT_SYMBOLS[suit]}</span>
                  <span className="suit-name">
                    {{
                      Hearts: 'Пшеница',
                      Diamonds: 'Свёкла',
                      Clubs: 'Картофель',
                      Spades: 'Подсолнечник',
                    }[suit]}
                  </span>
                </button>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
