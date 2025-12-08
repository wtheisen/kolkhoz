// GameRenderer - converts Jinja2 templates to JavaScript template literals
// Ported from templates/game.html

import { SUITS } from '../core/constants.js';
// Import touchHandler - if import fails, the module won't load, so we'll handle that gracefully
import { touchHandler } from './TouchHandler.js';

export class GameRenderer {
  constructor(containerElement) {
    this.container = containerElement;
    this.assignmentMap = new Map(); // Track card assignments during assignment phase
  }

  renderGame(gameState) {
    this.container.innerHTML = `
      <div class="page-wrapper">
        ${this._renderHeader(gameState)}
        <div class="container">
          ${this._renderGameBoard(gameState)}
        </div>
        ${this._renderRulesModal()}
        ${gameState.phase === 'game_over' ? this._renderGameOverModal(gameState) : ''}
      </div>
    `;

    // Add class to game-table during assignment phase for styling
    const gameTable = this.container.querySelector('.game-table');
    if (gameTable) {
      if (gameState.phase === 'assignment') {
        gameTable.classList.add('assignment-phase');
      } else {
        gameTable.classList.remove('assignment-phase');
      }
    }

    // Attach event listeners after rendering
    this._attachGameEventListeners(gameState);
  }

  _renderHeader(game) {
    // Topbar removed - year tracker and new game button moved to game-info-left
    return '';
  }

  _renderJobEffects(game, suit) {
    // Only show special effects if the variant is enabled
    if (!game.gameVariants || !game.gameVariants.specialEffects) {
      return '';
    }

    const bucket = game.jobBuckets[suit] || [];
    const effects = bucket
      .filter(c => c.suit === game.trump && [11, 12, 13].includes(c.value))
      .map(c => {
        if (c.value === 11) return '<p>Пьяница</p>';
        if (c.value === 12) return '<p>Информатор</p>';
        if (c.value === 13) return '<p>Партийный чиновник</p>';
        return '';
      });
    return effects.join('');
  }

  _renderHistory(game) {
    // History sidebar removed - tricks are now shown on the table for current year only
    return '';
  }

  _renderHistoryEntry(entry, game, idx) {
    if (entry.type === 'requisition') {
      return `
        <strong>Ищут врагов народа:</strong>
        <strong>${entry.requisitions.join(', ')}</strong>
      `;
    } else if (entry.type === 'jobs') {
      return `
        <strong>работы for Year ${entry.year}</strong>
        <div class="history-hand">
          ${Object.entries(entry.jobs).map(([suit, hours]) => `
            <div class="history-card">
              ${this._suitImage(suit)}
              <div class="card-player">${hours}</div>
            </div>
          `).join('')}
        </div>
      `;
    } else {
      // Trick entry
      return `
        <strong>взятка – Бригадир: ${game.players[entry.winner].name}</strong>
        <div class="history-hand">
          ${entry.plays.map(([pid, card]) => `
            <div class="history-card">
              <div class="card-player">${game.players[pid].name}</div>
              ${this._cardImage(card)}
            </div>
          `).join('')}
        </div>
      `;
    }
  }

  _renderGameBoard(game) {
    return `
      <main class="main">
        <section class="current-trick">
          <h3>взятка:</h3>
          <div class="game-table">
            ${this._renderJobsAndTrump(game)}
            ${this._renderPlayerArea(game, 1, 'top', 'left')}
            ${this._renderPlayerArea(game, 2, 'top', 'center')}
            ${this._renderPlayerArea(game, 3, 'top', 'right')}
            ${this._renderPlayerArea(game, 0, 'bottom')}
            ${this._renderTrickArea(game)}
            ${this._renderGulag(game)}
            ${game.phase === 'swap' && game.currentSwapPlayer === 0 ? this._renderSwapModal(game) : ''}
          </div>
        </section>

      </main>
    `;
  }

