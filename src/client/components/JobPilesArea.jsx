import React from 'react';
import { CardSVG } from './CardSVG.jsx';
import { SUITS, THRESHOLD, JOB_NAMES } from '../../game/constants.js';

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
  // Vertical layout on the left side - 4 jobs in a row
  const startX = 80;
  const startY = 150;
  const horizontalSpacing = 130; // Space between each job column
  const cardWidth = 45;
  const cardHeight = 63;
  const cardStackOffset = 20; // Vertical offset for stacked cards

  const getSuitColor = (suit) => {
    return suit === 'Hearts' || suit === 'Diamonds' ? '#c41e3a' : '#1a1a2e';
  };

  const getSuitSymbol = (suit) => {
    const symbols = { Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' };
    return symbols[suit];
  };

  return (
    <g className="job-piles-area">
      {SUITS.map((suit, idx) => {
        const x = startX + idx * horizontalSpacing;
        const y = startY;
        const hours = workHours[suit] || 0;
        const isClaimed = claimedJobs?.includes(suit);
        const isTrump = suit === trump;
        const bucket = jobBuckets[suit] || [];
        const progress = Math.min(80, (hours / THRESHOLD) * 80);

        // Get job reward card
        const jobCard = revealedJobs[suit];
        const jobCards = Array.isArray(jobCard) ? jobCard : jobCard ? [jobCard] : [];

        // Calculate total height needed for assigned cards
        const headerHeight = 100;

        return (
          <g key={suit} className={`job-pile ${isClaimed ? 'claimed' : ''}`}>
            {/* Job header background */}
            <rect
              x={x - 55}
              y={y - 30}
              width={110}
              height={headerHeight}
              fill={isTrump ? 'rgba(255,215,0,0.15)' : 'rgba(0,0,0,0.4)'}
              stroke={isTrump ? '#FFD700' : '#555'}
              strokeWidth={isTrump ? 2 : 1}
              rx="8"
            />

            {/* Trump indicator */}
            {isTrump && (
              <text
                x={x}
                y={y - 15}
                textAnchor="middle"
                fill="#FFD700"
                fontSize="9"
                fontWeight="bold"
              >
                TRUMP
              </text>
            )}

            {/* Suit symbol */}
            <text
              x={x}
              y={y + 8}
              textAnchor="middle"
              fill={getSuitColor(suit)}
              fontSize="20"
            >
              {getSuitSymbol(suit)}
            </text>

            {/* Job name */}
            <text
              x={x}
              y={y + 25}
              textAnchor="middle"
              fill="#bbb"
              fontSize="10"
            >
              {JOB_NAMES[suit]}
            </text>

            {/* Progress bar */}
            <rect
              x={x - 40}
              y={y + 35}
              width={80}
              height={8}
              fill="#333"
              rx="4"
            />
            <rect
              x={x - 40}
              y={y + 35}
              width={progress}
              height={8}
              fill={isClaimed ? '#4CAF50' : hours >= THRESHOLD ? '#4CAF50' : '#2196F3'}
              rx="4"
            />
            <text
              x={x}
              y={y + 42}
              textAnchor="middle"
              fill="white"
              fontSize="7"
            >
              {hours}/{THRESHOLD}
            </text>

            {/* Claimed indicator */}
            {isClaimed && (
              <text
                x={x}
                y={y + 60}
                textAnchor="middle"
                fill="#4CAF50"
                fontSize="9"
                fontWeight="bold"
              >
                COMPLETE
              </text>
            )}

            {/* Job reward card(s) - shown above the stack */}
            {jobCards.map((card, cardIdx) => (
              <CardSVG
                key={`reward-${cardIdx}`}
                card={card}
                x={x - cardWidth / 2 + cardIdx * 8}
                y={y + headerHeight - 25}
                width={cardWidth}
              />
            ))}

            {/* Assigned cards - stacked vertically beneath */}
            {bucket.map((card, cardIdx) => (
              <CardSVG
                key={`assigned-${cardIdx}`}
                card={card}
                x={x - cardWidth / 2}
                y={y + headerHeight + 50 + cardIdx * cardStackOffset}
                width={cardWidth}
              />
            ))}

            {/* Card count if cards are assigned */}
            {bucket.length > 0 && (
              <text
                x={x}
                y={y + headerHeight + 40}
                textAnchor="middle"
                fill="#888"
                fontSize="9"
              >
                {bucket.length} assigned
              </text>
            )}
          </g>
        );
      })}
    </g>
  );
}
