// Card helper functions for Kolkhoz
// Note: Cards in boardgame.io state are plain objects { suit, value }

// Map crop suits to card image file names
// The actual SVG files use traditional card suit names
const SUIT_TO_FILE = {
  Wheat: 'spades',
  Sunflower: 'clubs',
  Potato: 'diamonds',
  Beet: 'hearts',
};

// Helper to get image path for a plain card object
export function getCardImagePath(card) {
  const faces = { 1: 'ace', 11: 'jack', 12: 'queen', 13: 'king' };
  const rank = faces[card.value] || card.value;
  const fileSuit = SUIT_TO_FILE[card.suit] || card.suit.toLowerCase();
  return `assets/cards/${rank}_of_${fileSuit}.svg`;
}
