import React from 'react';
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
}) {
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

        {displayMode === 'jobs' && (
          <div className="jobs-view">
            <h2 className="view-title">Работы</h2>
            {SUITS.map((suit) => {
              const hours = workHours?.[suit] || 0;
              const isClaimed = claimedJobs?.includes(suit);
              const isTrump = suit === trump;
              const bucket = jobBuckets?.[suit] || [];
              const jobCard = revealedJobs?.[suit];
              const jobCards = Array.isArray(jobCard) ? jobCard : jobCard ? [jobCard] : [];

              return (
                <div key={suit} className={`job-row ${isTrump ? 'trump' : ''} ${isClaimed ? 'claimed' : ''}`}>
                  <div className="job-info">
                    <span className={`suit-symbol ${suit.toLowerCase()}`}>{SUIT_SYMBOLS[suit]}</span>
                    <span className="progress">{isClaimed ? '✓' : `${hours}/40`}</span>
                  </div>
                  <div className="job-reward">
                    {jobCards.length > 0 && !isClaimed ? (
                      <img src={getCardImagePath(jobCards[0])} alt="reward" className="reward-card" />
                    ) : (
                      <img src="assets/cards/back.svg" alt="reward" className="reward-card dimmed" />
                    )}
                  </div>
                  <div className="job-cards">
                    {bucket.slice(0, 12).map((card, idx) => (
                      <img
                        key={idx}
                        src={getCardImagePath(card)}
                        alt={`${card.value} of ${card.suit}`}
                        className="bucket-card"
                      />
                    ))}
                    {bucket.length > 12 && <span className="more-cards">+{bucket.length - 12}</span>}
                    {bucket.length === 0 && <div className="empty-bucket" />}
                  </div>
                </div>
              );
            })}
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
