// Card class - ported from engine.py:7-31

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

  // Serialization
  toJSON() {
    return {
      suit: this.suit,
      value: this.value
    };
  }

  static fromJSON(data) {
    return new Card(data.suit, data.value);
  }

  // UI helper - returns path to card image
  getImagePath() {
    const faces = { 1: 'ace', 11: 'jack', 12: 'queen', 13: 'king' };
    const rank = faces[this.value] || this.value;
    return `assets/cards/${rank}_of_${this.suit.toLowerCase()}.svg`;
  }
}
