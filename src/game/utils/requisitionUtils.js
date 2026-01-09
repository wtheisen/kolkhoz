// Requisition utility functions for boardgame.io
// Adapted from RequisitionManager.js

import { THRESHOLD } from '../constants.js';

// Find the Hero of the Soviet Union (player who won all tricks this year)
function findHero(G, variants) {
  if (!variants.heroOfSovietUnion) return -1;
  // Famine year has 3 tricks, normal years have 4
  const requiredMedals = G.isFamine ? 3 : 4;
  for (let i = 0; i < G.players.length; i++) {
    if (G.players[i].medals === requiredMedals) {
      return i;
    }
  }
  return -1;
}

// Perform requisition for all failed jobs
export function performRequisition(G, variants) {
  // Check for Hero of the Soviet Union first
  const heroIdx = findHero(G, variants);

  // Initialize animation tracking data
  G.requisitionData = {
    revealedCards: [],  // {playerIdx, card, fromHidden}
    exiledCards: [],    // {playerIdx, card}
    failedJobs: [],     // suit names that failed
    heroIdx: heroIdx,   // player index of hero (-1 if none)
    heroName: heroIdx !== -1 ? G.players[heroIdx].name : null,
  };

  // Log work hours
  if (!G.trickHistory) G.trickHistory = [];
  G.trickHistory.push({
    type: 'jobs',
    year: G.year,
    jobs: { ...G.workHours },
  });

  // Log requisition events
  G.trickHistory.push({
    type: 'requisition',
    year: G.year,
    requisitions: [],
  });

  // Log Hero of the Soviet Union if present
  if (heroIdx !== -1) {
    G.trickHistory[G.trickHistory.length - 1].requisitions.push(
      `${G.players[heroIdx].name} - Герой Советского Союза!`
    );
  }

  for (const [suit, bucket] of Object.entries(G.jobBuckets)) {
    if (G.workHours[suit] >= THRESHOLD) {
      continue;
    }

    // Track failed job for animation
    G.requisitionData.failedJobs.push(suit);

    if (variants.miceVariant) {
      performMiceVariant(G, suit, bucket, variants, heroIdx);
    } else if (variants.deckType === 36) {
      perform36Card(G, suit, bucket, variants, heroIdx);
    } else {
      performStandard(G, suit, bucket, variants, heroIdx);
    }
  }
}

// Check for drunkard (Jack of trump) - gets exiled instead of player cards
// When drunkard is exiled, add the failed job's reward to the worker deck as compensation
function handleDrunkard(G, bucket, variants, suit) {
  if (!variants.nomenclature) return false;

  for (const c of bucket) {
    if (c.value === 11 && c.suit === G.trump) {
      G.trickHistory[G.trickHistory.length - 1].requisitions.push(
        'Пьяница отправить на Север'
      );
      addToExiled(G, `${c.suit}-${c.value}`);

      // Add the failed job's reward to drunkard replacements
      // This compensates for the exiled Jack, maintaining deck balance
      const jobReward = G.revealedJobs[suit];
      if (jobReward) {
        if (!G.drunkardReplacements) {
          G.drunkardReplacements = [];
        }
        const reward = Array.isArray(jobReward) ? jobReward[0] : jobReward;
        if (reward) {
          G.drunkardReplacements.push({ ...reward });
        }
      }

      return true;
    }
  }
  return false;
}

// Check for informant (Queen of trump)
function hasInformant(bucket, trump, variants) {
  if (!variants.nomenclature) return false;
  return bucket.some((c) => c.value === 12 && c.suit === trump);
}

// Check for party official (King of trump)
function hasPartyOfficial(bucket, trump, variants) {
  if (!variants.nomenclature) return false;
  return bucket.some((c) => c.value === 13 && c.suit === trump);
}

// Add card to exiled pile
function addToExiled(G, cardKey) {
  if (!G.exiled[G.year]) {
    G.exiled[G.year] = [];
  }
  G.exiled[G.year].push(cardKey);
}

// Get card display string
function cardToString(card) {
  const face = { 11: 'J', 12: 'Q', 13: 'K' }[card.value] || card.value;
  return `${face} of ${card.suit}`;
}

