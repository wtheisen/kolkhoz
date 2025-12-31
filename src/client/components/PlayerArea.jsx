import React from 'react';
import { CardSVG } from './CardSVG.jsx';

export function PlayerArea({ player, position, isActive, isBrigadeLeader }) {
  const { x, y } = position;

  const handSize = player.hand?.length || 0;
  const revealedCards = player.plot?.revealed || [];
  const hiddenCount = player.plot?.hidden?.length || 0;
  const cardWidth = 50;
  const cardSpacing = 12;

  // Calculate total width needed for revealed cards
  const revealedWidth = revealedCards.length > 0
    ? revealedCards.length * (cardWidth + cardSpacing) - cardSpacing
    : 0;

  return (
    <g className={`player-area ${isActive ? 'active' : ''}`}>
      {/* Background - expanded to fit content */}
      <rect
        x={x - 120}
        y={y - 85}
        width={240}
        height={170}
        fill={isActive ? 'rgba(196, 30, 58, 0.2)' : 'rgba(20,20,20,0.8)'}
        stroke={isActive ? '#d4a857' : '#333'}
        strokeWidth={isActive ? 2 : 1}
        rx="10"
      />

      {/* Player name */}
      <text
        x={x}
        y={y - 65}
        textAnchor="middle"
        fill={isActive ? '#d4a857' : '#e8dcc4'}
        fontSize="16"
        fontWeight={isActive ? 'bold' : 'normal'}
      >
        {player.name}
        {isBrigadeLeader && ' ☆'}
      </text>

      {/* Medals */}
      {player.medals > 0 && (
        <text
          x={x + 85}
          y={y - 65}
          fill="#FFD700"
          fontSize="14"
        >
          🏅 {player.medals}
        </text>
      )}

      {/* Hand (card backs using actual card back asset) */}
      <g transform={`translate(${x - 55}, ${y - 45})`}>
        {Array.from({ length: Math.min(5, handSize) }).map((_, idx) => (
          <CardSVG
            key={`hand-${idx}`}
            card={{}}
            faceDown={true}
            x={idx * 20 + cardWidth / 2}
            y={cardWidth * 0.7}
            width={cardWidth}
          />
        ))}
        <text
          x={55}
          y={cardWidth * 1.4 + 22}
          textAnchor="middle"
          fill="#a09080"
          fontSize="12"
        >
          Hand: {handSize}
        </text>
      </g>

      {/* Revealed plot cards (visible to all) */}
      {revealedCards.length > 0 && (
        <g transform={`translate(${x - revealedWidth / 2}, ${y + 35})`}>
          {revealedCards.map((card, idx) => (
            <CardSVG
              key={`revealed-${idx}`}
              card={card}
              x={idx * (cardWidth + cardSpacing) + cardWidth / 2}
              y={cardWidth * 0.7}
              width={cardWidth}
            />
          ))}
        </g>
      )}

      {/* Hidden plot indicator */}
      {hiddenCount > 0 && (
        <text
          x={x}
          y={y + 78}
          textAnchor="middle"
          fill="#a09080"
          fontSize="12"
        >
          +{hiddenCount} hidden
        </text>
      )}
    </g>
  );
}
