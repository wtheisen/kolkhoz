// Base AI interface for future extensibility

export class AIPlayer {
  constructor(playerIdx) {
    if (new.target === AIPlayer) {
      throw new Error('AIPlayer is abstract - use a concrete implementation');
    }
    this.playerIdx = playerIdx;
  }

  // Must return card index to play
  play(gameState) {
    throw new Error('Must implement play()');
  }

  // Must return Map<Card, string> mapping cards to suit assignments
  assignTrick(gameState) {
    throw new Error('Must implement assignTrick()');
  }
}
