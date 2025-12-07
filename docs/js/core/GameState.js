// GameState class - ported from engine.py:65-348

import { Card } from './Card.js';
import { Player } from './Player.js';
import { SUITS, VALUES, THRESHOLD, MAX_YEARS, PLAYER_NAMES } from './constants.js';

export class GameState {
  static THRESHOLD = THRESHOLD;
  static MAX_YEARS = MAX_YEARS;

  constructor(numPlayers = 4) {
    const names = [...PLAYER_NAMES];
    this.numPlayers = numPlayers;
    this.players = Array.from({ length: numPlayers }, (_, i) => {
      if (i === 0) {
        return new Player(0, true, 'Player');
      } else {
        const randomIndex = Math.floor(Math.random() * names.length);
        const name = names.splice(randomIndex, 1)[0];
        return new Player(i, false, name);
      }
    });

    this.lead = Math.floor(Math.random() * numPlayers);
    this.year = 1;
    this.trump = null;
    this.jobPiles = {};
    this.revealedJobs = {};
    this.claimedJobs = new Set();
    this.workHours = {};
    for (const suit of SUITS) {
      this.workHours[suit] = 0;
    }
    this.jobBuckets = {};
    for (const suit of SUITS) {
      this.jobBuckets[suit] = [];
    }
    this.currentTrick = [];
    this.lastTrick = [];
    this.lastWinner = null;
    this.trickHistory = [];
    this.requisitionLog = {};
    this.phase = 'planning';
    this.trickCount = 0;
    this.exiled = new Set();

    this._prepareJobPiles();
    this._revealJobs();
    this._prepareWorkersDeck();
    this._dealHands();
  }

  _prepareJobPiles() {
    for (const suit of SUITS) {
      const pile = Array.from({ length: MAX_YEARS }, (_, i) =>
        new Card(suit, i + 1)
      );
      this._shuffle(pile);
      this.jobPiles[suit] = pile;
    }
  }

  _revealJobs() {
    this.claimedJobs.clear();
    this.jobBuckets = {};
    for (const suit of SUITS) {
      this.jobBuckets[suit] = [];
    }
    this.requisitionLog = {};

    for (const [suit, pile] of Object.entries(this.jobPiles)) {
      this.revealedJobs[suit] = pile.pop();
    }
  }

  _prepareWorkersDeck() {
    const allCards = SUITS.flatMap(suit =>
      VALUES.map(value => new Card(suit, value))
    );

    // Collect used cards
    const used = new Set();
    for (const p of this.players) {
      for (const c of p.plot.revealed) {
        used.add(`${c.suit}-${c.value}`);
      }
      for (const c of p.plot.hidden) {
        used.add(`${c.suit}-${c.value}`);
      }
    }
    for (const cardKey of this.exiled) {
      used.add(cardKey);
    }

    console.log('[GameState] Total cards:', allCards.length, 'Used cards:', used.size);

    // Filter unused cards
    this.workersDeck = allCards.filter(c =>
      !used.has(`${c.suit}-${c.value}`)
    );

    console.log('[GameState] Workers deck size:', this.workersDeck.length);

    this._shuffle(this.workersDeck);
  }

  _dealHands() {
    console.log('[GameState] Dealing hands, deck size:', this.workersDeck.length);
    for (let i = 0; i < 5; i++) {
      for (const p of this.players) {
        if (this.workersDeck.length > 0) {
          p.hand.push(this.workersDeck.pop());
        }
      }
    }
    console.log('[GameState] After dealing - Player 0 hand size:', this.players[0].hand.length);
  }

  setTrump(suit = null) {
    if (suit) {
      this.trump = suit;
      console.log('[GameState] Trump set to:', this.trump);
    } else {
      this.trump = SUITS[Math.floor(Math.random() * SUITS.length)];
      console.log('[GameState] Trump randomly set to:', this.trump);
    }
  }

  playCard(pid, idx) {
    if (this.currentTrick.length === 0 && this.lastTrick.length > 0) {
      this.lastTrick = [];
      this.lastWinner = null;
    }

    const card = this.players[pid].hand.splice(idx, 1)[0];
    this.currentTrick.push([pid, card]);

    if (this.currentTrick.length === this.numPlayers) {
      this._resolveTrick();
    }
  }

