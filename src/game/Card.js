// Card helper functions for Kolkhoz
// Note: Cards in boardgame.io state are plain objects { suit, value }

// Helper to get image path for a plain card object
export function getCardImagePath(card) {
  const faces = { 1: 'ace', 11: 'jack', 12: 'queen', 13: 'king' };
  const rank = faces[card.value] || card.value;
  return `assets/cards/${rank}_of_${card.suit.toLowerCase()}.svg`;
}
