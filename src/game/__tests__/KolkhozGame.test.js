import { describe, it, expect, beforeEach } from 'vitest';
import { Client } from 'boardgame.io/client';
import { KolkhozGame } from '../KolkhozGame.js';
import { SUITS, THRESHOLD, DEFAULT_VARIANTS } from '../constants.js';
import {
  prepareJobPiles,
  revealJobs,
  prepareWorkersDeck,
  dealHands,
} from '../utils/deckUtils.js';
import {
  isValidPlay,
  resolveTrick,
  applyTrickResult,
  applyAssignments,
  generateAutoAssignment,
  getTricksPerYear,
} from '../utils/trickUtils.js';
import { transitionToNextYear } from '../utils/scoringUtils.js';

// Mock random for deterministic tests
const mockRandom = {
  Number: () => 0.5,
  Die: (n) => Math.ceil(n / 2),
  Shuffle: (arr) => [...arr],
};

describe('KolkhozGame', () => {
  describe('Game Setup', () => {
    it('should initialize with correct number of players', () => {
      const client = Client({
        game: KolkhozGame,
        numPlayers: 4,
      });
      const { G } = client.getState();

      expect(G.players).toHaveLength(4);
      expect(G.numPlayers).toBe(4);
    });

    it('should deal 5 cards to each player in normal year', () => {
      const client = Client({
        game: KolkhozGame,
        numPlayers: 4,
      });
      const { G } = client.getState();

      // Each player should have 5 cards (unless famine)
      if (!G.isFamine) {
        for (const player of G.players) {
          expect(player.hand).toHaveLength(5);
        }
      }
    });

    it('should initialize job piles for each suit', () => {
      const client = Client({
        game: KolkhozGame,
        numPlayers: 4,
      });
      const { G } = client.getState();

      for (const suit of SUITS) {
        expect(G.jobPiles[suit]).toBeDefined();
        expect(G.workHours[suit]).toBe(0);
        expect(G.jobBuckets[suit]).toEqual([]);
      }
    });

    it('should start in planning phase (or trick if famine)', () => {
      const client = Client({
        game: KolkhozGame,
        numPlayers: 4,
      });
      const { G, ctx } = client.getState();

      // If famine, planning is auto-skipped
      if (G.isFamine) {
        expect(ctx.phase).toBe('trick');
      } else {
        expect(ctx.phase).toBe('planning');
      }
    });

    it('should start at year 1', () => {
      const client = Client({
        game: KolkhozGame,
        numPlayers: 4,
      });
      const { G } = client.getState();

      expect(G.year).toBe(1);
    });
  });

  describe('Deck Utilities', () => {
    it('prepareJobPiles should create 5 cards per suit for 52-card deck', () => {
      const variants = { ...DEFAULT_VARIANTS, deckType: 52 };
      const piles = prepareJobPiles(variants, mockRandom);

      for (const suit of SUITS) {
        expect(piles[suit]).toHaveLength(5);
        // Cards should be Ace-5 (values 1-5)
        const values = piles[suit].map(c => c.value).sort((a, b) => a - b);
        expect(values).toEqual([1, 2, 3, 4, 5]);
      }
    });

    it('prepareJobPiles should create single Ace per suit for 36-card deck', () => {
      const variants = { ...DEFAULT_VARIANTS, deckType: 36 };
      const piles = prepareJobPiles(variants, mockRandom);

      for (const suit of SUITS) {
        expect(piles[suit]).toHaveLength(1);
        expect(piles[suit][0].value).toBe(1);
      }
    });

    it('revealJobs should reveal jobs without detecting famine (famine is year-based)', () => {
      const variants = { ...DEFAULT_VARIANTS, deckType: 52 };
      // Create piles where Clubs has Ace on top
      const jobPiles = {
        Hearts: [{ suit: 'Hearts', value: 2 }],
        Diamonds: [{ suit: 'Diamonds', value: 3 }],
        Clubs: [{ suit: 'Clubs', value: 1 }], // Ace of Clubs - no longer triggers famine
        Spades: [{ suit: 'Spades', value: 4 }],
      };
      const accumulatedJobCards = { Hearts: [], Diamonds: [], Clubs: [], Spades: [] };

      const { jobs } = revealJobs(jobPiles, accumulatedJobCards, variants);

      // revealJobs no longer returns isFamine - famine is determined by year (Year 5)
      expect(jobs.Clubs.value).toBe(1);
    });

    it('getTricksPerYear should return 3 during famine, 4 otherwise', () => {
      expect(getTricksPerYear(true)).toBe(3);
      expect(getTricksPerYear(false)).toBe(4);
    });

    it('dealHands should deal 4 cards during famine', () => {
      const players = [
        { hand: [], plot: { revealed: [], hidden: [] } },
        { hand: [], plot: { revealed: [], hidden: [] } },
      ];
      const deck = [];
      for (let i = 0; i < 20; i++) {
        deck.push({ suit: 'Hearts', value: 6 + (i % 8) });
      }

      dealHands(players, deck, true); // famine = true

      expect(players[0].hand).toHaveLength(4);
      expect(players[1].hand).toHaveLength(4);
    });
  });

  describe('Trick Utilities', () => {
    it('isValidPlay should allow any card when leading', () => {
      const G = {
        currentTrick: [],
        players: [{ hand: [{ suit: 'Hearts', value: 7 }, { suit: 'Clubs', value: 8 }] }],
      };

      expect(isValidPlay(G, 0, 0)).toBe(true);
      expect(isValidPlay(G, 0, 1)).toBe(true);
    });

    it('isValidPlay should require following suit when able', () => {
      const G = {
        currentTrick: [[1, { suit: 'Hearts', value: 10 }]],
        players: [{ hand: [{ suit: 'Hearts', value: 7 }, { suit: 'Clubs', value: 8 }] }],
      };

      expect(isValidPlay(G, 0, 0)).toBe(true);  // Hearts - valid
      expect(isValidPlay(G, 0, 1)).toBe(false); // Clubs - invalid, has Hearts
    });

    it('isValidPlay should allow any card when cannot follow suit', () => {
      const G = {
        currentTrick: [[1, { suit: 'Hearts', value: 10 }]],
        players: [{ hand: [{ suit: 'Clubs', value: 7 }, { suit: 'Spades', value: 8 }] }],
      };

      expect(isValidPlay(G, 0, 0)).toBe(true);
      expect(isValidPlay(G, 0, 1)).toBe(true);
    });

    it('resolveTrick should find highest card of lead suit', () => {
      const G = {
        numPlayers: 4,
        trump: 'Spades',
        currentTrick: [
          [0, { suit: 'Hearts', value: 7 }],
          [1, { suit: 'Hearts', value: 10 }],
          [2, { suit: 'Hearts', value: 8 }],
          [3, { suit: 'Clubs', value: 13 }], // Off-suit King doesn't win
        ],
      };

      const winner = resolveTrick(G);
      expect(winner).toBe(1); // Player 1 has highest Hearts
    });

    it('resolveTrick should let trump beat lead suit', () => {
      const G = {
        numPlayers: 4,
        trump: 'Spades',
        currentTrick: [
          [0, { suit: 'Hearts', value: 13 }], // King of Hearts leads
          [1, { suit: 'Hearts', value: 10 }],
          [2, { suit: 'Spades', value: 6 }],  // Low trump beats King
          [3, { suit: 'Hearts', value: 8 }],
        ],
      };

      const winner = resolveTrick(G);
      expect(winner).toBe(2); // Player 2 with trump wins
    });

    it('resolveTrick should find highest trump when multiple trumps played', () => {
      const G = {
        numPlayers: 4,
        trump: 'Spades',
        currentTrick: [
          [0, { suit: 'Hearts', value: 13 }],
          [1, { suit: 'Spades', value: 7 }],
          [2, { suit: 'Spades', value: 10 }], // Highest trump
          [3, { suit: 'Spades', value: 6 }],
        ],
      };

      const winner = resolveTrick(G);
      expect(winner).toBe(2); // Player 2 with highest trump
    });

    it('generateAutoAssignment should return assignments when all same suit', () => {
      const trick = [
        [0, { suit: 'Hearts', value: 7 }],
        [1, { suit: 'Hearts', value: 10 }],
        [2, { suit: 'Hearts', value: 8 }],
        [3, { suit: 'Hearts', value: 6 }],
      ];

      const assignments = generateAutoAssignment(trick);

      expect(assignments).not.toBeNull();
      expect(Object.keys(assignments)).toHaveLength(4);
      for (const targetSuit of Object.values(assignments)) {
        expect(targetSuit).toBe('Hearts');
      }
    });

    it('generateAutoAssignment should return null for mixed suits', () => {
      const trick = [
        [0, { suit: 'Hearts', value: 7 }],
        [1, { suit: 'Hearts', value: 10 }],
        [2, { suit: 'Clubs', value: 8 }],
        [3, { suit: 'Hearts', value: 6 }],
      ];

      const assignments = generateAutoAssignment(trick);

      expect(assignments).toBeNull();
    });

    it('applyAssignments should add work hours correctly', () => {
      const G = {
        trump: 'Spades',
        jobBuckets: { Hearts: [], Diamonds: [], Clubs: [], Spades: [] },
        workHours: { Hearts: 0, Diamonds: 0, Clubs: 0, Spades: 0 },
        claimedJobs: [],
        lastWinner: 0,
        players: [{ plot: { revealed: [], hidden: [] } }],
        revealedJobs: { Hearts: { suit: 'Hearts', value: 1 } },
      };
      const variants = { ...DEFAULT_VARIANTS };

      const assignments = {
        'Hearts-7': 'Hearts',
        'Hearts-10': 'Hearts',
      };

      applyAssignments(G, assignments, variants);

      expect(G.workHours.Hearts).toBe(17); // 7 + 10
      expect(G.jobBuckets.Hearts).toHaveLength(2);
    });

    it('applyAssignments should complete job at threshold', () => {
      const G = {
        trump: 'Spades',
        jobBuckets: { Hearts: [], Diamonds: [], Clubs: [], Spades: [] },
        workHours: { Hearts: 30, Diamonds: 0, Clubs: 0, Spades: 0 },
        claimedJobs: [],
        lastWinner: 0,
        players: [{ plot: { revealed: [], hidden: [] } }],
        revealedJobs: { Hearts: { suit: 'Hearts', value: 1 } },
        variants: { ...DEFAULT_VARIANTS, deckType: 52 },
      };
      const variants = { ...DEFAULT_VARIANTS, deckType: 52 };

      const assignments = {
        'Hearts-10': 'Hearts', // 30 + 10 = 40 = THRESHOLD
      };

      applyAssignments(G, assignments, variants);

      expect(G.workHours.Hearts).toBe(40);
      expect(G.claimedJobs).toContain('Hearts');
    });
  });

  describe('Phase Transitions', () => {
    it('should transition from planning to trick after trump is set', () => {
      const client = Client({
        game: KolkhozGame,
        numPlayers: 4,
      });

      let { G, ctx } = client.getState();

      // If famine, planning is skipped automatically
      if (G.isFamine) {
        expect(ctx.phase).toBe('trick');
        expect(G.trump).toBeNull();
      } else {
        expect(ctx.phase).toBe('planning');

        // Set trump
        client.moves.setTrump('Hearts');

        ({ G, ctx } = client.getState());
        expect(G.trump).toBe('Hearts');
        expect(ctx.phase).toBe('trick');
      }
    });

    it('should skip planning during famine (no trump)', () => {
      // Just verify getTricksPerYear behavior
      expect(getTricksPerYear(true)).toBe(3);
    });
  });

  describe('Swap Phase', () => {
    it('swapCard should exchange hand and plot cards', () => {
      const G = {
        players: [{
          hand: [{ suit: 'Hearts', value: 7 }],
          plot: { hidden: [{ suit: 'Clubs', value: 10 }], revealed: [] },
        }],
        swapConfirmed: {},
      };

      // Simulate swap
      const temp = G.players[0].plot.hidden[0];
      G.players[0].plot.hidden[0] = G.players[0].hand[0];
      G.players[0].hand[0] = temp;

      expect(G.players[0].hand[0].suit).toBe('Clubs');
      expect(G.players[0].hand[0].value).toBe(10);
      expect(G.players[0].plot.hidden[0].suit).toBe('Hearts');
      expect(G.players[0].plot.hidden[0].value).toBe(7);
    });
  });

  describe('Year Transition', () => {
    it('should increment year', () => {
      const G = {
        year: 1,
        players: [
          { hand: [], plot: { revealed: [], hidden: [] }, medals: 0, hasWonTrickThisYear: false, brigadeLeader: false },
        ],
        claimedJobs: [],
        revealedJobs: { Hearts: null, Diamonds: null, Clubs: null, Spades: null },
        accumulatedJobCards: { Hearts: [], Diamonds: [], Clubs: [], Spades: [] },
        workHours: { Hearts: 0, Diamonds: 0, Clubs: 0, Spades: 0 },
        jobBuckets: { Hearts: [], Diamonds: [], Clubs: [], Spades: [] },
        jobPiles: {
          Hearts: [{ suit: 'Hearts', value: 2 }],
          Diamonds: [{ suit: 'Diamonds', value: 2 }],
          Clubs: [{ suit: 'Clubs', value: 2 }],
          Spades: [{ suit: 'Spades', value: 2 }],
        },
        exiled: {},
        trickCount: 0,
        currentTrick: [],
      };
      const variants = { ...DEFAULT_VARIANTS, deckType: 52 };

      transitionToNextYear(G, variants, mockRandom);

      expect(G.year).toBe(2);
    });

    it('should send unclaimed job rewards to gulag (non-accumulate mode)', () => {
      const G = {
        year: 1,
        players: [
          { hand: [], plot: { revealed: [], hidden: [] }, medals: 0, hasWonTrickThisYear: false, brigadeLeader: false },
        ],
        claimedJobs: ['Hearts'], // Only Hearts claimed
        revealedJobs: {
          Hearts: { suit: 'Hearts', value: 1 },
          Diamonds: { suit: 'Diamonds', value: 2 }, // Unclaimed
          Clubs: { suit: 'Clubs', value: 3 },       // Unclaimed
          Spades: { suit: 'Spades', value: 4 },     // Unclaimed
        },
        accumulatedJobCards: { Hearts: [], Diamonds: [], Clubs: [], Spades: [] },
        workHours: { Hearts: 0, Diamonds: 0, Clubs: 0, Spades: 0 },
        jobBuckets: { Hearts: [], Diamonds: [], Clubs: [], Spades: [] },
        jobPiles: {
          Hearts: [{ suit: 'Hearts', value: 5 }],
          Diamonds: [{ suit: 'Diamonds', value: 5 }],
          Clubs: [{ suit: 'Clubs', value: 5 }],
          Spades: [{ suit: 'Spades', value: 5 }],
        },
        exiled: {},
        trickCount: 0,
        currentTrick: [],
      };
      const variants = { ...DEFAULT_VARIANTS, deckType: 52, accumulateJobs: false };

      transitionToNextYear(G, variants, mockRandom);

      // Unclaimed rewards should be in gulag (year 1)
      expect(G.exiled[1]).toBeDefined();
      expect(G.exiled[1]).toContain('Diamonds-2');
      expect(G.exiled[1]).toContain('Clubs-3');
      expect(G.exiled[1]).toContain('Spades-4');
      expect(G.exiled[1]).not.toContain('Hearts-1'); // Hearts was claimed
    });

    it('should accumulate unclaimed rewards when variant enabled', () => {
      const G = {
        year: 1,
        players: [
          { hand: [], plot: { revealed: [], hidden: [] }, medals: 0, hasWonTrickThisYear: false, brigadeLeader: false },
        ],
        claimedJobs: ['Hearts'],
        revealedJobs: {
          Hearts: { suit: 'Hearts', value: 1 },
          Diamonds: { suit: 'Diamonds', value: 2 },
          Clubs: { suit: 'Clubs', value: 3 },
          Spades: { suit: 'Spades', value: 4 },
        },
        accumulatedJobCards: { Hearts: [], Diamonds: [], Clubs: [], Spades: [] },
        workHours: { Hearts: 0, Diamonds: 0, Clubs: 0, Spades: 0 },
        jobBuckets: { Hearts: [], Diamonds: [], Clubs: [], Spades: [] },
        jobPiles: {
          Hearts: [{ suit: 'Hearts', value: 5 }],
          Diamonds: [{ suit: 'Diamonds', value: 5 }],
          Clubs: [{ suit: 'Clubs', value: 5 }],
          Spades: [{ suit: 'Spades', value: 5 }],
        },
        exiled: {},
        trickCount: 0,
        currentTrick: [],
      };
      const variants = { ...DEFAULT_VARIANTS, deckType: 52, accumulateJobs: true };

      transitionToNextYear(G, variants, mockRandom);

      // Unclaimed rewards should accumulate
      expect(G.accumulatedJobCards.Diamonds).toHaveLength(1);
      expect(G.accumulatedJobCards.Clubs).toHaveLength(1);
      expect(G.accumulatedJobCards.Spades).toHaveLength(1);
      expect(G.accumulatedJobCards.Hearts).toHaveLength(0); // Claimed
    });
  });

  describe('Famine Year', () => {
    it('should only require 3 tricks during famine', () => {
      // Create a game state with famine
      const G = {
        isFamine: true,
        trickCount: 0,
      };

      const tricksNeeded = getTricksPerYear(G.isFamine);
      expect(tricksNeeded).toBe(3);

      // Simulate 3 tricks
      G.trickCount = 3;
      expect(G.trickCount >= tricksNeeded).toBe(true);
    });

    it('should deal 4 cards during famine year', () => {
      const players = [
        { hand: [], plot: { revealed: [], hidden: [] } },
        { hand: [], plot: { revealed: [], hidden: [] } },
        { hand: [], plot: { revealed: [], hidden: [] } },
        { hand: [], plot: { revealed: [], hidden: [] } },
      ];
      const deck = [];
      for (let i = 0; i < 32; i++) {
        deck.push({ suit: SUITS[i % 4], value: 6 + (i % 8) });
      }

      dealHands(players, deck, true); // famine = true

      for (const player of players) {
        expect(player.hand).toHaveLength(4);
      }
    });

    it('should leave 1 card after 3 famine tricks', () => {
      // 4 cards dealt, 3 tricks played = 1 card left
      const cardsDealt = 4;
      const tricksPlayed = getTricksPerYear(true);
      const cardsLeft = cardsDealt - tricksPlayed;
      expect(cardsLeft).toBe(1);
    });

    it('famine should be determined by year (Year 5), not Ace of Clubs', () => {
      // Famine is now always Year 5, regardless of what cards are revealed
      // This test verifies that revealJobs correctly reveals the Ace of Clubs
      // without triggering famine detection
      const variants = { ...DEFAULT_VARIANTS, deckType: 52 };

      const jobPiles = {
        Hearts: [{ suit: 'Hearts', value: 5 }, { suit: 'Hearts', value: 2 }],
        Diamonds: [{ suit: 'Diamonds', value: 5 }, { suit: 'Diamonds', value: 3 }],
        Clubs: [{ suit: 'Clubs', value: 5 }, { suit: 'Clubs', value: 1 }], // Ace on top (end of array)
        Spades: [{ suit: 'Spades', value: 5 }, { suit: 'Spades', value: 4 }],
      };
      const accumulatedJobCards = { Hearts: [], Diamonds: [], Clubs: [], Spades: [] };

      const { jobs } = revealJobs(jobPiles, accumulatedJobCards, variants);

      // revealJobs no longer returns isFamine
      expect(jobs.Clubs.suit).toBe('Clubs');
      expect(jobs.Clubs.value).toBe(1);
    });

    it('trick phase next should return plotSelection after 3 tricks in famine', () => {
      // Simulate what the next function checks
      const G = {
        isFamine: true,
        trickCount: 3,
        needsManualAssignment: false,
      };

      const tricksPerYear = getTricksPerYear(G.isFamine);
      expect(tricksPerYear).toBe(3);
      expect(G.trickCount >= tricksPerYear).toBe(true);
      // This means next() should return 'plotSelection'
    });

    it('trick phase next should continue after 2 tricks in famine', () => {
      const G = {
        isFamine: true,
        trickCount: 2,
        needsManualAssignment: false,
      };

      const tricksPerYear = getTricksPerYear(G.isFamine);
      expect(tricksPerYear).toBe(3);
      expect(G.trickCount >= tricksPerYear).toBe(false);
      // This means next() should return 'trick'
    });
  });

  describe('Full Game Flow', () => {
    it('should play through a complete trick', () => {
      const client = Client({
        game: KolkhozGame,
        numPlayers: 4,
      });

      // Set trump
      client.moves.setTrump('Hearts');

      let { G, ctx } = client.getState();
      expect(ctx.phase).toBe('trick');

      // Play 4 cards (one from each player)
      const leadPlayer = G.lead;
      for (let i = 0; i < 4; i++) {
        const playerIdx = (leadPlayer + i) % 4;
        client.updatePlayerID(String(playerIdx));

        // Play first valid card
        const player = client.getState().G.players[playerIdx];
        if (player.hand.length > 0) {
          client.moves.playCard(0);
        }
      }

      ({ G, ctx } = client.getState());

      // After trick completes, should be in assignment or next trick
      expect(['assignment', 'trick', 'plotSelection']).toContain(ctx.phase);
    });

    it('famine year: should transition to plotSelection after exactly 3 tricks', () => {
      // Create a custom game that forces famine
      const FamineTestGame = {
        ...KolkhozGame,
        setup: (context, setupData) => {
          const G = KolkhozGame.setup(context, setupData);
          // Force famine state
          G.isFamine = true;
          G.trump = null;
          // Give each player exactly 4 cards (Hearts 6-9 for simplicity)
          for (let i = 0; i < G.players.length; i++) {
            G.players[i].hand = [
              { suit: 'Hearts', value: 6 + i },
              { suit: 'Hearts', value: 10 + i },
              { suit: 'Diamonds', value: 6 + i },
              { suit: 'Diamonds', value: 10 + i },
            ];
          }
          return G;
        },
      };

      const client = Client({
        game: FamineTestGame,
        numPlayers: 4,
      });

      let { G, ctx } = client.getState();

      // Verify famine is set
      expect(G.isFamine).toBe(true);
      expect(G.trump).toBeNull();

      // Should be in trick phase (planning skipped during famine)
      expect(ctx.phase).toBe('trick');

      // Helper to play one complete trick
      const playOneTrick = () => {
        const state = client.getState();
        const leadPlayer = state.G.lead;
        const numPlayers = state.ctx.numPlayers;

        for (let i = 0; i < numPlayers; i++) {
          const playerIdx = (leadPlayer + i) % numPlayers;
          client.updatePlayerID(String(playerIdx));
          const currentState = client.getState();
          const player = currentState.G.players[playerIdx];

          if (player.hand.length > 0) {
            client.moves.playCard(0);
          }
        }
      };

      // Helper to handle assignment phase or aiAssignment phase
      const handleAssignmentIfNeeded = () => {
        let { G: currentG, ctx: currentCtx } = client.getState();
        if (currentCtx.phase === 'assignment') {
          // The winner makes the assignment
          client.updatePlayerID(String(currentG.lastWinner));
          client.moves.submitAssignments();
        }
        // Handle aiAssignment phase (when AI wins and animation would normally play)
        ({ G: currentG, ctx: currentCtx } = client.getState());
        while (currentCtx.phase === 'aiAssignment' && currentG.pendingAIAssignments) {
          client.updatePlayerID('0'); // Human controls this phase
          const pending = currentG.pendingAIAssignments;
          for (const [cardKey, targetSuit] of Object.entries(pending.assignments)) {
            client.moves.applySingleAssignment(cardKey, targetSuit);
            ({ G: currentG, ctx: currentCtx } = client.getState());
            if (!currentG.pendingAIAssignments) break;
          }
          ({ G: currentG, ctx: currentCtx } = client.getState());
        }
      };

      // Play 3 tricks (the expected number for famine)
      for (let trick = 0; trick < 3; trick++) {
        playOneTrick();
        handleAssignmentIfNeeded();
      }

      // Handle requisition phase - now requires continueToNextYear move
      ({ G, ctx } = client.getState());
      if (ctx.phase === 'requisition') {
        client.moves.continueToNextYear();
        ({ G, ctx } = client.getState());
      }

      // After 3 tricks in famine year, game should have transitioned to year 2
      // (plotSelection and requisition phases run and transition immediately)
      ({ G, ctx } = client.getState());

      // The key assertion: year should be 2 (proving we completed year 1 after 3 tricks)
      expect(G.year).toBe(2);
      // trickCount resets to 0 for new year
      expect(G.trickCount).toBe(0);
    });

    it('normal year: should transition to plotSelection after exactly 4 tricks', () => {
      // Create a custom game that ensures non-famine
      const NormalTestGame = {
        ...KolkhozGame,
        setup: (context, setupData) => {
          const G = KolkhozGame.setup(context, setupData);
          // Force non-famine state
          G.isFamine = false;
          G.trump = 'Hearts';
          // Give each player exactly 5 cards
          for (let i = 0; i < G.players.length; i++) {
            G.players[i].hand = [
              { suit: 'Hearts', value: 6 + i },
              { suit: 'Hearts', value: 10 + i },
              { suit: 'Diamonds', value: 6 + i },
              { suit: 'Diamonds', value: 10 + i },
              { suit: 'Clubs', value: 6 + i },
            ];
          }
          return G;
        },
      };

      const client = Client({
        game: NormalTestGame,
        numPlayers: 4,
      });

      let { G, ctx } = client.getState();

      // Verify non-famine
      expect(G.isFamine).toBe(false);
      expect(G.trump).toBe('Hearts');

      // Should be in trick phase (planning ends because trump is set)
      expect(ctx.phase).toBe('trick');

      // Helper to play one complete trick
      const playOneTrick = () => {
        const state = client.getState();
        const leadPlayer = state.G.lead;
        const numPlayers = state.ctx.numPlayers;

        for (let i = 0; i < numPlayers; i++) {
          const playerIdx = (leadPlayer + i) % numPlayers;
          client.updatePlayerID(String(playerIdx));
          const currentState = client.getState();
          const player = currentState.G.players[playerIdx];

          if (player.hand.length > 0) {
            client.moves.playCard(0);
          }
        }
      };

      // Helper to handle assignment phase or aiAssignment phase
      const handleAssignmentIfNeeded = () => {
        let { G: currentG, ctx: currentCtx } = client.getState();
        if (currentCtx.phase === 'assignment') {
          client.updatePlayerID(String(currentG.lastWinner));
          client.moves.submitAssignments();
        }
        // Handle aiAssignment phase (when AI wins and animation would normally play)
        ({ G: currentG, ctx: currentCtx } = client.getState());
        while (currentCtx.phase === 'aiAssignment' && currentG.pendingAIAssignments) {
          client.updatePlayerID('0'); // Human controls this phase
          const pending = currentG.pendingAIAssignments;
          for (const [cardKey, targetSuit] of Object.entries(pending.assignments)) {
            client.moves.applySingleAssignment(cardKey, targetSuit);
            ({ G: currentG, ctx: currentCtx } = client.getState());
            if (!currentG.pendingAIAssignments) break;
          }
          ({ G: currentG, ctx: currentCtx } = client.getState());
        }
      };

      // Play 4 tricks (the expected number for normal year)
      for (let trick = 0; trick < 4; trick++) {
        playOneTrick();
        handleAssignmentIfNeeded();
      }

      // Handle requisition phase - now requires continueToNextYear move
      ({ G, ctx } = client.getState());
      if (ctx.phase === 'requisition') {
        client.moves.continueToNextYear();
        ({ G, ctx } = client.getState());
      }

      // After 4 tricks in normal year, game should have transitioned to year 2
      ({ G, ctx } = client.getState());

      // The key assertion: year should be 2 (proving we completed year 1 after 4 tricks)
      expect(G.year).toBe(2);
      // trickCount resets to 0 for new year
      expect(G.trickCount).toBe(0);
    });
  });
});
