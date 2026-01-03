/**
 * AI Strategy Utilities for Kolkhoz
 *
 * Provides heuristic-based decision making for AI players.
 */

import { SUITS } from '../constants.js';

/**
 * Calculate card work hours (value for job progress)
 */
function getCardWorkHours(card, trump, nomenclature = true) {
  // Jack of trump = 0 hours in nomenclature variant
  if (nomenclature && card.value === 11 && card.suit === trump) {
    return 0;
  }
  return card.value;
}

/**
 * Evaluate how valuable completing a job is
 * Higher = more valuable to complete
 */
function evaluateJobCompletion(G, suit, playerIdx) {
  const hours = G.workHours[suit] || 0;
  const isCompleted = G.claimedJobs?.includes(suit);

  if (isCompleted) return -10; // Already done, low priority

  // How close to completion (40 hours)
  const remaining = Math.max(0, 40 - hours);
  const closenessBonus = remaining < 20 ? (20 - remaining) * 2 : 0;

  // Check player's risk - do they have cards of this suit in plot?
  const player = G.players[playerIdx];
  const plotCards = [...(player.plot?.revealed || []), ...(player.plot?.hidden || [])];
  const plotSuitCount = plotCards.filter(c => c.suit === suit).length;

  // High risk = high priority to complete (avoid requisition)
  const riskBonus = plotSuitCount * 15;

  return closenessBonus + riskBonus;
}

/**
 * Score a potential assignment decision
 * Higher = better assignment
 */
function scoreAssignment(G, card, targetSuit, playerIdx) {
  let score = 0;
  const hours = G.workHours[targetSuit] || 0;
  const cardHours = getCardWorkHours(card, G.trump, G.variants?.nomenclature);
  const newHours = hours + cardHours;
  const isCompleted = G.claimedJobs?.includes(targetSuit);

  // If job already completed, avoid wasting cards here
  if (isCompleted) {
    return -20;
  }

  const player = G.players[playerIdx];
  const plotCards = [...(player.plot?.revealed || []), ...(player.plot?.hidden || [])];
  const atRiskCount = plotCards.filter(c => c.suit === targetSuit).length;

  // HUGE BONUS: Completing a job is extremely valuable
  if (hours < 40 && newHours >= 40) {
    score += 100;
    // Even more if this player has cards at risk for this suit
    score += atRiskCount * 30;
  }

  // STRONG BONUS: Jobs that are close to completion (20+ hours)
  // Concentrate cards here to finish them!
  if (hours >= 20 && hours < 40) {
    score += 40 + (hours - 20); // 40-59 bonus based on progress
    score += atRiskCount * 15;
  }

  // MODERATE BONUS: Jobs with some progress (10-19 hours)
  if (hours >= 10 && hours < 20) {
    score += 15;
    score += atRiskCount * 10;
  }

  // PENALTY: Jobs with little progress - don't spread cards thin!
  // Better to concentrate on jobs already started
  if (hours < 10) {
    score -= 10;
    // Unless we have cards at risk, then it's worth starting
    score += atRiskCount * 8;
  }

  // BONUS: High value cards should go to jobs close to completion
  if (cardHours >= 10 && hours >= 25) {
    score += 20; // Use high cards to push over the finish line
  }

  // NO preference for matching suit - strategy over theme!
  // Actually SLIGHT PENALTY for matching to encourage off-suit thinking
  if (card.suit === targetSuit && hours < 20) {
    score -= 5; // Discourage lazy matching on low-progress jobs
  }

  return score;
}

/**
 * Score playing a specific card in the current trick context
 * Higher = better play
 */
