import React from 'react';
import { getCardImagePath } from '../../game/Card.js';

// Portrait paths for AI players
const PORTRAITS = [
  '/assets/portraits/worker1.svg',
  '/assets/portraits/worker2.svg',
  '/assets/portraits/worker3.svg',
  '/assets/portraits/worker4.svg',
];

export function PlayerArea({ player, position, isActive, isBrigadeLeader, playerIndex, scale = 1, isHuman = false }) {
  const { x, y } = position;

  const handSize = player.hand?.length || 0;
  const revealedCards = player.plot?.revealed || [];
  const hiddenCount = player.plot?.hidden?.length || 0;

  // Calculate visible score
  const visibleScore = revealedCards.reduce((sum, card) => sum + card.value, 0) + hiddenCount;

  // Sizing for content
  const cardWidth = 46 * scale;
  const cardHeight = cardWidth * 1.4;
  const cardOverlap = 26 * scale;
  const portraitSize = 52 * scale;
  const padding = 8 * scale;
  const rowGap = 6 * scale;

  // Human player: just show plot cards with golden dashed border (same size as bot areas)
  if (isHuman) {
    const boxWidth = 235 * scale;
    const boxHeight = 130 * scale;
    const boxLeft = x - boxWidth / 2;
    const boxTop = y - boxHeight / 2;

    // Cards centered in box
    const plotCardCount = revealedCards.length + hiddenCount;
    const plotWidth = plotCardCount > 0 ? (Math.min(4, plotCardCount) - 1) * cardOverlap + cardWidth : 0;
    const plotStartX = x - plotWidth / 2;
    const cardY = y - cardHeight / 2 + 10 * scale; // Slightly below center

    return (
      <g className="player-area human-plot">
        {/* Golden dashed border - same size as bot areas */}
        <rect
          x={boxLeft}
          y={boxTop}
          width={boxWidth}
          height={boxHeight}
          fill="none"
          stroke="#d4a857"
          strokeWidth={2 * scale}
          strokeDasharray={`${6 * scale},${4 * scale}`}
          rx={4 * scale}
        />
        {/* Label in upper left */}
        <text
          x={boxLeft + 8 * scale}
          y={boxTop + 16 * scale}
          textAnchor="start"
          fill="#d4a857"
          fontSize={11 * scale}
          fontFamily="'Oswald', sans-serif"
        >
          Подвал
        </text>
        {/* Revealed plot cards */}
        {revealedCards.map((card, idx) => (
          <image
            key={`plot-${idx}`}
            href={getCardImagePath(card)}
            x={plotStartX + idx * cardOverlap}
            y={cardY}
            width={cardWidth}
            height={cardHeight}
          />
        ))}
        {/* Hidden plot cards */}
        {Array.from({ length: hiddenCount }).map((_, idx) => (
          <image
            key={`hidden-${idx}`}
            href="assets/cards/back.svg"
            x={plotStartX + (revealedCards.length + idx) * cardOverlap}
            y={cardY}
            width={cardWidth}
            height={cardHeight}
            opacity={0.7}
          />
        ))}
      </g>
    );
  }

  // AI players: full layout
  const boxWidth = 235 * scale;
  const boxHeight = 130 * scale;

  // Center the box on x position
  const boxLeft = x - boxWidth / 2;
  const boxTop = y - boxHeight / 2;

  // Row 1 Y position (portrait and info)
  const row1Y = boxTop + padding;
  const row1CenterY = row1Y + portraitSize / 2;

  // Row 2 Y position (hand)
  const row2Y = row1Y + portraitSize + rowGap;

  // Content layout within fixed box - all centered
  const contentLeft = boxLeft + padding;

  // Row 1: Portrait | Name/Score | Plot (all fit in contentWidth)
  const portraitX = contentLeft;
  const infoX = portraitX + portraitSize + 6 * scale;
  const infoWidth = 65 * scale;
  const separatorX = infoX + infoWidth;
  const plotX = separatorX + 6 * scale;

  // Hand cards centered in box
  const handWidth = Math.min(4, handSize) * cardOverlap + cardWidth - cardOverlap;
  const handStartX = x - handWidth / 2;

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

      {/* Row 1: Portrait */}
      <image
        href={PORTRAITS[(playerIndex - 1) % PORTRAITS.length]}
        x={portraitX}
        y={row1Y}
        width={portraitSize}
        height={portraitSize}
        style={{ imageRendering: 'pixelated' }}
      />

      {/* Row 1: Name */}
      <text
        x={infoX}
        y={row1CenterY - 6 * scale}
        textAnchor="start"
        fill={isActive ? '#d4a857' : '#e8dcc4'}
        fontSize={12 * scale}
        fontWeight={isActive ? 'bold' : 'normal'}
        fontFamily="'Oswald', sans-serif"
      >
        {player.name}
        {isBrigadeLeader && ' ☆'}
      </text>

      {/* Row 1: Score */}
      <text
        x={infoX}
        y={row1CenterY + 10 * scale}
        textAnchor="start"
        fill={visibleScore > 0 ? '#c41e3a' : '#888'}
        fontSize={11 * scale}
        fontFamily="'Oswald', sans-serif"
      >
        {visibleScore > 0 ? `${visibleScore} pts` : `${handSize} cards`}
      </text>

      {/* Row 1: Vertical separator */}
      <line
        x1={separatorX}
        y1={row1Y + 4 * scale}
        x2={separatorX}
        y2={row1Y + portraitSize - 4 * scale}
        stroke="#555"
        strokeWidth={1}
      />

      {/* Row 1: Plot cards (revealed) */}
      {revealedCards.slice(0, 2).map((card, idx) => (
        <image
          key={`plot-${idx}`}
          href={getCardImagePath(card)}
          x={plotX + idx * cardOverlap}
          y={row1Y + (portraitSize - cardHeight) / 2}
          width={cardWidth}
          height={cardHeight}
        />
      ))}

      {/* Row 1: Hidden plot indicator if no revealed */}
      {revealedCards.length === 0 && hiddenCount > 0 && (
        <image
          href="assets/cards/back.svg"
          x={plotX}
          y={row1Y + (portraitSize - cardHeight) / 2}
          width={cardWidth}
          height={cardHeight}
          opacity={0.5}
        />
      )}

      {/* Row 2: Hand cards */}
      {Array.from({ length: Math.min(4, handSize) }).map((_, idx) => (
        <image
          key={`hand-${idx}`}
          href="assets/cards/back.svg"
          x={handStartX + idx * cardOverlap}
          y={row2Y}
          width={cardWidth}
          height={cardHeight}
        />
      ))}
      {handSize > 4 && (
        <text
          x={handStartX + 4 * cardOverlap + cardWidth / 2}
          y={row2Y + cardHeight / 2}
          textAnchor="middle"
          fill="#888"
          fontSize={9 * scale}
        >
          +{handSize - 4}
        </text>
      )}
    </g>
  );
}
