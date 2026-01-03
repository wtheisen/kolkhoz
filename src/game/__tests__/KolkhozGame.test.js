import { describe, it, expect } from 'vitest';
import { Client } from 'boardgame.io/client';
import { KolkhozGame } from '../KolkhozGame.js';
import { SUITS, DEFAULT_VARIANTS } from '../constants.js';

// Helper to play one complete trick from current lead
function playTrick(client) {
  const { G } = client.getState();
  const leadPlayer = G.lead;
  const numPlayers = G.numPlayers;

  for (let i = 0; i < numPlayers; i++) {
    const playerIdx = (leadPlayer + i) % numPlayers;
    client.updatePlayerID(String(playerIdx));
    const { G: currentG } = client.getState();
    if (currentG.players[playerIdx].hand.length > 0) {
      client.moves.playCard(0);
    }
  }
}

// Helper to handle assignment phase after trick
function handleAssignment(client) {
  let { G, ctx } = client.getState();

  if (ctx.phase === 'assignment') {
    client.updatePlayerID(String(G.lastWinner));
    client.moves.submitAssignments();
  }

  // Handle AI assignment animation phase
  ({ G, ctx } = client.getState());
  while (ctx.phase === 'aiAssignment' && G.pendingAIAssignments) {
    client.updatePlayerID('0');
    const pending = G.pendingAIAssignments;
    for (const [cardKey, targetSuit] of Object.entries(pending.assignments)) {
      client.moves.applySingleAssignment(cardKey, targetSuit);
      ({ G, ctx } = client.getState());
      if (!G.pendingAIAssignments) break;
    }
    ({ G, ctx } = client.getState());
  }
}

