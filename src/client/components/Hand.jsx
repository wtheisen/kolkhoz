import React from 'react';
import { CardSVG } from './CardSVG.jsx';

export function Hand({
  cards,
  onPlayCard,
  canPlay,
  leadSuit,
  trump,
  validIndices,
}) {
  if (!cards || cards.length === 0) {
    return <div className="hand empty">No cards in hand</div>;
  }

  // Calculate fan layout
  const fanAngle = Math.min(8, 60 / cards.length); // Degrees per card
  const totalAngle = fanAngle * (cards.length - 1);
  const startAngle = -totalAngle / 2;

  return (
    <div className="hand">
      {cards.map((card, idx) => {
        const isValid = !validIndices || validIndices.includes(idx);
        const angle = startAngle + idx * fanAngle;
        const offsetY = Math.abs(angle) * 0.5; // Cards at edges dip down

        return (
          <div
            key={`${card.suit}-${card.value}-${idx}`}
            className={`hand-card ${isValid && canPlay ? 'playable' : ''} ${!isValid ? 'invalid' : ''}`}
            style={{
              transform: `rotate(${angle}deg) translateY(${offsetY}px)`,
              zIndex: idx,
            }}
            onClick={() => {
              if (canPlay && isValid) {
                onPlayCard(idx);
              }
            }}
          >
            <CardSVG
              card={card}
              width={100}
              highlight={isValid && canPlay}
              dimmed={!isValid && canPlay}
            />
          </div>
        );
      })}
    </div>
  );
}
