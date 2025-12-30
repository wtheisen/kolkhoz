// Card class for Kolkhoz
// Note: For boardgame.io, we use plain objects in G state
// This class provides helper methods and can be used for validation

import { SUITS, VALUES } from './constants.js';

export class Card {
  static SUITS = SUITS;
  static VALUES = VALUES;

  constructor(suit, value) {
    this.suit = suit;
    this.value = value;
  }

  toString() {
    const face = { 11: 'J', 12: 'Q', 13: 'K' }[this.value] || this.value;
    return `${face} of ${this.suit}`;
  }

  compareTo(other) {
    return this.value - other.value;
  }

  // Returns path to card image
  getImagePath() {
    const faces = { 1: 'ace', 11: 'jack', 12: 'queen', 13: 'king' };
    const rank = faces[this.value] || this.value;
    return `assets/cards/${rank}_of_${this.suit.toLowerCase()}.svg`;
  }

  // Create a plain object (for boardgame.io state)
  toPlain() {
    return { suit: this.suit, value: this.value };
  }

  // Create Card from plain object
  static fromPlain(obj) {
    return new Card(obj.suit, obj.value);
  }
}

// Helper to get image path for a plain card object
export function getCardImagePath(card) {
  const faces = { 1: 'ace', 11: 'jack', 12: 'queen', 13: 'king' };
  const rank = faces[card.value] || card.value;
  return `assets/cards/${rank}_of_${card.suit.toLowerCase()}.svg`;
}

// Helper to get card display string
export function cardToString(card) {
  const face = { 11: 'J', 12: 'Q', 13: 'K' }[card.value] || card.value;
  return `${face} of ${card.suit}`;
}

// Helper to create a unique key for a card (used in assignment mapping)
export function cardKey(card) {
  return `${card.suit}-${card.value}`;
}
