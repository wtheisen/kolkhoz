import React from 'react';
import { CardSVG } from './CardSVG.jsx';

export function TrickArea({ trick, numPlayers, lead, centerX = 960, centerY = 450 }) {
  // Center of the trick area (can be overridden via props)
  const radius = 100;

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
      {/* Table circle */}
      <circle
        cx={centerX}
        cy={centerY}
        r={radius + 80}
        fill="#2d5016"
        stroke="#8B4513"
        strokeWidth="8"
      />
      <circle
        cx={centerX}
        cy={centerY}
        r={radius + 60}
        fill="none"
        stroke="#3d6b1e"
        strokeWidth="2"
      />

      {/* Lead indicator */}
      {trick.length > 0 && (
        <text
          x={centerX}
          y={centerY - radius - 40}
          textAnchor="middle"
          fill="#FFD700"
          fontSize="14"
        >
          Lead: {trick[0][1].suit}
        </text>
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
            width={80}
            rotation={playerIdx * 90}
          />
        );
      })}

      {/* Empty slots for players who haven't played */}
      {Array.from({ length: numPlayers }).map((_, idx) => {
        const hasPlayed = trick.some(([pid]) => pid === idx);
        if (hasPlayed) return null;

        const pos = getCardPosition(idx);
        return (
          <rect
            key={`slot-${idx}`}
            x={centerX + pos.x - 40}
            y={centerY + pos.y - 56}
            width={80}
            height={112}
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