  _resolveTrick() {
    console.log('[GameState] Resolving trick:', this.currentTrick.map(([pid, c]) => `P${pid}: ${c.toString()}`));

    // 1) Determine the lead suit
    const leadSuit = this.currentTrick[0][1].suit;
    console.log('[GameState] Lead suit:', leadSuit, 'Trump:', this.trump);

    // 2) Find the winner: trump beats lead, highest value among them wins
    const trumpCards = this.currentTrick.filter(([pid, c]) => c.suit === this.trump);

    let bestPid, bestCard;
    if (trumpCards.length > 0) {
      console.log('[GameState] Trump cards played:', trumpCards.map(([pid, c]) => `P${pid}: ${c.toString()}`));
      // Find highest trump card
      let maxValue = -1;
      for (const [pid, card] of trumpCards) {
        if (card.value > maxValue) {
          maxValue = card.value;
          bestPid = pid;
          bestCard = card;
        }
      }
    } else {
      console.log('[GameState] No trump cards, using lead suit');
      // Find highest card of lead suit
      const leadCards = this.currentTrick.filter(([pid, c]) => c.suit === leadSuit);
      let maxValue = -1;
      for (const [pid, card] of leadCards) {
        if (card.value > maxValue) {
          maxValue = card.value;
          bestPid = pid;
          bestCard = card;
        }
      }
    }

    console.log('[GameState] Winner: Player', bestPid, 'with', bestCard.toString());

    // 3) Record winner and clear the current trick
    this.lastWinner = bestPid;
    this.lastTrick = [...this.currentTrick];
    this.currentTrick = [];
    this.trickCount++;
    this.lead = this.lastWinner;

    // Clear brigade leader from all players first
    for (const p of this.players) {
      p.brigadeLeader = false;
    }
    this.players[bestPid].brigadeLeader = true;
    // Award medal for winning the trick
    this.players[bestPid].medals++;

    // 4) Assignment phase - human must assign manually
    if (this.players[this.lastWinner].isHuman) {
      this.phase = 'assignment';
      return;
    } else {
      // AI auto-assigns (will be called from controller with RandomAI)
      // For now, just transition to assignment phase and let controller handle it
      this.phase = 'assignment';
    }
  }

  applyAssignments(mapping) {
    // mapping is a Map<Card, string> where string is the assigned suit
    for (const [card, assignedSuit] of mapping.entries()) {
      this.jobBuckets[assignedSuit].push(card);

      // Skip drunkard (Jack of trump) for work hours
      if (card.value === 11 && card.suit === this.trump) {
        continue;
      }

      this.workHours[assignedSuit] += card.value;
    }

    // Check for any new completed jobs (threshold reached)
    for (const [suit, hours] of Object.entries(this.workHours)) {
      if (!this.claimedJobs.has(suit) && hours >= THRESHOLD) {
        this.players[this.lastWinner].plot.revealed.push(this.revealedJobs[suit]);
        this.claimedJobs.add(suit);
      }
    }

    // Log this trick into history
    this.trickHistory.push({
      type: 'trick',
      year: this.year,
      plays: [...this.lastTrick],
      winner: this.lastWinner
    });

    // Clean up and either continue or trigger requisition
    this.lastTrick = [];
    this.lastWinner = null;
    this.phase = 'trick';

    const tricksNeeded = (this.year === MAX_YEARS) ? 3 : 4;

    if (this.trickCount === tricksNeeded) {
      // Personal plot selection - each player keeps one card
      for (const p of this.players) {
        if (p.hand.length > 0) {
          p.plot.hidden.push(p.hand[0]);
          // Clear the hand after taking the card
          p.hand = [];
        }
      }
      this.performRequisition();
      this.phase = 'requisition';
    }
  }

