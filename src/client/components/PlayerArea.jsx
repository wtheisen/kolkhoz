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

  // Sizing - match button height (~44px CSS)
  const cardWidth = 40 * scale;
  const cardHeight = cardWidth * 1.4;
  const cardOverlap = 17 * scale;
  const portraitSize = 48 * scale;
  const padding = 8 * scale;
  const sectionGap = 12 * scale;

  // Calculate widths for each section
  const infoWidth = 70 * scale;
  const handCardsWidth = Math.min(5, handSize) * cardOverlap + cardWidth - cardOverlap;
  const plotCardsWidth = revealedCards.length > 0
    ? revealedCards.length * cardOverlap + cardWidth - cardOverlap
    : (hiddenCount > 0 ? cardWidth : 0);
  const separatorGap = (revealedCards.length > 0 || hiddenCount > 0) ? 8 * scale : 0;

  // Total box dimensions - single row
  const boxWidth = padding + portraitSize + sectionGap + infoWidth + sectionGap + handCardsWidth + separatorGap + plotCardsWidth + padding;
  const boxHeight = Math.max(portraitSize, cardHeight) + padding * 2;

  // Layout positions
  const boxLeft = x - boxWidth / 2;
  const boxTop = y - boxHeight / 2;
  const centerY = y;

  // Horizontal positions
  let curX = boxLeft + padding;
  const portraitX = curX;
  curX += portraitSize + sectionGap;
  const infoX = curX;
  curX += infoWidth + sectionGap;
  const handX = curX;
  curX += handCardsWidth;
  const separatorX = curX + separatorGap / 2;
  const plotX = curX + separatorGap;

  return (
    <g className={`player-area ${isActive ? 'active' : ''}`}>
      {/* Background */}
      <rect
        x={boxLeft}
        y={boxTop}
        width={boxWidth}
        height={boxHeight}
        fill={isActive ? 'rgba(196, 30, 58, 0.2)' : 'rgba(20,20,20,0.85)'}
        stroke={isActive ? '#d4a857' : '#444'}
        strokeWidth={isActive ? 2 : 1}
        rx={4 * scale}
      />

      {/* Portrait */}
      <image
        href={PORTRAITS[(playerIndex - 1) % PORTRAITS.length]}
        x={portraitX}
        y={centerY - portraitSize / 2}
        width={portraitSize}
        height={portraitSize}
        style={{ imageRendering: 'pixelated' }}
      />

      {/* Name and stats */}
      <text
        x={infoX}
        y={centerY - 8 * scale}
        textAnchor="start"
        fill={isActive ? '#d4a857' : '#e8dcc4'}
        fontSize={13 * scale}
        fontWeight={isActive ? 'bold' : 'normal'}
        fontFamily="'Oswald', sans-serif"
      >
        {player.name}
        {isBrigadeLeader && ' ☆'}
      </text>
      <text
        x={infoX}
        y={centerY + 12 * scale}
        textAnchor="start"
        fill="#888"
        fontSize={10 * scale}
        fontFamily="'Oswald', sans-serif"
      >
        {handSize} cards
      </text>
      {visibleScore > 0 && (
        <text
          x={infoX + 48 * scale}
          y={centerY + 12 * scale}
          textAnchor="start"
          fill="#c41e3a"
          fontSize={10 * scale}
          fontFamily="'Oswald', sans-serif"
        >
          {visibleScore}pts
        </text>
      )}

      {/* Hand cards (backs) */}
      {Array.from({ length: Math.min(5, handSize) }).map((_, idx) => (
        <image
          key={`hand-${idx}`}
          href="assets/cards/back.svg"
          x={handX + idx * cardOverlap}
          y={centerY - cardHeight / 2}
          width={cardWidth}
          height={cardHeight}
        />
      ))}

      {/* Vertical separator line */}
      {(revealedCards.length > 0 || hiddenCount > 0) && (
        <line
          x1={separatorX}
          y1={centerY - cardHeight / 2 + 4 * scale}
          x2={separatorX}
          y2={centerY + cardHeight / 2 - 4 * scale}
          stroke="#555"
          strokeWidth={1 * scale}
        />
      )}

      {/* Revealed plot cards */}
      {revealedCards.map((card, idx) => (
        <image
          key={`revealed-${idx}`}
          href={getCardImagePath(card)}
          x={plotX + idx * cardOverlap}
          y={centerY - cardHeight / 2}
          width={cardWidth}
          height={cardHeight}
        />
      ))}

      {/* Hidden plot indicator (card back) if no revealed but has hidden */}
      {revealedCards.length === 0 && hiddenCount > 0 && (
        <image
          href="assets/cards/back.svg"
          x={plotX}
          y={centerY - cardHeight / 2}
          width={cardWidth}
          height={cardHeight}
          opacity={0.5}
        />
      )}
    </g>
  );
}
