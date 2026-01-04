import React, { useState, useEffect, useRef } from 'react';
import { getCardImagePath } from '../../../game/Card.js';
import './animations.css';

// Flying Card Component - uses Web Animations API for AI assignment animation
export function FlyingCard({ card, playerIdx, targetSuit, cardValue, onComplete }) {
  const cardRef = useRef(null);
  const animationRef = useRef(null);
  const onCompleteRef = useRef(onComplete);
  const [showValue, setShowValue] = useState(false);

  // Keep the ref updated with the latest callback
  useEffect(() => {
    onCompleteRef.current = onComplete;
  }, [onComplete]);

  useEffect(() => {
    const slotClasses = ['left', 'center-left', 'center-right', 'right'];
    const slotOrder = [3, 0, 1, 2];
    const slotClass = slotClasses[slotOrder[playerIdx]];

    const sourceSlot = document.querySelector(`.player-column.${slotClass} .card-slot`);
    const targetJob = document.querySelector(`.job-indicator .suit-symbol.${targetSuit.toLowerCase()}`);

    if (!sourceSlot || !targetJob || !cardRef.current) {
      onCompleteRef.current();
      return;
    }

    const sourceRect = sourceSlot.getBoundingClientRect();
    const targetRect = targetJob.getBoundingClientRect();

    const cardRect = cardRef.current.getBoundingClientRect();
    const startScale = sourceRect.width / cardRect.width;
    const endScale = targetRect.width / cardRect.width;

    // Set initial position immediately to prevent jump
    cardRef.current.style.left = `${sourceRect.left + sourceRect.width / 2}px`;
    cardRef.current.style.top = `${sourceRect.top + sourceRect.height / 2}px`;
    cardRef.current.style.transform = `translate(-50%, -50%) scale(${startScale})`;

    const animation = cardRef.current.animate([
      {
        left: `${sourceRect.left + sourceRect.width / 2}px`,
        top: `${sourceRect.top + sourceRect.height / 2}px`,
        transform: `translate(-50%, -50%) scale(${startScale})`
      },
      {
        left: `${targetRect.left + targetRect.width / 2}px`,
        top: `${targetRect.top + targetRect.height / 2}px`,
        transform: `translate(-50%, -50%) scale(${endScale})`
      }
    ], { duration: 650, fill: 'forwards', easing: 'ease-in-out' });

    animationRef.current = animation;

    // Show +X value as card lands
    const valueTimeout = setTimeout(() => setShowValue(true), 570);

    // Delay completion to let the +X number persist
    let completionTimeout;
    animation.onfinish = () => {
      completionTimeout = setTimeout(() => onCompleteRef.current(), 800);
    };

    // Cleanup function
    return () => {
      clearTimeout(valueTimeout);
      clearTimeout(completionTimeout);
      if (animationRef.current) {
        animationRef.current.cancel();
      }
    };
  }, [playerIdx, targetSuit]);  // onComplete removed from deps - using ref instead

  return (
    <div ref={cardRef} className="flying-card-html">
      <img src={getCardImagePath(card)} alt={`${card.value} of ${card.suit}`} />
      {showValue && <span className="flying-value">+{cardValue}</span>}
    </div>
  );
}

export default FlyingCard;
