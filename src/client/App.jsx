import React, { useState } from 'react';
import { Client } from 'boardgame.io/react';
import { Local } from 'boardgame.io/multiplayer';
import { MCTSBot } from 'boardgame.io/ai';
import { KolkhozGame } from '../game/index.js';
import { Board } from './Board.jsx';

// Create local client with AI bots for players 1-3
const KolkhozClient = Client({
  game: KolkhozGame,
  board: Board,
  numPlayers: 4,
  multiplayer: Local({
    bots: {
      '1': MCTSBot,
      '2': MCTSBot,
      '3': MCTSBot,
    },
  }),
  debug: false,
});

export function App() {
  const [gameStarted, setGameStarted] = useState(false);
  const [variants, setVariants] = useState({
    deckType: 36,
    nomenclature: true,
    ordenNachalniku: true,
  });

  if (!gameStarted) {
    return (
      <div className="lobby">
        <h1>Колхоз</h1>
        <h2>Пятилетка</h2>

        <div className="variant-options">
          <h3>Game Options</h3>

          <label>
            <input
              type="radio"
              name="deckType"
              checked={variants.deckType === 36}
              onChange={() => setVariants({ ...variants, deckType: 36 })}
            />
            36-card deck (Classic)
          </label>

          <label>
            <input
              type="radio"
              name="deckType"
              checked={variants.deckType === 52}
              onChange={() => setVariants({ ...variants, deckType: 52 })}
            />
            52-card deck (With job rewards)
          </label>

          <label>
            <input
              type="checkbox"
              checked={variants.nomenclature}
              onChange={(e) => setVariants({ ...variants, nomenclature: e.target.checked })}
            />
            Nomenclature (Face card special effects)
          </label>
        </div>

        <button onClick={() => setGameStarted(true)}>
          Start Game
        </button>
      </div>
    );
  }

  return <KolkhozClient playerID="0" />;
}
