import React from 'react';
import { CardSVG } from './CardSVG.jsx';

// Portrait paths for AI players
const PORTRAITS = [
  '/assets/portraits/worker1.svg',
  '/assets/portraits/worker2.svg',
  '/assets/portraits/worker3.svg',
  '/assets/portraits/worker4.svg',
];

export function PlayerArea({ player, position, isActive, isBrigadeLeader, playerIndex }) {
  const { x, y } = position;

  const handSize = player.hand?.length || 0;
  const revealedCards = player.plot?.revealed || [];
  const hiddenCount = player.plot?.hidden?.length || 0;
  const cardWidth = 42;
  const cardSpacing = 8;
  const portraitSize = 56;

  // Get portrait based on player index (wraps around if more than 4 players)
  const portraitSrc = PORTRAITS[(playerIndex - 1) % PORTRAITS.length];

  // Calculate total width needed for revealed cards
  const revealedWidth = revealedCards.length > 0
    ? revealedCards.length * (cardWidth + cardSpacing) - cardSpacing
    : 0;

  // Layout constants
  const boxWidth = 210;
  const boxHeight = 150;
  const boxLeft = x - boxWidth / 2;
  const boxTop = y - boxHeight / 2;

  return (
    <g className={`player-area ${isActive ? 'active' : ''}`}>
      {/* Background */}
      <rect
        x={boxLeft}
        y={boxTop}
        width={boxWidth}
        height={boxHeight}
        fill={isActive ? 'rgba(196, 30, 58, 0.2)' : 'rgba(20,20,20,0.8)'}
        stroke={isActive ? '#d4a857' : '#333'}
        strokeWidth={isActive ? 2 : 1}
        rx="8"
      />

      {/* Portrait - upper left */}
      <image
        href={portraitSrc}
        x={boxLeft + 8}
        y={boxTop + 8}
        width={portraitSize}
        height={portraitSize}
        style={{ imageRendering: 'pixelated' }}
      />

      {/* Player name - to the right of portrait */}
      <text
        x={boxLeft + 8 + portraitSize + 10}
        y={boxTop + 24}
        textAnchor="start"
        fill={isActive ? '#d4a857' : '#e8dcc4'}
        fontSize="14"
        fontWeight={isActive ? 'bold' : 'normal'}
      >
        {player.name}
        {isBrigadeLeader && ' ☆'}
      </text>

      {/* Hand count - below name */}
      <text
        x={boxLeft + 8 + portraitSize + 10}
        y={boxTop + 42}
        textAnchor="start"
        fill="#a09080"
        fontSize="12"
      >
        Hand: {handSize}
      </text>

      {/* Medals - below hand count */}
      {player.medals > 0 && (
        <text
          x={boxLeft + 8 + portraitSize + 10}
          y={boxTop + 58}
          textAnchor="start"
          fill="#FFD700"
          fontSize="12"
        >
          🏅 {player.medals}
        </text>
      )}

      {/* Hand (card backs) - below portrait row */}
      <g transform={`translate(${boxLeft + 12}, ${boxTop + 68})`}>
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
      </g>

      {/* Revealed plot cards (visible to all) - at bottom */}
      {revealedCards.length > 0 && (
        <g transform={`translate(${x - revealedWidth / 2}, ${boxTop + boxHeight - 10})`}>
          {revealedCards.map((card, idx) => (
            <CardSVG
              key={`revealed-${idx}`}
              card={card}
              x={idx * (cardWidth + cardSpacing) + cardWidth / 2}
              y={0}
              width={cardWidth}
            />
          ))}
        </g>
      )}

      {/* Hidden plot indicator */}
      {hiddenCount > 0 && (
        <text
          x={boxLeft + boxWidth - 10}
          y={boxTop + boxHeight - 8}
          textAnchor="end"
          fill="#a09080"
          fontSize="11"
        >
          +{hiddenCount} hidden
        </text>
      )}
    </g>
  );
}
