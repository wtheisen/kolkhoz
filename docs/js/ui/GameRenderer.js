// GameRenderer - converts Jinja2 templates to JavaScript template literals
// Ported from templates/game.html

import { SUITS } from '../core/constants.js';

export class GameRenderer {
  constructor(containerElement) {
    this.container = containerElement;
  }

  renderGame(gameState) {
    this.container.innerHTML = `
      <div class="page-wrapper">
        ${this._renderHeader(gameState)}
        <div class="container">
          ${this._renderGameBoard(gameState)}
        </div>
        ${this._renderRulesModal()}
      </div>
    `;

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
            ${game.phase === 'assignment' && game.players[game.lastWinner]?.isHuman ? this._renderAssignmentModal(game) : ''}
            ${game.phase === 'swap' && game.currentSwapPlayer === 0 ? this._renderSwapModal(game) : ''}
          </div>
        </section>

        ${game.phase === 'game_over' ? this._renderGameOver(game) : ''}
      </main>
    `;
  }

  _renderJobsAndTrump(game) {
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
            
            return `
              <div class="job">
                ${game.workHours[suit] >= 40
                  ? '<img src="assets/card_back.png" alt="back" class="card-image">'
                  : game.gameVariants.accumulateUnclaimedJobs && remainingCards > 0
                    ? `<div class="job-rewards-container">
                        <div class="job-pile-remaining">
                          ${Array(remainingCards).fill(0).map((_, index) => `
                            <div class="job-pile-card" style="--pile-index: ${index}">
                              <img src="assets/card_back.png" alt="back" class="card-image">
                            </div>
                          `).join('')}
                        </div>
                        <div class="job-rewards-fanned">
                          ${rewardCards.map((card, index) => `
                            <div class="job-reward-card" style="--fan-index: ${index}">
                              ${this._cardImage(card)}
                            </div>
                          `).join('')}
                        </div>
                      </div>`
                    : isArray && rewardCards.length > 1
                      ? `<div class="job-rewards-fanned">
                          ${rewardCards.map((card, index) => `
                            <div class="job-reward-card" style="--fan-index: ${index}">
                              ${this._cardImage(card)}
                            </div>
                          `).join('')}
                        </div>`
                      : this._cardImage(rewardCards[0])
                }
                <span>
                  ${game.workHours[suit]}/40
                  ${this._renderJobEffects(game, suit)}
                </span>
                <div class="job-cards">
                  ${assignedCards.map((card, index) => `
                    <div class="job-card" style="--index: ${index}">
                      ${this._cardImage(card)}
                    </div>
                  `).join('')}
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
    const exiledArray = Array.from(game.exiled);
    return `
      <div class="game-info-right">
        <h3>ГУЛАГ:</h3>
        <div class="gulag-cards">
          ${exiledArray.map((key, index) => {
            const [suit, value] = key.split('-');
            const card = { suit, value: parseInt(value) };
            return `<div class="gulag-card" style="--index: ${index}">${this._cardImageFromData(card)}</div>`;
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
              ${player.brigadeLeader || player.medals > 0 ? '<img src="assets/medal_icon.png" class="medal-icon" alt="Medal" />' : ''}
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
              ${player.brigadeLeader || player.medals > 0 ? '<img src="assets/medal_icon.png" class="medal-icon" alt="Medal" />' : ''}
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
                ${player.brigadeLeader ? '<img src="assets/medal.svg" class="medal-icon" alt="Brigade Leader" />' : ''}
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
                ${player.brigadeLeader ? '<img src="assets/medal.svg" class="medal-icon" alt="Brigade Leader" />' : ''}
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
    // Get the lead suit from the first card played (if any)
    const leadSuit = game.currentTrick.length > 0 ? game.currentTrick[0][1].suit : null;

    return `
      <div class="trick-area-wrapper">
        ${leadSuit ? `
          <div class="lead-suit-indicator">
            <span style="color: #fff; font-size: 12px; margin-right: 4px;">Lead:</span>
            ${this._suitImage(leadSuit)}
          </div>
        ` : ''}
        <div class="trick-area" id="trick-area">
          ${game.currentTrick.length === 0 ? `
            <div style="color: #fff; font-size: 1.2em; text-align: center;">
              Waiting for first card...
            </div>
          ` : game.currentTrick.map(([pid, card]) => `
            <div class="card">
              <div class="card-player">${game.players[pid].name}</div>
              ${this._cardImage(card)}
            </div>
          `).join('')}
        </div>
      </div>
    `;
  }

  _renderAssignmentModal(game) {
    const validJobs = Array.from(new Set(
      game.lastTrick.map(([_, card]) => card.suit)
    ));

    return `
      <div class="assignment-overlay">
        <div class="assignment-modal">
          <h3 style="text-align:center;">Assign Workers</h3>
          <form id="assignment-form" style="display: flex; gap: 24px; justify-content: center; align-items: flex-end;">
            ${game.lastTrick.map(([pid, card], idx) => `
              <div style="display: flex; flex-direction: column; align-items: center;">
                ${this._cardImage(card)}
                <select name="assign_${idx}" style="margin-top: 8px;">
                  ${validJobs.map(suit =>
                    `<option value="${suit}">${suit}</option>`
                  ).join('')}
                </select>
              </div>
            `).join('')}
            <button class="button" type="submit" style="align-self: flex-end; margin-left: 16px;">
              Assign
            </button>
          </form>
        </div>
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

  _renderGameOver(game) {
    const finalScores = game.finalScores;

    return `
      <section class="game-over">
        <h3>Game Over</h3>
        <ul>
          ${game.players.map((player, idx) => `
            <li>${player.name}: ${finalScores[idx]}</li>
          `).join('')}
        </ul>
        <button class="button" id="new-game">New Game</button>
      </section>
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
    // Drag and drop for human player
    document.querySelectorAll('.draggable').forEach(card => {
      card.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('card-index', card.dataset.cardIndex);
        card.classList.add('dragging');
      });
      card.addEventListener('dragend', (e) => {
        card.classList.remove('dragging');
      });
    });

    const trickArea = document.getElementById('trick-area');
    if (trickArea) {
      trickArea.addEventListener('dragover', (e) => {
        e.preventDefault();
        trickArea.classList.add('dragover');
      });
      trickArea.addEventListener('dragleave', () => {
        trickArea.classList.remove('dragover');
      });
      trickArea.addEventListener('drop', (e) => {
        e.preventDefault();
        trickArea.classList.remove('dragover');
        const cardIndex = parseInt(e.dataTransfer.getData('card-index'));
        if (!isNaN(cardIndex)) {
          this.onCardPlayed(cardIndex);
        }
      });
    }

    // Assignment form
    const assignForm = document.getElementById('assignment-form');
    if (assignForm) {
      assignForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const formData = new FormData(assignForm);
        const mapping = new Map();

        game.lastTrick.forEach(([pid, card], idx) => {
          mapping.set(card, formData.get(`assign_${idx}`));
        });

        this.onAssignmentSubmitted(mapping);
      });
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

  // Event handler stubs - implemented by controller
  onCardPlayed(cardIndex) {}
  onAssignmentSubmitted(mapping) {}
  onSwapSubmitted(hiddenIndex, handIndex) {}
  onNewGame() {}
}
