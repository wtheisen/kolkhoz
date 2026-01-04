import React from 'react';
import { getCardImagePath } from '../../../game/Card.js';
import { translations, t } from '../../translations.js';
import './TrickView.css';

// Portrait paths for AI players
const PORTRAITS = [
  '/assets/portraits/worker1.svg',
  '/assets/portraits/worker2.svg',
  '/assets/portraits/worker3.svg',
  '/assets/portraits/worker4.svg',
];

export function TrickView({
  trick,
  players,
  currentPlayer,
  brigadeLeader,
  isMyTurn,
  currentPlayerName,
  variants,
  language,
}) {
  // Map player index to slot position
  const slotOrder = [3, 0, 1, 2]; // player 0 -> slot 3 (right), etc.
  const slotClasses = ['left', 'center-left', 'center-right', 'right'];

  const getSlotClass = (playerIdx) => slotClasses[slotOrder[playerIdx]];
  const hasPlayerPlayed = (playerIdx) => trick.some(([pid]) => pid === playerIdx);
  const getCardForPlayer = (playerIdx) => {
    const entry = trick.find(([pid]) => pid === playerIdx);
    return entry ? entry[1] : null;
  };

  return (
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
        const medals = player?.medals || 0;

        return (
          <div key={playerIdx} className={`player-column ${getSlotClass(playerIdx)}`}>
            <div className={`player-panel ${isActive ? 'active' : ''} ${playerIdx === 0 ? 'human' : ''} ${medals === 4 ? 'hero-candidate' : ''}`}>
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
                  {visibleScore > 0 ? `${visibleScore} ${t(translations, language, 'pts')}` : ''}
                </span>
              </div>
              {/* Hand cards and medal tracker container */}
              <div className="hand-medals-wrapper">
                {playerIdx !== 0 && (
                  <div className="player-hand-cards">
                    {Array.from({ length: handSize }).map((_, idx) => (
                      <img
                        key={idx}
                        src="assets/cards/back.svg"
                        alt="card"
                        className="mini-card"
                      />
                    ))}
                  </div>
                )}
                {/* Medal tracker - shows tricks won this year */}
                {variants.heroOfSovietUnion && (
                  <div className={`medal-tracker ${medals > 0 ? 'has-medals' : ''} ${medals === 4 ? 'hero' : ''}`}>
                    {[0, 1, 2, 3].map((i) => (
                      <span
                        key={i}
                        className={`medal-slot ${i < medals ? 'earned' : 'empty'}`}
                      >
                        ★
                      </span>
                    ))}
                  </div>
                )}
              </div>
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
  );
}

export default TrickView;
