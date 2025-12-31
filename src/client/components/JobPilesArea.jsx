import React from 'react';
import { CardSVG } from './CardSVG.jsx';
import { SUITS, THRESHOLD, JOB_NAMES, JOB_TRANSLATIONS } from '../../game/constants.js';

export function JobPilesArea({
  revealedJobs,
  workHours,
  jobBuckets,
  claimedJobs,
  trump,
  phase,
  pendingAssignments,
  onAssign,
  lastTrick,
}) {
  // Layout constants
  const startX = 95;
  const startY = 70;
  const columnWidth = 120;
  const cardWidth = 50;
  const cardHeight = 70;
  const stackOffset = 16;

  const getSuitColor = (suit) => {
    return suit === 'Hearts' || suit === 'Diamonds' ? '#c41e3a' : '#e8dcc4';
  };

  const getSuitSymbol = (suit) => {
    const symbols = { Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' };
    return symbols[suit];
  };

  // Face cards with powers (trump suit only)
  const getFaceCardInfo = (value) => {
    const cards = {
      11: {
        russian: 'Пьяница',
        english: 'Jack (Drunkard)',
        power: 'Worth 0 work hours. Gets exiled instead of player cards',
      },
      12: {
        russian: 'Доносчик',
        english: 'Queen (Informant)',
        power: 'All players become vulnerable to requisition',
      },
      13: {
        russian: 'Чиновник',
        english: 'King (Party Official)',
        power: 'Exiles two cards instead of one',
      },
    };
    return cards[value] || null;
  };

  return (
    <g className="job-piles-area">
      {SUITS.map((suit, idx) => {
        const centerX = startX + idx * columnWidth;
        const hours = workHours?.[suit] || 0;
        const isClaimed = claimedJobs?.includes(suit);
        const isTrump = suit === trump;
        const bucket = jobBuckets?.[suit] || [];
        const progress = Math.min(90, (hours / THRESHOLD) * 90);

        const jobCard = revealedJobs?.[suit];
        const jobCards = Array.isArray(jobCard) ? jobCard : jobCard ? [jobCard] : [];

        // Vertical rhythm - each section starts at a clear position
        const headerY = startY;
        const rewardY = startY + 95;
        const assignedY = rewardY + cardHeight + 25;

        return (
          <g key={suit} className={`job-pile ${isClaimed ? 'claimed' : ''}`}>
            {/* Header box */}
            <rect
              x={centerX - 55}
              y={headerY}
              width={110}
              height={88}
              fill={isTrump ? 'rgba(255,215,0,0.12)' : 'rgba(0,0,0,0.5)'}
              stroke={isTrump ? '#FFD700' : '#444'}
              strokeWidth={isTrump ? 2 : 1}
              rx="6"
            />

            {/* Trump badge */}
            {isTrump && (
              <text
                x={centerX}
                y={headerY + 18}
                textAnchor="middle"
                fill="#FFD700"
                fontSize="14"
                fontWeight="bold"
              >
                TRUMP
              </text>
            )}

            {/* Suit symbol - large and centered */}
            <text
              x={centerX}
              y={headerY + (isTrump ? 46 : 38)}
              textAnchor="middle"
              fill={getSuitColor(suit)}
              fontSize="28"
            >
              {getSuitSymbol(suit)}
            </text>

            {/* Job name */}
            <text
              x={centerX}
              y={headerY + (isTrump ? 64 : 58)}
              textAnchor="middle"
              fill="#ccc"
              fontSize="14"
              fontWeight="600"
              style={{ cursor: 'help' }}
            >
              <title>{JOB_TRANSLATIONS[suit]}</title>
              {JOB_NAMES[suit]}
            </text>

            {/* Progress bar */}
            <rect
              x={centerX - 45}
              y={headerY + 72}
              width={90}
              height={12}
              fill="#222"
              rx="6"
            />
            <rect
              x={centerX - 45}
              y={headerY + 72}
              width={progress}
              height={12}
              fill={isClaimed ? '#4CAF50' : hours >= THRESHOLD ? '#4CAF50' : '#2196F3'}
              rx="6"
            />
            <text
              x={centerX}
              y={headerY + 82}
              textAnchor="middle"
              fill="white"
              fontSize="10"
              fontWeight="bold"
            >
              {hours}/{THRESHOLD}
            </text>

            {/* Reward card - centered below header */}
            {jobCards.map((card, cardIdx) => {
              const faceCardInfo = getFaceCardInfo(card.value);
              const isTrumpFaceCard = card.suit === trump && faceCardInfo;
              const offsetX = jobCards.length > 1 ? (cardIdx - (jobCards.length - 1) / 2) * 15 : 0;
              return (
                <g key={`reward-${cardIdx}`}>
                  <CardSVG
                    card={card}
                    x={centerX + offsetX}
                    y={rewardY + cardHeight / 2}
                    width={cardWidth}
                  />
                  {isTrumpFaceCard && (
                    <text
                      x={centerX + offsetX}
                      y={rewardY + cardHeight + 18}
                      textAnchor="middle"
                      fill="#FFD700"
                      fontSize="13"
                      fontWeight="600"
                      style={{ cursor: 'help' }}
                    >
                      <title>{faceCardInfo.english}: {faceCardInfo.power}</title>
                      {faceCardInfo.russian}
                    </text>
                  )}
                </g>
              );
            })}

            {/* Complete badge */}
            {isClaimed && (
              <text
                x={centerX}
                y={rewardY - 8}
                textAnchor="middle"
                fill="#4CAF50"
                fontSize="13"
                fontWeight="bold"
              >
                ✓ COMPLETE
              </text>
            )}

            {/* Assigned cards section */}
            {bucket.length > 0 && (
              <text
                x={centerX}
                y={assignedY - 6}
                textAnchor="middle"
                fill="#999"
                fontSize="12"
                fontWeight="500"
              >
                {bucket.length} assigned
              </text>
            )}

            {bucket.map((card, cardIdx) => {
              const faceCardInfo = getFaceCardInfo(card.value);
              const isTrumpFaceCard = card.suit === trump && faceCardInfo;
              const cardY = assignedY + cardHeight / 2 + cardIdx * stackOffset;
              return (
                <g key={`assigned-${cardIdx}`}>
                  <CardSVG
                    card={card}
                    x={centerX}
                    y={cardY}
                    width={cardWidth}
                  />
                  {isTrumpFaceCard && (
                    <text
                      x={centerX + cardWidth / 2 + 8}
                      y={cardY + 5}
                      textAnchor="start"
                      fill="#FFD700"
                      fontSize="11"
                      fontWeight="600"
                      style={{ cursor: 'help' }}
                    >
                      <title>{faceCardInfo.english}: {faceCardInfo.power}</title>
                      {faceCardInfo.russian}
                    </text>
                  )}
                </g>
              );
            })}
          </g>
        );
      })}
    </g>
  );
}