// Mice variant requisition
function performMiceVariant(G, suit, bucket, variants, heroIdx = -1) {
  if (handleDrunkard(G, bucket, variants, suit)) return;

  const informant = hasInformant(bucket, G.trump, variants);
  const partyOfficial = hasPartyOfficial(bucket, G.trump, variants);

  // Hero of the Soviet Union: hero is immune, everyone else reveals
  const vulnerabilityFilter = heroIdx !== -1 ? (p, idx) => idx !== heroIdx : null;

  // All players reveal matching cards
  const allRevealedCards = revealMatchingCards(G, suit, informant, vulnerabilityFilter, variants);
  if (allRevealedCards.length === 0) return;

  // Sort and exile highest
  allRevealedCards.sort((a, b) => b[1].value - a[1].value);
  exileCard(G, allRevealedCards[0]);

  // Party official exiles second card
  if (partyOfficial && allRevealedCards.length > 1) {
    exileCard(G, allRevealedCards[1]);
    G.trickHistory[G.trickHistory.length - 1].requisitions.push(
      `Партийный чиновник: ${allRevealedCards[1][0].name} отправить на Север ${cardToString(allRevealedCards[1][1])}`
    );
  }
}

// 36-card deck requisition
function perform36Card(G, suit, bucket, variants, heroIdx = -1) {
  if (handleDrunkard(G, bucket, variants, suit)) return;

  const informant = hasInformant(bucket, G.trump, variants);
  const partyOfficial = hasPartyOfficial(bucket, G.trump, variants);

  // For ordenNachalniku: only players with stacks are vulnerable
  // Hero of the Soviet Union: hero is immune, everyone else is vulnerable
  const vulnerabilityFilter = (p, idx) => {
    if (heroIdx !== -1) {
      return idx !== heroIdx;
    }
    if (!variants.ordenNachalniku) return true;
    const hasStacks = p.plot.stacks && p.plot.stacks.length > 0;
    return informant || hasStacks;
  };

  const allRevealedCards = revealMatchingCards(G, suit, informant, vulnerabilityFilter, variants);

  // Also check plot.revealed for vulnerable players
  for (let i = 0; i < G.players.length; i++) {
    const p = G.players[i];
    if (!vulnerabilityFilter(p, i)) continue;

    const revealedMatching = (p.plot.revealed || []).filter((c) => c.suit === suit);
    for (const card of revealedMatching) {
      const alreadyAdded = allRevealedCards.some(
        ([player, c]) => player === p && c.suit === card.suit && c.value === card.value
      );
      if (!alreadyAdded) {
        allRevealedCards.push([p, card]);
      }
    }
  }

  // Group by player and exile each player's highest
  const cardsByPlayer = new Map();
  for (const [player, card] of allRevealedCards) {
    if (!cardsByPlayer.has(player)) {
      cardsByPlayer.set(player, []);
    }
    cardsByPlayer.get(player).push(card);
  }

  for (const [player, cards] of cardsByPlayer.entries()) {
    if (cards.length === 0) continue;

    cards.sort((a, b) => b.value - a.value);
    exileCard(G, [player, cards[0]]);

    if (partyOfficial && cards.length > 1) {
      exileCard(G, [player, cards[1]]);
      G.trickHistory[G.trickHistory.length - 1].requisitions.push(
        `Партийный чиновник: ${player.name} отправить на Север ${cardToString(cards[1])}`
      );
    }
  }
}

