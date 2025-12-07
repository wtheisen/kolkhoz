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
      medals: 0  // Total medals in personal plot
    };
    this.brigadeLeader = false;
    this.medals = 0;  // Medals earned this year (temporary)
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
        medals: this.plot.medals
      },
      brigadeLeader: this.brigadeLeader,
      medals: this.medals
    };
  }

  static fromJSON(data) {
    const p = new Player(data.idx, data.isHuman, data.name);
    p.hand = data.hand.map(Card.fromJSON);
    p.plot.revealed = data.plot.revealed.map(Card.fromJSON);
    p.plot.hidden = data.plot.hidden.map(Card.fromJSON);
    p.plot.medals = data.plot.medals || 0;
    p.brigadeLeader = data.brigadeLeader;
    p.medals = data.medals || 0;
    return p;
  }
}
