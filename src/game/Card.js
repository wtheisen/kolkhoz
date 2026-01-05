// Card helper functions for Kolkhoz
// Note: Cards in boardgame.io state are plain objects { suit, value }

// Helper to get image path for a plain card object
// Card files use crop suit names directly: wheat, sunflower, potato, beet
export function getCardImagePath(card) {
  const faces = { 1: 'ace', 11: 'jack', 12: 'queen', 13: 'king' };
  const rank = faces[card.value] || card.value;
  const suit = card.suit.toLowerCase();
  return `/assets/cards/${rank}_of_${suit}.svg`;
}
