import React, { useState, useEffect, useCallback, useRef } from 'react';
import { CardSVG } from './CardSVG.jsx';

export function SwapDragDrop({
  hand,
  plot,
  onSwap,
  onConfirm,
  svgRef,
  centerY = 470,
  scale = 1,
  year,
}) {
  // Selected target card (click to select first)
  const [selectedTarget, setSelectedTarget] = useState(null);
  // { type: 'hand'|'revealed'|'hidden', index: number }

  // Drag state
  const [dragState, setDragState] = useState(null);
  // Flying card animation
  const [flyingCard, setFlyingCard] = useState(null);
  // Drop zone positions
  const [dropZones, setDropZones] = useState({ revealed: null, hidden: null });

  const containerRef = useRef(null);

  // Calculate drop zone positions from SVG coordinates
  const updateDropZones = useCallback(() => {
    if (!svgRef?.current) return;

    const svg = svgRef.current;
    const rect = svg.getBoundingClientRect();
    const viewBox = { width: 1920, height: 1080 };
    const scaleX = rect.width / viewBox.width;
    const scaleY = rect.height / viewBox.height;

    // Match TrickArea plot mode row positions
    const height = 540 * scale;
    const width = 1100 * scale;
    const centerX = 960;
    const rowHeight = 120 * scale;

    // Revealed row
    const revealedY = centerY - height / 2 + 95 * scale;
    const rowLeft = centerX - width / 2 + 20 * scale;
    const rowWidth = width - 40 * scale;

    // Hidden row
    const hiddenY = centerY - height / 2 + 230 * scale;

    setDropZones({
      revealed: {
        left: rect.left + rowLeft * scaleX,
        top: rect.top + revealedY * scaleY,
        width: rowWidth * scaleX,
        height: rowHeight * scaleY,
        centerX: rect.left + (rowLeft + rowWidth / 2) * scaleX,
        centerY: rect.top + (revealedY + rowHeight / 2) * scaleY,
      },
      hidden: {
        left: rect.left + rowLeft * scaleX,
        top: rect.top + hiddenY * scaleY,
        width: rowWidth * scaleX,
        height: rowHeight * scaleY,
        centerX: rect.left + (rowLeft + rowWidth / 2) * scaleX,
        centerY: rect.top + (hiddenY + rowHeight / 2) * scaleY,
      },
    });
  }, [svgRef, centerY, scale]);

  // Update drop zones on mount and resize
  useEffect(() => {
    updateDropZones();
    window.addEventListener('resize', updateDropZones);
    return () => window.removeEventListener('resize', updateDropZones);
  }, [updateDropZones]);

  // Get event position (mouse or touch)
  const getEventPosition = (e) => {
    if (e.touches && e.touches.length > 0) {
      return { x: e.touches[0].clientX, y: e.touches[0].clientY };
    }
    return { x: e.clientX, y: e.clientY };
  };

  // Check which drop zone we're over
  const getHoverZone = (x, y) => {
    for (const [type, zone] of Object.entries(dropZones)) {
      if (zone &&
        x >= zone.left &&
        x <= zone.left + zone.width &&
        y >= zone.top &&
        y <= zone.top + zone.height
      ) {
        return type; // 'revealed' or 'hidden'
      }
    }
    return null;
  };

  // Handle clicking a card to select it as swap target
  const handleCardClick = (type, index, card) => {
    if (selectedTarget?.type === type && selectedTarget?.index === index) {
      // Deselect
      setSelectedTarget(null);
    } else {
      setSelectedTarget({ type, index, card });
    }
  };

  // Start dragging a hand card
  const handleDragStart = (index, card, e) => {
    e.preventDefault();
    const pos = getEventPosition(e);
    const cardEl = e.currentTarget;
    const cardRect = cardEl.getBoundingClientRect();

    setDragState({
      source: { type: 'hand', index },
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

      // Check if we have a selected target in the zone we dropped on
      if (targetZone && selectedTarget && selectedTarget.type === targetZone) {
        // Perform the swap
        const zone = dropZones[targetZone];
        setFlyingCard({
          card: dragState.card,
          from: { x: pos.x - dragState.offset.x, y: pos.y - dragState.offset.y },
          to: { x: zone.centerX, y: zone.centerY },
          swapData: {
            plotIdx: selectedTarget.index,
            handIdx: dragState.source.index,
            plotType: targetZone,
          },
        });
        setSelectedTarget(null);
      } else if (targetZone) {
        // Dropped on zone but no target selected - select first card in that zone
        const plotArray = targetZone === 'revealed' ? plot?.revealed : plot?.hidden;
        if (plotArray && plotArray.length > 0) {
          // Swap with first card
          const zone = dropZones[targetZone];
          setFlyingCard({
            card: dragState.card,
            from: { x: pos.x - dragState.offset.x, y: pos.y - dragState.offset.y },
            to: { x: zone.centerX, y: zone.centerY },
            swapData: {
              plotIdx: 0,
              handIdx: dragState.source.index,
              plotType: targetZone,
            },
          });
        }
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
  }, [dragState, dropZones, selectedTarget, plot]);

  // Handle flying card animation completion
  useEffect(() => {
    if (!flyingCard) return;

    const timer = setTimeout(() => {
      const { plotIdx, handIdx, plotType } = flyingCard.swapData;
      onSwap(plotIdx, handIdx, plotType);
      setFlyingCard(null);
    }, 300);

    return () => clearTimeout(timer);
  }, [flyingCard, onSwap]);

  // Check if a card is selected
  const isSelected = (type, index) => {
    return selectedTarget?.type === type && selectedTarget?.index === index;
  };

  return (
    <div className="swap-drag-drop" ref={containerRef}>
      {/* Header */}
      <div className="swap-header">
        <h3>Swap Phase - Year {year}</h3>
        <p>
          {selectedTarget
            ? `Selected: ${selectedTarget.type} card - drag a hand card to swap`
            : 'Click a plot card to select, then drag a hand card to swap'}
        </p>
      </div>

      {/* Drop zones overlay */}
      <div className="drop-zones">
        {dropZones.revealed && (
          <div
            className={`drop-zone revealed ${dragState?.hoverZone === 'revealed' ? 'hover' : ''} ${selectedTarget?.type === 'revealed' ? 'target-selected' : ''}`}
            style={{
              left: dropZones.revealed.left,
              top: dropZones.revealed.top,
              width: dropZones.revealed.width,
              height: dropZones.revealed.height,
            }}
          />
        )}
        {dropZones.hidden && (
          <div
            className={`drop-zone hidden ${dragState?.hoverZone === 'hidden' ? 'hover' : ''} ${selectedTarget?.type === 'hidden' ? 'target-selected' : ''}`}
            style={{
              left: dropZones.hidden.left,
              top: dropZones.hidden.top,
              width: dropZones.hidden.width,
              height: dropZones.hidden.height,
            }}
          />
        )}
      </div>

      {/* Clickable plot cards overlay - for selecting swap targets */}
      <div className="plot-card-overlays">
        {plot?.revealed?.map((card, idx) => {
          if (!dropZones.revealed) return null;
          const cardWidth = 70 * scale;
          const cardSpacing = 55 * scale;
          const cardsStartX = dropZones.revealed.left + 120 * scale * (dropZones.revealed.width / (1060 * scale));
          const x = cardsStartX + idx * cardSpacing * (dropZones.revealed.width / (1060 * scale));
          const y = dropZones.revealed.top + (dropZones.revealed.height - cardWidth * 1.4) / 2;

          return (
            <div
              key={`revealed-overlay-${idx}`}
              className={`plot-card-overlay ${isSelected('revealed', idx) ? 'selected' : ''}`}
              style={{
                left: x,
                top: y,
                width: cardWidth * (dropZones.revealed.width / (1060 * scale)),
                height: cardWidth * 1.4 * (dropZones.revealed.height / (120 * scale)),
              }}
              onClick={() => handleCardClick('revealed', idx, card)}
            />
          );
        })}
        {plot?.hidden?.map((card, idx) => {
          if (!dropZones.hidden) return null;
          const cardWidth = 70 * scale;
          const cardSpacing = 55 * scale;
          const cardsStartX = dropZones.hidden.left + 120 * scale * (dropZones.hidden.width / (1060 * scale));
          const x = cardsStartX + idx * cardSpacing * (dropZones.hidden.width / (1060 * scale));
          const y = dropZones.hidden.top + (dropZones.hidden.height - cardWidth * 1.4) / 2;

          return (
            <div
              key={`hidden-overlay-${idx}`}
              className={`plot-card-overlay ${isSelected('hidden', idx) ? 'selected' : ''}`}
              style={{
                left: x,
                top: y,
                width: cardWidth * (dropZones.hidden.width / (1060 * scale)),
                height: cardWidth * 1.4 * (dropZones.hidden.height / (120 * scale)),
              }}
              onClick={() => handleCardClick('hidden', idx, card)}
            />
          );
        })}
      </div>

      {/* Draggable hand cards */}
      <div className="swap-hand-cards">
        {hand.map((card, idx) => {
          const isDragging = dragState?.source.index === idx;
          const isFlying = flyingCard?.swapData.handIdx === idx;

          if (isDragging || isFlying) {
            return (
              <div key={`hand-${idx}`} className="swap-card placeholder">
                <CardSVG card={card} width={90} dimmed />
              </div>
            );
          }

          return (
            <div
              key={`hand-${idx}`}
              className="swap-card"
              onMouseDown={(e) => handleDragStart(idx, card, e)}
              onTouchStart={(e) => handleDragStart(idx, card, e)}
            >
              <CardSVG card={card} width={90} />
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

      {/* Done button */}
      <button className="swap-confirm" onClick={onConfirm}>
        Done Swapping
      </button>
    </div>
  );
}
