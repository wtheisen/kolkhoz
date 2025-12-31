import React from 'react';
import { CardSVG } from './CardSVG.jsx';

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

  // Base unit for proportional scaling (all sizes derived from this)
  const unit = 7 * scale;

  // Derived sizes (all proportional to unit)
  const cardWidth = unit * 6;        // 42 at scale 1
  const cardSpacing = unit * 1.14;   // 8 at scale 1
  const portraitSize = unit * 8;     // 56 at scale 1
  const boxWidth = unit * 30;        // 210 at scale 1
  const boxHeight = unit * 21.4;     // 150 at scale 1
  const padding = unit * 1.14;       // 8 at scale 1

  // Font sizes (proportional)
  const nameSize = unit * 2.86;      // 20 at scale 1
  const infoSize = unit * 2.28;      // 16 at scale 1
  const smallSize = unit * 1.57;     // 11 at scale 1

  // Get portrait based on player index (wraps around if more than 4 players)
  const portraitSrc = PORTRAITS[(playerIndex - 1) % PORTRAITS.length];

  // Calculate total width needed for revealed cards
  const revealedWidth = revealedCards.length > 0
    ? revealedCards.length * (cardWidth + cardSpacing) - cardSpacing
    : 0;

  // Layout positions
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
        strokeWidth={isActive ? 2 * scale : 1 * scale}
        rx={padding}
      />

      {/* Portrait - upper left */}
      <image
        href={portraitSrc}
        x={boxLeft + padding}
        y={boxTop + padding}
        width={portraitSize}
        height={portraitSize}
        style={{ imageRendering: 'pixelated' }}
      />

      {/* Player name - to the right of portrait */}
      <text
        x={boxLeft + padding + portraitSize + padding * 1.5}
        y={boxTop + unit * 4}
        textAnchor="start"
        fill={isActive ? '#d4a857' : '#e8dcc4'}
        fontSize={nameSize}
        fontWeight={isActive ? 'bold' : 'normal'}
      >
        {player.name}
        {isBrigadeLeader && ' ☆'}
      </text>

      {/* Hand count - below name */}
      <text
        x={boxLeft + padding + portraitSize + padding * 1.5}
        y={boxTop + unit * 7.1}
        textAnchor="start"
        fill="#a09080"
        fontSize={infoSize}
      >
        Hand: {handSize}
      </text>

      {/* Medals - below hand count */}
      {player.medals > 0 && (
        <text
          x={boxLeft + padding + portraitSize + padding * 1.5}
          y={boxTop + unit * 10}
          textAnchor="start"
          fill="#FFD700"
          fontSize={infoSize * 0.875}
        >
          🏅 {player.medals}
        </text>
      )}

      {/* Hand (card backs) - below portrait row */}
      <g transform={`translate(${boxLeft + padding * 1.5}, ${boxTop + unit * 9.7})`}>
        {Array.from({ length: Math.min(5, handSize) }).map((_, idx) => (
          <CardSVG
            key={`hand-${idx}`}
            card={{}}
            faceDown={true}
            x={idx * unit * 2.14 + cardWidth / 2}
            y={cardWidth * 0.7}
            width={cardWidth}
          />
        ))}
      </g>

      {/* Revealed plot cards (visible to all) - at bottom */}
      {revealedCards.length > 0 && (
        <g transform={`translate(${x - revealedWidth / 2}, ${boxTop + boxHeight - padding * 1.25})`}>
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
          x={boxLeft + boxWidth - padding * 1.25}
          y={boxTop + boxHeight - padding}
          textAnchor="end"
          fill="#a09080"
          fontSize={smallSize}
        >
          +{hiddenCount} hidden
        </text>
      )}
    </g>
  );
}
