// GameState class - ported from engine.py:65-348

import { Card } from './Card.js';
import { Player } from './Player.js';
import { SUITS, VALUES, THRESHOLD, MAX_YEARS, PLAYER_NAMES } from './constants.js';

export class GameState {
  static THRESHOLD = THRESHOLD;
  static MAX_YEARS = MAX_YEARS;

  constructor(numPlayers = 4, gameVariants = {}) {
    const names = [...PLAYER_NAMES];
    this.numPlayers = numPlayers;
    this.players = Array.from({ length: numPlayers }, (_, i) => {
      if (i === 0) {
        return new Player(0, true, 'игрок');
      } else {
        const randomIndex = Math.floor(Math.random() * names.length);
        const name = names.splice(randomIndex, 1)[0];
        return new Player(i, false, name);
      }
    });

    // Initialize game variants with defaults
    this.gameVariants = {
      specialEffects: true,  // Face card powers (drunkard, informant, party official)
      medalsCount: false,  // If true, medals accumulate and count toward final score
      accumulateUnclaimedJobs: true,  // If true, unclaimed job rewards accumulate to next year
      allowSwap: false,  // If true, players can swap one hidden plot card with one hand card at year start
      ...gameVariants
    };

    this.lead = Math.floor(Math.random() * numPlayers);
    this.year = 1;
    this.trump = null;
    this.jobPiles = {};
    this.revealedJobs = {};  // Will store arrays of cards when accumulateUnclaimedJobs is enabled
    this.claimedJobs = new Set();
    this.accumulatedJobCards = {};  // Track accumulated cards for unclaimed jobs (variant)
    for (const suit of SUITS) {
      this.accumulatedJobCards[suit] = [];
    }
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
    this.exiled = {};  // Maps year to array of card keys: { 1: ['Hearts-10', ...], 2: [...], ... }
    this.currentSwapPlayer = null;  // Tracks which player is currently swapping
    this.currentSwapPlayer = null;  // Tracks which player is currently swapping

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
      const newJobCard = pile.pop();
      
      if (this.gameVariants.accumulateUnclaimedJobs) {
        // If there are accumulated cards from previous year, add new card to the array
        if (this.accumulatedJobCards[suit].length > 0) {
          // Keep accumulated cards and add the new one
          this.revealedJobs[suit] = [...this.accumulatedJobCards[suit], newJobCard];
          // Clear accumulated cards (will be set again if not claimed)
          this.accumulatedJobCards[suit] = [];
        } else {
          // First card for this job
          this.revealedJobs[suit] = [newJobCard];
        }
      } else {
        // Store as single card (backward compatibility)
        this.revealedJobs[suit] = newJobCard;
      }
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
    // Collect all exiled cards from all years
    for (const yearCards of Object.values(this.exiled)) {
      for (const cardKey of yearCards) {
        used.add(cardKey);
      }
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

  _addToExiled(cardKey) {
    // Initialize year array if it doesn't exist
    if (!this.exiled[this.year]) {
      this.exiled[this.year] = [];
    }
    this.exiled[this.year].push(cardKey);
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

  swapCard(playerId, hiddenCardIndex, handCardIndex) {
    // Validate indices
    const player = this.players[playerId];
    if (hiddenCardIndex < 0 || hiddenCardIndex >= player.plot.hidden.length) {
      throw new Error('Invalid hidden card index');
    }
    if (handCardIndex < 0 || handCardIndex >= player.hand.length) {
      throw new Error('Invalid hand card index');
    }

    // Perform the swap
    const hiddenCard = player.plot.hidden[hiddenCardIndex];
    const handCard = player.hand[handCardIndex];
    
    player.plot.hidden[hiddenCardIndex] = handCard;
    player.hand[handCardIndex] = hiddenCard;

    console.log(`[GameState] Player ${playerId} swapped hidden card with hand card`);
  }

  reorderHand(playerId, fromIndex, toIndex) {
    // Validate indices
    const player = this.players[playerId];
    if (fromIndex < 0 || fromIndex >= player.hand.length) {
      throw new Error('Invalid from index');
    }
    if (toIndex < 0 || toIndex >= player.hand.length) {
      throw new Error('Invalid to index');
    }
    if (fromIndex === toIndex) {
      return; // No change needed
    }

    // Remove card from original position
    const card = player.hand.splice(fromIndex, 1)[0];
    // Insert at new position
    player.hand.splice(toIndex, 0, card);

    console.log(`[GameState] Player ${playerId} reordered hand: moved card from index ${fromIndex} to ${toIndex}`);
  }

  completeSwap(playerId) {
    // Mark that this player has completed their swap
    if (this.currentSwapPlayer === playerId) {
      this.currentSwapPlayer++;
      
      // If all players have swapped, move to planning phase
      if (this.currentSwapPlayer >= this.numPlayers) {
        this.setTrump();
        this.phase = 'planning';
        this.currentSwapPlayer = null;
      }
    }
  }

  playCard(pid, idx) {
    if (this.currentTrick.length === 0 && this.lastTrick.length > 0) {
      this.lastTrick = [];
      this.lastWinner = null;
    }

    // Validate player and index
    if (!this.players[pid]) {
      console.error('[GameState] Invalid player ID:', pid);
      return;
    }

    if (idx < 0 || idx >= this.players[pid].hand.length) {
      console.error('[GameState] Invalid card index:', idx, 'for player', pid, 'hand size:', this.players[pid].hand.length);
      return;
    }

    const card = this.players[pid].hand.splice(idx, 1)[0];
    
    // Validate card was retrieved
    if (!card) {
      console.error('[GameState] Failed to retrieve card at index', idx, 'from player', pid);
      return;
    }

    this.currentTrick.push([pid, card]);

    if (this.currentTrick.length === this.numPlayers) {
      this._resolveTrick();
    }
  }

  _resolveTrick() {
    // Filter out any undefined cards before resolving
    this.currentTrick = this.currentTrick.filter(([pid, c]) => {
      if (!c) {
        console.warn('[GameState] Filtering out undefined card from player', pid);
        return false;
      }
      return true;
    });

    // Check if we still have enough cards
    if (this.currentTrick.length < this.numPlayers) {
      console.error('[GameState] Not enough cards in trick after filtering:', this.currentTrick.length, 'expected:', this.numPlayers);
      return;
    }

    console.log('[GameState] Resolving trick:', this.currentTrick.map(([pid, c]) => `P${pid}: ${c ? c.toString() : 'undefined'}`));

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
    // Mark that this player has won a trick this year (for requisition vulnerability)
    this.players[bestPid].hasWonTrickThisYear = true;
    // Award medal for winning the trick (only if medals variant is enabled)
    if (this.gameVariants.medalsCount) {
      this.players[bestPid].medals++;
    }

    // 4) Assignment phase - check if auto-assignment is possible
    if (this.players[this.lastWinner].isHuman) {
      // Check if all cards in the trick have the same suit
      const allCardsSameSuit = this.lastTrick.length > 0 && 
        this.lastTrick.every(([pid, card]) => card.suit === this.lastTrick[0][1].suit);
      
      if (allCardsSameSuit) {
        // Auto-assign all cards to the same suit
        const commonSuit = this.lastTrick[0][1].suit;
        const mapping = new Map();
        for (const [pid, card] of this.lastTrick) {
          mapping.set(card, commonSuit);
        }
        console.log('[GameState] All cards have same suit, auto-assigning to', commonSuit);
        this.applyAssignments(mapping);
        return;
      }
      
      // Otherwise, require manual assignment
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
    console.log('[GameState] applyAssignments called with mapping:', Array.from(mapping.entries()).map(([c, s]) => `${c.toString()} (value: ${c.value}, type: ${typeof c.value}) -> ${s}`));
    for (const [card, assignedSuit] of mapping.entries()) {
      // Ensure workHours is initialized for this suit
      if (!(assignedSuit in this.workHours)) {
        this.workHours[assignedSuit] = 0;
      }
      
      this.jobBuckets[assignedSuit].push(card);

      // Skip drunkard (Jack of trump) for work hours (only if special effects enabled)
      if (this.gameVariants.specialEffects && card.value === 11 && card.suit === this.trump) {
        console.log('[GameState] Skipping drunkard (Jack of trump) for work hours');
        continue;
      }

      const previousHours = this.workHours[assignedSuit];
      const cardValue = Number(card.value); // Ensure it's a number
      this.workHours[assignedSuit] += cardValue;
      console.log(`[GameState] Added ${cardValue} work hours to ${assignedSuit}: ${previousHours} + ${cardValue} = ${this.workHours[assignedSuit]}`);
    }

    // Check for any new completed jobs (threshold reached)
    console.log('[GameState] Current work hours:', this.workHours);
    console.log('[GameState] Threshold:', THRESHOLD);
    for (const [suit, hours] of Object.entries(this.workHours)) {
      console.log(`[GameState] Checking ${suit}: ${hours} hours, claimed: ${this.claimedJobs.has(suit)}`);
      if (!this.claimedJobs.has(suit) && hours >= THRESHOLD) {
        console.log(`[GameState] Job ${suit} completed! Claiming reward.`);
        // Get the job card(s) - could be array or single card
        const jobRewards = Array.isArray(this.revealedJobs[suit]) 
          ? this.revealedJobs[suit] 
          : [this.revealedJobs[suit]];
        
        // Add all accumulated reward cards to player's plot
        for (const card of jobRewards) {
          this.players[this.lastWinner].plot.revealed.push(card);
        }
        
        this.claimedJobs.add(suit);
        // Clear accumulated cards if job is claimed
        if (this.gameVariants.accumulateUnclaimedJobs) {
          this.accumulatedJobCards[suit] = [];
        }
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

      // Check for drunkard (Jack of trump) - only if special effects enabled
      let drunkard = false;
      if (this.gameVariants.specialEffects) {
        for (const c of bucket) {
          if (c.value === 11 && c.suit === this.trump) {
            this.trickHistory[this.trickHistory.length - 1].requisitions.push(
              "Пьяница отправить на Север"
            );
            this._addToExiled(`${c.suit}-${c.value}`);
            drunkard = true;
            break;
          }
        }
      }

      if (drunkard) {
        continue;
      }

      // Check for informant (Queen of trump) - only if special effects enabled
      let informant = false;
      if (this.gameVariants.specialEffects) {
        for (const c of bucket) {
          if (c.value === 12 && c.suit === this.trump) {
            informant = true;
            break;
          }
        }
      }

      // Process requisition for each player
      for (const p of this.players) {
        // Reveal hidden cards if player was a brigade leader this year or informant present (informant only if special effects enabled)
        if (p.hasWonTrickThisYear || informant) {
          const toReveal = p.plot.hidden.filter(c => c.suit === suit);
          p.plot.revealed.push(...toReveal);
          p.plot.hidden = p.plot.hidden.filter(c => c.suit !== suit);
        }

        // Only players who were brigade leaders this year are affected by card exile, unless informant is present in THIS job (then all players are affected for this job only)
        if (!p.hasWonTrickThisYear && !informant) continue;

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
        this._addToExiled(`${card.suit}-${card.value}`);
        this.trickHistory[this.trickHistory.length - 1].requisitions.push(
          `${p.name} отправить на Север ${card.toString()}`
        );

        // Check for party official (King of trump) - exile second card (only if special effects enabled)
        if (this.gameVariants.specialEffects) {
          const partyOfficial = bucket.some(c => c.value === 13 && c.suit === this.trump);
          if (partyOfficial && suitCards.length > 1) {
            const card2 = suitCards[1];
            const card2Index = p.plot.revealed.findIndex(
              c => c.suit === card2.suit && c.value === card2.value
            );
            p.plot.revealed.splice(card2Index, 1);
            this._addToExiled(`${card2.suit}-${card2.value}`);
            this.trickHistory[this.trickHistory.length - 1].requisitions.push(
              `Партийный чиновник: ${p.name} отправить на Север ${card2.toString()}`
            );
          }
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

    // Store accumulated cards for unclaimed jobs (if variant enabled)
    if (this.gameVariants.accumulateUnclaimedJobs) {
      for (const suit of SUITS) {
        if (!this.claimedJobs.has(suit)) {
          // Accumulate the unclaimed job card(s)
          const jobRewards = Array.isArray(this.revealedJobs[suit]) 
            ? this.revealedJobs[suit] 
            : [this.revealedJobs[suit]];
          this.accumulatedJobCards[suit].push(...jobRewards);
        }
      }
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
      // Transfer medals earned this year to personal plot (only if medals variant is enabled)
      if (this.gameVariants.medalsCount) {
        p.plot.medals += p.medals;
        console.log(`[GameState] Player ${p.idx} total medals in plot:`, p.plot.medals);
      }
      p.hand = [];
      p.brigadeLeader = false;
      // Reset temporary medal counter for new year
      p.medals = 0;
      // Reset trick winner flag for new year
      p.hasWonTrickThisYear = false;
    }

    this._dealHands();
    this.lead = Math.floor(Math.random() * this.numPlayers);
    
    // If swap variant is enabled, go to swap phase; otherwise go to planning
    if (this.gameVariants.allowSwap) {
      this.phase = 'swap';
      this.currentSwapPlayer = 0;  // Start with player 0
    } else {
      this.setTrump();
      this.phase = 'planning';
    }
    console.log('[GameState] nextYear() complete');
  }

  get scores() {
    return this.players.map(p => {
      const cardScore = p.plot.revealed.reduce((sum, c) => sum + c.value, 0);
      const medalScore = this.gameVariants.medalsCount ? (p.plot.medals + p.medals) : 0;
      return cardScore + medalScore;
    });
  }

  get finalScores() {
    return this.players.map(p => {
      const cardScore = [...p.plot.revealed, ...p.plot.hidden].reduce((sum, c) => sum + c.value, 0);
      const medalScore = this.gameVariants.medalsCount ? (p.plot.medals + p.medals) : 0;
      return cardScore + medalScore;
    });
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
      gameVariants: this.gameVariants,
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
        Object.entries(this.revealedJobs).map(([suit, cardOrArray]) => {
          // Handle both single cards and arrays of cards
          if (Array.isArray(cardOrArray)) {
            return [suit, cardOrArray.map(c => c.toJSON())];
          } else {
            return [suit, cardOrArray.toJSON()];
          }
        })
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
      exiled: this.exiled,  // Now an object mapping year to arrays
      accumulatedJobCards: Object.fromEntries(
        Object.entries(this.accumulatedJobCards).map(([suit, cards]) =>
          [suit, cards.map(c => c.toJSON())]
        )
      )
    };
  }

  static fromJSON(data) {
    const game = Object.create(GameState.prototype);

    // Handle version migrations
    if (data.version !== 1) {
      throw new Error('Unsupported save version');
    }

    game.numPlayers = data.numPlayers;
    // Handle game variants - default to special effects and reward accumulation enabled for new games
    // Old saves will preserve their settings via the spread operator
    game.gameVariants = {
      specialEffects: true,
      medalsCount: false,
      accumulateUnclaimedJobs: true,
      allowSwap: false,
      ...(data.gameVariants || {})
    };
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
      Object.entries(data.revealedJobs).map(([suit, cardOrArray]) => {
        // Handle both single cards and arrays of cards
        if (Array.isArray(cardOrArray)) {
          return [suit, cardOrArray.map(Card.fromJSON)];
        } else {
          return [suit, Card.fromJSON(cardOrArray)];
        }
      })
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
    // exiled should be an object mapping year to arrays, not a Set
    game.exiled = data.exiled || {};
    // Handle backward compatibility: if exiled is an array (old format), convert to object
    if (Array.isArray(data.exiled)) {
      game.exiled = {};
    }
    game.requisitionLog = {};
    game.currentSwapPlayer = data.currentSwapPlayer || null;
    
    // Initialize accumulated job cards (for variant)
    game.accumulatedJobCards = {};
    if (data.accumulatedJobCards) {
      for (const [suit, cards] of Object.entries(data.accumulatedJobCards)) {
        game.accumulatedJobCards[suit] = cards.map(Card.fromJSON);
      }
    }
    // Ensure all suits have arrays (for backward compatibility with old saves)
    for (const suit of SUITS) {
      if (!(suit in game.accumulatedJobCards)) {
        game.accumulatedJobCards[suit] = [];
      }
    }

    return game;
  }
}