  performRequisition() {
    // Log work hours for this year
    this.trickHistory.push({
      type: 'jobs',
      year: this.year,
      jobs: { ...this.workHours }
    });

    // Log requisition events
    this.trickHistory.push({
      type: 'requisition',
      year: this.year,
      requisitions: []
    });

    for (const [suit, bucket] of Object.entries(this.jobBuckets)) {
      if (this.workHours[suit] >= THRESHOLD) {
        continue;
      }

      // Check for drunkard (Jack of trump)
      let drunkard = false;
      for (const c of bucket) {
        if (c.value === 11 && c.suit === this.trump) {
          this.trickHistory[this.trickHistory.length - 1].requisitions.push(
            "Пьяница отправить на Север"
          );
          this.exiled.add(`${c.suit}-${c.value}`);
          drunkard = true;
          break;
        }
      }

      if (drunkard) {
        continue;
      }

      // Check for informant (Queen of trump)
      let informant = false;
      for (const c of bucket) {
        if (c.value === 12 && c.suit === this.trump) {
          informant = true;
          break;
        }
      }

      // Process requisition for each player
      for (const p of this.players) {
        // Reveal hidden cards if brigade leader or informant present
        if (p.brigadeLeader || informant) {
          const toReveal = p.plot.hidden.filter(c => c.suit === suit);
          p.plot.revealed.push(...toReveal);
          p.plot.hidden = p.plot.hidden.filter(c => c.suit !== suit);
        }

        // Find highest card of this suit in revealed plot
        const suitCards = p.plot.revealed
          .filter(c => c.suit === suit)
          .sort((a, b) => b.value - a.value);

        if (suitCards.length === 0) continue;

        // Remove highest card
        const card = suitCards[0];
        const cardIndex = p.plot.revealed.findIndex(
          c => c.suit === card.suit && c.value === card.value
        );
        p.plot.revealed.splice(cardIndex, 1);
        this.exiled.add(`${card.suit}-${card.value}`);
        this.trickHistory[this.trickHistory.length - 1].requisitions.push(
          `${p.name} отправить на Север ${card.toString()}`
        );

        // Check for party official (King of trump) - exile second card
        const partyOfficial = bucket.some(c => c.value === 13 && c.suit === this.trump);
        if (partyOfficial && suitCards.length > 1) {
          const card2 = suitCards[1];
          const card2Index = p.plot.revealed.findIndex(
            c => c.suit === card2.suit && c.value === card2.value
          );
          p.plot.revealed.splice(card2Index, 1);
          this.exiled.add(`${card2.suit}-${card2.value}`);
          this.trickHistory[this.trickHistory.length - 1].requisitions.push(
            `Партийный чиновник: ${p.name} отправить на Север ${card2.toString()}`
          );
        }
      }
    }
  }

  nextYear() {
    console.log('[GameState] nextYear() called, current year:', this.year);
    if (this.year >= MAX_YEARS) {
      this.phase = 'game_over';
      return;
    }

    this.year++;
    console.log('[GameState] Starting year:', this.year);
    this.phase = 'planning';
    this.trickCount = 0;

    for (const suit of SUITS) {
      this.workHours[suit] = 0;
    }

    this._revealJobs();
    this._prepareWorkersDeck();

    console.log('[GameState] Clearing player hands and transferring medals to plots');
    for (const p of this.players) {
      console.log(`[GameState] Player ${p.idx} hand before clear:`, p.hand.length, 'medals this year:', p.medals);
      // Transfer medals earned this year to personal plot
      p.plot.medals += p.medals;
      console.log(`[GameState] Player ${p.idx} total medals in plot:`, p.plot.medals);
      p.hand = [];
      p.brigadeLeader = false;
      // Reset temporary medal counter for new year
      p.medals = 0;
    }

    this._dealHands();
    this.lead = Math.floor(Math.random() * this.numPlayers);
    this.setTrump();
    console.log('[GameState] nextYear() complete');
  }

  get scores() {
    return this.players.map(p =>
      p.plot.revealed.reduce((sum, c) => sum + c.value, 0) + p.plot.medals + p.medals
    );
  }

