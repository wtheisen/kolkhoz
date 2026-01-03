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
  // Include variants in deps so Client recreates if variants change before start
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
  }, [gameStarted, variants]);

  const [showRules, setShowRules] = useState(false);

  if (!gameStarted) {
    return (
      <div className="lobby">
        {/* Left: Title + Buttons */}
        <div className="lobby-left">
          <div className="lobby-title">
            <h1 title="Kolkhoz - Collective Farm">Колхоз</h1>
            <h2 title="Pyatiletka - Five-Year Plan">Пятилетка</h2>
          </div>
          <div className="lobby-buttons">
            <button className="start-btn" onClick={() => setGameStarted(true)}>
              Start Game
            </button>
            <button
              className={`rules-btn ${showRules ? 'active' : ''}`}
              onClick={() => setShowRules(!showRules)}
            >
              {showRules ? 'Options' : 'Rules'}
            </button>
          </div>
        </div>

        {/* Right: Variant options OR Rules */}
        <div className="lobby-right-panel">
          {showRules ? (
            <div className="rules-panel">
              <h3>Kolkhoz Rules</h3>
              <div className="rules-text">
                <h4>Objective</h4>
                <p>Complete collective farm jobs while protecting your private plot. Highest score wins!</p>
                <h4>Gameplay</h4>
                <p>• Play cards to tricks - must follow lead suit if able</p>
                <p>• Trick winner assigns cards to matching job suits</p>
                <p>• Jobs need 40 work hours to complete</p>
                <h4>Trump Face Cards</h4>
                <p>• <strong>Jack (Пьяница)</strong>: Worth 0, gets exiled instead of your cards</p>
                <p>• <strong>Queen (Доносчик)</strong>: All players become vulnerable</p>
                <p>• <strong>King (Чиновник)</strong>: Exiles two cards instead of one</p>
                <h4>Scoring</h4>
                <p>Cards in your plot = your score. Highest score wins!</p>
              </div>
            </div>
          ) : (
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
            <strong title="Nomenklatura - The Party Elite">Номенклатура</strong> - Face card special effects
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
            <strong title="Severny Stil - Northern Style">Северный стиль</strong> - No job rewards, all vulnerable
          </label>

          <label>
            <input
              type="checkbox"
              checked={variants.miceVariant}
              onChange={(e) => setVariants({ ...variants, miceVariant: e.target.checked })}
            />
            <strong title="Myshi - Mice">Мыши</strong> - All reveal during requisition
          </label>

          <label>
            <input
              type="checkbox"
              checked={variants.ordenNachalniku}
              onChange={(e) => setVariants({ ...variants, ordenNachalniku: e.target.checked })}
            />
            <strong title="Orden Nachalniku - Medal for the Boss">Орден Начальнику</strong> - Stack cards on job complete
          </label>

          <label>
            <input
              type="checkbox"
              checked={variants.medalsCount}
              onChange={(e) => setVariants({ ...variants, medalsCount: e.target.checked })}
            />
            <strong title="Medali - Medals">Медали</strong> - Trick wins add to score
          </label>

          {variants.deckType === 52 && (
            <label>
              <input
                type="checkbox"
                checked={variants.accumulateJobs}
                onChange={(e) => setVariants({ ...variants, accumulateJobs: e.target.checked })}
              />
              <strong title="Nakoplenie - Accumulation">Накопление</strong> - Job rewards carry over
            </label>
          )}
            </div>
          )}
        </div>
      </div>
    );
  }

  return <KolkhozClient playerID="0" setupData={{ variants }} />;
}
