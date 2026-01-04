import React from 'react';
import { getCardImagePath } from '../../../game/Card.js';
import { translations, t } from '../../translations.js';
import './GulagView.css';

export function GulagView({ exiled, year, language }) {
  const parseCardKey = (cardKey) => {
    const [suit, value] = cardKey.split('-');
    return { suit, value: parseInt(value, 10) };
  };

  // Generate snow effect
  const hasWind = Math.random() > 0.4;
  const windDirection = Math.random() > 0.5 ? 1 : -1;
  const snowflakeCount = hasWind
    ? 60 + Math.floor(Math.random() * 21)
    : 40 + Math.floor(Math.random() * 16);

  return (
    <div className="gulag-view">
      {/* Snow effect */}
      <div className="snow-container">
        {Array.from({ length: snowflakeCount }).map((_, i) => {
          const windStrength = hasWind ? 50 + Math.random() * 100 : 0;
          return (
            <div
              key={i}
              className={`snowflake ${hasWind ? 'windy' : ''}`}
              style={{
                '--delay': `${Math.random() * 10}s`,
                '--duration': `${5 + Math.random() * 10}s`,
                '--x-start': `${Math.random() * 100}%`,
                '--x-drift': `${-20 + Math.random() * 40}px`,
                '--size': `${2 + Math.random() * 4}px`,
                '--opacity': `${0.3 + Math.random() * 0.7}`,
                '--wind-strength': `${windStrength * windDirection}px`,
                '--wind-mid': `${(windStrength * 0.5 + Math.random() * 30) * windDirection}px`,
                '--wiggle': `${2 + Math.random() * 4}px`,
              }}
            />
          );
        })}
      </div>
      <div className="gulag-header">
        <h2 className="view-title">{t(translations, language, 'theNorth')}</h2>
      </div>
      <div className="gulag-columns">
        {[1, 2, 3, 4, 5].map((yr) => {
          const yearCards = exiled?.[yr] || [];
          const isCurrent = yr === year;

          return (
            <div key={yr} className={`gulag-column ${isCurrent ? 'current' : ''}`}>
              <div className="column-header">
                <span className="year-number">{t(translations, language, 'year')} {yr}</span>
                {yearCards.length > 0 && <span className="card-count">{yearCards.length}</span>}
              </div>
              <div className="column-cards">
                {yearCards.map((cardKey, idx) => {
                  const card = parseCardKey(cardKey);
                  return (
                    <img
                      key={idx}
                      src={getCardImagePath(card)}
                      alt={`${card.value} of ${card.suit}`}
                      className="exiled-card"
                    />
                  );
                })}
                {yearCards.length === 0 && (
                  <div className="empty-column">—</div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export default GulagView;