function scoreCardPlay(G, playerIdx, cardIndex) {
  const player = G.players[playerIdx];
  const card = player.hand[cardIndex];
  let score = 0;

  const isLeading = G.currentTrick.length === 0;
  const leadSuit = G.currentTrick[0]?.[1]?.suit;
  const trickCards = G.currentTrick.map(([, c]) => c);

  // Estimate if we'd win with this card
  const wouldWin = estimateWinProbability(G, card, trickCards);

  // Do we WANT to win this trick?
  const wantToWin = evaluateWinDesirability(G, playerIdx);

  if (isLeading) {
    // When leading, play suits we want to progress
    const jobValue = evaluateJobCompletion(G, card.suit, playerIdx);
    score += jobValue * 0.3;

    // Lead with medium cards to feel out opponents
    if (card.value >= 8 && card.value <= 11) {
      score += 5;
    }

    // Don't lead trump early unless necessary
    if (card.suit === G.trump && G.trickCount < 2) {
      score -= 10;
    }
  } else {
    // Following
    if (wantToWin > 0 && wouldWin > 0.5) {
      // We want to win and this card likely wins
      score += wantToWin * wouldWin * 20;
    } else if (wantToWin < 0 && wouldWin < 0.5) {
      // We don't want to win and this card likely loses
      score += Math.abs(wantToWin) * (1 - wouldWin) * 15;
    }

    // If we can't follow suit, consider dumping high-risk cards
    if (card.suit !== leadSuit) {
      const plotCards = [...(player.plot?.revealed || []), ...(player.plot?.hidden || [])];
      const suitRisk = plotCards.filter(c => c.suit === card.suit).length;

      // If job not completed, dumping cards of risky suits is good
      if (!G.claimedJobs?.includes(card.suit)) {
        score += suitRisk * 3;
      }
    }
  }

  // Slight randomness to prevent predictability
  score += Math.random() * 2;

  return score;
}

/**
 * Estimate probability this card wins the trick
 */
function estimateWinProbability(G, card, trickCards) {
  if (trickCards.length === 0) return 0.5; // Leading

  const leadSuit = trickCards[0].suit;

  // Find current winning card
  let winningCard = trickCards[0];
  for (const c of trickCards) {
    if (c.suit === G.trump && winningCard.suit !== G.trump) {
      winningCard = c;
    } else if (c.suit === winningCard.suit && c.value > winningCard.value) {
      winningCard = c;
    }
  }

  // Would our card beat the current winner?
  if (card.suit === G.trump && winningCard.suit !== G.trump) {
    return 0.8; // Trump beats non-trump
  }
  if (card.suit === winningCard.suit && card.value > winningCard.value) {
    return 0.7;
  }
  if (card.suit !== leadSuit && card.suit !== G.trump) {
    return 0.1; // Off-suit non-trump rarely wins
  }

  return 0.3; // Default uncertainty
}

/**
 * Evaluate how much we want to win the current trick
 * Positive = want to win, Negative = don't want to win
 */
function evaluateWinDesirability(G, playerIdx) {
  let desire = 0;
  const player = G.players[playerIdx];

  // If we haven't won a trick yet, we're safe from requisition
  // Penalize winning unless it's very valuable
  if (!player.hasWonTrickThisYear) {
    const plotCards = [...(player.plot?.revealed || []), ...(player.plot?.hidden || [])];
    if (plotCards.length > 0) {
      desire -= 30; // Strong penalty - stay safe from requisition!
    }
  }

  // Check what suits are in the trick
  const trickSuits = [...new Set(G.currentTrick.map(([, c]) => c.suit))];

  // If trick contains suits of jobs we want to complete, we want to win
  for (const suit of trickSuits) {
    const jobValue = evaluateJobCompletion(G, suit, playerIdx);
    desire += jobValue * 0.1;
  }

  // If we're brigade leader, might want to keep control
  if (player.brigadeLeader) {
    desire += 5;
  }

  // Late game, winning is more important for final assignments
  if (G.trickCount >= 2) {
    desire += 3;
  }

  return desire;
}

/**
 * Score a potential swap decision
 * Higher = more beneficial swap
 * Returns negative if swap is bad, 0 if neutral, positive if good
 */
function scoreSwap(G, playerIdx, handCardIndex, plotCardIndex, plotType) {
  const player = G.players[playerIdx];
  const handCard = player.hand[handCardIndex];
  const plotArray = plotType === 'revealed' ? player.plot.revealed : player.plot.hidden;
  const plotCard = plotArray[plotCardIndex];

  if (!handCard || !plotCard) return -100;

  let score = 0;

  // Basic value comparison: high value cards are better in hand for tricks
  const handValue = handCard.value;
  const plotValue = plotCard.value;

  // We want HIGH cards in hand (for winning tricks) and LOW cards in plot (less penalty if requisitioned)
  const valueDiff = plotValue - handValue;
  score += valueDiff * 2; // Getting a higher card in hand is good

  // Consider job completion status - if job is complete, that suit is safe in plot
  const handSuitComplete = G.claimedJobs?.includes(handCard.suit);
  const plotSuitComplete = G.claimedJobs?.includes(plotCard.suit);

  // Safe to move cards of completed suits to plot
  if (handSuitComplete && !plotSuitComplete) {
    score += 10; // Hand card is safe to put in plot
  }
  if (plotSuitComplete && !handSuitComplete) {
    score -= 10; // Plot card's suit is already safe, don't bring it to hand
  }

  // Consider current work hours - suits close to completion are "safer"
  const handSuitHours = G.workHours[handCard.suit] || 0;
  const plotSuitHours = G.workHours[plotCard.suit] || 0;

  // Cards of suits with high hours (close to completion) are safer in plot
  if (handSuitHours >= 30) score += 5;
  if (plotSuitHours >= 30) score -= 5;

  // Trump cards are valuable in hand - don't swap them to plot
  if (handCard.suit === G.trump) {
    score -= 15; // Penalty for putting trump in plot
  }
  if (plotCard.suit === G.trump) {
    score += 15; // Bonus for getting trump in hand
  }

  // High cards (J, Q, K) are more valuable in hand for winning tricks
  if (handCard.value >= 11) score -= 8;
  if (plotCard.value >= 11) score += 8;

  // Revealed cards are more "known" - AI might prefer swapping hidden
  if (plotType === 'hidden') {
    score += 2; // Slight preference for swapping hidden cards
  }

  return score;
}

