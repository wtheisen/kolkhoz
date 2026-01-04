import { useState, useEffect, useCallback } from 'react';
import { getEventPosition } from './useDragDrop.js';

// Find drop target for swap drag
function findSwapDropTarget(x, y, sourceType, plotDropRefs, plotCardRefs, handCardRefs) {
  // Check plot cards in panel (plotDropRefs - used during swap phase)
  for (const [key, ref] of Object.entries(plotDropRefs.current)) {
    if (!ref) continue;
    const rect = ref.getBoundingClientRect();
    if (x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom) {
      const [type, indexStr] = key.split('-');
      const index = parseInt(indexStr, 10);
      // Only valid if dragging from hand
      if (sourceType === 'hand') {
        return { type: `plot-${type}`, index };
      }
    }
  }
  // Check plot cards in hand area (plotCardRefs - fallback for non-panel mode)
  for (const [key, ref] of Object.entries(plotCardRefs.current)) {
    if (!ref) continue;
    const rect = ref.getBoundingClientRect();
    if (x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom) {
      const [type, indexStr] = key.split('-');
      const index = parseInt(indexStr, 10);
      // Only valid if dragging from hand
      if (sourceType === 'hand') {
        return { type: `plot-${type}`, index };
      }
    }
  }
  // Check hand cards
  for (const [key, ref] of Object.entries(handCardRefs.current)) {
    if (!ref) continue;
    const rect = ref.getBoundingClientRect();
    if (x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom) {
      const index = parseInt(key, 10);
      // Only valid if dragging from plot
      if (sourceType.startsWith('plot-')) {
        return { type: 'hand', index };
      }
    }
  }
  return null;
}

// Hook for swap phase drag and drop
export function useSwapDrag({ phase, plotDropRefs, plotCardRefs, handCardRefs, onSwap }) {
  const [swapDragState, setSwapDragState] = useState(null);

  const handleSwapDragStart = useCallback((sourceType, index, card, e) => {
    if (phase !== 'swap') return;
    e.preventDefault();
    const pos = getEventPosition(e);
    const cardEl = e.currentTarget;
    const rect = cardEl.getBoundingClientRect();

    setSwapDragState({
      sourceType,
      sourceIndex: index,
      card,
      position: pos,
      offset: {
        x: pos.x - (rect.left + rect.width / 2),
        y: pos.y - (rect.top + rect.height / 2),
      },
      dropTarget: null,
    });
  }, [phase]);

  // Handle swap drag movement and drop
  useEffect(() => {
    if (!swapDragState) return;

    const handleMove = (e) => {
      e.preventDefault();
      const pos = getEventPosition(e);
      const dropTarget = findSwapDropTarget(pos.x, pos.y, swapDragState.sourceType, plotDropRefs, plotCardRefs, handCardRefs);
      setSwapDragState((prev) => ({ ...prev, position: pos, dropTarget }));
    };

    const handleEnd = (e) => {
      const pos = e.changedTouches
        ? { x: e.changedTouches[0].clientX, y: e.changedTouches[0].clientY }
        : { x: e.clientX, y: e.clientY };

      const dropTarget = findSwapDropTarget(pos.x, pos.y, swapDragState.sourceType, plotDropRefs, plotCardRefs, handCardRefs);

      if (dropTarget) {
        let plotIndex, handIndex, plotType;

        if (swapDragState.sourceType === 'hand') {
          handIndex = swapDragState.sourceIndex;
          plotIndex = dropTarget.index;
          plotType = dropTarget.type === 'plot-revealed' ? 'revealed' : 'hidden';
        } else {
          plotIndex = swapDragState.sourceIndex;
          handIndex = dropTarget.index;
          plotType = swapDragState.sourceType === 'plot-revealed' ? 'revealed' : 'hidden';
        }

        onSwap(plotIndex, handIndex, plotType);
      }

      setSwapDragState(null);
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
  }, [swapDragState, onSwap, plotDropRefs, plotCardRefs, handCardRefs]);

  return { swapDragState, handleSwapDragStart };
}

export default useSwapDrag;