  _renderJobsAndTrump(game) {
    const isAssignmentPhase = game.phase === 'assignment';
    const validJobs = isAssignmentPhase ? Array.from(new Set(
      game.lastTrick.map(([_, card]) => card.suit)
    )) : [];
    
    return `
      <div class="game-info-left">
        <div class="year-tracker">
          <strong>год ${game.year} of the Пятилетка</strong>
        </div>
        <div class="trump-info">
          <span>Наша главная задача:</span>
          ${this._suitImage(game.trump)}
        </div>
        <div class="jobs-info">
          ${SUITS.map(suit => {
            const assignedCards = game.jobBuckets[suit] || [];
            const jobRewards = game.revealedJobs[suit];
            const isArray = Array.isArray(jobRewards);
            const rewardCards = isArray ? jobRewards : [jobRewards];
            const remainingCards = game.jobPiles[suit] ? game.jobPiles[suit].length : 0;
            const isClaimed = game.workHours[suit] >= 40;
            const isValidDropTarget = isAssignmentPhase && validJobs.includes(suit);
            
            return `
              <div class="job ${isValidDropTarget ? 'job-drop-target' : ''}" 
                   ${isValidDropTarget ? `data-job-suit="${suit}"` : ''}>
                ${isClaimed
                  ? // Job claimed: show fan of remaining face-down cards from pile
                    remainingCards > 1
                      ? `<div class="job-rewards-fanned">
                          ${Array(remainingCards).fill(0).map((_, index) => `
                            <div class="job-reward-card" style="--fan-index: ${index}">
                              <img src="assets/card_back.png" alt="back" class="card-image">
                            </div>
                          `).join('')}
                        </div>`
                      : remainingCards === 1
                        ? '<img src="assets/card_back.png" alt="back" class="card-image">'
                        : '<img src="assets/card_back.png" alt="back" class="card-image">'
                  : // Job not claimed: show revealed job cards
                    game.gameVariants.accumulateUnclaimedJobs && remainingCards > 0
                      ? `<div class="job-rewards-container">
                          ${Array(remainingCards).fill(0).map((_, index) => `
                            <div class="job-pile-card" style="--pile-index: ${index}">
                              <img src="assets/card_back.png" alt="back" class="card-image">
                            </div>
                          `).join('')}
                          ${rewardCards.map((card, index) => {
                            // Continue the fan from where face-down cards left off
                            const fanIndex = remainingCards + index;
                            return `
                              <div class="job-reward-card" style="--fan-index: ${fanIndex}">
                                ${this._cardImage(card)}
                              </div>
                            `;
                          }).join('')}
                        </div>`
                      : isArray && rewardCards.length > 1
                        ? `<div class="job-rewards-fanned">
                            ${rewardCards.map((card, index) => `
                              <div class="job-reward-card" style="--fan-index: ${index}">
                                ${this._cardImage(card)}
                              </div>
                            `).join('')}
                          </div>`
                        : rewardCards.length > 0
                          ? this._cardImage(rewardCards[0])
                          : '<img src="assets/card_back.png" alt="back" class="card-image">'
                }
                <span>
                  ${game.workHours[suit]}/40
                  ${this._renderJobEffects(game, suit)}
                </span>
                <div class="job-cards-container">
                  ${isValidDropTarget ? `
                    <div class="job-drop-zone" data-job-suit="${suit}">
                      <div class="job-drop-zone-label">Drop workers here</div>
                    </div>
                  ` : ''}
                  <div class="job-cards">
                    ${assignedCards.map((card, index) => `
                      <div class="job-card" style="--index: ${index}">
                        ${this._cardImage(card)}
                      </div>
                    `).join('')}
                  </div>
                </div>
              </div>
            `;
          }).join('')}
        </div>
      </div>
      <div class="game-controls">
        <button class="button button-small" id="rules-button">Rules</button>
        <button class="button button-small" id="new-game-header">New Game</button>
      </div>
    `;
  }

  _renderGulag(game) {
    // Group exiled cards by year
    const years = Object.keys(game.exiled || {})
      .map(y => parseInt(y))
      .sort((a, b) => a - b);
    
    return `
      <div class="game-info-right">
        <h3>ГУЛАГ:</h3>
        <div class="gulag-container">
          ${years.map(year => {
            const yearCards = game.exiled[year] || [];
            return `
              <div class="gulag-year-group">
                <div class="gulag-year-label">год ${year}</div>
                <div class="gulag-cards">
                  ${yearCards.map((key, index) => {
                    const [suit, value] = key.split('-');
                    const card = { suit, value: parseInt(value) };
                    return `<div class="gulag-card" style="--index: ${index}">${this._cardImageFromData(card)}</div>`;
                  }).join('')}
                </div>
              </div>
            `;
          }).join('')}
        </div>
      </div>
    `;
  }

  _renderPlayerArea(game, playerIdx, position, horizontalPosition = null) {
    const player = game.players[playerIdx];
    const isHuman = player.isHuman;
    const scores = game.scores;
    const isCentralPlanner = playerIdx === game.lead;
    const emblemIcon = isCentralPlanner ? '<img src="assets/emblem.svg" class="emblem-icon" alt="Central Planner" />' : '';
    
    // Calculate whose turn it is to play
    const isCurrentTurn = game.phase === 'trick' && 
                          game.currentTrick.length < game.numPlayers &&
                          playerIdx === (game.lead + game.currentTrick.length) % game.numPlayers;
    const turnIcon = isCurrentTurn ? '<img src="assets/player.svg" class="player-icon" alt="Current Turn" />' : '';

    const horizontalClass = horizontalPosition ? ` top-${horizontalPosition}` : '';

    return `
      <div class="player-area ${position}${horizontalClass}">
        ${position === 'top' || position === 'bottom' ? `
          ${position === 'top' ? `
            <div class="player-plot" id="player-${playerIdx}-plot">
              ${player.plot.revealed.map(c => this._cardImage(c)).join('')}
              ${player.plot.hidden.map(c =>
                '<img src="assets/card_back.png" class="card-image" />'
              ).join('')}
              ${Array(player.plot.medals).fill(0).map(() =>
                '<img src="assets/cards/medal.png" class="medal-image" alt="Medal" />'
              ).join('')}
            </div>
            <div class="player-score">
              <strong>${player.name}: ${scores[playerIdx]}</strong>${emblemIcon}${turnIcon}
              ${(player.hasWonTrickThisYear === true) ? '<img src="assets/medal_icon.png" class="medal-icon" alt="Medal" />' : ''}
            </div>
            <div class="player-hand ${isHuman ? 'human-hand' : 'opponent-hand'}" id="player-${playerIdx}-hand">
              ${isHuman
                ? player.hand.map((card, idx) => `
                    <span class="draggable" draggable="true" data-card-index="${idx}">
                      ${this._cardImage(card)}
                    </span>
                  `).join('')
                : player.hand.map(() =>
                    '<img src="assets/card_back.png" class="card-image" />'
                  ).join('')
              }
            </div>
          ` : `
            <div class="player-hand ${isHuman ? 'human-hand' : 'opponent-hand'}" id="player-${playerIdx}-hand">
              ${isHuman
                ? player.hand.map((card, idx) => `
                    <span class="draggable" draggable="true" data-card-index="${idx}">
                      ${this._cardImage(card)}
                    </span>
                  `).join('')
                : player.hand.map(() =>
                    '<img src="assets/card_back.png" class="card-image" />'
                  ).join('')
              }
            </div>
            <div class="player-score">
              <strong>${player.name}: ${scores[playerIdx]}</strong>${emblemIcon}${turnIcon}
              ${(player.hasWonTrickThisYear === true) ? '<img src="assets/medal_icon.png" class="medal-icon" alt="Medal" />' : ''}
            </div>
            <div class="player-plot" id="player-${playerIdx}-plot">
              ${player.plot.revealed.map(c => this._cardImage(c)).join('')}
              ${player.plot.hidden.map(c => this._cardImage(c)).join('')}
              ${Array(player.plot.medals).fill(0).map(() =>
                '<img src="assets/cards/medal.png" class="medal-image" alt="Medal" />'
              ).join('')}
            </div>
          `}
        ` : `
          ${position === 'left' ? `
            <div class="player-plot" id="player-${playerIdx}-plot">
              ${player.plot.revealed.map(c => this._cardImage(c)).join('')}
              ${player.plot.hidden.map(c =>
                '<img src="assets/card_back.png" class="card-image" />'
              ).join('')}
              ${Array(player.plot.medals).fill(0).map(() =>
                '<img src="assets/cards/medal.png" class="medal-image" alt="Medal" />'
              ).join('')}
            </div>
            <div class="player-info">
              <div class="player-score">
                <strong>${player.name}: ${scores[playerIdx]}</strong>${emblemIcon}${turnIcon}
                ${(player.hasWonTrickThisYear === true) ? '<img src="assets/medal.svg" class="medal-icon" alt="Medal" />' : ''}
                ${player.medals > 0 ? ` <span class="year-medals">(${player.medals} 🏅)</span>` : ''}
              </div>
            </div>
            <div class="player-hand ${position} opponent-hand" id="player-${playerIdx}-hand">
              <div>
                ${player.hand.map(() =>
                  '<img src="assets/card_back.png" class="card-image" />'
                ).join('')}
              </div>
            </div>
          ` : `
            <div class="player-hand ${position} opponent-hand" id="player-${playerIdx}-hand">
              <div>
                ${player.hand.map(() =>
                  '<img src="assets/card_back.png" class="card-image" />'
                ).join('')}
              </div>
            </div>
            <div class="player-info">
              <div class="player-score">
                <strong>${player.name}: ${scores[playerIdx]}</strong>${emblemIcon}${turnIcon}
                ${(player.hasWonTrickThisYear === true) ? '<img src="assets/medal.svg" class="medal-icon" alt="Medal" />' : ''}
                ${player.medals > 0 ? ` <span class="year-medals">(${player.medals} 🏅)</span>` : ''}
              </div>
            </div>
            <div class="player-plot" id="player-${playerIdx}-plot">
              ${player.plot.revealed.map(c => this._cardImage(c)).join('')}
              ${player.plot.hidden.map(c =>
                '<img src="assets/card_back.png" class="card-image" />'
              ).join('')}
              ${Array(player.plot.medals).fill(0).map(() =>
                '<img src="assets/cards/medal.png" class="medal-image" alt="Medal" />'
              ).join('')}
            </div>
          `}
        `}
      </div>
    `;
  }

