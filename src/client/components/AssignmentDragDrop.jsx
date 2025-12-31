import React, { useState, useEffect, useMemo, useCallback, useRef } from 'react';
import { CardSVG } from './CardSVG.jsx';

const SUITS = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];
const SUIT_SYMBOLS = { Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' };

export function AssignmentDragDrop({
  lastTrick,
  pendingAssignments,
  onAssign,
  onSubmit,
  svgRef,
  centerY = 470,
  scale = 1,
}) {
  // Drag state: which card is being dragged, current position, which zone we're over
  const [dragState, setDragState] = useState(null);
  // Flying card animation state
  const [flyingCard, setFlyingCard] = useState(null);
  // Track drop zone positions
  const [dropZones, setDropZones] = useState([]);
  // Container ref for relative positioning
  const containerRef = useRef(null);

  // Valid suits = suits that appear in the trick
  const validSuits = useMemo(() =>
    [...new Set(lastTrick.map(([, c]) => c.suit))],
    [lastTrick]
  );

  // Calculate drop zone positions from SVG coordinates
  const updateDropZones = useCallback(() => {
    if (!svgRef?.current) return;

    const svg = svgRef.current;
    const rect = svg.getBoundingClientRect();
    const viewBox = { width: 1920, height: 1080 };
    const scaleX = rect.width / viewBox.width;
    const scaleY = rect.height / viewBox.height;

    // Match TrickArea jobs mode row positions (from TrickArea.jsx lines 237-239)
    // rowY = centerY - height / 2 + 95 * scale + suitIdx * rowSpacing
    const height = 540 * scale;
    const width = 1100 * scale;
    const centerX = 960; // Default SVG center
    const rowSpacing = 100 * scale;
    const rowHeight = 95 * scale;

    const zones = SUITS.map((suit, idx) => {
      const rowY = centerY - height / 2 + 95 * scale + idx * rowSpacing;
      const rowLeft = centerX - width / 2 + 20 * scale;
      const rowWidth = width - 40 * scale;

      return {
        suit,
        left: rect.left + rowLeft * scaleX,
        top: rect.top + rowY * scaleY,
        width: rowWidth * scaleX,
        height: rowHeight * scaleY,
        // Store center for fly-to animation
        centerX: rect.left + (rowLeft + rowWidth / 2) * scaleX,
        centerY: rect.top + (rowY + rowHeight / 2) * scaleY,
      };
    });

    setDropZones(zones);
  }, [svgRef, centerY, scale]);

  // Update drop zones on mount and resize
  useEffect(() => {
    updateDropZones();
    window.addEventListener('resize', updateDropZones);
    return () => window.removeEventListener('resize', updateDropZones);
  }, [updateDropZones]);

  // Get event position (works for mouse and touch)
  const getEventPosition = (e) => {
    if (e.touches && e.touches.length > 0) {
      return { x: e.touches[0].clientX, y: e.touches[0].clientY };
    }
    return { x: e.clientX, y: e.clientY };
  };

  // Check which drop zone we're over
  const getHoverZone = (x, y) => {
    for (const zone of dropZones) {
      if (
        x >= zone.left &&
        x <= zone.left + zone.width &&
        y >= zone.top &&
        y <= zone.top + zone.height &&
        validSuits.includes(zone.suit)
      ) {
        return zone.suit;
      }
    }
    return null;
  };

  // Start dragging a card
  const handleDragStart = (cardKey, card, e) => {
    e.preventDefault();
    const pos = getEventPosition(e);

    // Get the card element's position for offset calculation
    const cardEl = e.currentTarget;
    const cardRect = cardEl.getBoundingClientRect();

    setDragState({
      cardKey,
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
      hoverZone: null,
    });
  };

  // Handle drag movement
  useEffect(() => {
    if (!dragState) return;

    const handleMove = (e) => {
      const pos = getEventPosition(e);
      const hoverZone = getHoverZone(pos.x, pos.y);

      setDragState(prev => ({
        ...prev,
        position: pos,
        hoverZone,
      }));
    };

    const handleEnd = (e) => {
      const pos = getEventPosition(e);
      const targetZone = getHoverZone(pos.x, pos.y);

      if (targetZone && validSuits.includes(targetZone)) {
        // Find the drop zone for animation target
        const zone = dropZones.find(z => z.suit === targetZone);

        // Start fly animation
        setFlyingCard({
          card: dragState.card,
          cardKey: dragState.cardKey,
          targetSuit: targetZone,
          from: { x: pos.x - dragState.offset.x, y: pos.y - dragState.offset.y },
          to: { x: zone.centerX, y: zone.centerY },
        });
      }

      setDragState(null);
    };

    // Add listeners to document for smooth dragging
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
  }, [dragState, dropZones, validSuits]);

  // Handle flying card animation completion
  useEffect(() => {
    if (!flyingCard) return;

    const timer = setTimeout(() => {
      // Call the assignment move
      onAssign(flyingCard.cardKey, flyingCard.targetSuit);
      setFlyingCard(null);
    }, 300); // Match CSS transition duration

    return () => clearTimeout(timer);
  }, [flyingCard, onAssign]);

  // Check if all cards are assigned
  const allAssigned = Object.keys(pendingAssignments || {}).length === lastTrick.length;

  // Get cards that haven't been assigned yet (or are being dragged)
  const getCardStatus = (cardKey) => {
    if (flyingCard?.cardKey === cardKey) return 'flying';
    if (dragState?.cardKey === cardKey) return 'dragging';
    if (pendingAssignments?.[cardKey]) return 'assigned';
    return 'available';
  };

  return (
    <div className="assignment-drag-drop" ref={containerRef}>
      {/* Header */}
      <div className="assignment-header">
        <h3>Assign Cards to Jobs</h3>
        <p>Drag each card to a job pile</p>
      </div>

      {/* Drop zones overlay */}
      <div className="drop-zones">
        {dropZones.map((zone) => {
          const isValid = validSuits.includes(zone.suit);
          const isHover = dragState?.hoverZone === zone.suit;

          return (
            <div
              key={zone.suit}
              className={`drop-zone ${isValid ? 'valid' : 'invalid'} ${isHover ? 'hover' : ''}`}
              style={{
                left: zone.left,
                top: zone.top,
                width: zone.width,
                height: zone.height,
              }}
            >
              {isHover && (
                <span className="drop-hint">
                  {SUIT_SYMBOLS[zone.suit]} Drop here
                </span>
              )}
            </div>
          );
        })}
      </div>

      {/* Draggable trick cards */}
      <div className="drag-cards">
        {lastTrick.map(([pid, card]) => {
          const cardKey = `${card.suit}-${card.value}`;
          const status = getCardStatus(cardKey);

          // Don't render if flying or being dragged
          if (status === 'flying' || status === 'dragging') {
            return (
              <div key={cardKey} className="drag-card placeholder">
                <CardSVG card={card} width={90} dimmed />
              </div>
            );
          }

          return (
            <div
              key={cardKey}
              className={`drag-card ${status}`}
              onMouseDown={(e) => handleDragStart(cardKey, card, e)}
              onTouchStart={(e) => handleDragStart(cardKey, card, e)}
            >
              <CardSVG card={card} width={90} />
              {status === 'assigned' && (
                <div className="assigned-badge">
                  {SUIT_SYMBOLS[pendingAssignments[cardKey]]}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Ghost card following cursor during drag */}
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
          className="flying-card"
          style={{
            '--from-x': `${flyingCard.from.x}px`,
            '--from-y': `${flyingCard.from.y}px`,
            '--to-x': `${flyingCard.to.x}px`,
            '--to-y': `${flyingCard.to.y}px`,
          }}
        >
          <CardSVG card={flyingCard.card} width={60} />
        </div>
      )}

      {/* Submit button */}
      <button
        className="assignment-submit"
        onClick={onSubmit}
        disabled={!allAssigned}
      >
        {allAssigned ? 'Submit Assignments' : `Assign ${lastTrick.length - Object.keys(pendingAssignments || {}).length} more`}
      </button>
    </div>
  );
}
