// Layout manager for calculating positions of game elements

export class LayoutManager {
  constructor(gameWidth, gameHeight) {
    this.gameWidth = gameWidth;
    this.gameHeight = gameHeight;
    this.updateDimensions(gameWidth, gameHeight);
  }

  updateDimensions(width, height) {
    this.gameWidth = width;
    this.gameHeight = height;
    this.centerX = width / 2;
    this.centerY = height / 2;
  }

  // Calculate positions for 4 players around a table
  // Adjusted to account for jobs on left and gulag on right
  getPlayerPosition(playerIndex, totalPlayers = 4) {
    const angle = (playerIndex * 2 * Math.PI) / totalPlayers - Math.PI / 2; // Start at top
    // Use a slightly smaller radius to account for side panels
    const radius = Math.min(this.gameWidth, this.gameHeight) * 0.30;
    
    return {
      x: this.centerX + radius * Math.cos(angle),
      y: this.centerY + radius * Math.sin(angle),
      angle: angle
    };
  }

  // Calculate fan layout for cards in hand
  getFanCardPosition(cardIndex, totalCards, startAngle = -0.5, spreadAngle = 1.0) {
    const angle = startAngle + (spreadAngle * cardIndex) / Math.max(1, totalCards - 1);
    const radius = 120;
    const baseX = 0;
    const baseY = 0;
    
    return {
      x: baseX + radius * Math.sin(angle),
      y: baseY + radius * (1 - Math.cos(angle)),
      rotation: angle
    };
  }

  // Get trick area center (playing area in the middle)
  getTrickAreaCenter() {
    // Center is adjusted slightly to account for side panels
    return {
      x: this.centerX,
      y: this.centerY
    };
  }

  // Get job pile positions (4 jobs arranged horizontally in a row on the left side)
  getJobPilePosition(suitIndex, totalJobs = 4) {
    // Position jobs horizontally in a row on the left side of the screen
    const leftMargin = 120; // Space from left edge
    const horizontalSpacing = 140; // Space between jobs
    // Center vertically - start from center and go up a bit to account for card stacks
    const startY = this.centerY - 80; // Vertical position for the row, centered with offset for stacks
    
    return {
      x: leftMargin + suitIndex * horizontalSpacing,
      y: startY,
      angle: 0
    };
  }

  // Get gulag area position (on the right side, but moved more towards center)
  getGulagAreaPosition() {
    // Position gulag on the right side, but use percentage to move it more towards center
    // Use 85% of screen width to prevent clipping while staying on the right side
    return {
      x: this.gameWidth * 0.85,
      y: this.centerY
    };
  }

  // Calculate card size based on screen size
  getCardSize() {
    const baseSize = Math.min(this.gameWidth, this.gameHeight);
    return {
      width: Math.max(60, Math.min(100, baseSize * 0.08)),
      height: Math.max(84, Math.min(140, baseSize * 0.11))
    };
  }
}
