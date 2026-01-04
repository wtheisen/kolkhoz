import React from 'react';
import { translations, t } from '../../translations.js';
import './OptionsPanel.css';

export function OptionsPanel({ language }) {
  return (
    <div className="mobile-panel-content">
      <div className="options-panel">
        <h3>{t(translations, language, 'menu')}</h3>
        <div className="menu-options">
          <div className="rules-section">
            <h4>{t(translations, language, 'rules')}</h4>
            <div className="rules-text">
              <h5>{t(translations, language, 'objective')}</h5>
              <p>{t(translations, language, 'objectiveText')}</p>
              <h5>{t(translations, language, 'gameplay')}</h5>
              <p>• {t(translations, language, 'gameplayRule1')}</p>
              <p>• {t(translations, language, 'gameplayRule2')}</p>
              <p>• {t(translations, language, 'gameplayRule3')}</p>
              <h5>{t(translations, language, 'trumpFaceCards')}</h5>
              <p>• <strong>Jack ({t(translations, language, 'jackName')})</strong>: {t(translations, language, 'jackDesc')}</p>
              <p>• <strong>Queen ({t(translations, language, 'queenName')})</strong>: {t(translations, language, 'queenDesc')}</p>
              <p>• <strong>King ({t(translations, language, 'kingName')})</strong>: {t(translations, language, 'kingDesc')}</p>
            </div>
          </div>
          <button className="menu-btn-action" onClick={() => window.location.reload()}>
            {t(translations, language, 'newGame')}
          </button>
        </div>
      </div>
    </div>
  );
}

export default OptionsPanel;
