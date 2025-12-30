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
  const startX = 360;
  const y = 120;
  const spacing = 400;

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
        const x = startX + idx * spacing;
        const hours = workHours[suit] || 0;
        const isClaimed = claimedJobs?.includes(suit);
        const isTrump = suit === trump;
        const bucket = jobBuckets[suit] || [];
        const progress = Math.min(100, (hours / THRESHOLD) * 100);

        // Get job reward card
        const jobCard = revealedJobs[suit];
        const jobCards = Array.isArray(jobCard) ? jobCard : jobCard ? [jobCard] : [];

        return (
          <g key={suit} className={`job-pile ${isClaimed ? 'claimed' : ''}`}>
            {/* Background */}
            <rect
              x={x - 70}
              y={y - 20}
              width={140}
              height={200}
              fill={isTrump ? 'rgba(255,215,0,0.1)' : 'rgba(0,0,0,0.3)'}
              stroke={isTrump ? '#FFD700' : '#444'}
              strokeWidth={isTrump ? 3 : 1}
              rx="10"
            />

            {/* Suit symbol and name */}
            <text
              x={x}
              y={y + 10}
              textAnchor="middle"
              fill={getSuitColor(suit)}
              fontSize="24"
            >
              {getSuitSymbol(suit)}
            </text>
            <text
              x={x}
              y={y + 35}
              textAnchor="middle"
              fill="#ccc"
              fontSize="12"
            >
              {JOB_NAMES[suit]}
            </text>

            {/* Progress bar */}
            <rect
              x={x - 50}
              y={y + 50}
              width={100}
              height={12}
              fill="#333"
              rx="6"
            />
            <rect
              x={x - 50}
              y={y + 50}
              width={progress}
              height={12}
              fill={isClaimed ? '#4CAF50' : hours >= THRESHOLD ? '#4CAF50' : '#2196F3'}
              rx="6"
            />
            <text
              x={x}
              y={y + 60}
              textAnchor="middle"
              fill="white"
              fontSize="10"
            >
              {hours}/{THRESHOLD}
            </text>

            {/* Job reward card(s) */}
            {jobCards.map((card, cardIdx) => (
              <CardSVG
                key={cardIdx}
                card={card}
                x={x + cardIdx * 10}
                y={y + 110}
                width={50}
              />
            ))}

            {/* Assigned cards indicator */}
            {bucket.length > 0 && (
              <text
                x={x}
                y={y + 170}
                textAnchor="middle"
                fill="#888"
                fontSize="11"
              >
                {bucket.length} cards assigned
              </text>
            )}

            {/* Trump indicator */}
            {isTrump && (
              <text
                x={x}
                y={y - 5}
                textAnchor="middle"
                fill="#FFD700"
                fontSize="10"
              >
                TRUMP
              </text>
            )}

            {/* Claimed indicator */}
            {isClaimed && (
              <text
                x={x}
                y={y + 190}
                textAnchor="middle"
                fill="#4CAF50"
                fontSize="12"
                fontWeight="bold"
              >
                COMPLETE
              </text>
            )}
          </g>
        );
      })}
    </g>
  );
}
