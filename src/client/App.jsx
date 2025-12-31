import React, { useState, useMemo } from 'react';
import { Client } from 'boardgame.io/react';
import { Local } from 'boardgame.io/multiplayer';
import { MCTSBot } from 'boardgame.io/ai';
import { KolkhozGame } from '../game/index.js';
import { Board } from './Board.jsx';
import { DEFAULT_VARIANTS } from '../game/constants.js';

export function App() {
  const [gameStarted, setGameStarted] = useState(false);
  const [variants, setVariants] = useState({ ...DEFAULT_VARIANTS });

  // Create client dynamically with selected variants
  const KolkhozClient = useMemo(() => {
    if (!gameStarted) return null;
    return Client({
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
  }, [gameStarted]);

  if (!gameStarted) {
    return (
      <div className="lobby">
        <h1 title="Kolkhoz - Collective Farm">Колхоз</h1>
        <h2 title="Pyatiletka - Five-Year Plan">Пятилетка</h2>

        <div className="variant-options">
          <h3>Deck Type</h3>

          <label>
            <input
              type="radio"
              name="deckType"
              checked={variants.deckType === 52}
              onChange={() => setVariants({ ...variants, deckType: 52 })}
            />
            52-card deck (Classic)
          </label>

          <label>
            <input
              type="radio"
              name="deckType"
              checked={variants.deckType === 36}
              onChange={() => setVariants({ ...variants, deckType: 36 })}
            />
            36-card deck (Camp-style)
          </label>

          <h3>Variant Rules</h3>

          <label>
            <input
              type="checkbox"
              checked={variants.nomenclature}
              onChange={(e) => setVariants({ ...variants, nomenclature: e.target.checked })}
            />
            <strong title="Nomenklatura - The Party Elite">Номенклатура</strong> - Face card special effects (Drunkard Jack, etc.)
          </label>

          <label>
            <input
              type="checkbox"
              checked={variants.allowSwap}
              onChange={(e) => setVariants({ ...variants, allowSwap: e.target.checked })}
            />
            <strong title="Obmen - Exchange">Обмен</strong> - Swap hand/plot cards at year start
          </label>

          <label>
            <input
              type="checkbox"
              checked={variants.northernStyle}
              onChange={(e) => setVariants({ ...variants, northernStyle: e.target.checked })}
            />
            <strong title="Severny Stil - Northern Style">Северный стиль</strong> - Northern style (no job rewards, all vulnerable)
          </label>

          <label>
            <input
              type="checkbox"
              checked={variants.miceVariant}
              onChange={(e) => setVariants({ ...variants, miceVariant: e.target.checked })}
            />
            <strong title="Myshi - Mice">Мыши</strong> - Mice variant (all reveal during requisition)
          </label>

          <label>
            <input
              type="checkbox"
              checked={variants.ordenNachalniku}
              onChange={(e) => setVariants({ ...variants, ordenNachalniku: e.target.checked })}
            />
            <strong title="Orden Nachalniku - Medal for the Boss">Орден Начальнику</strong> - Stack cards when jobs complete (36-card only)
          </label>

          <label>
            <input
              type="checkbox"
              checked={variants.medalsCount}
              onChange={(e) => setVariants({ ...variants, medalsCount: e.target.checked })}
            />
            <strong title="Medali - Medals">Медали</strong> - Trick wins contribute to final score
          </label>

          {variants.deckType === 52 && (
            <label>
              <input
                type="checkbox"
                checked={variants.accumulateJobs}
                onChange={(e) => setVariants({ ...variants, accumulateJobs: e.target.checked })}
              />
              <strong title="Nakoplenie - Accumulation">Накопление</strong> - Unclaimed job rewards carry over to next year
            </label>
          )}
        </div>

        <button onClick={() => setGameStarted(true)}>
          Start Game
        </button>
      </div>
    );
  }

  return <KolkhozClient playerID="0" setupData={{ variants }} />;
}