  get finalScores() {
    return this.players.map(p =>
      [...p.plot.revealed, ...p.plot.hidden].reduce((sum, c) => sum + c.value, 0) + p.plot.medals + p.medals
    );
  }

  // Fisher-Yates shuffle
  _shuffle(array) {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
  }

  // Serialization
  toJSON() {
    return {
      version: 1,
      numPlayers: this.numPlayers,
      players: this.players.map(p => p.toJSON()),
      lead: this.lead,
      year: this.year,
      trump: this.trump,
      jobPiles: Object.fromEntries(
        Object.entries(this.jobPiles).map(([suit, cards]) =>
          [suit, cards.map(c => c.toJSON())]
        )
      ),
      revealedJobs: Object.fromEntries(
        Object.entries(this.revealedJobs).map(([suit, card]) =>
          [suit, card.toJSON()]
        )
      ),
      claimedJobs: Array.from(this.claimedJobs),
      workHours: this.workHours,
      jobBuckets: Object.fromEntries(
        Object.entries(this.jobBuckets).map(([suit, cards]) =>
          [suit, cards.map(c => c.toJSON())]
        )
      ),
      currentTrick: this.currentTrick.map(([pid, c]) => [pid, c.toJSON()]),
      lastTrick: this.lastTrick.map(([pid, c]) => [pid, c.toJSON()]),
      lastWinner: this.lastWinner,
      trickHistory: this.trickHistory.map(entry => {
        const serialized = {
          type: entry.type,
          year: entry.year
        };
        if (entry.plays) {
          serialized.plays = entry.plays.map(([pid, c]) => [pid, c.toJSON()]);
        }
        if (entry.winner !== undefined) {
          serialized.winner = entry.winner;
        }
        if (entry.jobs) {
          serialized.jobs = entry.jobs;
        }
        if (entry.requisitions) {
          serialized.requisitions = entry.requisitions;
        }
        return serialized;
      }),
      phase: this.phase,
      trickCount: this.trickCount,
      exiled: Array.from(this.exiled)
    };
  }

  static fromJSON(data) {
    const game = Object.create(GameState.prototype);

    // Handle version migrations
    if (data.version !== 1) {
      throw new Error('Unsupported save version');
    }

    game.numPlayers = data.numPlayers;
    game.players = data.players.map(Player.fromJSON);
    game.lead = data.lead;
    game.year = data.year;
    game.trump = data.trump;
    console.log('[GameState] Trump loaded from JSON:', game.trump);

    game.jobPiles = Object.fromEntries(
      Object.entries(data.jobPiles).map(([suit, cards]) =>
        [suit, cards.map(Card.fromJSON)]
      )
    );

    game.revealedJobs = Object.fromEntries(
      Object.entries(data.revealedJobs).map(([suit, card]) =>
        [suit, Card.fromJSON(card)]
      )
    );

    game.claimedJobs = new Set(data.claimedJobs);
    game.workHours = data.workHours;

    game.jobBuckets = Object.fromEntries(
      Object.entries(data.jobBuckets).map(([suit, cards]) =>
        [suit, cards.map(Card.fromJSON)]
      )
    );

    game.currentTrick = data.currentTrick.map(([pid, c]) =>
      [pid, Card.fromJSON(c)]
    );

    game.lastTrick = data.lastTrick.map(([pid, c]) =>
      [pid, Card.fromJSON(c)]
    );

    game.lastWinner = data.lastWinner;

    game.trickHistory = data.trickHistory.map(entry => {
      const deserialized = {
        type: entry.type,
        year: entry.year
      };
      if (entry.plays) {
        deserialized.plays = entry.plays.map(([pid, c]) => [pid, Card.fromJSON(c)]);
      }
      if (entry.winner !== undefined) {
        deserialized.winner = entry.winner;
      }
      if (entry.jobs) {
        deserialized.jobs = entry.jobs;
      }
      if (entry.requisitions) {
        deserialized.requisitions = entry.requisitions;
      }
      return deserialized;
    });

    game.phase = data.phase;
    game.trickCount = data.trickCount;
    game.exiled = new Set(data.exiled);
    game.requisitionLog = {};

    return game;
  }
}
