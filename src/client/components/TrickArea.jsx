import React from 'react';
import { CardSVG } from './CardSVG.jsx';

export function TrickArea({ trick, numPlayers, lead, centerX = 960, centerY = 450 }) {
  // Center of the trick area (can be overridden via props)
  const radius = 140;
  const cardWidth = 100;

  // Calculate positions for cards in circular arrangement
  const getCardPosition = (playerIdx) => {
    // Positions relative to center
    // Player 0 at bottom, going clockwise
    const positions = [
      { x: 0, y: radius },      // Bottom (player 0)
      { x: -radius, y: 0 },     // Left (player 1)
      { x: 0, y: -radius },     // Top (player 2)
      { x: radius, y: 0 },      // Right (player 3)
    ];
    return positions[playerIdx] || positions[0];
  };

  return (
    <g className="trick-area">
      {/* Table circle - Soviet theme with dark background and gold border */}
      <circle
        cx={centerX}
        cy={centerY}
        r={radius + 100}
        fill="#1a1a1a"
        stroke="#d4a857"
        strokeWidth="3"
      />
      <circle
        cx={centerX}
        cy={centerY}
        r={radius + 80}
        fill="none"
        stroke="#8b0000"
        strokeWidth="2"
      />

      {/* Lead indicator - centered in play area */}
      {trick.length > 0 && (
        <g>
          <text
            x={centerX}
            y={centerY - 14}
            textAnchor="middle"
            fill="#FFD700"
            fontSize="14"
            fontWeight="bold"
          >
            Lead:
          </text>
          <text
            x={centerX}
            y={centerY + 16}
            textAnchor="middle"
            fill={trick[0][1].suit === 'Hearts' || trick[0][1].suit === 'Diamonds' ? '#c41e3a' : '#e8dcc4'}
            fontSize="28"
          >
            {{ Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' }[trick[0][1].suit]}
          </text>
        </g>
      )}

      {/* Cards played */}
      {trick.map(([playerIdx, card], idx) => {
        const pos = getCardPosition(playerIdx);
        return (
          <CardSVG
            key={`${card.suit}-${card.value}`}
            card={card}
            x={centerX + pos.x}
            y={centerY + pos.y}
            width={cardWidth}
            rotation={playerIdx * 90}
          />
        );
      })}

      {/* Empty slots for players who haven't played */}
      {Array.from({ length: numPlayers }).map((_, idx) => {
        const hasPlayed = trick.some(([pid]) => pid === idx);
        if (hasPlayed) return null;

        const pos = getCardPosition(idx);
        const cardHeight = cardWidth * 1.4;
        return (
          <rect
            key={`slot-${idx}`}
            x={centerX + pos.x - cardWidth / 2}
            y={centerY + pos.y - cardHeight / 2}
            width={cardWidth}
            height={cardHeight}
            fill="none"
            stroke="rgba(255,255,255,0.2)"
            strokeWidth="2"
            strokeDasharray="5,5"
            rx="8"
          />
        );
      })}
    </g>
  );
}
