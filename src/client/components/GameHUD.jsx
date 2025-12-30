import React from 'react';

export function GameHUD({ year, trump, phase, currentPlayer, players, isMyTurn }) {
  const getSuitSymbol = (suit) => {
    const symbols = { Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' };
    return symbols[suit] || suit;
  };

  const getSuitColor = (suit) => {
    return suit === 'Hearts' || suit === 'Diamonds' ? '#c41e3a' : '#1a1a2e';
  };

  const getPhaseDisplay = (phase) => {
    const phases = {
      planning: 'Planning - Select Trump',
      trick: 'Trick Phase',
      assignment: 'Assign Cards to Jobs',
      plotSelection: 'Select Card for Plot',
      requisition: 'Requisition...',
      swap: 'Swap Cards',
    };
    return phases[phase] || phase;
  };

  return (
    <div className="game-hud">
      <div className="hud-section year">
        <span className="label">Year</span>
        <span className="value">{year}/5</span>
      </div>

      {trump && (
        <div className="hud-section trump">
          <span className="label">Trump</span>
          <span className="value" style={{ color: getSuitColor(trump) }}>
            {getSuitSymbol(trump)} {trump}
          </span>
        </div>
      )}

      <div className="hud-section phase">
        <span className="label">Phase</span>
        <span className="value">{getPhaseDisplay(phase)}</span>
      </div>

      <div className="hud-section turn">
        {isMyTurn ? (
          <span className="your-turn">Your Turn!</span>
        ) : (
          <span className="waiting">
            Waiting for {players[parseInt(currentPlayer, 10)]?.name}...
          </span>
        )}
      </div>
    </div>
  );
}
