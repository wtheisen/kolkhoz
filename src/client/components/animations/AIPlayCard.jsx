import React, { useRef, useLayoutEffect } from 'react';
import { getCardImagePath } from '../../../game/Card.js';
import './animations.css';

// AI Play Card Component - animates AI card from hand area to slot
// Uses CSS transitions with transform-only for GPU acceleration
export function AIPlayCard({ card, playerIdx }) {
  const cardRef = useRef(null);

  useLayoutEffect(() => {
    const slotClasses = ['left', 'center-left', 'center-right', 'right'];
    const slotOrder = [3, 0, 1, 2];
    const slotClass = slotClasses[slotOrder[playerIdx]];

    const playerPanel = document.querySelector(`.player-column.${slotClass} .player-panel`);
    const targetSlot = document.querySelector(`.player-column.${slotClass} .card-slot`);

    if (!playerPanel || !targetSlot || !cardRef.current) return;

    const sourceRect = playerPanel.getBoundingClientRect();
    const targetRect = targetSlot.getBoundingClientRect();
    const cardRect = cardRef.current.getBoundingClientRect();

    const startScale = (sourceRect.width * 0.3) / cardRect.width;
    const targetScale = targetRect.width / cardRect.width;

    // Calculate positions - target top-left of the slot
    const startX = sourceRect.left + sourceRect.width / 2;
    const startY = sourceRect.top + sourceRect.height / 2;
    const endX = targetRect.left;
    const endY = targetRect.top;

    // Disable transition, set start position
    cardRef.current.style.transition = 'none';
    cardRef.current.style.transform = `translate(${startX}px, ${startY}px) scale(${startScale})`;

    // Force reflow, then enable transition and animate to target
    cardRef.current.offsetHeight;
    cardRef.current.style.transition = '';
    cardRef.current.style.transform = `translate(${endX}px, ${endY}px) scale(${targetScale})`;
  }, [playerIdx, card.suit, card.value]);

  return (
    <div ref={cardRef} className="ai-play-card">
      <img src={getCardImagePath(card)} alt={`${card.value} of ${card.suit}`} />
    </div>
  );
}

export default AIPlayCard;
