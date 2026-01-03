#!/usr/bin/env node
/**
 * Interactive CLI Game Runner for Kolkhoz
 *
 * Run with: node scripts/play.js
 *
 * Commands:
 *   state / s         - Show current game state
 *   hand / h          - Show current player's hand
 *   play <index>      - Play card at index (0-based)
 *   trump <suit>      - Set trump suit (Hearts, Diamonds, Clubs, Spades)
 *   assign <card> <suit> - Assign card to suit (e.g., "assign Hearts-7 Diamonds")
 *   submit            - Submit assignments
 *   swap <p> <h> <type> - Swap plot[p] with hand[h] (type: hidden/revealed)
 *   confirm           - Confirm swap phase
 *   continue          - Continue to next year (requisition phase)
 *   ai                - Let AI make a move
 *   auto              - Auto-play until human input needed
 *   help              - Show commands
 *   quit / q          - Exit
 */

import * as readline from 'readline';
import { Client } from 'boardgame.io/dist/cjs/client.js';
import { KolkhozGame } from '../src/game/KolkhozGame.js';
import { getPrioritizedMoves } from '../src/game/utils/aiUtils.js';

const SUITS = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];
const SUIT_SYMBOLS = { Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' };
const SUIT_COLORS = { Hearts: '\x1b[31m', Diamonds: '\x1b[31m', Clubs: '\x1b[37m', Spades: '\x1b[37m' };
const RESET = '\x1b[0m';
const BOLD = '\x1b[1m';
const DIM = '\x1b[2m';

// Create game client in spectator mode (sees all cards for debugging)
const client = Client({
  game: KolkhozGame,
  numPlayers: 4,
  playerID: null, // Spectator mode - see all cards
});

function cardStr(card) {
  if (!card) return '??';
  if (!card.suit || !card.value) return '??';
  const faces = { 1: 'A', 11: 'J', 12: 'Q', 13: 'K' };
  const rank = faces[card.value] || card.value;
  const sym = SUIT_SYMBOLS[card.suit];
  const color = SUIT_COLORS[card.suit];
  return `${color}${rank}${sym}${RESET}`;
}

function handStr(hand) {
  return hand.map((c, i) => `[${i}]${cardStr(c)}`).join(' ');
}

function showState() {
  const { G, ctx } = client.getState();

  console.log('\n' + '='.repeat(60));
  const trumpDisplay = G.trump ? `${SUIT_COLORS[G.trump]}${SUIT_SYMBOLS[G.trump]}${G.trump}${RESET}` : 'None';
  console.log(`${BOLD}YEAR ${G.year}/5${RESET} | Phase: ${BOLD}${ctx.phase}${RESET} | Trump: ${trumpDisplay}`);
  console.log(`Trick ${G.trickCount + 1}/${G.isFamine ? 3 : 4} | Lead: P${G.lead} | Current: P${ctx.currentPlayer}`);
  if (G.isFamine) console.log(`${BOLD}*** FAMINE YEAR ***${RESET}`);
  console.log('='.repeat(60));

  // Work hours
  console.log('\nJOBS:');
  for (const suit of SUITS) {
    const hours = G.workHours[suit];
    const claimed = G.claimedJobs?.includes(suit);
    const filled = Math.min(10, Math.floor(hours / 4));
    const bar = '█'.repeat(filled) + '░'.repeat(10 - filled);
    const status = claimed ? ' ✓DONE' : '';
    console.log(`  ${SUIT_SYMBOLS[suit]} ${suit.padEnd(8)} [${bar}] ${hours}/40${status}`);
  }

  // Current trick
  if (G.currentTrick.length > 0) {
    console.log('\nCURRENT TRICK:');
    for (const [pid, card] of G.currentTrick) {
      console.log(`  P${pid}: ${cardStr(card)}`);
    }
  }

  // Pending assignments
  if (ctx.phase === 'assignment' && G.lastTrick) {
    console.log('\nLAST TRICK (to assign):');
    for (const [pid, card] of G.lastTrick) {
      const key = `${card.suit}-${card.value}`;
      const assigned = G.pendingAssignments?.[key];
      console.log(`  ${cardStr(card)} -> ${assigned || '?'}`);
    }
  }

  // Players
  console.log('\nPLAYERS:');
  for (let i = 0; i < G.numPlayers; i++) {
    const p = G.players[i];
    const isHuman = i === 0;
    const isCurrent = String(i) === ctx.currentPlayer;
    const marker = isCurrent ? '>' : ' ';
    const type = isHuman ? 'YOU' : 'AI';

    console.log(`${marker} P${i} (${type}): ${p.hand.length} cards | Plot: ${p.plot.revealed.length}r/${p.plot.hidden.length}h | Medals: ${p.medals}`);

    if (isHuman || true) { // Show all hands for debugging
      if (p.hand.length > 0) {
        console.log(`    Hand: ${handStr(p.hand)}`);
      }
      if (p.plot.revealed.length > 0) {
        console.log(`    Plot(r): ${p.plot.revealed.map(c => cardStr(c)).join(' ')}`);
      }
      if (p.plot.hidden.length > 0) {
        console.log(`    Plot(h): ${p.plot.hidden.map(c => cardStr(c)).join(' ')}`);
      }
    }
  }

  // Game over
  if (ctx.gameover) {
    console.log('\n' + '='.repeat(60));
    console.log(`${BOLD}GAME OVER!${RESET}`);
    console.log(`Winner: Player ${ctx.gameover.winner}`);
    console.log('Final Scores:', ctx.gameover.scores);
    console.log('='.repeat(60));
  }

  console.log('');
}

function showHelp() {
  console.log(`
${BOLD}COMMANDS:${RESET}
  state, s          - Show current game state
  hand, h           - Show your hand
  play <n>          - Play card at index n (as current player)
  trump <suit>      - Set trump (Hearts/Diamonds/Clubs/Spades)
  assign <c> <s>    - Assign card to suit (e.g., "assign Hearts-7 Diamonds")
  submit            - Submit assignments
  swap <p> <h> <t>  - Swap plot[p] with hand[h] (t=hidden/revealed)
  confirm           - Confirm swap
  continue          - Continue to next year
  ai                - Let AI make one move
  auto              - Auto-play until human input needed
  fullauto, f       - Auto-play entire game (all players)
  quit, q           - Exit
`);
}

// Execute a move, temporarily switching player ID then resetting to spectator
function execMove(playerID, moveName, ...args) {
  client.updatePlayerID(playerID);
  client.moves[moveName](...args);
  client.updatePlayerID(null); // Reset to spectator mode
}

function aiMove() {
  const { G, ctx } = client.getState();
  const playerIdx = parseInt(ctx.currentPlayer);

  const moves = getPrioritizedMoves(G, ctx, playerIdx);
  if (moves.length === 0) {
    console.log('AI has no valid moves');
    return false;
  }

  const best = moves[0];
  console.log(`${DIM}AI P${playerIdx}: ${best.move}(${best.args.join(', ')})${RESET}`);

  execMove(ctx.currentPlayer, best.move, ...best.args);
  return true;
}

function autoPlay() {
  // Keep playing AI moves until it's player 0's turn or game over
  let iterations = 0;
  while (iterations < 200) {
    const { G, ctx: currentCtx } = client.getState();

    if (currentCtx.gameover) {
      console.log('Game over!');
      break;
    }

    const currentPlayer = currentCtx.currentPlayer;
    const isHuman = currentPlayer === '0';

    // Handle phases that don't need input
    if (currentCtx.phase === 'plotSelection') {
      // plotSelection auto-transitions, just wait
      iterations++;
      continue;
    }

    // Handle requisition - anyone can continue
    if (currentCtx.phase === 'requisition') {
      execMove('0', 'continueToNextYear');
      iterations++;
      continue;
    }

    // AI assignment animation
    if (currentCtx.phase === 'aiAssignment' && G.pendingAIAssignments) {
      const pending = G.pendingAIAssignments;
      for (const [cardKey, targetSuit] of Object.entries(pending.assignments)) {
        execMove('0', 'applySingleAssignment', cardKey, targetSuit);
        break; // One at a time
      }
      iterations++;
      continue;
    }

    // Assignment phase - check if human or AI needs to assign
    if (currentCtx.phase === 'assignment') {
      if (G.lastWinner === 0) {
        console.log('Your turn to assign cards.');
        break;
      }
      // AI assignment - let aiMove handle it
    }

    // Human's turn - stop and wait for input
    if (isHuman) {
      if (currentCtx.phase === 'planning' && !G.trump && !G.isFamine) {
        console.log('Your turn to set trump.');
        break;
      }
      if (currentCtx.phase === 'trick') {
        console.log('Your turn to play a card.');
        break;
      }
      if (currentCtx.phase === 'swap') {
        console.log('Your turn to swap cards.');
        break;
      }
    }

    // AI swap - just confirm (no swapping for now)
    if (currentCtx.phase === 'swap' && !isHuman) {
      execMove(currentPlayer, 'confirmSwap');
      iterations++;
      continue;
    }

    // Let AI make a move
    if (!aiMove()) {
      // No valid moves available - might be stuck
      console.log(`No moves available in phase: ${currentCtx.phase}`);
      break;
    }
    iterations++;
  }

  showState();
}

function fullAutoPlay() {
  // Play through entire game automatically (including human moves)
  let iterations = 0;
  while (iterations < 500) {
    const { G, ctx: currentCtx } = client.getState();

    if (currentCtx.gameover) {
      console.log('Game over!');
      break;
    }

    const currentPlayer = currentCtx.currentPlayer;

    // Handle all phases automatically
    if (currentCtx.phase === 'plotSelection') {
      iterations++;
      continue;
    }

    if (currentCtx.phase === 'requisition') {
      execMove('0', 'continueToNextYear');
      iterations++;
      continue;
    }

    if (currentCtx.phase === 'aiAssignment' && G.pendingAIAssignments) {
      const pending = G.pendingAIAssignments;
      for (const [cardKey, targetSuit] of Object.entries(pending.assignments)) {
        execMove('0', 'applySingleAssignment', cardKey, targetSuit);
        break;
      }
      iterations++;
      continue;
    }

    if (currentCtx.phase === 'swap') {
      execMove(currentPlayer, 'confirmSwap');
      iterations++;
      continue;
    }

    // For all other phases, let AI decide (even for human player)
    if (!aiMove()) {
      console.log(`No moves available in phase: ${currentCtx.phase}`);
      break;
    }
    iterations++;

    // Print progress every 50 iterations
    if (iterations % 50 === 0) {
      console.log(`... Year ${G.year}, ${currentCtx.phase}, Trick ${G.trickCount + 1}`);
    }
  }

  showState();
}

function processCommand(input) {
  const parts = input.trim().toLowerCase().split(/\s+/);
  const cmd = parts[0];
  const args = parts.slice(1);

  const { G, ctx } = client.getState();

  switch (cmd) {
    case 'state':
    case 's':
      showState();
      break;

    case 'hand':
    case 'h':
      console.log(`Your hand: ${handStr(G.players[0].hand)}`);
      break;

    case 'play':
    case 'p': {
      const idx = parseInt(args[0]);
      if (isNaN(idx)) {
        console.log('Usage: play <index>');
        break;
      }
      // Play as current player (for debugging any player)
      execMove(ctx.currentPlayer, 'playCard', idx);
      showState();
      break;
    }

    case 'trump':
    case 't': {
      const suit = args[0]?.charAt(0).toUpperCase() + args[0]?.slice(1).toLowerCase();
      if (!SUITS.includes(suit)) {
        console.log('Usage: trump <Hearts|Diamonds|Clubs|Spades>');
        break;
      }
      // Use current player (brigade leader sets trump)
      execMove(ctx.currentPlayer, 'setTrump', suit);
      showState();
      break;
    }

    case 'assign':
    case 'a': {
      if (args.length < 2) {
        console.log('Usage: assign <card> <suit> (e.g., assign Hearts-7 Diamonds)');
        break;
      }
      const cardKey = args[0];
      const targetSuit = args[1].charAt(0).toUpperCase() + args[1].slice(1).toLowerCase();
      execMove(String(G.lastWinner), 'assignCard', cardKey, targetSuit);
      showState();
      break;
    }

    case 'submit': {
      execMove(String(G.lastWinner), 'submitAssignments');
      showState();
      break;
    }

    case 'swap': {
      const plotIdx = parseInt(args[0]);
      const handIdx = parseInt(args[1]);
      const plotType = args[2] || 'hidden';
      if (isNaN(plotIdx) || isNaN(handIdx)) {
        console.log('Usage: swap <plotIndex> <handIndex> [hidden|revealed]');
        break;
      }
      execMove('0', 'swapCard', plotIdx, handIdx, plotType);
      showState();
      break;
    }

    case 'confirm': {
      execMove('0', 'confirmSwap');
      showState();
      break;
    }

    case 'continue':
    case 'c': {
      execMove('0', 'continueToNextYear');
      showState();
      break;
    }

    case 'ai': {
      aiMove();
      showState();
      break;
    }

    case 'auto': {
      autoPlay();
      break;
    }

    case 'fullauto':
    case 'f': {
      fullAutoPlay();
      break;
    }

    case 'help':
    case '?': {
      showHelp();
      break;
    }

    case 'quit':
    case 'q':
    case 'exit': {
      console.log('Goodbye!');
      process.exit(0);
    }

    default:
      if (cmd) {
        console.log(`Unknown command: ${cmd}. Type 'help' for commands.`);
      }
  }
}

// Main loop
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

console.log(`
${BOLD}=== KOLKHOZ - CLI Game Runner ===${RESET}
Type 'help' for commands, 'auto' to start playing.
`);

showState();

rl.setPrompt('> ');
rl.prompt();

rl.on('line', (line) => {
  processCommand(line);
  rl.prompt();
});

rl.on('close', () => {
  console.log('\nGoodbye!');
  process.exit(0);
});