// Standard 52-card requisition
function performStandard(G, suit, bucket, variants, heroIdx = -1) {
  if (handleDrunkard(G, bucket, variants, suit)) return;

  const informant = hasInformant(bucket, G.trump, variants);
  const partyOfficial = hasPartyOfficial(bucket, G.trump, variants);

  for (let i = 0; i < G.players.length; i++) {
    const p = G.players[i];

    // Hero of the Soviet Union: hero is immune, everyone else is vulnerable
    let isVulnerable;
    if (heroIdx !== -1) {
      isVulnerable = i !== heroIdx;
    } else {
      isVulnerable = variants.northernStyle || p.hasWonTrickThisYear || informant;
    }

    if (!isVulnerable) continue;

    // Get matching hidden cards
    const matchingHidden = (p.plot.hidden || []).filter((c) => c.suit === suit);

    let toReveal;
    if (informant) {
      // Informant: reveal ALL matching cards
      toReveal = matchingHidden;
    } else {
      // No informant: reveal only the HIGHEST matching card
      if (matchingHidden.length > 0) {
        const highest = matchingHidden.reduce((max, c) => c.value > max.value ? c : max);
        toReveal = [highest];
      } else {
        toReveal = [];
      }
    }

    // Track revealed cards for animation
    for (const card of toReveal) {
      G.requisitionData.revealedCards.push({
        playerIdx: i,
        card: { ...card },
        fromHidden: true,
      });
    }

    // Move revealed cards
    p.plot.revealed.push(...toReveal);

    // Remove only the revealed cards from hidden (not all matching)
    for (const card of toReveal) {
      const idx = p.plot.hidden.findIndex(c => c.suit === card.suit && c.value === card.value);
      if (idx !== -1) p.plot.hidden.splice(idx, 1);
    }

    // Check for matching cards in revealed plot
    const suitCards = (p.plot.revealed || [])
      .filter((c) => c.suit === suit)
      .sort((a, b) => b.value - a.value);

    if (suitCards.length === 0) continue;

    // Exile highest (don't remove from plot yet - wait for animation)
    const card = suitCards[0];
    addToExiled(G, `${card.suit}-${card.value}`);
    G.trickHistory[G.trickHistory.length - 1].requisitions.push(
      `${p.name} отправить на Север ${cardToString(card)}`
    );

    // Track exiled card for animation
    G.requisitionData.exiledCards.push({
      playerIdx: i,
      card: { ...card },
    });

    // Party official exiles second card (don't remove from plot yet - wait for animation)
    if (partyOfficial && suitCards.length > 1) {
      const card2 = suitCards[1];
      addToExiled(G, `${card2.suit}-${card2.value}`);
      G.trickHistory[G.trickHistory.length - 1].requisitions.push(
        `Партийный чиновник: ${p.name} отправить на Север ${cardToString(card2)}`
      );

      // Track second exiled card for animation
      G.requisitionData.exiledCards.push({
        playerIdx: i,
        card: { ...card2 },
      });
    }
  }
}