/**
 * Get best swap moves for AI player
 * Returns array of swapCard moves sorted by score, plus confirmSwap when done
 */
function getAISwapMoves(G, playerIdx) {
  const player = G.players[playerIdx];
  const moves = [];

  // Evaluate all possible swaps
  const allSwaps = [];

  for (let handIdx = 0; handIdx < player.hand.length; handIdx++) {
    // Check hidden plot cards
    for (let plotIdx = 0; plotIdx < player.plot.hidden.length; plotIdx++) {
      const score = scoreSwap(G, playerIdx, handIdx, plotIdx, 'hidden');
      if (score > 5) { // Only consider swaps with meaningful benefit
        allSwaps.push({ handIdx, plotIdx, plotType: 'hidden', score });
      }
    }
    // Check revealed plot cards
    for (let plotIdx = 0; plotIdx < player.plot.revealed.length; plotIdx++) {
      const score = scoreSwap(G, playerIdx, handIdx, plotIdx, 'revealed');
      if (score > 5) { // Only consider swaps with meaningful benefit
        allSwaps.push({ handIdx, plotIdx, plotType: 'revealed', score });
      }
    }
  }

  // Sort by score (best first)
  allSwaps.sort((a, b) => b.score - a.score);

  // AI makes at most 1-2 swaps per turn (to keep it reasonable)
  const maxSwaps = Math.min(2, allSwaps.length);

  for (let i = 0; i < maxSwaps; i++) {
    const swap = allSwaps[i];
    moves.push({
      move: 'swapCard',
      args: [swap.plotIdx, swap.handIdx, swap.plotType],
      score: swap.score
    });
  }

  // Always end with confirmSwap to finish the turn
  moves.push({ move: 'confirmSwap', args: [], score: 0 });

  return moves;
}

/**
 * Score trump suit selection
 * Higher = better trump choice
 */
function scoreTrumpSelection(G, suit, playerIdx) {
  let score = 0;
  const player = G.players[playerIdx];
  const hand = player.hand || [];

  // Count high cards in this suit (J, Q, K = 11, 12, 13)
  const highCards = hand.filter(c => c.suit === suit && c.value >= 11).length;
  score += highCards * 15;

  // Count total cards in this suit
  const suitCount = hand.filter(c => c.suit === suit).length;
  score += suitCount * 5;

  // Check job status - prefer trump where job is close to completion
  const hours = G.workHours[suit] || 0;
  if (hours >= 20 && hours < 40) {
    score += 10; // Close to completion
  }

  // PENALTY: Avoid trump where we have many plot cards (requisition risk)
  const plotCards = [...(player.plot?.revealed || []), ...(player.plot?.hidden || [])];
  const plotSuitCount = plotCards.filter(c => c.suit === suit).length;
  score -= plotSuitCount * 8;

  // Slight randomness
  score += Math.random() * 5;

  return score;
}

/**
 * Get prioritized moves for AI (ordered by score)
 */
