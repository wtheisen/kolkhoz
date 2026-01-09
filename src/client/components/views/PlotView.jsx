import React, { useState, useEffect, useRef } from 'react';
import { getCardImagePath } from '../../../game/Card.js';
import { translations, t } from '../../translations.js';
import './PlotView.css';

// Portrait paths for AI players
const PORTRAITS = [
  '/assets/portraits/worker1.svg',
  '/assets/portraits/worker2.svg',
  '/assets/portraits/worker3.svg',
  '/assets/portraits/worker4.svg',
];

export function PlotView({
  phase,
  players,
  playerPlot,
  currentSwapPlayer,
  swapConfirmed,
  swapDragState,
  onSwapDragStart,
  plotDropRefs,
  lastSwap,
  // Requisition phase props
  requisitionData,
  currentRequisitionSuit,
  currentJobStage,
  language,
}) {
  // Track animated swap for bot visual feedback
  const [animatedSwap, setAnimatedSwap] = useState(null);
  const lastSwapTimestamp = useRef(null);

  // Detect bot swaps and trigger animation
  useEffect(() => {
    if (lastSwap && lastSwap.playerIdx !== 0 && lastSwap.timestamp !== lastSwapTimestamp.current) {
      lastSwapTimestamp.current = lastSwap.timestamp;
      setAnimatedSwap({
        playerIdx: lastSwap.playerIdx,
        plotType: lastSwap.plotType,
        plotCardIndex: lastSwap.plotCardIndex,
        key: lastSwap.timestamp,
      });
      const timer = setTimeout(() => setAnimatedSwap(null), 600);
      return () => clearTimeout(timer);
    }
  }, [lastSwap]);

  // Get revealed cards - no longer filtering here, FlyingExileCard hides source via DOM
  const getVisibleRevealedCards = (revealedCards) => {
    return revealedCards || [];
  };

  // Swap mode
  if (phase === 'swap') {
    return (
      <div className="swap-view multiplayer">
        {/* Top row: Bot sections */}
        <div className="swap-bots-row">
          {[1, 2, 3].map((botIdx) => {
            const bot = players?.[botIdx];
            const isActive = currentSwapPlayer === botIdx;
            const isConfirmed = swapConfirmed[botIdx];
            const revealedCards = bot?.plot?.revealed || [];
            const hiddenCount = bot?.plot?.hidden?.length || 0;
            const handSize = bot?.hand?.length || 0;

            return (
              <div
                key={botIdx}
                className={`swap-bot-section ${isActive ? 'active' : ''} ${isConfirmed ? 'confirmed' : ''}`}
              >
                <div className="swap-bot-header">
                  <img
                    src={PORTRAITS[(botIdx - 1) % PORTRAITS.length]}
                    alt={bot?.name}
                    className="swap-bot-portrait"
                  />
                  <span className="swap-bot-name">
                    {bot?.name || `${t(translations, language, 'player')} ${botIdx}`}
                    {isConfirmed && <span className="confirmed-check">✓</span>}
                  </span>
                  <div className="swap-bot-hand">
                    {Array.from({ length: handSize }).map((_, idx) => (
                      <img
                        key={idx}
                        src="assets/cards/back.svg"
                        alt="card"
                        className="swap-hand-card"
                      />
                    ))}
                  </div>
                </div>
                <div className="swap-bot-cards">
                  {revealedCards.map((card, idx) => {
                    const isSwapping = animatedSwap &&
                      animatedSwap.playerIdx === botIdx &&
                      animatedSwap.plotType === 'revealed' &&
                      animatedSwap.plotCardIndex === idx;
                    return (
                      <img
                        key={`revealed-${idx}-${isSwapping ? animatedSwap.key : ''}`}
                        src={getCardImagePath(card)}
                        alt={`${card.value} of ${card.suit}`}
                        className={`swap-mini-card revealed ${isSwapping ? 'bot-swapped' : ''}`}
                      />
                    );
                  })}
                  {Array.from({ length: hiddenCount }).map((_, idx) => {
                    const isSwapping = animatedSwap &&
                      animatedSwap.playerIdx === botIdx &&
                      animatedSwap.plotType === 'hidden' &&
                      animatedSwap.plotCardIndex === idx;
                    return (
                      <img
                        key={`hidden-${idx}-${isSwapping ? animatedSwap.key : ''}`}
                        src="assets/cards/back.svg"
                        alt="hidden"
                        className={`swap-mini-card back ${isSwapping ? 'bot-swapped' : ''}`}
                      />
                    );
                  })}
                  {revealedCards.length === 0 && hiddenCount === 0 && (
                    <span className="no-cards">—</span>
                  )}
                </div>
              </div>
            );
          })}
        </div>

        {/* Bottom: Player's plot in two side-by-side boxes */}
        <div className={`swap-player-section ${currentSwapPlayer !== 0 ? 'disabled' : ''}`}>
          {/* Hidden cards box */}
          <div className="swap-player-box hidden">
            <div className="box-header">
              <span className="box-title">{t(translations, language, 'hidden')}</span>
              <span className="box-count">{playerPlot?.hidden?.length || 0}</span>
            </div>
            <div className="swap-cards">
              {(playerPlot?.hidden || []).map((card, idx) => {
                const isDropTarget = currentSwapPlayer === 0 && swapDragState?.sourceType === 'hand';
                const isDropHover = swapDragState?.dropTarget?.type === 'plot-hidden' &&
                                   swapDragState?.dropTarget?.index === idx;
                const isDragging = swapDragState?.sourceType === 'plot-hidden' &&
                                  swapDragState?.index === idx;

                return (
                  <div
                    key={`hidden-${idx}`}
                    ref={(el) => { plotDropRefs.current[`hidden-${idx}`] = el; }}
                    className={`swap-card-slot ${isDropTarget ? 'drop-target' : ''} ${isDropHover ? 'drop-hover' : ''} ${isDragging ? 'dragging' : ''} ${currentSwapPlayer !== 0 ? 'disabled' : ''}`}
                    onMouseDown={(e) => currentSwapPlayer === 0 && onSwapDragStart?.('plot-hidden', idx, card, e)}
                    onTouchStart={(e) => currentSwapPlayer === 0 && onSwapDragStart?.('plot-hidden', idx, card, e)}
                  >
                    <img
                      src={getCardImagePath(card)}
                      alt={`${card.value} of ${card.suit}`}
                      draggable={false}
                    />
                  </div>
                );
              })}
              {(!playerPlot?.hidden || playerPlot.hidden.length === 0) && (
                <div className="empty-slot">—</div>
              )}
            </div>
          </div>

          {/* Revealed cards box */}
          <div className="swap-player-box revealed">
            <div className="box-header">
              <span className="box-title">{t(translations, language, 'rewards')}</span>
              <span className="box-count">{playerPlot?.revealed?.length || 0}</span>
            </div>
            <div className="swap-cards">
              {(playerPlot?.revealed || []).map((card, idx) => {
                const isDropTarget = currentSwapPlayer === 0 && swapDragState?.sourceType === 'hand';
                const isDropHover = swapDragState?.dropTarget?.type === 'plot-revealed' &&
                                   swapDragState?.dropTarget?.index === idx;
                const isDragging = swapDragState?.sourceType === 'plot-revealed' &&
                                  swapDragState?.index === idx;

                return (
                  <div
                    key={`revealed-${idx}`}
                    ref={(el) => { plotDropRefs.current[`revealed-${idx}`] = el; }}
                    className={`swap-card-slot ${isDropTarget ? 'drop-target' : ''} ${isDropHover ? 'drop-hover' : ''} ${isDragging ? 'dragging' : ''} ${currentSwapPlayer !== 0 ? 'disabled' : ''}`}
                    onMouseDown={(e) => currentSwapPlayer === 0 && onSwapDragStart?.('plot-revealed', idx, card, e)}
                    onTouchStart={(e) => currentSwapPlayer === 0 && onSwapDragStart?.('plot-revealed', idx, card, e)}
                  >
                    <img
                      src={getCardImagePath(card)}
                      alt={`${card.value} of ${card.suit}`}
                      draggable={false}
                    />
                  </div>
                );
              })}
              {(!playerPlot?.revealed || playerPlot.revealed.length === 0) && (
                <div className="empty-slot">—</div>
              )}
            </div>
          </div>
        </div>

        {/* Player status bar */}
        {swapConfirmed[0] && (
          <div className="swap-status-bar">
            <span className="confirmed-badge">{t(translations, language, 'confirmed')} ✓</span>
          </div>
        )}
      </div>
    );
  }

  // Read-only mode (non-swap phases)
  return (
    <div className={`swap-view multiplayer readonly ${phase === 'requisition' ? 'requisition-mode' : ''}`}>
      {/* Top row: Bot sections */}
      <div className="swap-bots-row">
        {[1, 2, 3].map((botIdx) => {
          const bot = players?.[botIdx];
          const revealedCards = getVisibleRevealedCards(bot?.plot?.revealed);
          const hiddenCount = bot?.plot?.hidden?.length || 0;

          return (
            <div
              key={botIdx}
              className="swap-bot-section"
              data-player={botIdx}
            >
              <div className="swap-bot-header">
                <img
                  src={PORTRAITS[(botIdx - 1) % PORTRAITS.length]}
                  alt={bot?.name}
                  className="swap-bot-portrait"
                />
                <span className="swap-bot-name">
                  {bot?.name || `${t(translations, language, 'player')} ${botIdx}`}
                </span>
              </div>
              <div className="swap-bot-cards">
                {revealedCards.map((card, idx) => {
                  const isCurrentSuit = card.suit === currentRequisitionSuit;
                  const isNewlyRevealed = phase === 'requisition' &&
                    isCurrentSuit &&
                    (currentJobStage === 'revealing' || currentJobStage === 'exiling') &&
                    requisitionData?.revealedCards?.some(rc =>
                      rc.playerIdx === botIdx &&
                      rc.card.suit === card.suit &&
                      rc.card.value === card.value
                    );
                  const isAboutToBeExiled = phase === 'requisition' &&
                    currentJobStage === 'revealing' &&
                    requisitionData?.exiledCards?.some(ec =>
                      ec.playerIdx === botIdx &&
                      ec.card.suit === card.suit &&
                      ec.card.value === card.value
                    );
                  const isDimmed = phase === 'requisition' &&
                    currentRequisitionSuit &&
                    !isCurrentSuit;
                  return (
                    <img
                      key={`revealed-${idx}`}
                      src={getCardImagePath(card)}
                      alt={`${card.value} of ${card.suit}`}
                      className={`swap-mini-card revealed ${isNewlyRevealed ? 'newly-revealed' : ''} ${isAboutToBeExiled ? 'about-to-exile' : ''} ${isDimmed ? 'dimmed' : ''}`}
                      data-card={`${card.suit}-${card.value}`}
                      data-player={botIdx}
                    />
                  );
                })}
                {Array.from({ length: hiddenCount }).map((_, idx) => (
                  <img
                    key={`hidden-${idx}`}
                    src="assets/cards/back.svg"
                    alt="hidden"
                    className="swap-mini-card back"
                  />
                ))}
                {revealedCards.length === 0 && hiddenCount === 0 && (
                  <span className="no-cards">—</span>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Bottom: Player's plot in two side-by-side boxes (read-only) */}
      <div className="swap-player-section">
        {/* Hidden cards box */}
        <div className="swap-player-box hidden">
          <div className="box-header">
            <span className="box-title">{t(translations, language, 'hidden')}</span>
            <span className="box-count">{playerPlot?.hidden?.length || 0}</span>
          </div>
          <div className="swap-cards">
            {(playerPlot?.hidden || []).map((card, idx) => (
              <div
                key={`hidden-${idx}`}
                className="swap-card-slot readonly"
                data-card={`${card.suit}-${card.value}`}
              >
                <img
                  src={getCardImagePath(card)}
                  alt={`${card.value} of ${card.suit}`}
                  draggable={false}
                />
              </div>
            ))}
            {(!playerPlot?.hidden || playerPlot.hidden.length === 0) && (
              <div className="empty-slot">—</div>
            )}
          </div>
        </div>

        {/* Revealed cards box */}
        <div className="swap-player-box revealed">
          <div className="box-header">
            <span className="box-title">{t(translations, language, 'rewards')}</span>
            <span className="box-count">{playerPlot?.revealed?.length || 0}</span>
          </div>
          <div className="swap-cards">
            {getVisibleRevealedCards(playerPlot?.revealed).map((card, idx) => {
              const isCurrentSuit = card.suit === currentRequisitionSuit;
              const isNewlyRevealed = phase === 'requisition' &&
                isCurrentSuit &&
                (currentJobStage === 'revealing' || currentJobStage === 'exiling') &&
                requisitionData?.revealedCards?.some(rc =>
                  rc.playerIdx === 0 &&
                  rc.card.suit === card.suit &&
                  rc.card.value === card.value
                );
              const isAboutToBeExiled = phase === 'requisition' &&
                currentJobStage === 'revealing' &&
                requisitionData?.exiledCards?.some(ec =>
                  ec.playerIdx === 0 &&
                  ec.card.suit === card.suit &&
                  ec.card.value === card.value
                );
              const isDimmed = phase === 'requisition' &&
                currentRequisitionSuit &&
                !isCurrentSuit;
              return (
                <div
                  key={`revealed-${idx}`}
                  className={`swap-card-slot readonly ${isNewlyRevealed ? 'newly-revealed' : ''} ${isAboutToBeExiled ? 'about-to-exile' : ''} ${isDimmed ? 'dimmed' : ''}`}
                  data-card={`${card.suit}-${card.value}`}
                  data-player="0"
                >
                  <img
                    src={getCardImagePath(card)}
                    alt={`${card.value} of ${card.suit}`}
                    draggable={false}
                  />
                </div>
              );
            })}
            {(!playerPlot?.revealed || playerPlot.revealed.length === 0) && (
              <div className="empty-slot">—</div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default PlotView;
