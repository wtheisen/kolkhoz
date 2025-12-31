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

  // Straight horizontal layout - no fan
  return (
    <div className="hand">
      {cards.map((card, idx) => {
        const isValid = !validIndices || validIndices.includes(idx);

        return (
          <div
            key={`${card.suit}-${card.value}-${idx}`}
            className={`hand-card ${isValid && canPlay ? 'playable' : ''} ${!isValid ? 'invalid' : ''}`}
            style={{
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
              width={130}
              highlight={isValid && canPlay}
              dimmed={!isValid && canPlay}
            />
          </div>
        );
      })}
    </div>
  );
}
