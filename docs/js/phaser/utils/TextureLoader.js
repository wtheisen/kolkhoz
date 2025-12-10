// Texture loader utility for loading SVG cards as Phaser textures

import { SUITS } from '../../core/constants.js';

export class TextureLoader {
  static loadCardTextures(scene) {
    // Configure texture settings for crisp rendering
    const loadConfig = {
      // Disable texture smoothing for crisp rendering
      textureX: 0,
      textureY: 0,
      textureWidth: 0,
      textureHeight: 0
    };

    // Load card back (custom card back)
    scene.load.image('card_back', 'assets/card_back.png');

    // Load suit icons
    scene.load.image('suit_hearts', 'assets/cards/heart.svg');
    scene.load.image('suit_diamonds', 'assets/cards/diamond.svg');
    scene.load.image('suit_clubs', 'assets/cards/club.svg');
    scene.load.image('suit_spades', 'assets/cards/spade.svg');

    // Load all card faces
    const faces = { 1: 'ace', 11: 'jack', 12: 'queen', 13: 'king' };
    
    // Load cards for 52-card deck (6-10, J, Q, K) and also Ace for 36-card deck
    const values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
    
    SUITS.forEach(suit => {
      values.forEach(value => {
        const face = faces[value] || value;
        const suitLower = suit.toLowerCase();
        const key = `card_${face}_${suitLower}`;
        const path = `assets/cards/${face}_of_${suitLower}.svg`;
        scene.load.image(key, path);
      });
    });

    // Load jokers (if needed)
    scene.load.image('card_red_joker', 'assets/cards/red_joker.svg');
    scene.load.image('card_black_joker', 'assets/cards/black_joker.svg');
  }

  static getCardTextureKey(card) {
    const faces = { 1: 'ace', 11: 'jack', 12: 'queen', 13: 'king' };
    const face = faces[card.value] || card.value;
    const suitLower = card.suit.toLowerCase();
    return `card_${face}_${suitLower}`;
  }

  static getSuitTextureKey(suit) {
    const suitLower = suit.toLowerCase();
    return `suit_${suitLower}`;
  }
}
