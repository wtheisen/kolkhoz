import React from 'react';
import { getCardImagePath } from '../../game/Card.js';

export function GulagArea({ exiled, currentYear }) {
  // Layout for sidebar - simple explicit positions
  const cardWidth = 55;
  const cardHeight = cardWidth * 1.4;
  const cardStackOffset = 16;

  const startY = 0;

  // Parse card key like "Hearts-11" into a card object
  const parseCardKey = (cardKey) => {
    const [suit, value] = cardKey.split('-');
    return { suit, value: parseInt(value, 10) };
  };

  // Calculate total exiled cards
  const totalExiled = Object.values(exiled || {}).flat().length;

  // Explicit pixel positions - evenly distributed in ~350px width
  const row1Y = startY + 32;
  const row1X = [58, 175, 292];
  const row2Y = row1Y + 145;
  const row2X = [116, 233];

  const yearBoxWidth = 50;
  const yearBoxHeight = 22;

  const renderYearColumn = (year, centerX, y) => {
    const yearCards = exiled?.[year] || [];
    const isPast = year < currentYear;
    const isCurrent = year === currentYear;

    return (
      <g key={year} className="gulag-year">
        {/* Year indicator box */}
        <rect
          x={centerX - yearBoxWidth / 2}
          y={y}
          width={yearBoxWidth}
          height={yearBoxHeight}
          fill={isCurrent ? 'rgba(196,30,58,0.35)' : 'rgba(30,30,30,0.9)'}
          stroke={isCurrent ? '#c41e3a' : '#3a3a3a'}
          strokeWidth={isCurrent ? 2 : 1}
        />

        {/* Year number */}
        <text
          x={centerX}
          y={y + 15}
          textAnchor="middle"
          fill={isPast ? '#5a5a5a' : isCurrent ? '#ff4757' : '#888'}
          fontSize="12"
          fontWeight={isCurrent ? 'bold' : 'normal'}
          fontFamily="monospace"
        >
          {year}
        </text>

        {/* Exiled cards - using direct image elements for proper alignment */}
        {yearCards.map((cardKey, cardIdx) => {
          const card = parseCardKey(cardKey);
          const cardY = y + yearBoxHeight + 8 + cardIdx * cardStackOffset;
          const imagePath = getCardImagePath(card);
          return (
            <image
              key={cardIdx}
              href={imagePath}
              x={centerX - cardWidth / 2}
              y={cardY}
              width={cardWidth}
              height={cardHeight}
            />
          );
        })}

        {/* Empty slot for past years */}
        {yearCards.length === 0 && isPast && (
          <rect
            x={centerX - cardWidth / 2}
            y={y + yearBoxHeight + 8}
            width={cardWidth}
            height={cardHeight}
            fill="none"
            stroke="#2a2a2a"
            strokeWidth={1}
            strokeDasharray="4,4"
            rx="3"
          />
        )}

        {/* Card count badge */}
        {yearCards.length > 0 && (
          <g>
            <circle
              cx={centerX + cardWidth / 2}
              cy={y + yearBoxHeight + 14}
              r={9}
              fill="#c41e3a"
            />
            <text
              x={centerX + cardWidth / 2}
              y={y + yearBoxHeight + 18}
              textAnchor="middle"
              fill="white"
              fontSize="10"
              fontWeight="bold"
            >
              {yearCards.length}
            </text>
          </g>
        )}
      </g>
    );
  };

  return (
    <g className="gulag-area">
      {/* Title */}
      <text
        x={175}
        y={startY + 4}
        textAnchor="middle"
        fill="#c41e3a"
        fontSize="14"
        fontWeight="bold"
        letterSpacing="0.2em"
        fontFamily="monospace"
      >
        GULAG
      </text>

      {/* Subtitle with count */}
      {totalExiled > 0 && (
        <text
          x={175}
          y={startY + 20}
          textAnchor="middle"
          fill="#555"
          fontSize="10"
          fontFamily="monospace"
        >
          [{totalExiled} exiled]
        </text>
      )}

      {/* Row 1: Years 1, 2, 3 */}
      {renderYearColumn(1, row1X[0], row1Y)}
      {renderYearColumn(2, row1X[1], row1Y)}
      {renderYearColumn(3, row1X[2], row1Y)}

      {/* Row 2: Years 4, 5 */}
      {renderYearColumn(4, row2X[0], row2Y)}
      {renderYearColumn(5, row2X[1], row2Y)}
    </g>
  );
}
