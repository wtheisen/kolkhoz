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
          ${this._renderHistory(gameState)}
          ${this._renderGameBoard(gameState)}
        </div>
      </div>
    `;

    // Attach event listeners after rendering
    this._attachGameEventListeners(gameState);
  }

  _renderHeader(game) {
    console.log('[GameRenderer] Rendering header with trump:', game.trump);
    return `
      <header class="topbar">
        <div class="top-section">
          <strong>год ${game.year} of the Пятилетка</strong>
          <button class="button button-small" id="new-game-header">New Game</button>
        </div>
        <div class="top-section">
          <span>Наша главная задача: ${game.trump}</span>
          ${this._suitImage(game.trump)}
        </div>

        <div class="top-section jobs">
          ${SUITS.map(suit => `
            <div class="job">
              ${game.workHours[suit] >= 40
                ? '<img src="assets/cards/back.svg" alt="back" class="card-image">'
                : this._cardImage(game.revealedJobs[suit])
              }
              <span>
                ${game.workHours[suit]}/40
                ${this._renderJobEffects(game, suit)}
              </span>
            </div>
          `).join('')}
        </div>

        <div class="top-section jobs">
          <h3>ГУЛАГ:</h3>
          ${Array.from(game.exiled).map(key => {
            const [suit, value] = key.split('-');
            const card = { suit, value: parseInt(value) };
            return `<div class="job"><div class="card">${this._cardImageFromData(card)}</div></div>`;
          }).join('')}
        </div>
      </header>
    `;
  }

  _renderJobEffects(game, suit) {
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
    // Group by year
    const grouped = {};
    for (const entry of game.trickHistory) {
      if (!grouped[entry.year]) grouped[entry.year] = [];
      grouped[entry.year].push(entry);
    }

    const years = Object.keys(grouped).sort((a, b) => b - a);

    return `
      <aside class="history">
        <h3>взятка History</h3>
        ${years.map(year => `
          <h4>год ${year}</h4>
          ${grouped[year].slice().reverse().map((entry, idx) => `
            <div class="trick-entry">
              ${this._renderHistoryEntry(entry, game, idx)}
            </div>
          `).join('')}
        `).join('')}
      </aside>
    `;
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
            ${this._renderPlayerArea(game, 1, 'top')}
            ${this._renderPlayerArea(game, 2, 'left')}
            ${this._renderPlayerArea(game, 3, 'right')}
            ${this._renderPlayerArea(game, 0, 'bottom')}
            ${this._renderTrickArea(game)}
            ${game.phase === 'assignment' ? this._renderAssignmentModal(game) : ''}
          </div>
        </section>

        ${game.phase === 'game_over' ? this._renderGameOver(game) : ''}
      </main>
    `;
  }

  _renderPlayerArea(game, playerIdx, position) {
    const player = game.players[playerIdx];
    const isHuman = player.isHuman;
    const scores = game.scores;

    return `
      <div class="player-area ${position}">
        ${position === 'top' || position === 'bottom' ? `
          ${position === 'top' ? `
            <div class="player-plot" id="player-${playerIdx}-plot">
              ${player.plot.revealed.map(c => this._cardImage(c)).join('')}
              ${player.plot.hidden.map(c =>
                '<img src="assets/cards/back.svg" class="card-image" />'
              ).join('')}
              ${Array(player.plot.medals).fill(0).map(() =>
                '<img src="assets/medal.svg" class="medal-image" alt="Medal" />'
              ).join('')}
            </div>
          ` : ''}

          <div class="player-hand ${isHuman ? 'human-hand' : 'opponent-hand'}" id="player-${playerIdx}-hand">
            ${isHuman
              ? player.hand.map((card, idx) => `
                  <span class="draggable" draggable="true" data-card-index="${idx}">
                    ${this._cardImage(card)}
                  </span>
                `).join('')
              : player.hand.map(() =>
                  '<img src="assets/cards/back.svg" class="card-image" />'
                ).join('')
            }
            <div class="player-name">${player.name}</div>
          </div>

          ${position === 'bottom' ? `
            <div class="player-plot" id="player-${playerIdx}-plot">
              ${player.plot.revealed.map(c => this._cardImage(c)).join('')}
              ${player.plot.hidden.map(c => this._cardImage(c)).join('')}
              ${Array(player.plot.medals).fill(0).map(() =>
                '<img src="assets/medal.svg" class="medal-image" alt="Medal" />'
              ).join('')}
            </div>
          ` : ''}

          <div class="player-score">
            <strong>${player.name}: ${scores[playerIdx]}</strong>
            ${player.brigadeLeader ? '<img src="assets/medal.svg" class="medal-icon" alt="Brigade Leader" />' : ''}
            ${player.medals > 0 ? ` <span class="year-medals">(${player.medals} 🏅)</span>` : ''}
          </div>
        ` : `
          ${position === 'left' ? `
            <div class="player-plot" id="player-${playerIdx}-plot">
              ${player.plot.revealed.map(c => this._cardImage(c)).join('')}
              ${player.plot.hidden.map(c =>
                '<img src="assets/cards/back.svg" class="card-image" />'
              ).join('')}
              ${Array(player.plot.medals).fill(0).map(() =>
                '<img src="assets/medal.svg" class="medal-image" alt="Medal" />'
              ).join('')}
            </div>
          ` : ''}

          <div class="player-hand ${position} opponent-hand" id="player-${playerIdx}-hand">
            <div>
              ${player.hand.map(() =>
                '<img src="assets/cards/back.svg" class="card-image" />'
              ).join('')}
              <div class="player-name" style="writing-mode: vertical-lr;">${player.name}</div>
            </div>
          </div>

          ${position === 'right' ? `
            <div class="player-plot" id="player-${playerIdx}-plot">
              ${player.plot.revealed.map(c => this._cardImage(c)).join('')}
              ${player.plot.hidden.map(c =>
                '<img src="assets/cards/back.svg" class="card-image" />'
              ).join('')}
              ${Array(player.plot.medals).fill(0).map(() =>
                '<img src="assets/medal.svg" class="medal-image" alt="Medal" />'
              ).join('')}
            </div>
          ` : ''}

          <div class="player-info">
            <div class="player-score">
              <strong>${player.name}: ${scores[playerIdx]}</strong>
              ${player.brigadeLeader ? '<img src="assets/medal.svg" class="medal-icon" alt="Brigade Leader" />' : ''}
              ${player.medals > 0 ? ` <span class="year-medals">(${player.medals} 🏅)</span>` : ''}
            </div>
          </div>
        `}
      </div>
    `;
  }

  _renderTrickArea(game) {
    if (game.currentTrick.length === 0) {
      return `
        <div class="trick-area" id="trick-area">
          <div style="color: #fff; font-size: 1.2em; text-align: center;">
            Waiting for first card...
          </div>
        </div>
      `;
    }

    return `
      <div class="trick-area" id="trick-area">
        ${game.currentTrick.map(([pid, card]) => `
          <div class="card">
            <div class="card-player">${game.players[pid].name}</div>
            ${this._cardImage(card)}
          </div>
        `).join('')}
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

    // New game buttons (both in game-over screen and header)
    const newGameBtn = document.getElementById('new-game');
    if (newGameBtn) {
      newGameBtn.addEventListener('click', () => this.onNewGame());
    }

    const newGameHeaderBtn = document.getElementById('new-game-header');
    if (newGameHeaderBtn) {
      newGameHeaderBtn.addEventListener('click', () => this.onNewGame());
    }
  }

  // Event handler stubs - implemented by controller
  onCardPlayed(cardIndex) {}
  onAssignmentSubmitted(mapping) {}
  onNewGame() {}
}
