// Player class - ported from engine.py:33-63

import { Card } from './Card.js';

export class Player {
  constructor(idx, isHuman = false, name = 'игрок') {
    this.idx = idx;
    this.isHuman = isHuman;
    this.name = name;
    this.hand = [];
    // Replace Python's defaultdict(list) with explicit structure
    this.plot = {
      revealed: [],
      hidden: [],
      medals: 0,  // Total medals in personal plot
      stacks: []  // Array of stack objects: { suit: string, revealed: [Card], hidden: [Card] } for ordenNachalniku variant
    };
    this.brigadeLeader = false;
    this.medals = 0;  // Medals earned this year (temporary)
    this.hasWonTrickThisYear = false;  // Track if player has won any trick this year (for requisition vulnerability)
  }

  // Serialization
  toJSON() {
    return {
      idx: this.idx,
      isHuman: this.isHuman,
      name: this.name,
      hand: this.hand.map(c => c.toJSON()),
      plot: {
        revealed: this.plot.revealed.map(c => c.toJSON()),
        hidden: this.plot.hidden.map(c => c.toJSON()),
        medals: this.plot.medals,
        stacks: this.plot.stacks.map(stack => ({
          suit: stack.suit,
          revealed: stack.revealed.map(c => c.toJSON()),
          hidden: stack.hidden.map(c => c.toJSON())
        }))
      },
      brigadeLeader: this.brigadeLeader,
      medals: this.medals,
      hasWonTrickThisYear: this.hasWonTrickThisYear
    };
  }

  static fromJSON(data) {
    const p = new Player(data.idx, data.isHuman, data.name);
    p.hand = data.hand.map(Card.fromJSON);
    p.plot.revealed = data.plot.revealed.map(Card.fromJSON);
    p.plot.hidden = data.plot.hidden.map(Card.fromJSON);
    p.plot.medals = data.plot.medals || 0;
    p.plot.stacks = (data.plot.stacks || []).map(stack => ({
      suit: stack.suit,
      revealed: stack.revealed.map(Card.fromJSON),
      hidden: stack.hidden.map(Card.fromJSON)
    }));
    p.brigadeLeader = data.brigadeLeader;
    p.medals = data.medals || 0;
    p.hasWonTrickThisYear = data.hasWonTrickThisYear || false;
    return p;
  }
}
