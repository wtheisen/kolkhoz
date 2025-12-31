import React from 'react';
import { GulagArea } from './GulagArea.jsx';

export function RightSidebar({
  year,
  trump,
  phase,
  currentPlayer,
  players,
  isMyTurn,
  exiled,
}) {
  const startX = 1540;
  const startY = 120;

  const getSuitSymbol = (suit) => {
    const symbols = { Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' };
    return symbols[suit] || suit;
  };

  const getSuitColor = (suit) => {
    return suit === 'Hearts' || suit === 'Diamonds' ? '#c41e3a' : '#e8dcc4';
  };

  const getPhaseDisplay = (phase) => {
    const phases = {
      planning: 'Select Trump',
      trick: 'Trick Phase',
      assignment: 'Assign Cards',
      plotSelection: 'Select Plot Card',
      requisition: 'Requisition',
      swap: 'Swap Cards',
    };
    return phases[phase] || phase;
  };

  return (
    <g className="right-sidebar">
      {/* Info panel background */}
      <rect
        x={startX}
        y={startY}
        width={360}
        height={180}
        fill="rgba(20,20,20,0.9)"
        stroke="#d4a857"
        strokeWidth={1}
        rx="10"
      />

      {/* Year */}
      <text
        x={startX + 20}
        y={startY + 30}
        fill="#a09080"
        fontSize="11"
      >
        Year
      </text>
      <text
        x={startX + 20}
        y={startY + 50}
        fill="#d4a857"
        fontSize="18"
        fontWeight="bold"
      >
        {year}/5
      </text>

      {/* Trump */}
      <text
        x={startX + 100}
        y={startY + 30}
        fill="#a09080"
        fontSize="11"
      >
        Trump
      </text>
      {trump ? (
        <text
          x={startX + 100}
          y={startY + 50}
          fill={getSuitColor(trump)}
          fontSize="18"
          fontWeight="bold"
        >
          {getSuitSymbol(trump)} {trump}
        </text>
      ) : (
        <text
          x={startX + 100}
          y={startY + 50}
          fill="#a09080"
          fontSize="14"
        >
          Not selected
        </text>
      )}

      {/* Phase */}
      <text
        x={startX + 20}
        y={startY + 85}
        fill="#a09080"
        fontSize="11"
      >
        Phase
      </text>
      <text
        x={startX + 20}
        y={startY + 105}
        fill="#e8dcc4"
        fontSize="14"
      >
        {getPhaseDisplay(phase)}
      </text>

      {/* Turn status */}
      <text
        x={startX + 20}
        y={startY + 135}
        fill="#a09080"
        fontSize="11"
      >
        Turn
      </text>
      {isMyTurn ? (
        <text
          x={startX + 20}
          y={startY + 155}
          fill="#d4a857"
          fontSize="14"
          fontWeight="bold"
        >
          Your Turn!
        </text>
      ) : (
        <text
          x={startX + 20}
          y={startY + 155}
          fill="#a09080"
          fontSize="12"
        >
          Waiting for {players[parseInt(currentPlayer, 10)]?.name}...
        </text>
      )}

      {/* Gulag section - centered in sidebar */}
      <g transform={`translate(${startX + 5}, ${startY + 195})`}>
        <GulagArea exiled={exiled} currentYear={year} />
      </g>
    </g>
  );
}
