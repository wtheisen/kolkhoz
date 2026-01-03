import React, { useState, useEffect, useRef } from 'react';
import { getCardImagePath } from '../../game/Card.js';
import { translations, t, getJobName } from '../translations.js';
import './TrickAreaHTML.css';

const SUITS = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];
const SUIT_SYMBOLS = { Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' };
const FACE_CARD_SYMBOLS = { 11: 'J', 12: 'Q', 13: 'K' };

// Find trump face cards (J, Q, K) in a job bucket
function getTrumpFaceCardsInBucket(bucket, trump) {
  if (!trump || !bucket) return [];
  return bucket
    .filter(card => card.suit === trump && card.value >= 11 && card.value <= 13)
    .map(card => FACE_CARD_SYMBOLS[card.value]);
}

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
  // Swap phase props
  swapDragState,
  onSwapDragStart,
  plotDropRefs = { current: {} },
  swapConfirmed = {},
  currentSwapPlayer = null,
  lastSwap = null,
  // Requisition phase props
  requisitionData = null,
  requisitionStage = 'idle',
  currentRequisitionSuit = null,
  currentJobStage = 'header',
  // Language
  language = 'ru',
  // Variants
  variants = {},
  // Famine state
  isFamine = false,
}) {
  // Calculate work value for a card (Jack of trump = 0 with nomenclature)
  const getWorkValue = (card) => {
    if (variants.nomenclature && card.suit === trump && card.value === 11) {
      return 0;
    }
    return card.value;
  };
  // Track animated swap for bot visual feedback
  const [animatedSwap, setAnimatedSwap] = useState(null);
  const lastSwapTimestamp = useRef(null);

  // Detect bot swaps and trigger animation
  useEffect(() => {
    if (lastSwap && lastSwap.playerIdx !== 0 && lastSwap.timestamp !== lastSwapTimestamp.current) {
      lastSwapTimestamp.current = lastSwap.timestamp;
      setAnimatedSwap({
        playerIdx: lastSwap.playerIdx,
        plotType: lastSwap.plotType,
        plotCardIndex: lastSwap.plotCardIndex,
        key: lastSwap.timestamp,
      });
      // Clear animation after it completes
      const timer = setTimeout(() => {
        setAnimatedSwap(null);
      }, 600);
      return () => clearTimeout(timer);
    }
  }, [lastSwap]);
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
          const cardValue = getWorkValue(cardEntry[1]);
          const popupKey = Date.now();
          // Show popup for this suit
          setPointPopups(p => ({ ...p, [targetSuit]: { value: cardValue, type: 'add', key: popupKey } }));
          // Clear popup after animation (only if key still matches)
          setTimeout(() => {
            setPointPopups(p => {
              if (p[targetSuit]?.key !== popupKey) return p;  // Different popup, don't remove
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
          const cardValue = getWorkValue(cardEntry[1]);
          const popupKey = Date.now();
          // Show negative popup for the old suit
          setPointPopups(p => ({ ...p, [oldSuit]: { value: cardValue, type: 'remove', key: popupKey } }));
          // Clear popup after animation (only if key still matches)
          setTimeout(() => {
            setPointPopups(p => {
              if (p[oldSuit]?.key !== popupKey) return p;  // Different popup, don't remove
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
          <span className="label">{t(translations, language, 'year')}</span>
          <span className="value">{year}/5</span>
        </div>

        <div className="info-trump">
          <span className="label">{t(translations, language, 'task')}</span>
          {trump ? (
            <span className={`suit-symbol ${trump.toLowerCase()}`}>
              {SUIT_SYMBOLS[trump]}
            </span>
          ) : isFamine ? (
            <span className="famine">{t(translations, language, 'famineYear')}</span>
          ) : (
            <span className="no-trump">—</span>
          )}
        </div>

        {trick.length > 0 && (
          <div className="info-lead">
            <span className="label">{t(translations, language, 'lead')}</span>
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
            const trumpFaceCards = getTrumpFaceCardsInBucket(jobBuckets?.[suit], trump);

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
                {trumpFaceCards.length > 0 && (
                  <span className="trump-face-badges">
                    {trumpFaceCards.map(symbol => (
                      <span key={symbol} className="trump-face-badge">{symbol}</span>
                    ))}
                  </span>
                )}
              </div>
            );
          })}
        </div>

        <div className="info-score">
          <span className="label">{t(translations, language, 'cellar')}</span>
          <span className="value">
            {((playerPlot?.revealed || []).reduce((sum, c) => sum + c.value, 0) +
              (playerPlot?.hidden || []).reduce((sum, c) => sum + c.value, 0))}
          </span>
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
                        {playerIdx === 0 ? t(translations, language, 'you') : (player?.name || `${t(translations, language, 'player')} ${playerIdx}`)}
                        {isLeader && <span className="leader-star">★</span>}
                      </span>
                      <span className="player-score">
                        {visibleScore > 0 ? `${visibleScore} ${t(translations, language, 'pts')}` : (playerIdx === 0 ? '' : `${handSize} ${t(translations, language, 'cards')}`)}
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
                        {isHumanTurn && <span className="turn-text">{t(translations, language, 'yourTurn')}</span>}
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
                  const pendingHours = assignedCards.reduce((sum, [, card]) => sum + getWorkValue(card), 0);
                  const totalHours = hours + pendingHours;
                  const popup = pointPopups[suit];

                  // Get reward card for this job
                  const jobCard = revealedJobs?.[suit];
                  const rewardCards = Array.isArray(jobCard) ? jobCard : jobCard ? [jobCard] : [];

                  // Find trump face cards in this bucket
                  const trumpFaceCards = getTrumpFaceCardsInBucket(bucket, trump);

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
                            {trumpFaceCards.length > 0 && (
                              <span className="trump-face-badges">
                                {trumpFaceCards.map(symbol => (
                                  <span key={symbol} className="trump-face-badge">{symbol}</span>
                                ))}
                              </span>
                            )}
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
                          <span className="drop-hint">{t(translations, language, 'dropHere')}</span>
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
            {/* Snow effect */}
            {(() => {
              const hasWind = Math.random() > 0.4; // 60% chance of wind for all flakes
              const windDirection = Math.random() > 0.5 ? 1 : -1;
              // More flakes when windy (60-80), fewer when calm (40-55)
              const snowflakeCount = hasWind
                ? 60 + Math.floor(Math.random() * 21)
                : 40 + Math.floor(Math.random() * 16);

              return (
                <div className="snow-container">
                  {Array.from({ length: snowflakeCount }).map((_, i) => {
                    const windStrength = hasWind ? 50 + Math.random() * 100 : 0;
                    return (
                      <div
                        key={i}
                        className={`snowflake ${hasWind ? 'windy' : ''}`}
                        style={{
                          '--delay': `${Math.random() * 10}s`,
                          '--duration': `${5 + Math.random() * 10}s`,
                          '--x-start': `${Math.random() * 100}%`,
                          '--x-drift': `${-20 + Math.random() * 40}px`,
                          '--size': `${2 + Math.random() * 4}px`,
                          '--opacity': `${0.3 + Math.random() * 0.7}`,
                          '--wind-strength': `${windStrength * windDirection}px`,
                          '--wind-mid': `${(windStrength * 0.5 + Math.random() * 30) * windDirection}px`,
                          '--wiggle': `${2 + Math.random() * 4}px`,
                        }}
                      />
                    );
                  })}
                </div>
              );
            })()}
            <div className="gulag-header">
              <h2 className="view-title">{t(translations, language, 'theNorth')}</h2>
            </div>
            <div className="gulag-columns">
              {[1, 2, 3, 4, 5].map((yr) => {
                const yearCards = exiled?.[yr] || [];
                const isCurrent = yr === year;

                const parseCardKey = (cardKey) => {
                  const [suit, value] = cardKey.split('-');
                  return { suit, value: parseInt(value, 10) };
                };

                return (
                  <div key={yr} className={`gulag-column ${isCurrent ? 'current' : ''}`}>
                    <div className="column-header">
                      <span className="year-number">{t(translations, language, 'year')} {yr}</span>
                      {yearCards.length > 0 && <span className="card-count">{yearCards.length}</span>}
                    </div>
                    <div className="column-cards">
                      {yearCards.map((cardKey, idx) => {
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
                      {yearCards.length === 0 && (
                        <div className="empty-column">—</div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Swap View - Multi-player layout during swap phase */}
        {displayMode === 'plot' && phase === 'swap' && (
          <div className="swap-view multiplayer">
            {/* Top row: Bot sections */}
            <div className="swap-bots-row">
              {[1, 2, 3].map((botIdx) => {
                const bot = players?.[botIdx];
                const isActive = currentSwapPlayer === botIdx;
                const isConfirmed = swapConfirmed[botIdx];
                const revealedCards = bot?.plot?.revealed || [];
                const hiddenCount = bot?.plot?.hidden?.length || 0;
                const handSize = bot?.hand?.length || 0;

                return (
                  <div
                    key={botIdx}
                    className={`swap-bot-section ${isActive ? 'active' : ''} ${isConfirmed ? 'confirmed' : ''}`}
                  >
                    <div className="swap-bot-header">
                      <img
                        src={PORTRAITS[(botIdx - 1) % PORTRAITS.length]}
                        alt={bot?.name}
                        className="swap-bot-portrait"
                      />
                      <span className="swap-bot-name">
                        {bot?.name || `${t(translations, language, 'player')} ${botIdx}`}
                        {isConfirmed && <span className="confirmed-check">✓</span>}
                      </span>
                      <div className="swap-bot-hand">
                        {Array.from({ length: handSize }).map((_, idx) => (
                          <img
                            key={idx}
                            src="assets/cards/back.svg"
                            alt="card"
                            className="swap-hand-card"
                          />
                        ))}
                      </div>
                    </div>
                    <div className="swap-bot-cards">
                      {/* Revealed cards (face up) */}
                      {revealedCards.map((card, idx) => {
                        const isSwapping = animatedSwap &&
                          animatedSwap.playerIdx === botIdx &&
                          animatedSwap.plotType === 'revealed' &&
                          animatedSwap.plotCardIndex === idx;
                        return (
                          <img
                            key={`revealed-${idx}-${isSwapping ? animatedSwap.key : ''}`}
                            src={getCardImagePath(card)}
                            alt={`${card.value} of ${card.suit}`}
                            className={`swap-mini-card revealed ${isSwapping ? 'bot-swapped' : ''}`}
                          />
                        );
                      })}
                      {/* Hidden cards (backs) */}
                      {Array.from({ length: hiddenCount }).map((_, idx) => {
                        const isSwapping = animatedSwap &&
                          animatedSwap.playerIdx === botIdx &&
                          animatedSwap.plotType === 'hidden' &&
                          animatedSwap.plotCardIndex === idx;
                        return (
                          <img
                            key={`hidden-${idx}-${isSwapping ? animatedSwap.key : ''}`}
                            src="assets/cards/back.svg"
                            alt="hidden"
                            className={`swap-mini-card back ${isSwapping ? 'bot-swapped' : ''}`}
                          />
                        );
                      })}
                      {revealedCards.length === 0 && hiddenCount === 0 && (
                        <span className="no-cards">—</span>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Bottom: Player's plot in two side-by-side boxes */}
            <div className={`swap-player-section ${currentSwapPlayer !== 0 ? 'disabled' : ''}`}>
              {/* Hidden cards box */}
              <div className="swap-player-box hidden">
                <div className="box-header">
                  <span className="box-title">{t(translations, language, 'hidden')}</span>
                  <span className="box-count">{playerPlot?.hidden?.length || 0}</span>
                </div>
                <div className="swap-cards">
                  {(playerPlot?.hidden || []).map((card, idx) => {
                    const isDropTarget = currentSwapPlayer === 0 && swapDragState?.sourceType === 'hand';
                    const isDropHover = swapDragState?.dropTarget?.type === 'plot-hidden' &&
                                       swapDragState?.dropTarget?.index === idx;
                    const isDragging = swapDragState?.sourceType === 'plot-hidden' &&
                                      swapDragState?.index === idx;

                    return (
                      <div
                        key={`hidden-${idx}`}
                        ref={(el) => { plotDropRefs.current[`hidden-${idx}`] = el; }}
                        className={`swap-card-slot ${isDropTarget ? 'drop-target' : ''} ${isDropHover ? 'drop-hover' : ''} ${isDragging ? 'dragging' : ''} ${currentSwapPlayer !== 0 ? 'disabled' : ''}`}
                        onMouseDown={(e) => currentSwapPlayer === 0 && onSwapDragStart?.('plot-hidden', idx, card, e)}
                        onTouchStart={(e) => currentSwapPlayer === 0 && onSwapDragStart?.('plot-hidden', idx, card, e)}
                      >
                        <img
                          src={getCardImagePath(card)}
                          alt={`${card.value} of ${card.suit}`}
                          draggable={false}
                        />
                      </div>
                    );
                  })}
                  {(!playerPlot?.hidden || playerPlot.hidden.length === 0) && (
                    <div className="empty-slot">—</div>
                  )}
                </div>
              </div>

              {/* Revealed cards box */}
              <div className="swap-player-box revealed">
                <div className="box-header">
                  <span className="box-title">{t(translations, language, 'rewards')}</span>
                  <span className="box-count">{playerPlot?.revealed?.length || 0}</span>
                </div>
                <div className="swap-cards">
                  {(playerPlot?.revealed || []).map((card, idx) => {
                    const isDropTarget = currentSwapPlayer === 0 && swapDragState?.sourceType === 'hand';
                    const isDropHover = swapDragState?.dropTarget?.type === 'plot-revealed' &&
                                       swapDragState?.dropTarget?.index === idx;
                    const isDragging = swapDragState?.sourceType === 'plot-revealed' &&
                                      swapDragState?.index === idx;

                    return (
                      <div
                        key={`revealed-${idx}`}
                        ref={(el) => { plotDropRefs.current[`revealed-${idx}`] = el; }}
                        className={`swap-card-slot ${isDropTarget ? 'drop-target' : ''} ${isDropHover ? 'drop-hover' : ''} ${isDragging ? 'dragging' : ''} ${currentSwapPlayer !== 0 ? 'disabled' : ''}`}
                        onMouseDown={(e) => currentSwapPlayer === 0 && onSwapDragStart?.('plot-revealed', idx, card, e)}
                        onTouchStart={(e) => currentSwapPlayer === 0 && onSwapDragStart?.('plot-revealed', idx, card, e)}
                      >
                        <img
                          src={getCardImagePath(card)}
                          alt={`${card.value} of ${card.suit}`}
                          draggable={false}
                        />
                      </div>
                    );
                  })}
                  {(!playerPlot?.revealed || playerPlot.revealed.length === 0) && (
                    <div className="empty-slot">—</div>
                  )}
                </div>
              </div>
            </div>

            {/* Player status bar */}
            {swapConfirmed[0] && (
              <div className="swap-status-bar">
                <span className="confirmed-badge">{t(translations, language, 'confirmed')} ✓</span>
              </div>
            )}
          </div>
        )}

        {/* Plot View - Read-only view when not in swap phase (same layout as swap view) */}
        {displayMode === 'plot' && phase !== 'swap' && (
          <div className={`swap-view multiplayer readonly ${phase === 'requisition' ? 'requisition-mode' : ''}`}>
            {/* Top row: Bot sections */}
            <div className="swap-bots-row">
              {[1, 2, 3].map((botIdx) => {
                const bot = players?.[botIdx];
                const revealedCards = bot?.plot?.revealed || [];
                const hiddenCount = bot?.plot?.hidden?.length || 0;

                return (
                  <div
                    key={botIdx}
                    className="swap-bot-section"
                    data-player={botIdx}
                  >
                    <div className="swap-bot-header">
                      <img
                        src={PORTRAITS[(botIdx - 1) % PORTRAITS.length]}
                        alt={bot?.name}
                        className="swap-bot-portrait"
                      />
                      <span className="swap-bot-name">
                        {bot?.name || `${t(translations, language, 'player')} ${botIdx}`}
                      </span>
                    </div>
                    <div className="swap-bot-cards">
                      {/* Revealed cards (face up) */}
                      {revealedCards.map((card, idx) => {
                        const isCurrentSuit = card.suit === currentRequisitionSuit;
                        const isNewlyRevealed = phase === 'requisition' &&
                          isCurrentSuit &&
                          (currentJobStage === 'revealing' || currentJobStage === 'exiling') &&
                          requisitionData?.revealedCards?.some(rc =>
                            rc.playerIdx === botIdx &&
                            rc.card.suit === card.suit &&
                            rc.card.value === card.value
                          );
                        const isDimmed = phase === 'requisition' &&
                          currentRequisitionSuit &&
                          !isCurrentSuit;
                        return (
                          <img
                            key={`revealed-${idx}`}
                            src={getCardImagePath(card)}
                            alt={`${card.value} of ${card.suit}`}
                            className={`swap-mini-card revealed ${isNewlyRevealed ? 'newly-revealed' : ''} ${isDimmed ? 'dimmed' : ''}`}
                            data-card={`${card.suit}-${card.value}`}
                            data-player={botIdx}
                          />
                        );
                      })}
                      {/* Ghost cards for exiling animation - cards already removed from state */}
                      {phase === 'requisition' && currentJobStage === 'exiling' &&
                        (requisitionData?.exiledCards || [])
                          .filter(ec => ec.playerIdx === botIdx && ec.card.suit === currentRequisitionSuit)
                          .map((ec, idx) => (
                            <img
                              key={`exiling-ghost-${idx}`}
                              src={getCardImagePath(ec.card)}
                              alt={`${ec.card.value} of ${ec.card.suit}`}
                              className="swap-mini-card revealed exiling"
                              data-card={`${ec.card.suit}-${ec.card.value}`}
                              data-player={botIdx}
                            />
                          ))
                      }
                      {/* Hidden cards (backs) */}
                      {Array.from({ length: hiddenCount }).map((_, idx) => (
                        <img
                          key={`hidden-${idx}`}
                          src="assets/cards/back.svg"
                          alt="hidden"
                          className="swap-mini-card back"
                        />
                      ))}
                      {revealedCards.length === 0 && hiddenCount === 0 && (
                        <span className="no-cards">—</span>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Bottom: Player's plot in two side-by-side boxes (read-only) */}
            <div className="swap-player-section">
              {/* Hidden cards box */}
              <div className="swap-player-box hidden">
                <div className="box-header">
                  <span className="box-title">{t(translations, language, 'hidden')}</span>
                  <span className="box-count">{playerPlot?.hidden?.length || 0}</span>
                </div>
                <div className="swap-cards">
                  {(playerPlot?.hidden || []).map((card, idx) => (
                    <div
                      key={`hidden-${idx}`}
                      className="swap-card-slot readonly"
                      data-card={`${card.suit}-${card.value}`}
                    >
                      <img
                        src={getCardImagePath(card)}
                        alt={`${card.value} of ${card.suit}`}
                        draggable={false}
                      />
                    </div>
                  ))}
                  {(!playerPlot?.hidden || playerPlot.hidden.length === 0) && (
                    <div className="empty-slot">—</div>
                  )}
                </div>
              </div>

              {/* Revealed cards box */}
              <div className="swap-player-box revealed">
                <div className="box-header">
                  <span className="box-title">{t(translations, language, 'rewards')}</span>
                  <span className="box-count">{playerPlot?.revealed?.length || 0}</span>
                </div>
                <div className="swap-cards">
                  {(playerPlot?.revealed || []).map((card, idx) => {
                    const isCurrentSuit = card.suit === currentRequisitionSuit;
                    const isNewlyRevealed = phase === 'requisition' &&
                      isCurrentSuit &&
                      (currentJobStage === 'revealing' || currentJobStage === 'exiling') &&
                      requisitionData?.revealedCards?.some(rc =>
                        rc.playerIdx === 0 &&
                        rc.card.suit === card.suit &&
                        rc.card.value === card.value
                      );
                    const isDimmed = phase === 'requisition' &&
                      currentRequisitionSuit &&
                      !isCurrentSuit;
                    return (
                      <div
                        key={`revealed-${idx}`}
                        className={`swap-card-slot readonly ${isNewlyRevealed ? 'newly-revealed' : ''} ${isDimmed ? 'dimmed' : ''}`}
                        data-card={`${card.suit}-${card.value}`}
                        data-player="0"
                      >
                        <img
                          src={getCardImagePath(card)}
                          alt={`${card.value} of ${card.suit}`}
                          draggable={false}
                        />
                      </div>
                    );
                  })}
                  {/* Ghost cards for exiling animation - cards already removed from state */}
                  {phase === 'requisition' && currentJobStage === 'exiling' &&
                    (requisitionData?.exiledCards || [])
                      .filter(ec => ec.playerIdx === 0 && ec.card.suit === currentRequisitionSuit)
                      .map((ec, idx) => (
                        <div
                          key={`exiling-ghost-${idx}`}
                          className="swap-card-slot readonly exiling"
                          data-card={`${ec.card.suit}-${ec.card.value}`}
                          data-player="0"
                        >
                          <img
                            src={getCardImagePath(ec.card)}
                            alt={`${ec.card.value} of ${ec.card.suit}`}
                            draggable={false}
                          />
                        </div>
                      ))
                  }
                  {(!playerPlot?.revealed || playerPlot.revealed.length === 0) && (
                    <div className="empty-slot">—</div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Trump Selection - only show when it's the player's turn */}
        {phase === 'planning' && !trump && onSetTrump && isMyTurn && (
          <div className="trump-selection">
            <h2 className="selection-title">{t(translations, language, 'chooseMainTask')}</h2>
            <div className="trump-buttons">
              {SUITS.map((suit) => (
                <button
                  key={suit}
                  className={`trump-btn ${suit.toLowerCase()}`}
                  onClick={() => onSetTrump(suit)}
                >
                  <span className="suit-symbol">{SUIT_SYMBOLS[suit]}</span>
                  <span className="suit-name">{getJobName(language, suit)}</span>
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Waiting for AI to pick trump */}
        {phase === 'planning' && !trump && !isMyTurn && (
          <div className="trump-waiting">
            <span className="waiting-text">
              {currentPlayerName} {language === 'en' ? 'is choosing the main task...' : 'выбирает задание...'}
            </span>
          </div>
        )}
      </div>
    </div>
  );
}
