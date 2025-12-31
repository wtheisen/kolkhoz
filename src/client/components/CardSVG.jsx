import React from 'react';
import { getCardImagePath } from '../../game/Card.js';

// Convert numeric card value to display name for accessibility
function getCardValueName(value) {
  const names = {
    1: 'Ace',
    11: 'Jack',
    12: 'Queen',
    13: 'King',
  };
  return names[value] || String(value);
}

export function CardSVG({
  card,
  x = 0,
  y = 0,
  width = 100,
  rotation = 0,
  faceDown = false,
  onClick,
  highlight = false,
  dimmed = false,
  className = '',
}) {
  const height = width * 1.4; // Standard card ratio
  const imagePath = faceDown ? 'assets/cards/back.svg' : getCardImagePath(card);

  // For SVG context (inside <svg>)
  if (x !== 0 || y !== 0) {
    return (
      <g
        className={`card-svg ${className} ${highlight ? 'highlight' : ''} ${dimmed ? 'dimmed' : ''}`}
        transform={`translate(${x}, ${y}) rotate(${rotation})`}
        onClick={onClick}
        style={{ cursor: onClick ? 'pointer' : 'default' }}
      >
        <image
          href={imagePath}
          width={width}
          height={height}
          x={-width / 2}
          y={-height / 2}
        />
        {highlight && (
          <rect
            x={-width / 2 - 4}
            y={-height / 2 - 4}
            width={width + 8}
            height={height + 8}
            fill="none"
            stroke="#d4a857"
            strokeWidth="3"
            rx="8"
          />
        )}
      </g>
    );
  }

  // For HTML context (outside <svg>)
  return (
    <div
      className={`card-html ${className} ${highlight ? 'highlight' : ''} ${dimmed ? 'dimmed' : ''}`}
      onClick={onClick}
      style={{
        width: `${width}px`,
        height: `${height}px`,
        cursor: onClick ? 'pointer' : 'default',
      }}
    >
      <img
        src={imagePath}
        alt={faceDown ? 'Card back' : `${getCardValueName(card.value)} of ${card.suit}`}
        style={{ width: '100%', height: '100%' }}
      />
    </div>
  );
}
