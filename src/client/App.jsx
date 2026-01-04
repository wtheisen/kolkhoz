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
    variants: null, // Uses current variants state
  },
};

// Variant explanations (Russian primary, English as tooltip)
const VARIANT_INFO = {
  nomenclature: {
    name: 'Номенклатура',
    nameEn: 'Nomenclature',
    desc: 'Козырные фигуры имеют особые силы: Валет ссылается, Дама раскрывает всех, Король удваивает ссылку',
    descEn: 'Trump face cards have special powers: Jack gets exiled, Queen exposes everyone, King doubles exile',
  },
  allowSwap: {
    name: 'Обмен',
    nameEn: 'Swap',
    desc: 'Обмен картами между рукой и участком в начале каждого года',
    descEn: 'Swap cards between your hand and plot at the start of each year',
  },
  northernStyle: {
    name: 'Северный стиль',
    nameEn: 'Northern Style',
    desc: 'Нет наград за выполнение работ — все остаются уязвимы для реквизиции',
    descEn: 'No rewards for completing jobs - everyone stays vulnerable to requisition',
  },
  miceVariant: {
    name: 'Мыши',
    nameEn: 'Mice',
    desc: 'Все игроки раскрывают весь участок при реквизиции, а не только подходящие карты',
    descEn: 'All players reveal their entire plot during requisition, not just matching cards',
  },
  ordenNachalniku: {
    name: 'Орден Начальнику',
    nameEn: 'Order to the Boss',
    desc: 'Карты, назначенные на выполненные работы, накапливаются как бонусные награды',
    descEn: 'Cards assigned to completed jobs stack as bonus rewards',
  },
  medalsCount: {
    name: 'Медали',
    nameEn: 'Medals',
    desc: 'Победы во взятках учитываются в итоговом счёте',
    descEn: 'Trick victories count toward your final score',
  },
  heroOfSovietUnion: {
    name: 'Герой',
    nameEn: 'Hero of Soviet Union',
    desc: 'Выиграй все 4 взятки за год — получи иммунитет от реквизиции',
    descEn: 'Win all 4 tricks in a year to become immune from requisition',
  },
  accumulateJobs: {
    name: 'Накопление',
    nameEn: 'Accumulation',
    desc: 'Невостребованные награды за работы переносятся на следующий год',
    descEn: 'Unclaimed job rewards carry over to the next year',
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
                  </div>
                ))}
              </div>

              {/* Variant Details - show for all presets */}
              <div className="variant-details">
                {selectedPreset === 'custom' ? (
                  /* Editable options for Custom */
                  <div className="custom-options">
                    <div className="variant-row">
                      <span className="variant-label" title="Deck">Колода:</span>
                      <label className="radio-option" title="52 cards">
                        <input
                          type="radio"
                          name="deckType"
                          checked={customVariants.deckType === 52}
                          onChange={() => setCustomVariants({ ...customVariants, deckType: 52 })}
                        />
                        52 карты
                      </label>
                      <label className="radio-option" title="36 cards">
                        <input
                          type="radio"
                          name="deckType"
                          checked={customVariants.deckType === 36}
                          onChange={() => setCustomVariants({ ...customVariants, deckType: 36 })}
                        />
                        36 карт
                      </label>
                    </div>

                    <div className="variant-list">
                      {Object.entries(VARIANT_INFO).map(([key, info]) => {
                        // Hide accumulateJobs for 36-card deck
                        if (key === 'accumulateJobs' && customVariants.deckType === 36) return null;
                        return (
                          <label key={key} className="variant-item" title={info.descEn}>
                            <input
                              type="checkbox"
                              checked={customVariants[key]}
                              onChange={(e) => setCustomVariants({ ...customVariants, [key]: e.target.checked })}
                            />
                            <div className="variant-item-content">
                              <span className="variant-item-name" title={info.nameEn}>{info.name}</span>
                              <span className="variant-item-desc">{info.desc}</span>
                            </div>
                          </label>
                        );
                      })}
                    </div>
                  </div>
                ) : (
                  /* Read-only display for presets */
                  <div className="preset-summary">
                    <div className="variant-row">
                      <span className="variant-label">Колода:</span>
                      <span className="variant-value" title={`${variants.deckType} cards`}>{variants.deckType} карт</span>
                    </div>
                    <div className="variant-list">
                      {Object.entries(VARIANT_INFO).map(([key, info]) => {
                        if (!variants[key]) return null;
                        return (
                          <div key={key} className="variant-item enabled" title={info.descEn}>
                            <span className="variant-check">✓</span>
                            <div className="variant-item-content">
                              <span className="variant-item-name" title={info.nameEn}>{info.name}</span>
                              <span className="variant-item-desc">{info.desc}</span>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>
    );
  }

  return <KolkhozClient playerID="0" />;
}
