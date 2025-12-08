// TouchHandler - provides touch event support for drag and drop on mobile devices
// This complements the existing HTML5 drag and drop API which doesn't work well on mobile

export class TouchHandler {
  constructor() {
    this.activeTouch = null;
    this.dragElement = null;
    this.startX = 0;
    this.startY = 0;
    this.offsetX = 0;
    this.offsetY = 0;
  }

  // Setup touch handlers for a draggable element
  setupTouchDrag(element, onDragStart, onDrag, onDragEnd, onDrop) {
    let isDragging = false;
    let touchStartTime = 0;
    let touchStartPos = null;

    const handleTouchStart = (e) => {
      if (e.touches.length !== 1) return;
      
      const touch = e.touches[0];
      touchStartTime = Date.now();
      touchStartPos = { x: touch.clientX, y: touch.clientY };
      
      // Prevent default to avoid scrolling
      e.preventDefault();
      
      this.activeTouch = touch.identifier;
      this.dragElement = element;
      
      const rect = element.getBoundingClientRect();
      this.startX = touch.clientX;
      this.startY = touch.clientY;
      this.offsetX = touch.clientX - rect.left;
      this.offsetY = touch.clientY - rect.top;
      
      // Add dragging class
      element.classList.add('dragging');
      
      // Call onDragStart callback if provided
      if (onDragStart) {
        onDragStart({
          clientX: touch.clientX,
          clientY: touch.clientY,
          target: element
        });
      }
    };

    const handleTouchMove = (e) => {
      if (!this.activeTouch || this.dragElement !== element) return;
      
      const touch = Array.from(e.touches).find(t => t.identifier === this.activeTouch);
      if (!touch) return;
      
      e.preventDefault();
      
      // Check if we've moved enough to consider it a drag (not just a tap)
      if (touchStartPos) {
        const dx = Math.abs(touch.clientX - touchStartPos.x);
        const dy = Math.abs(touch.clientY - touchStartPos.y);
        if (dx < 5 && dy < 5) return; // Too small movement, might be a tap
      }
      
      isDragging = true;
      
      // Move element with touch
      const currentX = touch.clientX - this.offsetX;
      const currentY = touch.clientY - this.offsetY;
      
      element.style.position = 'fixed';
      element.style.left = currentX + 'px';
      element.style.top = currentY + 'px';
      element.style.zIndex = '10000';
      element.style.pointerEvents = 'none';
      element.style.transform = 'scale(1.1) rotate(5deg)';
      
      // Find drop target under touch point
      const elementBelow = document.elementFromPoint(touch.clientX, touch.clientY);
      
      // Call onDrag callback if provided
      if (onDrag) {
        onDrag({
          clientX: touch.clientX,
          clientY: touch.clientY,
          target: elementBelow,
          element: element
        });
      }
    };

    const handleTouchEnd = (e) => {
      if (!this.activeTouch || this.dragElement !== element) return;
      
      const touch = Array.from(e.changedTouches || []).find(t => t.identifier === this.activeTouch);
      if (!touch) return;
      
      e.preventDefault();
      
      // Reset element styles
      element.style.position = '';
      element.style.left = '';
      element.style.top = '';
      element.style.zIndex = '';
      element.style.pointerEvents = '';
      element.style.transform = '';
      element.classList.remove('dragging');
      
      // Check if it was a tap or a drag
      const touchDuration = Date.now() - touchStartTime;
      const wasTap = !isDragging && touchDuration < 300;
      
      if (wasTap && !onDrop) {
        // If it was a tap and there's no drop handler, treat as click
        element.click();
      } else if (isDragging) {
        // Find drop target
        const dropTarget = document.elementFromPoint(touch.clientX, touch.clientY);
        
        // Call onDrop callback if provided
        if (onDrop && dropTarget) {
          onDrop({
            clientX: touch.clientX,
            clientY: touch.clientY,
            target: dropTarget,
            element: element
          });
        }
      }
      
      // Call onDragEnd callback if provided
      if (onDragEnd) {
        onDragEnd({
          clientX: touch.clientX,
          clientY: touch.clientY,
          target: element
        });
      }
      
      // Reset state
      this.activeTouch = null;
      this.dragElement = null;
      isDragging = false;
      touchStartPos = null;
    };

    const handleTouchCancel = (e) => {
      if (!this.activeTouch || this.dragElement !== element) return;
      
      // Reset element styles
      element.style.position = '';
      element.style.left = '';
      element.style.top = '';
      element.style.zIndex = '';
      element.style.pointerEvents = '';
      element.style.transform = '';
      element.classList.remove('dragging');
      
      // Call onDragEnd callback
      if (onDragEnd) {
        onDragEnd({
          clientX: 0,
          clientY: 0,
          target: element
        });
      }
      
      // Reset state
      this.activeTouch = null;
      this.dragElement = null;
      isDragging = false;
      touchStartPos = null;
    };

    // Add touch event listeners
    element.addEventListener('touchstart', handleTouchStart, { passive: false });
    element.addEventListener('touchmove', handleTouchMove, { passive: false });
    element.addEventListener('touchend', handleTouchEnd, { passive: false });
    element.addEventListener('touchcancel', handleTouchCancel, { passive: false });
    
    // Store handlers for cleanup if needed
    element._touchHandlers = {
      touchstart: handleTouchStart,
      touchmove: handleTouchMove,
      touchend: handleTouchEnd,
      touchcancel: handleTouchCancel
    };
  }

  // Setup touch handlers for a drop zone
  setupTouchDrop(dropZone, onDragEnter, onDragOver, onDragLeave, onDrop) {
    let isOver = false;

    // We'll handle this through the touch events on draggable elements
    // For now, we'll use a global touch move listener to detect when dragging over drop zones
    const checkDropZone = (touchX, touchY, dragElement) => {
      const rect = dropZone.getBoundingClientRect();
      const isInside = touchX >= rect.left && touchX <= rect.right &&
                      touchY >= rect.top && touchY <= rect.bottom;
      
      if (isInside && !isOver) {
        isOver = true;
        dropZone.classList.add('dragover');
        if (onDragEnter) {
          onDragEnter({
            clientX: touchX,
            clientY: touchY,
            target: dropZone,
            element: dragElement
          });
        }
      } else if (!isInside && isOver) {
        isOver = false;
        dropZone.classList.remove('dragover');
        if (onDragLeave) {
          onDragLeave({
            clientX: touchX,
            clientY: touchY,
            target: dropZone,
            element: dragElement
          });
        }
      } else if (isInside && isOver) {
        if (onDragOver) {
          onDragOver({
            clientX: touchX,
            clientY: touchY,
            target: dropZone,
            element: dragElement
          });
        }
      }
    };

    // Store the check function so it can be called from drag handlers
    dropZone._touchDropCheck = checkDropZone;
    dropZone._touchDropHandlers = {
      onDragEnter,
      onDragOver,
      onDragLeave,
      onDrop
    };
  }

  // Cleanup touch handlers
  cleanup(element) {
    if (element._touchHandlers) {
      Object.entries(element._touchHandlers).forEach(([event, handler]) => {
        element.removeEventListener(event, handler);
      });
      delete element._touchHandlers;
    }
  }
}

// Global instance
export const touchHandler = new TouchHandler();

