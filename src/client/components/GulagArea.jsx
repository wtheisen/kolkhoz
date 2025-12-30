import React from 'react';
import { CardSVG } from './CardSVG.jsx';

export function GulagArea({ exiled, currentYear }) {
  const startX = 0;
  const startY = 0;
  const yearSpacing = 70;
  const cardWidth = 40;
  const cardStackOffset = 18;

  // Parse card key like "Hearts-11" into a card object
  const parseCardKey = (cardKey) => {
    const [suit, value] = cardKey.split('-');
    return { suit, value: parseInt(value, 10) };
  };

  // Get all years (1 to 5)
  const years = [1, 2, 3, 4, 5];

  return (
    <g className="gulag-area">
      {/* Title */}
      <text
        x={startX + 140}
        y={startY}
        textAnchor="middle"
        fill="#888"
        fontSize="12"
        fontWeight="bold"
      >
        GULAG
      </text>

      {years.map((year, idx) => {
        const x = startX + idx * yearSpacing;
        const y = startY + 20;
        const yearCards = exiled[year] || [];
        const isPast = year < currentYear;
        const isCurrent = year === currentYear;

        return (
          <g key={year} className="gulag-year">
            {/* Year header */}
            <rect
              x={x}
              y={y}
              width={60}
              height={25}
              fill={isCurrent ? 'rgba(196,30,58,0.3)' : 'rgba(0,0,0,0.3)'}
              stroke={isCurrent ? '#c41e3a' : '#444'}
              strokeWidth={1}
              rx="4"
            />
            <text
              x={x + 30}
              y={y + 17}
              textAnchor="middle"
              fill={isPast ? '#666' : isCurrent ? '#c41e3a' : '#888'}
              fontSize="11"
            >
              Year {year}
            </text>

            {/* Exiled cards stacked vertically */}
            {yearCards.map((cardKey, cardIdx) => {
              const card = parseCardKey(cardKey);
              return (
                <CardSVG
                  key={cardIdx}
                  card={card}
                  x={x + 10}
                  y={y + 35 + cardIdx * cardStackOffset}
                  width={cardWidth}
                />
              );
            })}

            {/* Empty state indicator */}
            {yearCards.length === 0 && isPast && (
              <text
                x={x + 30}
                y={y + 55}
                textAnchor="middle"
                fill="#444"
                fontSize="9"
              >
                -
              </text>
            )}
          </g>
        );
      })}
    </g>
  );
}
