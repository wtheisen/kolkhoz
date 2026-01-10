import React from 'react';
import { translations, t, getJobName } from '../../translations.js';
import SuitIcon from '../SuitIcon.jsx';
import './RequisitionOverlay.css';

export function RequisitionOverlay({
  requisitionData,
  year,
  language,
  onContinue,
}) {
  const hasHero = requisitionData?.heroIdx !== undefined && requisitionData?.heroIdx !== -1;
  const heroName = requisitionData?.heroIdx === 0
    ? t(translations, language, 'you')
    : requisitionData?.heroName;

  return (
    <div className={`requisition-continue-overlay ${hasHero ? 'has-hero' : ''}`}>
      {/* Hero of the Soviet Union Banner */}
      {hasHero && (
        <div className="hero-announcement">
          <div className="hero-medal">
            <div className="medal-star">★</div>
            <div className="medal-rays">
              {[...Array(12)].map((_, i) => (
                <div key={i} className="medal-ray" style={{ '--ray-index': i }} />
              ))}
            </div>
          </div>
          <div className="hero-text">
            <div className="hero-title">{t(translations, language, 'heroOfSovietUnion')}</div>
            <div className="hero-name">{heroName}</div>
            <div className="hero-subtitle">{t(translations, language, 'heroAchievement')}</div>
            <div className="hero-immunity">
              <span className="immunity-shield">🛡</span>
              {t(translations, language, 'heroImmune', { name: heroName })}
            </div>
          </div>
        </div>
      )}

      <div className="requisition-summary">
        <h3>{t(translations, language, 'yearComplete', { year })}</h3>
        {requisitionData?.failedJobs?.length > 0 && (
          <p className="failed-jobs">
            {t(translations, language, 'failed')}{' '}
            {requisitionData.failedJobs.map((suit, idx) => (
              <span key={suit} className="failed-job-suit">
                <SuitIcon suit={suit} className="suit-symbol" />
                {idx < requisitionData.failedJobs.length - 1 ? ' ' : ''}
              </span>
            ))}
          </p>
        )}
        {requisitionData?.exiledCards?.length > 0 && (
          <p className="exiled-count">
            {t(translations, language, 'cardsToNorth')} {requisitionData.exiledCards.length}
          </p>
        )}
        {(!requisitionData?.failedJobs?.length && !requisitionData?.exiledCards?.length) && (
          <p className="no-exile">{t(translations, language, 'allJobsComplete')}</p>
        )}
      </div>

      <button className="continue-btn" onClick={onContinue}>
        {t(translations, language, 'continueToYear', { year: year + 1 })}
      </button>
    </div>
  );
}

export default RequisitionOverlay;
