import React from 'react';
import { translations, t } from '../../translations.js';
import './GameOverScreen.css';

export function GameOverScreen({
  players,
  winner,
  scores,
  medals,
  language,
  onNewGame,
}) {
  // Sort players by score descending for standings display
  const rankedPlayers = players
    .map((p, idx) => ({ ...p, idx, score: scores[idx], medals: medals?.[idx] || 0 }))
    .sort((a, b) => b.score - a.score);

  return (
    <div className="game-over">
      {/* Decorative background burst */}
      <div className="victory-burst" />

      {/* Left column: Title + Winner + Button */}
      <div className="game-over-left">
        <div className="game-over-title">
          <div className="victory-star">★</div>
          <h1>{t(translations, language, 'gameOver')}</h1>
          <h2>{t(translations, language, 'winner')}</h2>
        </div>
        <div className="winner-spotlight">
          <div className="winner-medal">
            <span className="medal-star">★</span>
            <span className="medal-rank">1</span>
          </div>
          <div className="winner-info">
            <span className="winner-name">{players[winner].name}</span>
            <span className="winner-score">{scores[winner]} {t(translations, language, 'pts')}</span>
          </div>
        </div>
        <div className="game-over-buttons">
          <button className="new-game-btn" onClick={onNewGame}>
            {t(translations, language, 'newGame')}
          </button>
        </div>
      </div>

      {/* Right column: Final standings */}
      <div className="game-over-right">
        <div className="final-standings">
          <div className="standings-header">
            <span className="header-rank">#</span>
            <span className="header-name">{t(translations, language, 'brigade')}</span>
            <span className="header-medals">🏅</span>
            <span className="header-score">{t(translations, language, 'pts')}</span>
          </div>
          {rankedPlayers.map((p, idx) => (
            <div
              key={p.idx}
              className={`standing-row ${p.idx === winner ? 'winner' : ''}`}
              style={{ '--delay': `${idx * 0.1}s` }}
            >
              <span className="standing-rank">{idx + 1}</span>
              <span className="standing-name">{p.name}</span>
              <span className="standing-medals">{p.medals}</span>
              <span className="standing-score">{p.score}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default GameOverScreen;