  _renderTrickArea(game) {
    const isAssignmentPhase = game.phase === 'assignment' && game.players[game.lastWinner]?.isHuman;
    const trickToShow = isAssignmentPhase ? game.lastTrick : game.currentTrick;
    const leadSuit = trickToShow.length > 0 ? trickToShow[0][1].suit : null;

    return `
      <div class="trick-area-wrapper">
        ${leadSuit && !isAssignmentPhase ? `
          <div class="lead-suit-indicator">
            <span style="color: #fff; font-size: 12px; margin-right: 4px;">Lead:</span>
            ${this._suitImage(leadSuit)}
          </div>
        ` : ''}
        ${isAssignmentPhase ? `
          <div class="assignment-instructions">
            <span style="color: #c9a961; font-size: 14px; font-weight: 600;">
              Drag cards to job piles to assign workers
            </span>
          </div>
        ` : ''}
        <div class="trick-area ${isAssignmentPhase ? 'assignment-trick-area' : ''}" id="trick-area">
          ${trickToShow.length === 0 ? `
            <div style="color: #fff; font-size: 1.2em; text-align: center;">
              Waiting for first card...
            </div>
          ` : trickToShow.map(([pid, card]) => {
            const cardKey = `${card.suit}-${card.value}`;
            const isAssigned = isAssignmentPhase && this.assignmentMap && this.assignmentMap.has(cardKey) && this.assignmentMap.get(cardKey) !== null;
            const assignedSuit = isAssigned ? this.assignmentMap.get(cardKey) : null;
            return `
            <div class="trick-card ${isAssignmentPhase ? 'assignment-card' : ''} ${isAssigned ? 'assigned' : ''}" 
                 ${isAssignmentPhase && !isAssigned ? `draggable="true"` : ''} 
                 data-card-key="${cardKey}" 
                 data-player-id="${pid}">
              <div class="card-player">${game.players[pid].name}</div>
              ${this._cardImage(card)}
              ${isAssignmentPhase ? `
                <div class="assignment-status" data-status="${isAssigned ? 'assigned' : 'unassigned'}">
                  ${isAssigned ? `Assigned to ${assignedSuit}` : 'Unassigned'}
                </div>
              ` : ''}
            </div>
          `;
          }).join('')}
        </div>
        ${isAssignmentPhase ? `
          <button class="button button-primary" id="complete-assignment" style="margin-top: 16px; display: none;">
            Complete Assignment
          </button>
        ` : ''}
      </div>
    `;
  }


