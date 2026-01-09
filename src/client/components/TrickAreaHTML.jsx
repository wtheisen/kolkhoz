import React from 'react';
import { translations, t, getJobName } from '../translations.js';
import { SUITS } from '../../game/constants.js';
import SuitIcon from './SuitIcon.jsx';
import { TrickView } from './views/TrickView.jsx';
import { JobsView } from './views/JobsView.jsx';
import { GulagView } from './views/GulagView.jsx';
import { PlotView } from './views/PlotView.jsx';
import { TrumpSelection, TrumpWaiting } from './overlays/TrumpSelection.jsx';
import './TrickAreaHTML.css';

// Helper to get requisition status message
function getRequisitionStatusMessage(language, currentRequisitionSuit, currentJobStage, requisitionStage) {
  if (requisitionStage === 'waiting' || !currentRequisitionSuit) {
    return null;
  }

  const jobName = getJobName(language, currentRequisitionSuit);

  if (currentJobStage === 'header') {
    return t(translations, language, 'checkingJob', { job: jobName });
  } else if (currentJobStage === 'revealing') {
    return t(translations, language, 'requisitionStatus', { job: jobName });
  } else if (currentJobStage === 'exiling') {
    return t(translations, language, 'requisitionStatus', { job: jobName });
  }

  return t(translations, language, 'requisition');
}

const FACE_CARD_SYMBOLS = { 11: 'J', 12: 'Q', 13: 'K' };

// Find trump face cards (J, Q, K) in a job bucket
function getTrumpFaceCardsInBucket(bucket, trump) {
  if (!trump || !bucket) return [];
  return bucket
    .filter(card => card.suit === trump && card.value >= 11 && card.value <= 13)
    .map(card => FACE_CARD_SYMBOLS[card.value]);
}

export function TrickAreaHTML({
  trick,
  numPlayers,
  year,
  trump,
  phase,
  isMyTurn,
  currentPlayerName,
  players,
  currentPlayer,
  brigadeLeader,
  displayMode = 'game',
  workHours,
  claimedJobs,
  jobBuckets,
  revealedJobs,
  exiled,
  playerPlot,
  onSetTrump,
  highlightedSuits = [],
  lastTrick = [],
  pendingAssignments = {},
  assignDragState,
  onAssignDragStart,
  jobDropRefs = { current: {} },
  onSubmitAssignments,
  // Swap phase props
  swapDragState,
  onSwapDragStart,
  plotDropRefs = { current: {} },
  swapConfirmed = {},
  currentSwapPlayer = null,
  lastSwap = null,
  // Requisition phase props
  requisitionData = null,
  requisitionStage = 'idle',
  currentRequisitionSuit = null,
  currentJobStage = 'header',
  // Language
  language = 'ru',
  // Variants
  variants = {},
  // Famine state
  isFamine = false,
}) {
  return (
    <div className="trick-area-html">
      {/* Info Bar */}
      <div className={`info-bar ${phase === 'requisition' ? 'requisition-mode' : ''}`}>
        {/* Normal mode: year/trump/lead */}
        {phase !== 'requisition' && (
          <>
            <div className="info-year">
              <span className="label">{t(translations, language, 'year')}</span>
              <span className="value">{year}/5</span>
            </div>

            <div className="info-trump">
              <span className="label">{t(translations, language, 'task')}</span>
              {trump ? (
                <SuitIcon suit={trump} className="suit-symbol" />
              ) : isFamine ? (
                <span className="famine">{t(translations, language, 'famineYear')}</span>
              ) : (
                <span className="no-trump">—</span>
              )}
            </div>

            {trick.length > 0 && (
              <div className="info-lead">
                <span className="label">{t(translations, language, 'lead')}</span>
                <SuitIcon suit={trick[0][1].suit} className="suit-symbol" />
              </div>
            )}
          </>
        )}

        {/* Requisition mode: status message with suit icon */}
        {phase === 'requisition' && (
          <div className="info-requisition">
            {currentRequisitionSuit && (
              <SuitIcon suit={currentRequisitionSuit} className="suit-symbol" />
            )}
            <span className="requisition-text">
              {getRequisitionStatusMessage(language, currentRequisitionSuit, currentJobStage, requisitionStage) ||
               t(translations, language, 'requisition')}
            </span>
          </div>
        )}

        <div className="info-jobs">
          {SUITS.map((suit) => {
            const hours = workHours?.[suit] || 0;
            const isClaimed = claimedJobs?.includes(suit);
            const isHighlighted = highlightedSuits.includes(suit);
            const trumpFaceCards = getTrumpFaceCardsInBucket(jobBuckets?.[suit], trump);

            return (
              <div
                key={suit}
                className={`job-indicator ${isHighlighted ? 'highlighted' : ''} ${isClaimed ? 'claimed' : ''}`}
              >
                <SuitIcon suit={suit} className="suit-symbol" />
                <span className="progress">
                  {isClaimed ? '✓' : `${hours}/40`}
                </span>
                {trumpFaceCards.length > 0 && (
                  <span className="trump-face-badges">
                    {trumpFaceCards.map(symbol => (
                      <span key={symbol} className="trump-face-badge">{symbol}</span>
                    ))}
                  </span>
                )}
              </div>
            );
          })}
        </div>

        <div className="info-score">
          <span className="label">{t(translations, language, 'cellar')}</span>
          <span className="value">
            {((playerPlot?.revealed || []).reduce((sum, c) => sum + c.value, 0) +
              (playerPlot?.hidden || []).reduce((sum, c) => sum + c.value, 0))}
          </span>
        </div>
      </div>

      {/* Main Content Area */}
      <div className="play-area">
        {displayMode === 'game' && (
          <TrickView
            trick={trick}
            players={players}
            currentPlayer={currentPlayer}
            brigadeLeader={brigadeLeader}
            isMyTurn={isMyTurn}
            currentPlayerName={currentPlayerName}
            variants={variants}
            language={language}
          />
        )}

        {displayMode === 'jobs' && (
          <JobsView
            workHours={workHours}
            claimedJobs={claimedJobs}
            jobBuckets={jobBuckets}
            revealedJobs={revealedJobs}
            trump={trump}
            phase={phase}
            lastTrick={lastTrick}
            pendingAssignments={pendingAssignments}
            assignDragState={assignDragState}
            onAssignDragStart={onAssignDragStart}
            jobDropRefs={jobDropRefs}
            variants={variants}
            language={language}
          />
        )}

        {displayMode === 'gulag' && (
          <GulagView
            exiled={exiled}
            year={year}
            language={language}
          />
        )}

        {displayMode === 'plot' && (
          <PlotView
            phase={phase}
            players={players}
            playerPlot={playerPlot}
            currentSwapPlayer={currentSwapPlayer}
            swapConfirmed={swapConfirmed}
            swapDragState={swapDragState}
            onSwapDragStart={onSwapDragStart}
            plotDropRefs={plotDropRefs}
            lastSwap={lastSwap}
            requisitionData={requisitionData}
            currentRequisitionSuit={currentRequisitionSuit}
            currentJobStage={currentJobStage}
            language={language}
          />
        )}

        {/* Trump Selection - only show when it's the player's turn */}
        {phase === 'planning' && !trump && onSetTrump && isMyTurn && (
          <TrumpSelection onSetTrump={onSetTrump} language={language} />
        )}

        {/* Waiting for AI to pick trump */}
        {phase === 'planning' && !trump && !isMyTurn && (
          <TrumpWaiting currentPlayerName={currentPlayerName} language={language} />
        )}
      </div>
    </div>
  );
}
