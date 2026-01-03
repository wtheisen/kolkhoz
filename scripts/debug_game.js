// Debug script to trace hand sizes through a game
import { Client } from 'boardgame.io/client';
import { KolkhozGame } from '../src/game/KolkhozGame.js';
import { getPrioritizedMoves } from '../src/game/utils/aiUtils.js';

const client = Client({ game: KolkhozGame, numPlayers: 4, playerID: null });

function getHandSizes(G) {
  return G.players.map(p => p.hand.length).join(',');
}

function execMove(playerID, moveName, ...args) {
  client.updatePlayerID(playerID);
  client.moves[moveName](...args);
  client.updatePlayerID(null);
}

let iterations = 0;
let lastPhase = '';
let lastTrickCount = -1;

while (iterations < 500) {
  const { G, ctx } = client.getState();

  if (ctx.gameover) {
    console.log('GAME OVER - Winner:', ctx.gameover.winner);
    break;
  }

  // Log phase/trick changes
  if (ctx.phase !== lastPhase || G.trickCount !== lastTrickCount) {
    console.log(`Year ${G.year}, ${ctx.phase}, Trick ${G.trickCount}, Hands: [${getHandSizes(G)}], Current: P${ctx.currentPlayer}`);
    lastPhase = ctx.phase;
    lastTrickCount = G.trickCount;
  }

  // Check for hand size inconsistency at the START of a trick (before anyone plays)
  const handSizes = G.players.map(p => p.hand.length);
  const uniqueSizes = [...new Set(handSizes)];
  if (uniqueSizes.length > 1 && ctx.phase === 'trick' && G.currentTrick.length === 0) {
    console.log('ERROR: Inconsistent hand sizes at trick start!', handSizes);
    console.log('State:', JSON.stringify({ year: G.year, trickCount: G.trickCount, phase: ctx.phase }));
    break;
  }

  const currentPlayer = ctx.currentPlayer;

  if (ctx.phase === 'plotSelection') { iterations++; continue; }
  if (ctx.phase === 'requisition') { execMove('0', 'continueToNextYear'); iterations++; continue; }
  if (ctx.phase === 'aiAssignment' && G.pendingAIAssignments) {
    for (const [cardKey, targetSuit] of Object.entries(G.pendingAIAssignments.assignments)) {
      execMove('0', 'applySingleAssignment', cardKey, targetSuit);
      break;
    }
    iterations++; continue;
  }
  if (ctx.phase === 'swap') { execMove(currentPlayer, 'confirmSwap'); iterations++; continue; }

  const moves = getPrioritizedMoves(G, ctx, parseInt(currentPlayer));
  if (moves.length === 0) {
    console.log('No moves for P' + currentPlayer, 'in phase', ctx.phase, 'hand:', G.players[parseInt(currentPlayer)].hand.length);
    break;
  }

  const best = moves[0];
  client.updatePlayerID(currentPlayer);
  client.moves[best.move](...best.args);
  client.updatePlayerID(null);
  iterations++;
}