// Reveal matching cards from players' plots
function revealMatchingCards(G, suit, informant, vulnerabilityFilter, variants) {
  const allRevealedCards = [];

  for (let i = 0; i < G.players.length; i++) {
    const p = G.players[i];
    if (vulnerabilityFilter && !vulnerabilityFilter(p, i)) continue;

    const matchingHidden = (p.plot.hidden || []).filter((c) => c.suit === suit);

    // For ordenNachalniku, also check stacks
    const matchingFromStacks = [];
    if (variants.ordenNachalniku && variants.deckType === 36 && p.plot.stacks) {
      for (const stack of p.plot.stacks) {
        for (const card of stack.revealed || []) {
          if (card.suit === suit) {
            matchingFromStacks.push({ card, stack, location: 'revealed' });
          }
        }
        for (const card of stack.hidden || []) {
          if (card.suit === suit) {
            matchingFromStacks.push({ card, stack, location: 'hidden' });
          }
        }
      }
    }

    const allMatching = [...matchingHidden, ...matchingFromStacks.map((m) => m.card)];
    if (allMatching.length === 0) continue;

    if (informant) {
      // Reveal all matching cards
      for (const card of matchingHidden) {
        const cardIndex = p.plot.hidden.findIndex(
          (c) => c.suit === card.suit && c.value === card.value
        );
        p.plot.hidden.splice(cardIndex, 1);
        p.plot.revealed.push(card);
        allRevealedCards.push([p, card]);
        // Track for animation
        G.requisitionData.revealedCards.push({
          playerIdx: i,
          card: { ...card },
          fromHidden: true,
        });
      }
      for (const { card, stack, location } of matchingFromStacks) {
        const arr = location === 'hidden' ? stack.hidden : stack.revealed;
        const cardIndex = arr.findIndex(
          (c) => c.suit === card.suit && c.value === card.value
        );
        if (cardIndex !== -1) {
          arr.splice(cardIndex, 1);
          p.plot.revealed.push(card);
          allRevealedCards.push([p, card]);
          // Track for animation
          G.requisitionData.revealedCards.push({
            playerIdx: i,
            card: { ...card },
            fromHidden: location === 'hidden',
          });
        }
      }
    } else {
      // Reveal only highest card
      const highestCard = allMatching.reduce((max, card) =>
        card.value > max.value ? card : max
      );

      const isFromHidden = matchingHidden.some(
        (c) => c.suit === highestCard.suit && c.value === highestCard.value
      );

      if (isFromHidden) {
        const cardIndex = p.plot.hidden.findIndex(
          (c) => c.suit === highestCard.suit && c.value === highestCard.value
        );
        p.plot.hidden.splice(cardIndex, 1);
        p.plot.revealed.push(highestCard);
        allRevealedCards.push([p, highestCard]);
        // Track for animation
        G.requisitionData.revealedCards.push({
          playerIdx: i,
          card: { ...highestCard },
          fromHidden: true,
        });
      } else {
        const stackEntry = matchingFromStacks.find(
          (m) => m.card.suit === highestCard.suit && m.card.value === highestCard.value
        );
        if (stackEntry) {
          const { stack, location } = stackEntry;
          const arr = location === 'hidden' ? stack.hidden : stack.revealed;
          const cardIndex = arr.findIndex(
            (c) => c.suit === highestCard.suit && c.value === highestCard.value
          );
          if (cardIndex !== -1) {
            arr.splice(cardIndex, 1);
            p.plot.revealed.push(highestCard);
            allRevealedCards.push([p, highestCard]);
            // Track for animation
            G.requisitionData.revealedCards.push({
              playerIdx: i,
              card: { ...highestCard },
              fromHidden: location === 'hidden',
            });
          }
        }
      }
    }

    // Clean up empty stacks
    if (p.plot.stacks) {
      p.plot.stacks = p.plot.stacks.filter(
        (stack) =>
          (stack.revealed && stack.revealed.length > 0) ||
          (stack.hidden && stack.hidden.length > 0)
      );
    }
  }

  return allRevealedCards;
}

// Exile a card from a player's plot (don't remove yet - wait for animation)
function exileCard(G, [player, card]) {
  // Just track the exile - actual removal happens in applyExiledCards
  addToExiled(G, `${card.suit}-${card.value}`);
  G.trickHistory[G.trickHistory.length - 1].requisitions.push(
    `${player.name} отправить на Север ${cardToString(card)}`
  );

  // Track exiled card for animation
  const playerIdx = G.players.indexOf(player);
  if (playerIdx !== -1) {
    G.requisitionData.exiledCards.push({
      playerIdx,
      card: { ...card },
    });
  }
}

// Apply exiled cards - actually remove them from players' plots
// Called after animation completes (when user clicks continue)
export function applyExiledCards(G) {
  if (!G.requisitionData?.exiledCards) return;

  for (const { playerIdx, card } of G.requisitionData.exiledCards) {
    const player = G.players[playerIdx];
    if (!player) continue;

    // Try to remove from plot.revealed
    let cardIndex = (player.plot.revealed || []).findIndex(
      (c) => c.suit === card.suit && c.value === card.value
    );

    if (cardIndex !== -1) {
      player.plot.revealed.splice(cardIndex, 1);
      continue;
    }

    // Try to remove from stacks (36-card variants)
    if (player.plot.stacks) {
      for (const stack of player.plot.stacks) {
        cardIndex = (stack.revealed || []).findIndex(
          (c) => c.suit === card.suit && c.value === card.value
        );
        if (cardIndex !== -1) {
          stack.revealed.splice(cardIndex, 1);
          break;
        }
        cardIndex = (stack.hidden || []).findIndex(
          (c) => c.suit === card.suit && c.value === card.value
        );
        if (cardIndex !== -1) {
          stack.hidden.splice(cardIndex, 1);
          break;
        }
      }

      // Clean up empty stacks
      player.plot.stacks = player.plot.stacks.filter(
        (stack) =>
          (stack.revealed && stack.revealed.length > 0) ||
          (stack.hidden && stack.hidden.length > 0)
      );
    }
  }
}
