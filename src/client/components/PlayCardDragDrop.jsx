import React, { useState, useEffect, useCallback, useRef } from 'react';
import { CardSVG } from './CardSVG.jsx';

export function PlayCardDragDrop({
  hand,
  onPlayCard,
  canPlay = false,
  validIndices,
  svgRef,
  centerX = 960,
  centerY = 560,
  cardWidth = 280,
  cardSpacing = 350,
}) {
  const [dragState, setDragState] = useState(null);
  const [flyingCard, setFlyingCard] = useState(null);
  const [dropZone, setDropZone] = useState(null);
  const [handCenterX, setHandCenterX] = useState(null);

  // Calculate player 0's card slot position (slot 3, rightmost)
  const updateDropZone = useCallback(() => {
    if (!svgRef?.current) return;

    const svg = svgRef.current;
    const rect = svg.getBoundingClientRect();
    const scaleX = rect.width / 1920;
    const scaleY = rect.height / 1080;

    // Player 0 slot: slotOrder[0] = 3, so x = centerX + 1.5 * cardSpacing
    const slotX = centerX + 1.5 * cardSpacing;
    const slotY = centerY + 120; // cardYOffset from TrickArea
    const cardHeight = cardWidth * 1.4;

    setDropZone({
      left: rect.left + (slotX - cardWidth / 2) * scaleX,
      top: rect.top + (slotY - cardHeight / 2) * scaleY,
      width: cardWidth * scaleX,
      height: cardHeight * scaleY,
      centerX: rect.left + slotX * scaleX,
      centerY: rect.top + slotY * scaleY,
    });

    // Calculate the center X of the trick area for hand positioning
    setHandCenterX(rect.left + centerX * scaleX);
  }, [svgRef, centerX, centerY, cardWidth, cardSpacing]);

  // Update drop zone on mount and resize
  useEffect(() => {
    updateDropZone();
    window.addEventListener('resize', updateDropZone);
    return () => window.removeEventListener('resize', updateDropZone);
  }, [updateDropZone]);

  // Get event position (mouse or touch)
  const getEventPosition = (e) => {
    if (e.touches && e.touches.length > 0) {
      return { x: e.touches[0].clientX, y: e.touches[0].clientY };
    }
    return { x: e.clientX, y: e.clientY };
  };

  // Check if we're over the drop zone
  const isOverDropZone = (x, y) => {
    if (!dropZone) return false;
    return (
      x >= dropZone.left &&
      x <= dropZone.left + dropZone.width &&
      y >= dropZone.top &&
      y <= dropZone.top + dropZone.height
    );
  };

  // Start dragging a hand card
  const handleDragStart = (index, card, e) => {
    // Only allow dragging when it's player's turn and card is valid
    if (!canPlay) return;
    if (!validIndices || !validIndices.includes(index)) return;

    e.preventDefault();
    const pos = getEventPosition(e);
    const cardEl = e.currentTarget;
    const cardRect = cardEl.getBoundingClientRect();

    setDragState({
      index,
      card,
      position: pos,
      offset: {
        x: pos.x - (cardRect.left + cardRect.width / 2),
        y: pos.y - (cardRect.top + cardRect.height / 2),
      },
      origin: {
        x: cardRect.left + cardRect.width / 2,
        y: cardRect.top + cardRect.height / 2,
      },
      isOverTarget: false,
    });
  };

  // Handle drag movement
  useEffect(() => {
    if (!dragState) return;

    const handleMove = (e) => {
      const pos = getEventPosition(e);
      const isOverTarget = isOverDropZone(pos.x, pos.y);

      setDragState((prev) => ({
        ...prev,
        position: pos,
        isOverTarget,
      }));
    };

    const handleEnd = (e) => {
      const pos = getEventPosition(e);
      const isOver = isOverDropZone(pos.x, pos.y);

      if (isOver && dropZone) {
        // Animate card flying to slot, then play it
        setFlyingCard({
          card: dragState.card,
          index: dragState.index,
          from: {
            x: pos.x - dragState.offset.x,
            y: pos.y - dragState.offset.y,
          },
          to: {
            x: dropZone.centerX,
            y: dropZone.centerY,
          },
        });
      }

      setDragState(null);
    };

    document.addEventListener('mousemove', handleMove);
    document.addEventListener('mouseup', handleEnd);
    document.addEventListener('touchmove', handleMove, { passive: false });
    document.addEventListener('touchend', handleEnd);

    return () => {
      document.removeEventListener('mousemove', handleMove);
      document.removeEventListener('mouseup', handleEnd);
      document.removeEventListener('touchmove', handleMove);
      document.removeEventListener('touchend', handleEnd);
    };
  }, [dragState, dropZone]);

  // Handle flying card animation completion
  useEffect(() => {
    if (!flyingCard) return;

    const timer = setTimeout(() => {
      onPlayCard(flyingCard.index);
      setFlyingCard(null);
    }, 250);

    return () => clearTimeout(timer);
  }, [flyingCard, onPlayCard]);

  return (
    <div className="play-card-drag-drop">
      {/* Drop zone highlight when dragging */}
      {dragState && dropZone && (
        <div
          className={`play-drop-zone ${dragState.isOverTarget ? 'hover' : ''}`}
          style={{
            left: dropZone.left,
            top: dropZone.top,
            width: dropZone.width,
            height: dropZone.height,
          }}
        >
          {dragState.isOverTarget && <span className="drop-hint">Drop</span>}
        </div>
      )}

      {/* Draggable hand cards */}
      <div
        className="play-hand-cards"
        style={handCenterX ? { left: handCenterX } : {}}
      >
        {hand.map((card, idx) => {
          const isValid = !canPlay || (validIndices && validIndices.includes(idx));
          const isDragging = dragState?.index === idx;
          const isFlying = flyingCard?.index === idx;

          if (isDragging || isFlying) {
            return (
              <div key={`hand-${idx}`} className="play-card placeholder">
                <CardSVG card={card} width={90} dimmed />
              </div>
            );
          }

          return (
            <div
              key={`hand-${idx}`}
              className={`play-card ${canPlay && isValid ? 'valid' : ''} ${canPlay && !isValid ? 'invalid' : ''}`}
              onMouseDown={(e) => handleDragStart(idx, card, e)}
              onTouchStart={(e) => handleDragStart(idx, card, e)}
            >
              <CardSVG card={card} width={90} dimmed={canPlay && !isValid} />
            </div>
          );
        })}
      </div>

      {/* Ghost card following cursor */}
      {dragState && (
        <div
          className="drag-ghost"
          style={{
            left: dragState.position.x - dragState.offset.x,
            top: dragState.position.y - dragState.offset.y,
          }}
        >
          <CardSVG card={dragState.card} width={90} />
        </div>
      )}

      {/* Flying card animation */}
      {flyingCard && (
        <div
          className="flying-card play-flying"
          style={{
            '--from-x': `${flyingCard.from.x}px`,
            '--from-y': `${flyingCard.from.y}px`,
            '--to-x': `${flyingCard.to.x}px`,
            '--to-y': `${flyingCard.to.y}px`,
          }}
        >
          <CardSVG card={flyingCard.card} width={90} />
        </div>
      )}
    </div>
  );
}