  _renderSwapModal(game) {
    const player = game.players[0];
    
    if (player.plot.hidden.length === 0 || player.hand.length === 0) {
      // Can't swap, skip
      return '';
    }

    return `
      <div class="assignment-overlay">
        <div class="assignment-modal">
          <h3 style="text-align:center;">Swap Cards</h3>
          <p style="text-align:center; margin-bottom: 16px;">Choose one hidden card and one hand card to swap</p>
          <form id="swap-form" style="display: flex; gap: 24px; justify-content: center; align-items: flex-end;">
            <div style="display: flex; flex-direction: column; align-items: center;">
              <h4>Hidden Card</h4>
              <div style="display: flex; gap: 8px; margin-bottom: 8px;">
                ${player.plot.hidden.map((card, idx) => `
                  <label style="cursor: pointer;">
                    <input type="radio" name="hidden_card" value="${idx}" required>
                    <img src="assets/card_back.png" class="card-image" style="opacity: 0.7;">
                  </label>
                `).join('')}
              </div>
            </div>
            <div style="display: flex; flex-direction: column; align-items: center;">
              <h4>Hand Card</h4>
              <div style="display: flex; gap: 8px; margin-bottom: 8px;">
                ${player.hand.map((card, idx) => `
                  <label style="cursor: pointer;">
                    <input type="radio" name="hand_card" value="${idx}" required>
                    ${this._cardImage(card)}
                  </label>
                `).join('')}
              </div>
            </div>
            <div style="display: flex; flex-direction: column; gap: 8px;">
              <button type="submit" class="button button-primary">Swap</button>
              <button type="button" class="button button-secondary" id="skip-swap">Skip</button>
            </div>
          </form>
        </div>
      </div>
    `;
  }

  _renderGameOverModal(game) {
    const finalScores = game.finalScores;
    // Sort players by score (highest first)
    const sortedPlayers = game.players.map((player, idx) => ({
      name: player.name,
      score: finalScores[idx],
      idx: idx
    })).sort((a, b) => b.score - a.score);

    return `
      <div id="game-over-modal" class="modal" style="display: flex;">
        <div class="modal-backdrop"></div>
        <div class="modal-content game-over-modal-content">
          <div class="modal-header">
            <h2>Game Over</h2>
          </div>
          <div class="modal-body">
            <div class="game-over-scores">
              <h3>Final Scores</h3>
              <ul class="game-over-list">
                ${sortedPlayers.map((player, rank) => `
                  <li class="${rank === 0 ? 'winner' : ''}">
                    <span class="rank">${rank === 0 ? '🏆' : `#${rank + 1}`}</span>
                    <span class="player-name">${player.name}</span>
                    <span class="player-score">${player.score}</span>
                  </li>
                `).join('')}
              </ul>
            </div>
            <button class="button" id="new-game" style="margin-top: 24px; width: 100%;">New Game</button>
          </div>
        </div>
      </div>
    `;
  }

  _renderRulesModal() {
    return `
      <div id="rules-modal" class="modal" style="display: none;">
        <div class="modal-backdrop"></div>
        <div class="modal-content">
          <div class="modal-header">
            <h2>Game Rules</h2>
            <button class="modal-close" id="rules-modal-close">&times;</button>
          </div>
          <div class="modal-body">
            <div class="rules-section">
              <iframe src="https://docs.google.com/document/d/e/2PACX-1vT0wmZXS3b4hT7NXVtfzjqVbgCs-RUcKtCxoeAE9d71jKXUEy6iYJkw1FMjfxPrtzmwVQ1YWUY4C0cN/pub?embedded=true"
                      class="rules-iframe"
                      frameborder="0"></iframe>
            </div>
          </div>
        </div>
      </div>
    `;
  }

  _cardImage(card) {
    const faces = { 1: 'ace', 11: 'jack', 12: 'queen', 13: 'king' };
    const rank = faces[card.value] || card.value;
    return `<img src="assets/cards/${rank}_of_${card.suit.toLowerCase()}.svg" class="card-image" alt="${card.toString()}">`;
  }

  _cardImageFromData(cardData) {
    const faces = { 1: 'ace', 11: 'jack', 12: 'queen', 13: 'king' };
    const rank = faces[cardData.value] || cardData.value;
    return `<img src="assets/cards/${rank}_of_${cardData.suit.toLowerCase()}.svg" class="card-image">`;
  }

  _suitImage(suit) {
    const suitMap = {
      'Diamonds': 'diamond',
      'Spades': 'spade',
      'Hearts': 'heart',
      'Clubs': 'club'
    };
    const suitFile = suitMap[suit];
    if (!suitFile) {
      console.error('Invalid suit for image:', suit);
      return `<span style="color: red;">${suit}</span>`;
    }
    return `<img src="assets/cards/${suitFile}.svg" class="card-image" alt="${suit}">`;
  }

