# Phaser Card Dragging Fixes

## Issues Fixed

### 1. **Incorrect Drag Coordinate Detection** ([InputManager.js:31-47](docs/js/phaser/managers/InputManager.js#L31-L47))
**Problem:** The drag detection was using `cardSprite.x` and `cardSprite.y` instead of pointer world coordinates.

**Fix:** Changed to use `pointer.worldX` and `pointer.worldY` for accurate drop detection.

```javascript
// Before (WRONG)
const dragX = cardSprite.x;
const dragY = cardSprite.y;

// After (CORRECT)
const dragX = pointer.worldX;
const dragY = pointer.worldY;
```

### 2. **Missing TrickArea.getBounds() Method** ([TrickArea.js:96-106](docs/js/phaser/objects/TrickArea.js#L96-L106))
**Problem:** TrickArea had no `getBounds()` method, so drop zone registration failed.

**Fix:** Added proper `getBounds()` method that returns world coordinates:

```javascript
getBounds() {
  const radius = 150;
  return {
    x: this.x - radius,
    y: this.y - radius,
    width: radius * 2,
    height: radius * 2
  };
}
```

### 3. **Incorrect JobPile Drop Zone Bounds** ([JobPile.js:192-212](docs/js/phaser/objects/JobPile.js#L192-L212))
**Problem:** Drop zone bounds calculation didn't properly account for centered rectangles in Phaser containers.

**Fix:** Properly calculated world bounds accounting for container position and drop zone dimensions:

```javascript
// Properly centers the drop zone
x: worldX - dropZoneWidth / 2,
y: worldY + dropZoneLocalY - dropZoneHeight / 2
```

### 4. **Improved Drop Zone Registration** ([InputManager.js:78-96](docs/js/phaser/managers/InputManager.js#L78-L96))
**Problem:** Drop zone registration had weak fallback logic that didn't work with Phaser containers.

**Fix:** Now checks for both `getBounds()` and `getDropZoneBounds()` methods with proper error handling.

### 5. **Added Visual Feedback** ([InputManager.js:64-71](docs/js/phaser/managers/InputManager.js#L64-L71))
**Problem:** Cards just snapped back instantly with no animation.

**Fix:** Added smooth tween animation when cards return to original position.

### 6. **Assignment Phase Card Hiding** ([InputManager.js:144-145](docs/js/phaser/managers/InputManager.js#L144-L145))
**Problem:** Dragged cards stayed visible after being assigned.

**Fix:** Cards are now hidden (`setVisible(false)`) when successfully assigned to a job pile.

## How to Enable Debug Mode

If dragging still isn't working, enable debug mode to see what's happening:

1. Open [InputManager.js](docs/js/phaser/managers/InputManager.js#L13)
2. Change `this.debugMode = false;` to `this.debugMode = true;`
3. Open browser console (F12) while playing
4. You'll see logs like:
   ```
   Card dropped at: 512 384
   Checking drop zone 'trick': { x: 362, y: 234, width: 300, height: 300 }
   Card dropped in zone 'trick'
   ```

## Common Issues & Solutions

### Cards won't drag at all
- Check that `CardSprite.enableDrag()` is being called
- Verify card sprites have `setInteractive({ draggable: true })`
- Check browser console for JavaScript errors

### Cards drag but don't drop
- Enable debug mode (see above)
- Check that drop zones are registered: `inputManager.registerDropZone(...)`
- Verify `getBounds()` returns valid coordinates (not NaN or negative)

### Drop zones in wrong place
- Check that containers use world coordinates, not local coordinates
- Verify drop zone bounds account for parent container position
- Use debug mode to see actual bounds vs pointer position

### Cards snap back too fast
- Animation duration is 200ms in the tween
- Increase duration in [InputManager.js:65-71](docs/js/phaser/managers/InputManager.js#L65-L71)

## Testing Checklist

- [ ] **Trick Phase**: Drag cards from hand to trick area
- [ ] **Trick Phase**: Cards return to hand if dropped outside trick area
- [ ] **Trick Phase**: Validate suit-following rules work
- [ ] **Assignment Phase**: Drag cards from trick to job piles
- [ ] **Assignment Phase**: Cards hide when assigned
- [ ] **Assignment Phase**: Preview shows assigned cards
- [ ] **Assignment Phase**: Complete button appears when all assigned
- [ ] **Mobile**: Touch dragging works (Phaser handles this automatically)

## Architecture Notes

### Coordinate Systems
Phaser uses multiple coordinate systems:
- **World coordinates**: Absolute position in game world (used for drop detection)
- **Local coordinates**: Position relative to parent container
- **Screen coordinates**: Browser viewport pixels

Always use **world coordinates** (`pointer.worldX/worldY`) for drop detection!

### Drop Zone Flow
1. Scene creates drop zone object (TrickArea, JobPile)
2. Scene registers drop zone: `inputManager.registerDropZone(key, object, callback)`
3. InputManager stores drop zone with its `getBounds()` function
4. On drag end, InputManager checks if pointer is within any drop zone bounds
5. If match found, calls the registered callback

### Card Lifecycle (Assignment Phase)
1. Cards displayed in TrickArea
2. User drags card
3. On drop in JobPile: card hidden, assignment recorded in `assignmentMap`
4. Preview updated via `onAssignmentChanged()` callback
5. JobPile shows preview of assigned cards
6. On submit: actual assignment applied to game state

## Files Changed

- [docs/js/phaser/managers/InputManager.js](docs/js/phaser/managers/InputManager.js)
- [docs/js/phaser/objects/TrickArea.js](docs/js/phaser/objects/TrickArea.js)
- [docs/js/phaser/objects/JobPile.js](docs/js/phaser/objects/JobPile.js)

---

**Date:** 2025-12-10
**Fixed by:** Claude Sonnet 4.5