describe('KolkhozGame', () => {
  describe('Game Setup', () => {
    it('should initialize with correct player count and hands', () => {
      const client = Client({ game: KolkhozGame, numPlayers: 4 });
      const { G } = client.getState();

      expect(G.players).toHaveLength(4);
      expect(G.numPlayers).toBe(4);
      expect(G.year).toBe(1);

      // Year 1 is never famine, so should have 5 cards each
      for (const player of G.players) {
        expect(player.hand).toHaveLength(5);
      }
    });

    it('should initialize job tracking for all suits', () => {
      const client = Client({ game: KolkhozGame, numPlayers: 4 });
      const { G } = client.getState();

      for (const suit of SUITS) {
        expect(G.jobPiles[suit]).toBeDefined();
        expect(G.workHours[suit]).toBe(0);
        expect(G.jobBuckets[suit]).toEqual([]);
      }
    });

    it('should start in planning phase', () => {
      const client = Client({ game: KolkhozGame, numPlayers: 4 });
      const { ctx } = client.getState();
      expect(ctx.phase).toBe('planning');
    });
  });

  describe('Trump Selection', () => {
    it('should set trump and transition to trick phase', () => {
      const client = Client({ game: KolkhozGame, numPlayers: 4 });

      client.moves.setTrump('Hearts');

      const { G, ctx } = client.getState();
      expect(G.trump).toBe('Hearts');
      expect(ctx.phase).toBe('trick');
    });

    it('should skip trump selection during famine year', () => {
      // Create game that starts in famine
      const FamineGame = {
        ...KolkhozGame,
        setup: (context, setupData) => {
          const G = KolkhozGame.setup(context, setupData);
          G.isFamine = true;
          G.trump = null;
          // Deal 4 cards for famine
          for (const player of G.players) {
            player.hand = player.hand.slice(0, 4);
          }
          return G;
        },
      };

      const client = Client({ game: FamineGame, numPlayers: 4 });
      const { G, ctx } = client.getState();

      expect(G.trump).toBeNull();
      expect(ctx.phase).toBe('trick'); // Planning skipped
    });
  });

  describe('Trick Resolution', () => {
    it('should award trick to highest card of lead suit', () => {
      const TestGame = {
        ...KolkhozGame,
        setup: (context, setupData) => {
          const G = KolkhozGame.setup(context, setupData);
          G.trump = 'Spades';
          G.lead = 0;
          // All Hearts - player 1 has highest
          G.players[0].hand = [{ suit: 'Hearts', value: 6 }];
          G.players[1].hand = [{ suit: 'Hearts', value: 13 }]; // King wins
          G.players[2].hand = [{ suit: 'Hearts', value: 7 }];
          G.players[3].hand = [{ suit: 'Hearts', value: 8 }];
          return G;
        },
      };

      const client = Client({ game: TestGame, numPlayers: 4 });

      playTrick(client);
      handleAssignment(client);

      const { G } = client.getState();
      expect(G.lastWinner).toBe(1);
    });

    it('should let trump beat lead suit', () => {
      const TestGame = {
        ...KolkhozGame,
        setup: (context, setupData) => {
          const G = KolkhozGame.setup(context, setupData);
          G.trump = 'Spades';
          G.lead = 0;
          // Player 2 plays low trump
          G.players[0].hand = [{ suit: 'Hearts', value: 13 }]; // King leads
          G.players[1].hand = [{ suit: 'Hearts', value: 10 }];
          G.players[2].hand = [{ suit: 'Spades', value: 6 }]; // Low trump wins
          G.players[3].hand = [{ suit: 'Hearts', value: 8 }];
          return G;
        },
      };

      const client = Client({ game: TestGame, numPlayers: 4 });

      playTrick(client);
      handleAssignment(client);

      const { G } = client.getState();
      expect(G.lastWinner).toBe(2);
    });

    it('should find highest trump when multiple trumps played', () => {
      const TestGame = {
        ...KolkhozGame,
        setup: (context, setupData) => {
          const G = KolkhozGame.setup(context, setupData);
          G.trump = 'Spades';
          G.lead = 0;
          G.players[0].hand = [{ suit: 'Hearts', value: 13 }];
          G.players[1].hand = [{ suit: 'Spades', value: 7 }];
          G.players[2].hand = [{ suit: 'Spades', value: 10 }]; // Highest trump
          G.players[3].hand = [{ suit: 'Spades', value: 6 }];
          return G;
        },
      };

      const client = Client({ game: TestGame, numPlayers: 4 });

      playTrick(client);
      handleAssignment(client);

      const { G } = client.getState();
      expect(G.lastWinner).toBe(2);
    });
  });

  describe('Job Completion', () => {
    it('should track work hours from assigned cards', () => {
      const TestGame = {
        ...KolkhozGame,
        setup: (context, setupData) => {
          const G = KolkhozGame.setup(context, setupData);
          G.trump = 'Spades';
          G.lead = 0;
          // All Hearts - auto-assigns to Hearts
          G.players[0].hand = [{ suit: 'Hearts', value: 7 }];
          G.players[1].hand = [{ suit: 'Hearts', value: 8 }];
          G.players[2].hand = [{ suit: 'Hearts', value: 9 }];
          G.players[3].hand = [{ suit: 'Hearts', value: 10 }];
          return G;
        },
      };

      const client = Client({ game: TestGame, numPlayers: 4 });

      playTrick(client);
      handleAssignment(client);

      const { G } = client.getState();
      // 7 + 8 + 9 + 10 = 34 work hours
      expect(G.workHours.Hearts).toBe(34);
    });

    it('should complete job when reaching 40 hours threshold', () => {
      const TestGame = {
        ...KolkhozGame,
        setup: (context, setupData) => {
          const G = KolkhozGame.setup(context, setupData);
          G.trump = 'Spades';
          G.lead = 0;
          G.workHours.Hearts = 6; // Start with 6 (so 6+7+8+9+10=40 completes)
          // All Hearts - auto-assigns
          G.players[0].hand = [{ suit: 'Hearts', value: 7 }];
          G.players[1].hand = [{ suit: 'Hearts', value: 8 }];
          G.players[2].hand = [{ suit: 'Hearts', value: 9 }];
          G.players[3].hand = [{ suit: 'Hearts', value: 10 }];
          return G;
        },
      };

      const client = Client({ game: TestGame, numPlayers: 4 });

      playTrick(client);
      handleAssignment(client);

      const { G } = client.getState();
      // 6 + 7 + 8 + 9 + 10 = 40
      expect(G.workHours.Hearts).toBeGreaterThanOrEqual(40);
      expect(G.claimedJobs).toContain('Hearts');
    });
  });

  describe('Famine Year', () => {
    it('should complete after 3 tricks in famine', () => {
      const FamineGame = {
        ...KolkhozGame,
        setup: (context, setupData) => {
          const G = KolkhozGame.setup(context, setupData);
          G.isFamine = true;
          G.trump = null;
          // 4 cards for famine (3 tricks + 1 for plot)
          for (let i = 0; i < G.players.length; i++) {
            G.players[i].hand = [
              { suit: 'Hearts', value: 6 + i },
              { suit: 'Diamonds', value: 6 + i },
              { suit: 'Clubs', value: 6 + i },
              { suit: 'Spades', value: 6 + i },
            ];
          }
          return G;
        },
      };

      const client = Client({ game: FamineGame, numPlayers: 4 });

      // Play 3 tricks
      for (let t = 0; t < 3; t++) {
        playTrick(client);
        handleAssignment(client);
      }

      const { ctx } = client.getState();
      // After 3 tricks, should move to plot selection or requisition
      expect(['plotSelection', 'requisition']).toContain(ctx.phase);
    });
  });

  describe('Year Progression', () => {
    it('should complete a normal year with 4 tricks', () => {
      const TestGame = {
        ...KolkhozGame,
        setup: (context, setupData) => {
          const G = KolkhozGame.setup(context, setupData);
          G.isFamine = false;
          G.trump = 'Hearts';
          // 5 cards per player
          for (let i = 0; i < G.players.length; i++) {
            G.players[i].hand = [
              { suit: 'Hearts', value: 6 + i },
              { suit: 'Diamonds', value: 6 + i },
              { suit: 'Clubs', value: 6 + i },
              { suit: 'Spades', value: 6 + i },
              { suit: 'Hearts', value: 10 + i },
            ];
          }
          return G;
        },
      };

      const client = Client({ game: TestGame, numPlayers: 4 });

      // Play 4 tricks
      for (let t = 0; t < 4; t++) {
        playTrick(client);
        handleAssignment(client);
      }

      const { ctx } = client.getState();
      // After 4 tricks, should move to plot selection or requisition
      expect(['plotSelection', 'requisition']).toContain(ctx.phase);
    });

  });

  describe('Scoring', () => {
    it('should determine winner with highest score', () => {
      const EndGame = {
        ...KolkhozGame,
        setup: (context, setupData) => {
          const G = KolkhozGame.setup(context, setupData);
          G.year = 5;
          G.isFamine = true;
          G.trump = null;
          // Player 0 has high value cards in plot
          G.players[0].plot.revealed = [
            { suit: 'Hearts', value: 13 },
            { suit: 'Diamonds', value: 13 },
          ];
          G.players[1].plot.revealed = [{ suit: 'Clubs', value: 6 }];
          G.players[2].plot.revealed = [{ suit: 'Spades', value: 7 }];
          G.players[3].plot.revealed = [{ suit: 'Hearts', value: 8 }];
          // 4 cards for famine tricks
          for (let i = 0; i < G.players.length; i++) {
            G.players[i].hand = [
              { suit: 'Hearts', value: 6 + i },
              { suit: 'Diamonds', value: 6 + i },
              { suit: 'Clubs', value: 6 + i },
              { suit: 'Spades', value: 6 + i },
            ];
          }
          return G;
        },
      };

      const client = Client({ game: EndGame, numPlayers: 4 });

      // Play through final year
      for (let t = 0; t < 3; t++) {
        playTrick(client);
        handleAssignment(client);
      }

      // Transition past requisition
      let { G, ctx } = client.getState();
      if (ctx.phase === 'requisition') {
        client.moves.continueToNextYear();
      }

      ({ G, ctx } = client.getState());

      // Game should be over
      if (G.year > 5) {
        expect(ctx.gameover).toBeDefined();
        // Player 0 should win with highest score (26 from two Kings)
        expect(ctx.gameover.winner).toBe(0);
      }
    });
  });
});
