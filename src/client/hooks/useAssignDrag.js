import { useState, useEffect, useCallback } from 'react';
import { getEventPosition } from './useDragDrop.js';

// Find assignment drop target (job bucket)
function findAssignDropTarget(x, y, jobDropRefs) {
  for (const [suit, ref] of Object.entries(jobDropRefs.current)) {
    if (!ref) continue;
    const rect = ref.getBoundingClientRect();
    if (x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom) {
      return suit;
    }
  }
  return null;
}

// Hook for assignment phase drag and drop
export function useAssignDrag({ phase, jobDropRefs, onAssign }) {
  const [assignDragState, setAssignDragState] = useState(null);

  const handleAssignDragStart = useCallback((cardKey, card, e) => {
    if (phase !== 'assignment') return;
    e.preventDefault();
    const pos = getEventPosition(e);
    const cardEl = e.currentTarget;
    const rect = cardEl.getBoundingClientRect();

    setAssignDragState({
      cardKey,
      card,
      position: pos,
      offset: {
        x: pos.x - (rect.left + rect.width / 2),
        y: pos.y - (rect.top + rect.height / 2),
      },
      dropTarget: null,
    });
  }, [phase]);

  // Handle assignment drag movement and drop
  useEffect(() => {
    if (!assignDragState) return;

    const handleMove = (e) => {
      e.preventDefault();
      const pos = getEventPosition(e);
      const dropTarget = findAssignDropTarget(pos.x, pos.y, jobDropRefs);
      setAssignDragState((prev) => ({ ...prev, position: pos, dropTarget }));
    };

    const handleEnd = (e) => {
      const pos = e.changedTouches
        ? { x: e.changedTouches[0].clientX, y: e.changedTouches[0].clientY }
        : { x: e.clientX, y: e.clientY };

      const dropTarget = findAssignDropTarget(pos.x, pos.y, jobDropRefs);

      if (dropTarget) {
        onAssign(assignDragState.cardKey, dropTarget);
      }

      setAssignDragState(null);
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
  }, [assignDragState, onAssign, jobDropRefs]);

  return { assignDragState, handleAssignDragStart };
}

export default useAssignDrag;
