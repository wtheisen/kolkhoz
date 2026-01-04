import React from 'react';
import { translations, t, getJobName } from '../../translations.js';
import { SUITS } from '../../../game/constants.js';
import SuitIcon from '../SuitIcon.jsx';
import './TrumpSelection.css';

export function TrumpSelection({ onSetTrump, language }) {
  return (
    <div className="trump-selection">
      {/* Propaganda sunburst background */}
      <div className="trump-sunburst">
        {[...Array(24)].map((_, i) => (
          <div key={i} className="sunburst-ray" style={{ '--ray-index': i }} />
        ))}
      </div>

      {/* Central star decoration */}
      <div className="trump-star-decoration">★</div>

      {/* Header with Soviet styling */}
      <div className="trump-header">
        <div className="trump-header-line" />
        <h2 className="selection-title">
          {language === 'en' ? 'FIVE YEAR PLAN' : 'ПЯТИЛЕТНИЙ ПЛАН'}
        </h2>
        <h3 className="selection-subtitle">{t(translations, language, 'chooseMainTask')}</h3>
        <div className="trump-header-line" />
      </div>

      {/* Task selection buttons */}
      <div className="trump-buttons">
        {SUITS.map((suit, index) => (
          <button
            key={suit}
            className={`trump-btn ${suit.toLowerCase()}`}
            onClick={() => onSetTrump(suit)}
            style={{ '--btn-index': index }}
          >
            <div className="trump-btn-inner">
              <div className="trump-btn-badge">
                <span className="badge-star">★</span>
              </div>
              <SuitIcon suit={suit} className="suit-symbol" />
              <span className="suit-name">{getJobName(language, suit)}</span>
              <div className="trump-btn-quota">
                <span className="quota-label">{language === 'en' ? 'QUOTA' : 'ПЛАН'}</span>
                <span className="quota-value">40</span>
              </div>
            </div>
            <div className="trump-btn-corner tl" />
            <div className="trump-btn-corner tr" />
            <div className="trump-btn-corner bl" />
            <div className="trump-btn-corner br" />
          </button>
        ))}
      </div>

      {/* Bottom slogan */}
      <div className="trump-slogan">
        {language === 'en' ? '★ FOR THE GLORY OF THE COLLECTIVE ★' : '★ ВО СЛАВУ КОЛХОЗА ★'}
      </div>
    </div>
  );
}

export function TrumpWaiting({ currentPlayerName, language }) {
  return (
    <div className="trump-waiting">
      <span className="waiting-text">
        {currentPlayerName} {language === 'en' ? 'is choosing the main task...' : 'выбирает задание...'}
      </span>
    </div>
  );
}

export default TrumpSelection;
