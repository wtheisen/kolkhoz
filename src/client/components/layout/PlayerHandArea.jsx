import React from 'react';
import { getCardImagePath } from '../../../game/Card.js';
import { translations, t } from '../../translations.js';
import './PlayerHandArea.css';

export function PlayerHandArea({
  phase,
  playerData,
  currentPlayer,
  isMyTurn,
  lastWinner,
  lastTrick,
  pendingAssignments,
  swapCount,
  swapConfirmed,
  currentSwapPlayer,
  swapConfirmedLocally,
  // Drag states
  dragState,
  swapDragState,
  assignDragState,
  // Refs
  plotCardRefs,
  handCardRefs,
  // Callbacks
  getValidIndices,
  onDragStart,
  onSwapDragStart,
  onAssignDragStart,
  onSubmitAssignments,
  onConfirmSwap,
  onUndoSwap,
  // Language
  language,
}) {
  const plotRevealed = playerData?.plot?.revealed || [];
  const plotHidden = playerData?.plot?.hidden || [];
  const hand = playerData?.hand || [];
  const hasPlotCards = plotRevealed.length > 0 || plotHidden.length > 0;

  return (
    <div className={`player-hand-area ${phase === 'assignment' ? 'assignment-mode' : ''} ${phase === 'swap' ? 'swap-mode' : ''}`}>
      {/* ZONE 1: Plot cards (hidden during swap phase - shown in panel instead) */}
      {phase !== 'swap' && hasPlotCards && (
        <div className="plot-cards-section">
          {plotRevealed.map((card, idx) => {
            const isSwapDragging = swapDragState?.sourceType === 'plot-revealed' && swapDragState?.sourceIndex === idx;
            const isSwapTarget = phase === 'swap' && swapDragState?.sourceType === 'hand';
            const isSwapHover = swapDragState?.dropTarget?.type === 'plot-revealed' && swapDragState?.dropTarget?.index === idx;

            return (
              <div
                key={`revealed-${card.suit}-${card.value}`}
                ref={(el) => { plotCardRefs.current[`revealed-${idx}`] = el; }}
                className={`plot-card revealed ${phase === 'trick' ? 'dimmed' : ''} ${phase === 'swap' ? 'swappable' : ''} ${isSwapDragging ? 'swap-dragging' : ''} ${isSwapTarget ? 'swap-target' : ''} ${isSwapHover ? 'swap-hover' : ''}`}
                style={{ '--index': idx }}
                onMouseDown={(e) => onSwapDragStart('plot-revealed', idx, card, e)}
                onTouchStart={(e) => onSwapDragStart('plot-revealed', idx, card, e)}
              >
                <img
                  src={getCardImagePath(card)}
                  alt={`${card.value} of ${card.suit}`}
                  draggable={false}
                />
              </div>
            );
          })}
          {plotHidden.map((card, idx) => {
            const isSwapDragging = swapDragState?.sourceType === 'plot-hidden' && swapDragState?.sourceIndex === idx;
            const isSwapTarget = phase === 'swap' && swapDragState?.sourceType === 'hand';
            const isSwapHover = swapDragState?.dropTarget?.type === 'plot-hidden' && swapDragState?.dropTarget?.index === idx;
            const totalIdx = plotRevealed.length + idx;

            return (
              <div
                key={`hidden-${card.suit}-${card.value}`}
                ref={(el) => { plotCardRefs.current[`hidden-${idx}`] = el; }}
                className={`plot-card hidden ${phase === 'trick' ? 'dimmed' : ''} ${phase === 'swap' ? 'swappable' : ''} ${isSwapDragging ? 'swap-dragging' : ''} ${isSwapTarget ? 'swap-target' : ''} ${isSwapHover ? 'swap-hover' : ''}`}
                style={{ '--index': totalIdx }}
                onMouseDown={(e) => onSwapDragStart('plot-hidden', idx, card, e)}
                onTouchStart={(e) => onSwapDragStart('plot-hidden', idx, card, e)}
              >
                <img
                  src={getCardImagePath(card)}
                  alt={`${card.value} of ${card.suit}`}
                  draggable={false}
                />
              </div>
            );
          })}
        </div>
      )}

      {/* Divider between plot and hand (non-swap phases) */}
      {phase !== 'swap' && hasPlotCards && (
        <div className="hand-divider" />
      )}

      {/* Hand cards */}
      <div className="hand-cards-section">
        {hand.map((card, idx) => {
          const validIndices = getValidIndices();
          const isValid = validIndices?.includes(idx);
          const canPlay = phase === 'trick' && isMyTurn;
          const isDragging = dragState?.index === idx;
          const isSwapDragging = swapDragState?.sourceType === 'hand' && swapDragState?.sourceIndex === idx;
          const isSwapTarget = phase === 'swap' && swapDragState?.sourceType?.startsWith('plot-');
          const isSwapHover = swapDragState?.dropTarget?.type === 'hand' && swapDragState?.dropTarget?.index === idx;

          const handleCardDrag = (e) => {
            if (phase === 'swap') {
              onSwapDragStart('hand', idx, card, e);
            } else {
              onDragStart(idx, card, e);
            }
          };

          return (
            <div
              key={`${card.suit}-${card.value}`}
              ref={(el) => { handCardRefs.current[idx] = el; }}
              className={`hand-card ${canPlay && isValid ? 'playable' : ''} ${canPlay && !isValid ? 'invalid' : ''} ${isDragging ? 'dragging' : ''} ${phase === 'swap' ? 'swappable' : ''} ${isSwapDragging ? 'swap-dragging' : ''} ${isSwapTarget ? 'swap-target' : ''} ${isSwapHover ? 'swap-hover' : ''}`}
              onMouseDown={handleCardDrag}
              onTouchStart={handleCardDrag}
            >
              <img
                src={getCardImagePath(card)}
                alt={`${card.value} of ${card.suit}`}
                draggable={false}
              />
            </div>
          );
        })}
      </div>

      {/* Assignment phase: trick cards to the right of hand */}
      {phase === 'assignment' && lastWinner === currentPlayer && lastTrick?.length > 0 && (() => {
        const allAssigned = lastTrick.every(([, card]) => {
          const cardKey = `${card.suit}-${card.value}`;
          return pendingAssignments?.[cardKey];
        });

        const unassignedCards = lastTrick.filter(([, card]) => {
          const cardKey = `${card.suit}-${card.value}`;
          return !pendingAssignments?.[cardKey];
        });

        return (
          <>
            <div className="hand-divider" />
            {unassignedCards.length > 0 && (
              <div className="assign-cards-section">
                {unassignedCards.map(([, card]) => {
                  const cardKey = `${card.suit}-${card.value}`;
                  const isDragging = assignDragState?.cardKey === cardKey;

                  return (
                    <div
                      key={cardKey}
                      className={`hand-card assign-draggable ${isDragging ? 'dragging' : ''}`}
                      onMouseDown={(e) => onAssignDragStart(cardKey, card, e)}
                      onTouchStart={(e) => onAssignDragStart(cardKey, card, e)}
                    >
                      <img
                        src={getCardImagePath(card)}
                        alt={`${card.value} of ${card.suit}`}
                        draggable={false}
                      />
                    </div>
                  );
                })}
              </div>
            )}
            {allAssigned && (
              <button className="confirm-assign-btn" onClick={onSubmitAssignments}>
                {t(translations, language, 'confirm')}
              </button>
            )}
          </>
        );
      })()}

      {/* Swap phase: undo and confirm buttons */}
      {phase === 'swap' && currentSwapPlayer === 0 && !swapConfirmed?.[currentPlayer] && !swapConfirmedLocally && (
        <div className="swap-buttons">
          {swapCount?.[currentPlayer] && (
            <button className="undo-swap-btn" onClick={onUndoSwap}>
              {t(translations, language, 'undo')}
            </button>
          )}
          <button className="confirm-swap-btn" onClick={onConfirmSwap}>
            {t(translations, language, 'confirm')}
          </button>
        </div>
      )}
    </div>
  );
}

export default PlayerHandArea;
