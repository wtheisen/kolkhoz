// GameStorage - localStorage persistence layer

import { GameState } from '../core/GameState.js';

export class GameStorage {
  static STORAGE_KEY = 'kolkhoz_game_state';
  static VERSION = 1;

  static save(gameState) {
    try {
      const data = gameState.toJSON();
      localStorage.setItem(
        GameStorage.STORAGE_KEY,
        JSON.stringify(data)
      );
      return true;
    } catch (e) {
      console.error('Failed to save game:', e);
      if (e.name === 'QuotaExceededError') {
        alert('Storage full. Cannot save game.');
      }
      return false;
    }
  }

  static load() {
    try {
      const json = localStorage.getItem(GameStorage.STORAGE_KEY);
      if (!json) return null;

      const data = JSON.parse(json);

      // Handle version migrations
      const migrated = GameStorage._migrate(data);

      const game = GameState.fromJSON(migrated);

      // Validate loaded game
      if (!GameStorage._validate(game)) {
        throw new Error('Invalid game state');
      }

      return game;
    } catch (e) {
      console.error('Failed to load game:', e);

      // Offer to user
      if (confirm('Save game is corrupted. Start a new game?')) {
        GameStorage.clear();
        return null;
      } else {
        throw e;
      }
    }
  }

  static exists() {
    return localStorage.getItem(GameStorage.STORAGE_KEY) !== null;
  }

  static clear() {
    localStorage.removeItem(GameStorage.STORAGE_KEY);
  }

  static _migrate(data) {
    // Handle version migrations
    let currentVersion = data.version || 0;

    if (currentVersion === 0) {
      // Migration from version 0 to 1
      data.version = 1;
      currentVersion = 1;
    }

    // Update human player name from "Player" to "игрок" if needed
    if (data.players && Array.isArray(data.players)) {
      for (const player of data.players) {
        if (player.isHuman && player.name === 'Player') {
          player.name = 'игрок';
        }
      }
    }

    // Future migrations go here

    return data;
  }

  static _validate(game) {
    // Basic validation
    if (!(game instanceof GameState)) return false;
    if (game.year < 1 || game.year > 5) return false;
    if (game.players.length !== game.numPlayers) return false;

    return true;
  }

  static exportGame() {
    const json = localStorage.getItem(GameStorage.STORAGE_KEY);
    if (!json) return null;

    // Create downloadable file
    const blob = new Blob([json], { type: 'application/json' });
    const url = URL.createObjectURL(blob);

    const a = document.createElement('a');
    a.href = url;
    a.download = `kolkhoz_save_${Date.now()}.json`;
    a.click();

    URL.revokeObjectURL(url);
  }

  static async importGame(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        try {
          const data = JSON.parse(e.target.result);
          localStorage.setItem(
            GameStorage.STORAGE_KEY,
            JSON.stringify(data)
          );
          resolve(GameState.fromJSON(data));
        } catch (err) {
          reject(err);
        }
      };
      reader.onerror = reject;
      reader.readAsText(file);
    });
  }

  static isSupported() {
    try {
      const test = '__storage_test__';
      localStorage.setItem(test, test);
      localStorage.removeItem(test);
      return true;
    } catch (e) {
      return false;
    }
  }
}
