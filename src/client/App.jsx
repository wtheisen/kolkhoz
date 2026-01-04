import React, { useState, useMemo } from 'react';
import { Client } from 'boardgame.io/react';
import { Local } from 'boardgame.io/multiplayer';
import { MCTSBot } from 'boardgame.io/ai';
import { EffectsBoardWrapper } from 'bgio-effects/react';
import { KolkhozGame } from '../game/index.js';
import { Board } from './Board.jsx';
import { DEFAULT_VARIANTS } from '../game/constants.js';

// Preset configurations
const PRESETS = {
  kolkhoz: {
    name: 'Колхоз',
    nameEn: 'Kolkhoz',
    description: '52 cards, classic rules',
    variants: {
      deckType: 52,
      nomenclature: true,
      allowSwap: true,
      northernStyle: false,
      miceVariant: false,
      ordenNachalniku: false,
      medalsCount: false,
      accumulateJobs: false,
      heroOfSovietUnion: true,
    },
  },
  littleKolkhoz: {
    name: 'Колхозик',
    nameEn: 'Little Kolkhoz',
    description: '36 cards, stacking rewards',
    variants: {
      deckType: 36,
      nomenclature: true,
      allowSwap: true,
      northernStyle: false,
      miceVariant: false,
      ordenNachalniku: true,
      medalsCount: false,
      accumulateJobs: false,
      heroOfSovietUnion: false,
    },
  },
  campStyle: {
    name: 'Лагерный',
    nameEn: 'Camp Style',
    description: '36 cards, no rewards, mice',
    variants: {
      deckType: 36,
      nomenclature: true,
      allowSwap: true,
      northernStyle: true,
      miceVariant: true,
      ordenNachalniku: false,
      medalsCount: false,
      accumulateJobs: false,
      heroOfSovietUnion: true,
    },
  },
  custom: {
    name: 'Свой',
    nameEn: 'Custom',
    description: 'Mix and match',
    variants: null, // Uses current variants state
  },
};

// Wrap Board with effects - delays state updates until animations complete
const BoardWithEffects = EffectsBoardWrapper(Board, {
  updateStateAfterEffects: true,
});

export function App() {
  const [gameStarted, setGameStarted] = useState(false);
  const [selectedPreset, setSelectedPreset] = useState('kolkhoz');
  const [customVariants, setCustomVariants] = useState({ ...DEFAULT_VARIANTS });

  // Get active variants based on selected preset
  const variants = selectedPreset === 'custom'
    ? customVariants
    : PRESETS[selectedPreset].variants;

  // Handle preset selection
  const handlePresetSelect = (presetKey) => {
    setSelectedPreset(presetKey);
    if (presetKey !== 'custom' && PRESETS[presetKey].variants) {
      setCustomVariants({ ...PRESETS[presetKey].variants });
    }
  };

  // Callback to return to lobby for a new game
  const handleNewGame = () => setGameStarted(false);

  // Create client dynamically with selected variants
  // setupData must be passed in Client config, not as component prop
  const KolkhozClient = useMemo(() => {
    if (!gameStarted) return null;
    return Client({
      game: KolkhozGame,
      board: (props) => <BoardWithEffects {...props} onNewGame={handleNewGame} />,
      numPlayers: 4,
      multiplayer: Local({
        bots: {
          '1': MCTSBot,
          '2': MCTSBot,
          '3': MCTSBot,
        },
      }),
      debug: false,
      setupData: { variants },
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
              {/* Preset Selection Cards */}
              <div className="preset-cards">
                {Object.entries(PRESETS).map(([key, preset]) => (
                  <div
                    key={key}
                    className={`preset-card ${selectedPreset === key ? 'selected' : ''}`}
                    onClick={() => handlePresetSelect(key)}
                  >
                    <div className="preset-badge">
                      <div className="preset-star">★</div>
                      <div className="preset-name" title={preset.nameEn}>{preset.name}</div>
                    </div>
                    <div className="preset-ribbon">
                      <span className="preset-description">{preset.description}</span>
                    </div>
                  </div>
                ))}
              </div>

              {/* Custom Options - only show when Custom is selected */}
              {selectedPreset === 'custom' && (
                <div className="custom-options">
                  <h3>Deck Type</h3>

                  <label>
                    <input
                      type="radio"
                      name="deckType"
                      checked={customVariants.deckType === 52}
                      onChange={() => setCustomVariants({ ...customVariants, deckType: 52 })}
                    />
                    52-card deck (Classic)
                  </label>

                  <label>
                    <input
                      type="radio"
                      name="deckType"
                      checked={customVariants.deckType === 36}
                      onChange={() => setCustomVariants({ ...customVariants, deckType: 36 })}
                    />
                    36-card deck (Camp-style)
                  </label>

                  <h3>Variant Rules</h3>

                  <label>
                    <input
                      type="checkbox"
                      checked={customVariants.nomenclature}
                      onChange={(e) => setCustomVariants({ ...customVariants, nomenclature: e.target.checked })}
                    />
                    <strong title="Nomenklatura - The Party Elite">Номенклатура</strong> - Face card special effects
                  </label>

                  <label>
                    <input
                      type="checkbox"
                      checked={customVariants.allowSwap}
                      onChange={(e) => setCustomVariants({ ...customVariants, allowSwap: e.target.checked })}
                    />
                    <strong title="Obmen - Exchange">Обмен</strong> - Swap hand/plot cards at year start
                  </label>

                  <label>
                    <input
                      type="checkbox"
                      checked={customVariants.northernStyle}
                      onChange={(e) => setCustomVariants({ ...customVariants, northernStyle: e.target.checked })}
                    />
                    <strong title="Severny Stil - Northern Style">Северный стиль</strong> - No job rewards, all vulnerable
                  </label>

                  <label>
                    <input
                      type="checkbox"
                      checked={customVariants.miceVariant}
                      onChange={(e) => setCustomVariants({ ...customVariants, miceVariant: e.target.checked })}
                    />
                    <strong title="Myshi - Mice">Мыши</strong> - All reveal during requisition
                  </label>

                  <label>
                    <input
                      type="checkbox"
                      checked={customVariants.ordenNachalniku}
                      onChange={(e) => setCustomVariants({ ...customVariants, ordenNachalniku: e.target.checked })}
                    />
                    <strong title="Orden Nachalniku - Medal for the Boss">Орден Начальнику</strong> - Stack cards on job complete
                  </label>

                  <label>
                    <input
                      type="checkbox"
                      checked={customVariants.medalsCount}
                      onChange={(e) => setCustomVariants({ ...customVariants, medalsCount: e.target.checked })}
                    />
                    <strong title="Medali - Medals">Медали</strong> - Trick wins add to score
                  </label>

                  <label>
                    <input
                      type="checkbox"
                      checked={customVariants.heroOfSovietUnion}
                      onChange={(e) => setCustomVariants({ ...customVariants, heroOfSovietUnion: e.target.checked })}
                    />
                    <strong title="Geroy Sovetskogo Soyuza - Hero of the Soviet Union">Герой Советского Союза</strong> - Win all 4 tricks = immune
                  </label>

                  {customVariants.deckType === 52 && (
                    <label>
                      <input
                        type="checkbox"
                        checked={customVariants.accumulateJobs}
                        onChange={(e) => setCustomVariants({ ...customVariants, accumulateJobs: e.target.checked })}
                      />
                      <strong title="Nakoplenie - Accumulation">Накопление</strong> - Job rewards carry over
                    </label>
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    );
  }

  return <KolkhozClient playerID="0" />;
}