  _attachGameEventListeners(game) {
    // Drag and drop for human player hand reordering
    const humanHand = document.getElementById('player-0-hand');
    if (humanHand) {
      this._setupHandReordering(humanHand);
    }

    // Drag and drop for playing cards to trick area
    document.querySelectorAll('.draggable').forEach(card => {
      // HTML5 drag events (desktop)
      card.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('card-index', card.dataset.cardIndex);
        e.dataTransfer.effectAllowed = 'move';
        card.classList.add('dragging');
      });
      card.addEventListener('dragend', (e) => {
        card.classList.remove('dragging');
        // Clean up any drop indicators
        document.querySelectorAll('.drop-indicator').forEach(ind => ind.remove());
      });
      
      // Touch events (mobile) - wrapped in try-catch to prevent errors from breaking the page
      if (card.dataset.cardIndex !== undefined) {
        try {
          const cardIndex = parseInt(card.dataset.cardIndex);
          if (!isNaN(cardIndex) && touchHandler) {
            touchHandler.setupTouchDrag(
              card,
              // onDragStart
              () => {
                card.classList.add('dragging');
              },
              // onDrag
              (e) => {
                // Check if over trick area
                const trickArea = document.getElementById('trick-area');
                if (trickArea && game.phase !== 'assignment') {
                  const rect = trickArea.getBoundingClientRect();
                  const isOver = e.clientX >= rect.left && e.clientX <= rect.right &&
                                e.clientY >= rect.top && e.clientY <= rect.bottom;
                  if (isOver) {
                    trickArea.classList.add('dragover');
                    document.querySelectorAll('.drop-indicator').forEach(ind => ind.remove());
                  } else {
                    trickArea.classList.remove('dragover');
                  }
                }
              },
              // onDragEnd
              () => {
                card.classList.remove('dragging');
                document.querySelectorAll('.drop-indicator').forEach(ind => ind.remove());
                const trickArea = document.getElementById('trick-area');
                if (trickArea) {
                  trickArea.classList.remove('dragover');
                }
              },
              // onDrop
              (e) => {
                // Check if dropped on trick area
                const trickArea = document.getElementById('trick-area');
                if (trickArea && game.phase !== 'assignment') {
                  const rect = trickArea.getBoundingClientRect();
                  const isOver = e.clientX >= rect.left && e.clientX <= rect.right &&
                                e.clientY >= rect.top && e.clientY <= rect.bottom;
                  if (isOver && !isNaN(cardIndex)) {
                    document.querySelectorAll('.drop-indicator').forEach(ind => ind.remove());
                    this.onCardPlayed(cardIndex);
                  }
                }
              }
            );
          }
        } catch (error) {
          console.warn('[Renderer] Error setting up touch handler for card:', error);
        }
      }
    });

    const trickArea = document.getElementById('trick-area');
    if (trickArea && game.phase !== 'assignment') {
      // Only allow dropping cards to trick area when not in assignment phase
      // HTML5 drag events (desktop)
      trickArea.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        trickArea.classList.add('dragover');
        // Remove any drop indicators from hand when dragging to trick area
        document.querySelectorAll('.drop-indicator').forEach(ind => ind.remove());
      });
      trickArea.addEventListener('dragleave', (e) => {
        // Only remove dragover if we're actually leaving the trick area
        if (!trickArea.contains(e.relatedTarget)) {
          trickArea.classList.remove('dragover');
        }
      });
      trickArea.addEventListener('drop', (e) => {
        e.preventDefault();
        trickArea.classList.remove('dragover');
        const cardIndex = parseInt(e.dataTransfer.getData('card-index'));
        if (!isNaN(cardIndex)) {
          // Clean up any drop indicators
          document.querySelectorAll('.drop-indicator').forEach(ind => ind.remove());
          this.onCardPlayed(cardIndex);
        }
      });
      
      // Touch drop zone setup (mobile) - handled in card touch handlers above
    }

    // Assignment drag-and-drop (if in assignment phase)
    if (game.phase === 'assignment' && game.players[game.lastWinner]?.isHuman) {
      this._setupAssignmentDragAndDrop(game);
    }

    // Swap form
    const swapForm = document.getElementById('swap-form');
    if (swapForm) {
      swapForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const formData = new FormData(swapForm);
        const hiddenIndex = parseInt(formData.get('hidden_card'));
        const handIndex = parseInt(formData.get('hand_card'));
        
        if (!isNaN(hiddenIndex) && !isNaN(handIndex)) {
          this.onSwapSubmitted(hiddenIndex, handIndex);
        }
      });
    }

    // Skip swap button
    const skipSwapBtn = document.getElementById('skip-swap');
    if (skipSwapBtn) {
      skipSwapBtn.addEventListener('click', () => {
        // Skip swap by completing without swapping
        this.onSwapSubmitted(-1, -1);
      });
    }

    // New game buttons (both in game-over screen and header)
    const newGameBtn = document.getElementById('new-game');
    if (newGameBtn) {
      newGameBtn.addEventListener('click', () => this.onNewGame());
    }

    const newGameHeaderBtn = document.getElementById('new-game-header');
    if (newGameHeaderBtn) {
      newGameHeaderBtn.addEventListener('click', () => this.onNewGame());
    }

    // Rules modal
    const rulesModal = document.getElementById('rules-modal');
    const rulesButton = document.getElementById('rules-button');
    const rulesModalClose = document.getElementById('rules-modal-close');
    
    if (rulesButton && rulesModal) {
      rulesButton.addEventListener('click', () => {
        rulesModal.style.display = 'flex';
      });
    }

    if (rulesModalClose && rulesModal) {
      rulesModalClose.addEventListener('click', () => {
        rulesModal.style.display = 'none';
      });
    }

    if (rulesModal) {
      const backdrop = rulesModal.querySelector('.modal-backdrop');
      if (backdrop) {
        backdrop.addEventListener('click', () => {
          rulesModal.style.display = 'none';
        });
      }
    }
  }

  _setupHandReordering(handElement) {
    let draggedElement = null;
    let draggedIndex = null;

    handElement.addEventListener('dragstart', (e) => {
      if (!e.target.closest('.draggable')) return;
      
      draggedElement = e.target.closest('.draggable');
      draggedIndex = parseInt(draggedElement.dataset.cardIndex);
      draggedElement.classList.add('dragging');
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/html', draggedElement.outerHTML);
      
      // Create a semi-transparent clone for dragging
      const clone = draggedElement.cloneNode(true);
      clone.style.opacity = '0.5';
      e.dataTransfer.setDragImage(clone, 0, 0);
    });

    handElement.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      
      const afterElement = this._getDragAfterElement(handElement, e.clientX);
      const dropIndicator = handElement.querySelector('.drop-indicator');
      
      if (afterElement == null) {
        // Drop at the end
        if (dropIndicator) {
          dropIndicator.remove();
        }
        const indicator = document.createElement('div');
        indicator.className = 'drop-indicator';
        handElement.appendChild(indicator);
      } else {
        if (dropIndicator) {
          dropIndicator.remove();
        }
        const indicator = document.createElement('div');
        indicator.className = 'drop-indicator';
        afterElement.before(indicator);
      }
    });

    handElement.addEventListener('dragleave', (e) => {
      // Only remove indicator if we're leaving the hand area entirely
      if (!handElement.contains(e.relatedTarget)) {
        document.querySelectorAll('.drop-indicator').forEach(ind => ind.remove());
      }
    });

    handElement.addEventListener('drop', (e) => {
      e.preventDefault();
      
      const dropIndicator = handElement.querySelector('.drop-indicator');
      if (!dropIndicator || draggedIndex === null) {
        document.querySelectorAll('.drop-indicator').forEach(ind => ind.remove());
        if (draggedElement) {
          draggedElement.classList.remove('dragging');
        }
        draggedElement = null;
        draggedIndex = null;
        return;
      }

      const afterElement = this._getDragAfterElement(handElement, e.clientX);
      const cards = Array.from(handElement.querySelectorAll('.draggable'));
      let toIndex;

      if (afterElement == null) {
        // Drop at the end
        toIndex = cards.length - 1;
        // If we're dragging the last card, don't move it
        if (draggedIndex === toIndex) {
          dropIndicator.remove();
          draggedElement.classList.remove('dragging');
          draggedElement = null;
          draggedIndex = null;
          return;
        }
      } else {
        toIndex = parseInt(afterElement.dataset.cardIndex);
      }

      // Adjust toIndex if dragging from before the target
      if (draggedIndex < toIndex) {
        toIndex--;
      }

      // Remove indicator
      dropIndicator.remove();

      // Only reorder if position actually changed
      if (draggedIndex !== toIndex && toIndex >= 0 && toIndex < cards.length) {
        this.onHandReordered(draggedIndex, toIndex);
      }

      draggedElement.classList.remove('dragging');
      draggedElement = null;
      draggedIndex = null;
    });
  }

  _setupAssignmentDragAndDrop(game) {
    if (game.phase !== 'assignment' || !game.players[game.lastWinner]?.isHuman) {
      this.assignmentMap.clear();
      return;
    }

    // Initialize assignment tracking
    if (this.assignmentMap.size === 0) {
      game.lastTrick.forEach(([pid, card]) => {
        const cardKey = `${card.suit}-${card.value}`;
        this.assignmentMap.set(cardKey, null);
      });
    }

    const assignmentCards = document.querySelectorAll('.trick-card.assignment-card');
    const jobDropZones = document.querySelectorAll('.job-drop-zone');
    
    console.log('[Renderer] Setting up assignment drag and drop:', {
      assignmentCards: assignmentCards.length,
      jobDropZones: jobDropZones.length,
      phase: game.phase,
      lastWinner: game.lastWinner
    });

    // Helper function to handle assignment drop (used by both HTML5 and touch)
    const handleAssignmentDrop = (cardKey, suit) => {
      const cardElement = document.querySelector(`.trick-card[data-card-key="${cardKey}"]`);
      if (cardElement && !this.assignmentMap.get(cardKey)) {
        // Update assignment mapping
        this.assignmentMap.set(cardKey, suit);

        // Immediately add card to the job pile's fan for instant visual feedback
        const jobContainer = document.querySelector(`.job[data-job-suit="${suit}"]`) || 
                             document.querySelector(`.job-drop-zone[data-job-suit="${suit}"]`)?.closest('.job');
        if (jobContainer) {
          // Find the job-cards-container (it should exist from rendering)
          let jobCardsContainer = jobContainer.querySelector('.job-cards-container');
          if (!jobCardsContainer) {
            // Create it if it doesn't exist (shouldn't happen, but just in case)
            jobCardsContainer = document.createElement('div');
            jobCardsContainer.className = 'job-cards-container';
            // Insert it after the work hours span
            const workHoursSpan = jobContainer.querySelector('span');
            if (workHoursSpan) {
              workHoursSpan.parentNode.insertBefore(jobCardsContainer, workHoursSpan.nextSibling);
            }
          }
          
          // Find or create the job-cards fan
          let jobCards = jobCardsContainer.querySelector('.job-cards');
          if (!jobCards) {
            jobCards = document.createElement('div');
            jobCards.className = 'job-cards';
            // Insert it after the drop zone if it exists, otherwise just append
            const dropZone = jobCardsContainer.querySelector('.job-drop-zone');
            if (dropZone) {
              dropZone.parentNode.insertBefore(jobCards, dropZone.nextSibling);
            } else {
              jobCardsContainer.appendChild(jobCards);
            }
          }
          
          // Get the card data from the trick
          const trickEntry = game.lastTrick.find(([p, c]) => `${c.suit}-${c.value}` === cardKey);
          if (trickEntry) {
            const [pid, card] = trickEntry;
            
            // Update work hours counter immediately
            const workHoursSpan = jobContainer.querySelector('span');
            if (workHoursSpan) {
              // Parse current hours from text (format: "XX/40" possibly followed by job effects)
              const currentText = workHoursSpan.innerHTML;
              const match = currentText.match(/(\d+)\/40/);
              if (match) {
                const currentHours = parseInt(match[1], 10);
                // Check if this is a drunkard (Jack of trump) - skip work hours if special effects enabled
                const isDrunkard = game.gameVariants.specialEffects && card.value === 11 && card.suit === game.trump;
                if (!isDrunkard) {
                  const newHours = currentHours + card.value;
                  // Preserve any job effects HTML that might be after the hours
                  const jobEffects = workHoursSpan.querySelector('p');
                  const effectsHTML = jobEffects ? jobEffects.outerHTML : '';
                  workHoursSpan.innerHTML = `${newHours}/40${effectsHTML}`;
                }
              }
            }
            
            // Create a new job card element
            const jobCard = document.createElement('div');
            jobCard.className = 'job-card';
            const currentCardCount = jobCards.querySelectorAll('.job-card').length;
            jobCard.style.setProperty('--index', currentCardCount);
            
            // Add the card image using the same method as rendering
            const faces = { 1: 'ace', 11: 'jack', 12: 'queen', 13: 'king' };
            const rank = faces[card.value] || card.value;
            const cardImg = document.createElement('img');
            cardImg.src = `assets/cards/${rank}_of_${card.suit.toLowerCase()}.svg`;
            cardImg.className = 'card-image';
            cardImg.alt = `${card.value} of ${card.suit}`;
            jobCard.appendChild(cardImg);
            
            // Apply the fan positioning transform based on index
            // This matches the CSS nth-child rules
            const index = currentCardCount;
            let transform = '';
            if (index === 0) {
              transform = 'translateX(-50%) rotate(-10deg) translateX(-35px)';
            } else if (index === 1) {
              transform = 'translateX(-50%) rotate(-5deg) translateX(-18px)';
            } else if (index === 2) {
              transform = 'translateX(-50%) rotate(0deg)';
            } else if (index === 3) {
              transform = 'translateX(-50%) rotate(5deg) translateX(18px)';
            } else if (index === 4) {
              transform = 'translateX(-50%) rotate(10deg) translateX(35px)';
            } else {
              // For 5+ cards, use calculated values
              const angle = index * 5 - 10;
              const offset = index * 17.5 - 35;
              transform = `translateX(-50%) rotate(${angle}deg) translateX(${offset}px)`;
            }
            
            // Add to the fan with animation
            jobCard.style.position = 'absolute';
            jobCard.style.left = '50%';
            jobCard.style.transformOrigin = 'center bottom';
            jobCard.style.opacity = '0';
            jobCard.style.transform = transform + ' scale(0.5)';
            jobCard.style.zIndex = index + 1;
            jobCards.appendChild(jobCard);
            
            // Animate it in
            requestAnimationFrame(() => {
              jobCard.style.transition = 'opacity 0.4s ease, transform 0.4s cubic-bezier(.4,2,.6,1)';
              jobCard.style.opacity = '1';
              jobCard.style.transform = transform;
            });
          }
        }

        // Update the card status in trick area without full re-render
        cardElement.classList.add('assigned');
        const statusEl = cardElement.querySelector('.assignment-status');
        if (statusEl) {
          statusEl.textContent = `Assigned to ${suit}`;
          statusEl.setAttribute('data-status', 'assigned');
        }
        cardElement.draggable = false;
        cardElement.style.display = 'none';
        
        // Check if all cards are assigned and show complete button
        const allAssigned = Array.from(this.assignmentMap.values()).every(s => s !== null);
        const completeBtn = document.getElementById('complete-assignment');
        if (completeBtn) {
          completeBtn.style.display = allAssigned ? 'block' : 'none';
        }
        
        // Don't re-render yet - wait for Complete Assignment button
        // This keeps the dynamically added cards visible
      }
    };

    // Make assignment cards draggable
    assignmentCards.forEach((card, index) => {
      const cardKey = card.dataset.cardKey;
      if (!cardKey) {
        console.warn('[Renderer] Card missing card-key attribute:', card);
        return;
      }
      
      const isAssigned = this.assignmentMap.get(cardKey) !== null;

      if (isAssigned) {
        card.setAttribute('draggable', 'false');
        card.style.display = 'none'; // Hide assigned cards
        return;
      }

      // Ensure card is draggable
      card.setAttribute('draggable', 'true');
      card.style.pointerEvents = 'auto';
      card.style.cursor = 'grab';
      
      // Store original state for restoration
      const originalOpacity = card.style.opacity || '1';
      const originalPointerEvents = card.style.pointerEvents || 'auto';

      // Create handlers that reference the card
      const dragStartHandler = (e) => {
        console.log('[Renderer] Drag start for card:', cardKey);
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('card-key', cardKey);
        
        // Add dragging class for styling
        card.classList.add('dragging');
        
        // Don't hide immediately - let CSS handle it with opacity
        // This prevents the drag from being cancelled
        card.style.transition = 'opacity 0.15s ease';
        
        // Use the card itself as drag image (browser default)
        // Or create a simple drag image
        const img = card.querySelector('img');
        if (img) {
          // Try using the image as drag image
          try {
            e.dataTransfer.setDragImage(img, img.offsetWidth / 2, img.offsetHeight / 2);
          } catch (err) {
            console.warn('[Renderer] Could not set drag image:', err);
          }
        }
        
        // Hide the card after a small delay to allow drag to start
        setTimeout(() => {
          card.style.opacity = '0';
          card.style.pointerEvents = 'none';
        }, 10);
      };

      const dragEndHandler = (e) => {
        console.log('[Renderer] Drag end for card:', cardKey, 'dropEffect:', e.dataTransfer.dropEffect);
        card.classList.remove('dragging');
        card.style.transition = '';
        // Remove dragover classes from all drop zones
        jobDropZones.forEach(zone => zone.classList.remove('dragover'));
        
        // Check if card was successfully assigned
        const wasAssigned = this.assignmentMap.get(cardKey) !== null;
        
        // If drag was cancelled (not dropped in valid zone), restore the card
        if (!wasAssigned && e.dataTransfer.dropEffect === 'none') {
          console.log('[Renderer] Drag cancelled, restoring card');
          card.style.opacity = originalOpacity;
          card.style.pointerEvents = originalPointerEvents;
        } else if (wasAssigned) {
          // Card was assigned, keep it hidden
          console.log('[Renderer] Card assigned, keeping hidden');
          card.style.display = 'none';
        } else {
          // Drag ended but assignment might happen in drop handler
          // Wait a bit to see if assignment happens
          setTimeout(() => {
            const stillAssigned = this.assignmentMap.get(cardKey) !== null;
            if (!stillAssigned) {
              console.log('[Renderer] Card not assigned after drop, restoring');
              card.style.opacity = originalOpacity;
              card.style.pointerEvents = originalPointerEvents;
            }
          }, 100);
        }
      };
      
      // Remove old listeners if they exist (by cloning to clear)
      const oldDragStart = card._dragStartHandler;
      const oldDragEnd = card._dragEndHandler;
      if (oldDragStart) card.removeEventListener('dragstart', oldDragStart);
      if (oldDragEnd) card.removeEventListener('dragend', oldDragEnd);
      
      // Store handlers and add listeners
      card._dragStartHandler = dragStartHandler;
      card._dragEndHandler = dragEndHandler;
      card.addEventListener('dragstart', dragStartHandler);
      card.addEventListener('dragend', dragEndHandler);
      
      // Add touch support for mobile - wrapped in try-catch
      try {
        if (touchHandler) {
          touchHandler.setupTouchDrag(
            card,
            // onDragStart
            () => {
              card.classList.add('dragging');
              card.style.transition = 'opacity 0.15s ease';
              setTimeout(() => {
                card.style.opacity = '0';
                card.style.pointerEvents = 'none';
              }, 10);
            },
            // onDrag
            (e) => {
              // Check if over any job drop zone
              jobDropZones.forEach(zone => {
                const rect = zone.getBoundingClientRect();
                const isOver = e.clientX >= rect.left && e.clientX <= rect.right &&
                              e.clientY >= rect.top && e.clientY <= rect.bottom;
                if (isOver) {
                  zone.classList.add('dragover');
                } else {
                  zone.classList.remove('dragover');
                }
              });
            },
            // onDragEnd
            () => {
              card.classList.remove('dragging');
              card.style.transition = '';
              jobDropZones.forEach(zone => zone.classList.remove('dragover'));
              
              // Check if card was successfully assigned
              const wasAssigned = this.assignmentMap.get(cardKey) !== null;
              if (!wasAssigned) {
                card.style.opacity = originalOpacity;
                card.style.pointerEvents = originalPointerEvents;
              } else {
                card.style.display = 'none';
              }
            },
            // onDrop
            (e) => {
              // Find which drop zone we're over
              let droppedOnZone = null;
              jobDropZones.forEach(zone => {
                const rect = zone.getBoundingClientRect();
                const isOver = e.clientX >= rect.left && e.clientX <= rect.right &&
                              e.clientY >= rect.top && e.clientY <= rect.bottom;
                if (isOver) {
                  droppedOnZone = zone;
                }
              });
              
              if (droppedOnZone && !this.assignmentMap.get(cardKey)) {
                const suit = droppedOnZone.dataset.jobSuit;
                droppedOnZone.classList.remove('dragover');
                handleAssignmentDrop(cardKey, suit);
              }
            }
          );
        }
      } catch (error) {
        console.warn('[Renderer] Error setting up touch handler for assignment card:', error);
      }
      
      console.log(`[Renderer] Set up drag for card ${index} (${cardKey}), draggable:`, card.getAttribute('draggable'));
    });

    // Make job drop zones drop targets
    jobDropZones.forEach(zone => {
      const suit = zone.dataset.jobSuit;

      zone.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        zone.classList.add('dragover');
      });

      zone.addEventListener('dragleave', (e) => {
        // Only remove if we're actually leaving the drop zone
        if (!zone.contains(e.relatedTarget)) {
          zone.classList.remove('dragover');
        }
      });

      zone.addEventListener('drop', (e) => {
        e.preventDefault();
        zone.classList.remove('dragover');

        const cardKey = e.dataTransfer.getData('card-key');
        handleAssignmentDrop(cardKey, suit);
      });
    });

    // Check if all cards are assigned and show complete button
    const allAssigned = Array.from(this.assignmentMap.values()).every(s => s !== null);
    const completeBtn = document.getElementById('complete-assignment');
    if (completeBtn) {
      completeBtn.style.display = allAssigned ? 'block' : 'none';
      
      // Remove existing listeners to avoid duplicates
      const newCompleteBtn = completeBtn.cloneNode(true);
      completeBtn.parentNode.replaceChild(newCompleteBtn, completeBtn);
      
      newCompleteBtn.addEventListener('click', () => {
        // Build mapping from assignments
        const mapping = new Map();
        game.lastTrick.forEach(([pid, card]) => {
          const cardKey = `${card.suit}-${card.value}`;
          const assignedSuit = this.assignmentMap.get(cardKey);
          if (assignedSuit) {
            mapping.set(card, assignedSuit);
          }
        });

        // Verify all cards are assigned
        if (mapping.size === game.lastTrick.length) {
          this.assignmentMap.clear(); // Clear tracking
          this.onAssignmentSubmitted(mapping);
        } else {
          console.warn('[Renderer] Not all cards assigned:', mapping.size, 'of', game.lastTrick.length);
        }
      });
    }
  }

  _getDragAfterElement(container, x) {
    const draggableElements = [...container.querySelectorAll('.draggable:not(.dragging)')];
    
    if (draggableElements.length === 0) {
      return null;
    }
    
    // For fanned layouts, find the element whose center is closest to the cursor
    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect();
      const centerX = box.left + box.width / 2;
      const offset = Math.abs(x - centerX);
      
      if (offset < closest.offset) {
        return { offset: offset, element: child };
      } else {
        return closest;
      }
    }, { offset: Number.POSITIVE_INFINITY, element: null }).element;
  }

  // Event handler stubs - implemented by controller
  onCardPlayed(cardIndex) {}
  onHandReordered(fromIndex, toIndex) {}
  onAssignmentSubmitted(mapping) {}
  onSwapSubmitted(hiddenIndex, handIndex) {}
  onNewGame() {}
}
