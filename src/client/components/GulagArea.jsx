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

  // Get display name for face cards
  const getCardName = (value) => {
    const names = { 11: 'Jack', 12: 'Queen', 13: 'King', 1: 'Ace' };
    return names[value] || null;
  };

  const cardHeight = cardWidth * 1.4; // Standard card ratio

  // Get all years (1 to 5)
  const years = [1, 2, 3, 4, 5];

  return (
    <g className="gulag-area">
      {/* Title */}
      <text
        x={startX + 140}
        y={startY}
        textAnchor="middle"
        fill="#c41e3a"
        fontSize="12"
        fontWeight="bold"
        letterSpacing="0.1em"
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
              fill={isCurrent ? 'rgba(196,30,58,0.3)' : 'rgba(20,20,20,0.6)'}
              stroke={isCurrent ? '#c41e3a' : '#333'}
              strokeWidth={1}
              rx="4"
            />
            <text
              x={x + 30}
              y={y + 17}
              textAnchor="middle"
              fill={isPast ? '#a09080' : isCurrent ? '#c41e3a' : '#e8dcc4'}
              fontSize="11"
            >
              Year {year}
            </text>

            {/* Exiled cards stacked vertically */}
            {yearCards.map((cardKey, cardIdx) => {
              const card = parseCardKey(cardKey);
              const cardName = getCardName(card.value);
              const cardY = y + 35 + cardIdx * cardStackOffset;
              return (
                <g key={cardIdx}>
                  <CardSVG
                    card={card}
                    x={x + 10}
                    y={cardY}
                    width={cardWidth}
                  />
                  {cardName && (
                    <text
                      x={x + 30}
                      y={cardY + cardHeight + 8}
                      textAnchor="middle"
                      fill="#aaa"
                      fontSize="7"
                    >
                      {cardName}
                    </text>
                  )}
                </g>
              );
            })}

            {/* Empty state indicator */}
            {yearCards.length === 0 && isPast && (
              <text
                x={x + 30}
                y={y + 55}
                textAnchor="middle"
                fill="#333"
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
