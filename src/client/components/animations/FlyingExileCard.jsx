import React, { useEffect, useRef } from 'react';
import { getCardImagePath } from '../../../game/Card.js';
import './animations.css';

// Flying Exile Card Component - animates cards flying to gulag during requisition
export function FlyingExileCard({ card, playerIdx, delay, onComplete }) {
  const cardRef = useRef(null);
  const pointLossRef = useRef(null);
  const animationRef = useRef(null);
  const onCompleteRef = useRef(onComplete);

  // Keep the ref updated with the latest callback
  useEffect(() => {
    onCompleteRef.current = onComplete;
  }, [onComplete]);

  useEffect(() => {
    // Delay start based on stagger
    const delayTimeout = setTimeout(() => {
      // Source: find the card in the plot view by data attribute
      // For player 0, look in the player's plot section
      // For bots, look in the swap-bot-section
      let sourceCard;
      if (playerIdx === 0) {
        sourceCard = document.querySelector(
          `.swap-player-box .swap-card-slot[data-card="${card.suit}-${card.value}"], ` +
          `.swap-player-box .swap-mini-card[data-card="${card.suit}-${card.value}"]`
        );
      } else {
        sourceCard = document.querySelector(
          `.swap-bot-section[data-player="${playerIdx}"] .swap-mini-card[data-card="${card.suit}-${card.value}"]`
        );
      }

      // Target: gulag nav button
      const gulagButton = document.querySelector('.nav-btn[data-nav="gulag"]');

      if (!sourceCard || !gulagButton || !cardRef.current) {
        onCompleteRef.current();
        return;
      }

      // Hide the source card so we don't see duplicates
      sourceCard.style.opacity = '0';

      const sourceRect = sourceCard.getBoundingClientRect();
      const targetRect = gulagButton.getBoundingClientRect();

      const cardRect = cardRef.current.getBoundingClientRect();
      const startScale = sourceRect.width / cardRect.width;
      const endScale = Math.min(targetRect.width, targetRect.height) / cardRect.width * 0.6;

      // Set initial position
      cardRef.current.style.left = `${sourceRect.left + sourceRect.width / 2}px`;
      cardRef.current.style.top = `${sourceRect.top + sourceRect.height / 2}px`;
      cardRef.current.style.transform = `translate(-50%, -50%) scale(${startScale})`;
      cardRef.current.style.opacity = '1';

      // Position and animate point loss indicator
      if (pointLossRef.current) {
        const pointEl = pointLossRef.current;
        pointEl.style.left = `${sourceRect.left + sourceRect.width / 2}px`;
        pointEl.style.top = `${sourceRect.top}px`;

        // Animate point loss floating up and fading
        pointEl.animate([
          {
            transform: 'translate(-50%, 0) scale(0.5)',
            opacity: 0
          },
          {
            transform: 'translate(-50%, -20px) scale(1.3)',
            opacity: 1,
            offset: 0.15
          },
          {
            transform: 'translate(-50%, -60px) scale(1)',
            opacity: 1,
            offset: 0.5
          },
          {
            transform: 'translate(-50%, -100px) scale(0.9)',
            opacity: 0
          }
        ], { duration: 1200, fill: 'forwards', easing: 'ease-out' });
      }

      const animation = cardRef.current.animate([
        {
          left: `${sourceRect.left + sourceRect.width / 2}px`,
          top: `${sourceRect.top + sourceRect.height / 2}px`,
          transform: `translate(-50%, -50%) scale(${startScale})`,
          opacity: 1
        },
        {
          left: `${targetRect.left + targetRect.width / 2}px`,
          top: `${targetRect.top + targetRect.height / 2}px`,
          transform: `translate(-50%, -50%) scale(${endScale})`,
          opacity: 0.3
        }
      ], { duration: 800, fill: 'forwards', easing: 'ease-in' });

      animationRef.current = animation;
      animation.onfinish = () => onCompleteRef.current();
    }, delay);

    return () => {
      clearTimeout(delayTimeout);
      if (animationRef.current) {
        animationRef.current.cancel();
      }
    };
  }, [card, playerIdx, delay]);  // onComplete removed from deps - using ref instead

  return (
    <>
      <div ref={cardRef} className="flying-exile-card">
        <img src={getCardImagePath(card)} alt={`${card.value} of ${card.suit}`} />
      </div>
      <div ref={pointLossRef} className="exile-point-loss">
        -{card.value}
      </div>
    </>
  );
}

export default FlyingExileCard;
