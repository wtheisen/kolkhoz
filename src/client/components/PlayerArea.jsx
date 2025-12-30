import React from 'react';
import { CardSVG } from './CardSVG.jsx';

export function PlayerArea({ player, position, isActive, isBrigadeLeader }) {
  const { x, y } = position;

  const handSize = player.hand?.length || 0;
  const revealedCards = player.plot?.revealed || [];
  const hiddenCount = player.plot?.hidden?.length || 0;
  const cardWidth = 35;
  const cardSpacing = 10;

  // Calculate total width needed for revealed cards
  const revealedWidth = revealedCards.length > 0
    ? revealedCards.length * (cardWidth + cardSpacing) - cardSpacing
    : 0;

  return (
    <g className={`player-area ${isActive ? 'active' : ''}`}>
      {/* Background - expanded to fit content */}
      <rect
        x={x - 100}
        y={y - 70}
        width={200}
        height={140}
        fill={isActive ? 'rgba(76, 175, 80, 0.2)' : 'rgba(0,0,0,0.3)'}
        stroke={isActive ? '#4CAF50' : '#444'}
        strokeWidth={isActive ? 2 : 1}
        rx="10"
      />

      {/* Player name */}
      <text
        x={x}
        y={y - 52}
        textAnchor="middle"
        fill={isActive ? '#4CAF50' : '#fff'}
        fontSize="14"
        fontWeight={isActive ? 'bold' : 'normal'}
      >
        {player.name}
        {isBrigadeLeader && ' 🎖️'}
      </text>

      {/* Medals */}
      {player.medals > 0 && (
        <text
          x={x + 70}
          y={y - 52}
          fill="#FFD700"
          fontSize="12"
        >
          🏅 {player.medals}
        </text>
      )}

      {/* Hand (card backs using actual card back asset) */}
      <g transform={`translate(${x - 40}, ${y - 35})`}>
        {Array.from({ length: Math.min(5, handSize) }).map((_, idx) => (
          <CardSVG
            key={`hand-${idx}`}
            card={{}}
            faceDown={true}
            x={idx * 15 + cardWidth / 2}
            y={cardWidth * 0.7}
            width={cardWidth}
          />
        ))}
        <text
          x={40}
          y={cardWidth * 1.4 + 18}
          textAnchor="middle"
          fill="#888"
          fontSize="10"
        >
          Hand: {handSize}
        </text>
      </g>

      {/* Revealed plot cards (visible to all) */}
      {revealedCards.length > 0 && (
        <g transform={`translate(${x - revealedWidth / 2}, ${y + 25})`}>
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
          y={y + 62}
          textAnchor="middle"
          fill="#888"
          fontSize="10"
        >
          +{hiddenCount} hidden
        </text>
      )}
    </g>
  );
}
