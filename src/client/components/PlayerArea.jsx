import React from 'react';
import { getCardImagePath } from '../../game/Card.js';

// Portrait paths for AI players
const PORTRAITS = [
  '/assets/portraits/worker1.svg',
  '/assets/portraits/worker2.svg',
  '/assets/portraits/worker3.svg',
  '/assets/portraits/worker4.svg',
];

export function PlayerArea({ player, position, isActive, isBrigadeLeader, playerIndex, scale = 1 }) {
  const { x, y } = position;

  const handSize = player.hand?.length || 0;
  const revealedCards = player.plot?.revealed || [];
  const hiddenCount = player.plot?.hidden?.length || 0;

  // Calculate visible score (sum of revealed card values + hidden count as penalty)
  const visibleScore = revealedCards.reduce((sum, card) => sum + card.value, 0) + hiddenCount;

  // Sizing for compact two-row layout
  const cardWidth = 32 * scale;
  const cardHeight = cardWidth * 1.4;
  const cardOverlap = 14 * scale;
  const rowGap = 4 * scale;
  const padding = 6 * scale;

  // Two rows of cards - split hand cards
  const cardsPerRow = 3;
  const row1Cards = Math.min(cardsPerRow, handSize);
  const row2Cards = Math.min(cardsPerRow, Math.max(0, handSize - cardsPerRow));

  // Width based on cards per row
  const cardsWidth = cardsPerRow * cardOverlap + cardWidth - cardOverlap;

  // Box dimensions - compact vertical layout
  const boxWidth = cardsWidth + padding * 2;
  const boxHeight = padding + 20 * scale + rowGap + cardHeight + rowGap + cardHeight + padding;

  // Layout positions - centered on x
  const boxLeft = x - boxWidth / 2;
  const boxTop = y - boxHeight / 2;

  // Vertical positions
  const nameY = boxTop + padding + 12 * scale;
  const row1Y = nameY + 8 * scale;
  const row2Y = row1Y + cardHeight + rowGap;

  // Cards start position (centered)
  const cardsStartX = x - cardsWidth / 2;

  return (
    <g className={`player-area ${isActive ? 'active' : ''}`}>
      {/* Background */}
      <rect
        x={boxLeft}
        y={boxTop}
        width={boxWidth}
        height={boxHeight}
        fill={isActive ? 'rgba(196, 30, 58, 0.25)' : 'rgba(20,20,20,0.9)'}
        stroke={isActive ? '#d4a857' : '#444'}
        strokeWidth={isActive ? 2 : 1}
        rx={4 * scale}
      />

      {/* Name centered at top */}
      <text
        x={x}
        y={nameY}
        textAnchor="middle"
        fill={isActive ? '#d4a857' : '#e8dcc4'}
        fontSize={11 * scale}
        fontWeight={isActive ? 'bold' : 'normal'}
        fontFamily="'Oswald', sans-serif"
      >
        {player.name}
        {isBrigadeLeader && ' ☆'}
        {visibleScore > 0 && ` (${visibleScore})`}
      </text>

      {/* Row 1 of hand cards */}
      {Array.from({ length: row1Cards }).map((_, idx) => (
        <image
          key={`hand-r1-${idx}`}
          href="assets/cards/back.svg"
          x={cardsStartX + idx * cardOverlap}
          y={row1Y}
          width={cardWidth}
          height={cardHeight}
        />
      ))}

      {/* Row 2 of hand cards */}
      {Array.from({ length: row2Cards }).map((_, idx) => (
        <image
          key={`hand-r2-${idx}`}
          href="assets/cards/back.svg"
          x={cardsStartX + idx * cardOverlap}
          y={row2Y}
          width={cardWidth}
          height={cardHeight}
        />
      ))}

      {/* Show revealed plot cards on row 2 if no hand cards there */}
      {row2Cards === 0 && revealedCards.map((card, idx) => (
        <image
          key={`revealed-${idx}`}
          href={getCardImagePath(card)}
          x={cardsStartX + idx * cardOverlap}
          y={row2Y}
          width={cardWidth}
          height={cardHeight}
        />
      ))}
    </g>
  );
}
