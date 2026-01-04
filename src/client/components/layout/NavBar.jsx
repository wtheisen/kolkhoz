import React from 'react';
import { NavIcon } from '../SuitIcon.jsx';
import { translations, t } from '../../translations.js';
import './NavBar.css';

export function NavBar({
  activePanel,
  displayMode,
  actionView,
  language,
  onTogglePanel,
  onSetActivePanel,
  onToggleLanguage,
}) {
  return (
    <div className="mobile-nav-bar">
      <button
        className={`nav-btn ${activePanel === 'options' ? 'active' : ''}`}
        onClick={() => onTogglePanel('options')}
        title={t(translations, language, 'menu')}
      >
        <NavIcon type="menu" />
        <span className="nav-label">{t(translations, language, 'menu')}</span>
      </button>
      <button
        className={`nav-btn ${displayMode === 'game' && activePanel !== 'options' ? 'active' : ''} ${actionView === 'game' ? 'has-action' : ''}`}
        onClick={() => onSetActivePanel(null)}
        title={t(translations, language, 'brigade')}
      >
        <NavIcon type="brigade" />
        <span className="nav-label">{t(translations, language, 'brigade')}</span>
      </button>
      <button
        className={`nav-btn ${displayMode === 'jobs' ? 'active' : ''} ${actionView === 'jobs' ? 'has-action' : ''}`}
        onClick={() => onTogglePanel('jobs')}
        title={t(translations, language, 'jobs')}
      >
        <NavIcon type="fields" />
        <span className="nav-label">{t(translations, language, 'jobs')}</span>
      </button>
      <button
        className={`nav-btn ${displayMode === 'gulag' ? 'active' : ''}`}
        onClick={() => onTogglePanel('gulag')}
        title={t(translations, language, 'theNorth')}
        data-nav="gulag"
      >
        <NavIcon type="north" />
        <span className="nav-label">{t(translations, language, 'theNorth')}</span>
      </button>
      <button
        className={`nav-btn ${displayMode === 'plot' ? 'active' : ''} ${actionView === 'plot' ? 'has-action' : ''}`}
        onClick={() => onTogglePanel('plot')}
        title={t(translations, language, 'plot')}
      >
        <NavIcon type="cellar" />
        <span className="nav-label">{t(translations, language, 'plot')}</span>
      </button>
      <button
        className="nav-btn lang-toggle"
        onClick={onToggleLanguage}
        title={t(translations, language, 'toggleLanguage')}
      >
        <span className="nav-icon lang-flag">{language === 'en' ? 'RU' : 'EN'}</span>
        <span className="nav-label">{language === 'en' ? 'Русский' : 'English'}</span>
      </button>
    </div>
  );
}

export default NavBar;
