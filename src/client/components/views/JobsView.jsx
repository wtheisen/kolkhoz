import React, { useState, useEffect, useRef } from 'react';
import { getCardImagePath } from '../../../game/Card.js';
import { translations, t } from '../../translations.js';
import { SUITS } from '../../../game/constants.js';
import SuitIcon from '../SuitIcon.jsx';
import './JobsView.css';

const FACE_CARD_SYMBOLS = { 11: 'J', 12: 'Q', 13: 'K' };

// Find trump face cards (J, Q, K) in a job bucket
function getTrumpFaceCardsInBucket(bucket, trump) {
  if (!trump || !bucket) return [];
  return bucket
    .filter(card => card.suit === trump && card.value >= 11 && card.value <= 13)
    .map(card => FACE_CARD_SYMBOLS[card.value]);
}

export function JobsView({
  workHours,
  claimedJobs,
  jobBuckets,
  revealedJobs,
  trump,
  phase,
  lastTrick,
  pendingAssignments,
  assignDragState,
  onAssignDragStart,
  jobDropRefs,
  variants,
  language,
}) {
  // Calculate work value for a card (Jack of trump = 0 with nomenclature)
  const getWorkValue = (card) => {
    if (variants?.nomenclature && card.suit === trump && card.value === 11) {
      return 0;
    }
    return card.value;
  };

  // Track point popups per suit
  const [pointPopups, setPointPopups] = useState({});
  const prevAssignments = useRef({});

  // Detect when cards are assigned/unassigned and show popup
  useEffect(() => {
    const prev = prevAssignments.current;
    const current = pendingAssignments || {};

    // Find newly assigned cards (show +X)
    Object.entries(current).forEach(([cardKey, targetSuit]) => {
      if (prev[cardKey] !== targetSuit && targetSuit) {
        const cardEntry = lastTrick.find(([, card]) => `${card.suit}-${card.value}` === cardKey);
        if (cardEntry) {
          const cardValue = getWorkValue(cardEntry[1]);
          const popupKey = Date.now();
          setPointPopups(p => ({ ...p, [targetSuit]: { value: cardValue, type: 'add', key: popupKey } }));
          setTimeout(() => {
            setPointPopups(p => {
              if (p[targetSuit]?.key !== popupKey) return p;
              const copy = { ...p };
              delete copy[targetSuit];
              return copy;
            });
          }, 1200);
        }
      }
    });

    // Find cards that were removed from a suit (show -X)
    Object.entries(prev).forEach(([cardKey, oldSuit]) => {
      const newSuit = current[cardKey];
      if (oldSuit && oldSuit !== newSuit) {
        const cardEntry = lastTrick.find(([, card]) => `${card.suit}-${card.value}` === cardKey);
        if (cardEntry) {
          const cardValue = getWorkValue(cardEntry[1]);
          const popupKey = Date.now();
          setPointPopups(p => ({ ...p, [oldSuit]: { value: cardValue, type: 'remove', key: popupKey } }));
          setTimeout(() => {
            setPointPopups(p => {
              if (p[oldSuit]?.key !== popupKey) return p;
              const copy = { ...p };
              delete copy[oldSuit];
              return copy;
            });
          }, 1200);
        }
      }
    });

    prevAssignments.current = { ...current };
  }, [pendingAssignments, lastTrick, trump, variants]);

  const suitsInTrick = new Set(lastTrick.map(([, card]) => card.suit));

  return (
    <div className="assignment-view">
      <div className="assignment-grid">
        {SUITS.map((suit) => {
          const hours = workHours?.[suit] || 0;
          const isClaimed = claimedJobs?.includes(suit);
          const isTrump = suit === trump;
          const bucket = jobBuckets?.[suit] || [];

          const isAssignmentPhase = phase === 'assignment';
          const isValidTarget = isAssignmentPhase && suitsInTrick.has(suit);
          const isDropTarget = assignDragState && isValidTarget;
          const isDropHover = assignDragState?.dropTarget === suit;

          const assignedCards = isAssignmentPhase ? lastTrick.filter(([, card]) => {
            const cardKey = `${card.suit}-${card.value}`;
            return pendingAssignments[cardKey] === suit;
          }) : [];

          const pendingHours = assignedCards.reduce((sum, [, card]) => sum + getWorkValue(card), 0);
          const totalHours = hours + pendingHours;
          const popup = pointPopups[suit];

          const jobCard = revealedJobs?.[suit];
          const rewardCards = Array.isArray(jobCard) ? jobCard : jobCard ? [jobCard] : [];

          const trumpFaceCards = getTrumpFaceCardsInBucket(bucket, trump);

          const tileClasses = [
            'assign-job-tile',
            isTrump ? 'trump' : '',
            isClaimed ? 'claimed' : '',
            isAssignmentPhase && isValidTarget ? 'valid-target' : '',
            isAssignmentPhase && !isValidTarget && suitsInTrick.size > 0 ? 'invalid-target' : '',
            isDropTarget ? 'drop-target' : '',
            isDropHover ? 'drop-hover' : '',
          ].filter(Boolean).join(' ');

          return (
            <div
              key={suit}
              ref={(el) => { if (isValidTarget) jobDropRefs.current[suit] = el; }}
              className={tileClasses}
            >
              <div className="tile-header-row">
                <div className="tile-header-left">
                  <div className="tile-header-top">
                    <SuitIcon suit={suit} className="suit-symbol" />
                    {isTrump && <span className="trump-badge">★</span>}
                    {trumpFaceCards.length > 0 && (
                      <span className="trump-face-badges">
                        {trumpFaceCards.map(symbol => (
                          <span key={symbol} className="trump-face-badge">{symbol}</span>
                        ))}
                      </span>
                    )}
                    <div className="progress-track">
                      <div className="progress-fill" style={{ width: `${Math.min(100, (totalHours/40)*100)}%` }} />
                    </div>
                  </div>
                  <div className="progress-text-wrapper">
                    <span className="progress-text">{isClaimed ? '✓' : `${totalHours}/40`}</span>
                    {popup && (
                      <span key={popup.key} className={`point-popup ${popup.type}`}>
                        {popup.type === 'add' ? '+' : '-'}{popup.value}
                      </span>
                    )}
                  </div>
                </div>
                <div className="tile-header-right">
                  <div className="tile-reward">
                    {rewardCards.length > 0 && !isClaimed && totalHours < 40 ? (
                      <img
                        src={getCardImagePath(rewardCards[0])}
                        alt="reward"
                        className="reward-card"
                      />
                    ) : (
                      <img
                        src="assets/cards/back.svg"
                        alt="reward"
                        className={`reward-card ${isClaimed || totalHours >= 40 ? 'claimed' : 'dimmed'}`}
                      />
                    )}
                  </div>
                </div>
              </div>

              <div className={`tile-card-stack ${(bucket.length > 0 || assignedCards.length > 0) ? 'has-cards' : ''}`}>
                {bucket.map((card, idx) => (
                  <img
                    key={`bucket-${idx}`}
                    src={getCardImagePath(card)}
                    alt={`${card.value} of ${card.suit}`}
                    className="stacked-card bucket"
                  />
                ))}
                {assignedCards.map(([, card]) => {
                  const cardKey = `${card.suit}-${card.value}`;
                  const isDragging = assignDragState?.cardKey === cardKey;
                  return (
                    <div
                      key={cardKey}
                      className={`assigned-card-wrapper ${isDragging ? 'dragging' : ''}`}
                      onMouseDown={(e) => onAssignDragStart(cardKey, card, e)}
                      onTouchStart={(e) => onAssignDragStart(cardKey, card, e)}
                    >
                      <img
                        src={getCardImagePath(card)}
                        alt={`${card.value} of ${card.suit}`}
                        className="stacked-card assigned"
                        draggable={false}
                      />
                    </div>
                  );
                })}
                {isAssignmentPhase && isValidTarget && (
                  <span className="drop-hint">{t(translations, language, 'dropHere')}</span>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export default JobsView;
