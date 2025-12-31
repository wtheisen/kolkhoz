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
  const startX = 20;
  const startY = 60;
  const columnWidth = 130;
  const cardWidth = 70;
  const cardHeight = 98;
  const stackOffset = 22;

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
        const rewardY = startY + 110;
        const assignedY = rewardY + cardHeight + 30;

        return (
          <g key={suit} className={`job-pile ${isClaimed ? 'claimed' : ''}`}>
            {/* Header box */}
            <rect
              x={centerX - 65}
              y={headerY}
              width={130}
              height={100}
              fill={isTrump ? 'rgba(255,215,0,0.12)' : 'rgba(0,0,0,0.5)'}
              stroke={isTrump ? '#FFD700' : '#444'}
              strokeWidth={isTrump ? 2 : 1}
              rx="6"
            />

            {/* Trump badge */}
            {isTrump && (
              <text
                x={centerX}
                y={headerY + 20}
                textAnchor="middle"
                fill="#FFD700"
                fontSize="16"
                fontWeight="bold"
              >
                TRUMP
              </text>
            )}

            {/* Suit symbol - large and centered */}
            <text
              x={centerX}
              y={headerY + (isTrump ? 50 : 42)}
              textAnchor="middle"
              fill={getSuitColor(suit)}
              fontSize="32"
            >
              {getSuitSymbol(suit)}
            </text>

            {/* Job name */}
            <g style={{ cursor: 'help' }}>
              <title>{JOB_TRANSLATIONS[suit]}</title>
              <text
                x={centerX}
                y={headerY + (isTrump ? 70 : 64)}
                textAnchor="middle"
                fill="#ccc"
                fontSize="16"
                fontWeight="600"
                pointerEvents="all"
              >
                {JOB_NAMES[suit]}
              </text>
            </g>

            {/* Progress bar */}
            <rect
              x={centerX - 55}
              y={headerY + 82}
              width={110}
              height={14}
              fill="#222"
              rx="7"
            />
            <rect
              x={centerX - 55}
              y={headerY + 82}
              width={Math.min(110, (hours / THRESHOLD) * 110)}
              height={14}
              fill={isClaimed ? '#4CAF50' : hours >= THRESHOLD ? '#4CAF50' : '#2196F3'}
              rx="7"
            />
            <text
              x={centerX}
              y={headerY + 93}
              textAnchor="middle"
              fill="white"
              fontSize="11"
              fontWeight="bold"
            >
              {isClaimed ? '✓ DONE' : `${hours}/${THRESHOLD}`}
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
                    <g style={{ cursor: 'help' }}>
                      <title>{faceCardInfo.english}: {faceCardInfo.power}</title>
                      <text
                        x={centerX + offsetX}
                        y={rewardY + cardHeight + 22}
                        textAnchor="middle"
                        fill="#FFD700"
                        fontSize="14"
                        fontWeight="600"
                        pointerEvents="all"
                      >
                        {faceCardInfo.russian}
                      </text>
                    </g>
                  )}
                </g>
              );
            })}

            {/* Assigned cards section */}
            {bucket.length > 0 && (
              <text
                x={centerX}
                y={assignedY - 8}
                textAnchor="middle"
                fill="#999"
                fontSize="13"
                fontWeight="500"
              >
                {bucket.length} assigned
              </text>
            )}

            {/* Render assigned cards */}
            {bucket.map((card, cardIdx) => {
              const cardY = assignedY + cardHeight / 2 + cardIdx * stackOffset;
              return (
                <g key={`assigned-${cardIdx}`}>
                  <CardSVG
                    card={card}
                    x={centerX}
                    y={cardY}
                    width={cardWidth}
                  />
                </g>
              );
            })}

            {/* Face card labels below the pile */}
            {(() => {
              const trumpFaceCards = bucket
                .map((card, idx) => ({ card, idx, info: getFaceCardInfo(card.value) }))
                .filter(({ card, info }) => card.suit === trump && info);

              if (trumpFaceCards.length === 0) return null;

              const lastCardY = assignedY + cardHeight / 2 + (bucket.length - 1) * stackOffset;
              const labelsStartY = lastCardY + cardHeight / 2 + 12;

              return trumpFaceCards.map(({ info }, labelIdx) => (
                <g key={`label-${labelIdx}`} style={{ cursor: 'help' }}>
                  <title>{info.english}: {info.power}</title>
                  <text
                    x={centerX}
                    y={labelsStartY + labelIdx * 16}
                    textAnchor="middle"
                    fill="#FFD700"
                    fontSize="13"
                    fontWeight="600"
                    pointerEvents="all"
                  >
                    {info.russian}
                  </text>
                </g>
              ));
            })()}
          </g>
        );
      })}
    </g>
  );
}