export function getPrioritizedMoves(G, ctx, playerIdx) {
  const moves = [];
  const player = G.players[playerIdx];

  if (ctx.phase === 'planning' && !G.trump) {
    // Trump selection - score each option
    for (const suit of SUITS) {
      const score = scoreTrumpSelection(G, suit, playerIdx);
      moves.push({ move: 'setTrump', args: [suit], score });
    }
  } else if (ctx.phase === 'trick') {
    // Card play - score each valid card
    for (let i = 0; i < player.hand.length; i++) {
      const card = player.hand[i];
      const leadSuit = G.currentTrick[0]?.[1]?.suit;

      // Check if valid play
      if (G.currentTrick.length > 0) {
        const hasLeadSuit = player.hand.some(c => c.suit === leadSuit);
        if (hasLeadSuit && card.suit !== leadSuit) continue;
      }

      const score = scoreCardPlay(G, playerIdx, i);
      moves.push({ move: 'playCard', args: [i], score });
    }
  } else if (ctx.phase === 'assignment' && playerIdx === G.lastWinner) {
    const suitsInTrick = [...new Set(G.lastTrick.map(([, c]) => c.suit))];
    const player = G.players[playerIdx];
    const plotCards = [...(player.plot?.revealed || []), ...(player.plot?.hidden || [])];

    // Calculate total work hours in this trick
    const totalTrickHours = G.lastTrick.reduce((sum, [, card]) => {
      return sum + getCardWorkHours(card, G.trump, G.variants?.nomenclature);
    }, 0);

    // STRATEGY A: Concentrate all cards into one suit
    let bestConcentrateSuit = suitsInTrick[0];
    let bestConcentrateScore = -Infinity;

    for (const targetSuit of suitsInTrick) {
      const currentHours = G.workHours[targetSuit] || 0;
      const isCompleted = G.claimedJobs?.includes(targetSuit);

      if (isCompleted) {
        if (bestConcentrateScore < -20) {
          bestConcentrateScore = -20;
          bestConcentrateSuit = targetSuit;
        }
        continue;
      }

      const newHours = currentHours + totalTrickHours;
      let score = 0;

      if (newHours >= 40) {
        score += 200; // Huge bonus for completing
        score -= (newHours - 40) * 2; // Penalize waste
      } else {
        score += newHours;
        if (newHours >= 30) score += 30;
        else if (newHours >= 20) score += 15;
      }

      const atRiskCount = plotCards.filter(c => c.suit === targetSuit).length;
      score += atRiskCount * 20;

      if (score > bestConcentrateScore) {
        bestConcentrateScore = score;
        bestConcentrateSuit = targetSuit;
      }
    }

    // STRATEGY B: Split cards to their matching suits (or best individual assignments)
    let splitScore = 0;
    const splitAssignments = {};

    for (const [, card] of G.lastTrick) {
      const cardHours = getCardWorkHours(card, G.trump, G.variants?.nomenclature);
      let bestSuitForCard = card.suit;
      let bestCardScore = -Infinity;

      for (const targetSuit of suitsInTrick) {
        const currentHours = G.workHours[targetSuit] || 0;
        const isCompleted = G.claimedJobs?.includes(targetSuit);
        let cardScore = 0;

        if (isCompleted) {
          cardScore = -20; // Avoid wasting cards on already-completed jobs
        } else {
          const newHours = currentHours + cardHours;
          if (newHours >= 40) {
            cardScore += 150; // Good but not as good as concentrate
          } else {
            cardScore += newHours * 0.5;
            if (newHours >= 30) cardScore += 15;
          }

          const atRiskCount = plotCards.filter(c => c.suit === targetSuit).length;
          cardScore += atRiskCount * 10;
        }

        if (cardScore > bestCardScore) {
          bestCardScore = cardScore;
          bestSuitForCard = targetSuit;
        }
      }

      splitAssignments[`${card.suit}-${card.value}`] = bestSuitForCard;
      splitScore += bestCardScore;
    }

    // Choose the better strategy
    const pending = G.pendingAssignments || {};
    let targetAssignments;

    if (bestConcentrateScore >= splitScore) {
      // Concentrate strategy wins - all cards to one suit
      targetAssignments = {};
      for (const [, card] of G.lastTrick) {
        targetAssignments[`${card.suit}-${card.value}`] = bestConcentrateSuit;
      }
    } else {
      // Split strategy wins
      targetAssignments = splitAssignments;
    }

    // Check if we need to reassign any cards
    let needsReassignment = false;
    for (const [cardKey, targetSuit] of Object.entries(targetAssignments)) {
      if (pending[cardKey] !== targetSuit) {
        needsReassignment = true;
        moves.push({ move: 'assignCard', args: [cardKey, targetSuit], score: 100 });
      }
    }

    if (!needsReassignment) {
      moves.push({ move: 'submitAssignments', args: [], score: 100 });
    }
  } else if (ctx.phase === 'swap') {
    // AI makes swap decisions during their turn
    const swapMoves = getAISwapMoves(G, playerIdx);
    moves.push(...swapMoves);
  }

  // Sort by score (highest first)
  moves.sort((a, b) => b.score - a.score);

  return moves;
}
