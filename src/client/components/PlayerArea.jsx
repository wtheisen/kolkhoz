import React from 'react';
import { CardSVG } from './CardSVG.jsx';

export function PlayerArea({ player, position, isActive, isBrigadeLeader }) {
  const { x, y } = position;

  // Show card backs for other players' hands
  const handSize = player.hand?.length || 0;

  return (
    <g className={`player-area ${isActive ? 'active' : ''}`}>
      {/* Background */}
      <rect
        x={x - 80}
        y={y - 60}
        width={160}
        height={120}
        fill={isActive ? 'rgba(76, 175, 80, 0.2)' : 'rgba(0,0,0,0.3)'}
        stroke={isActive ? '#4CAF50' : '#444'}
        strokeWidth={isActive ? 2 : 1}
        rx="10"
      />

      {/* Player name */}
      <text
        x={x}
        y={y - 40}
        textAnchor="middle"
        fill={isActive ? '#4CAF50' : '#fff'}
        fontSize="14"
        fontWeight={isActive ? 'bold' : 'normal'}
      >
        {player.name}
        {isBrigadeLeader && ' 🎖️'}
      </text>

      {/* Hand indicator (card backs) */}
      <g transform={`translate(${x - 30}, ${y - 20})`}>
        {Array.from({ length: Math.min(5, handSize) }).map((_, idx) => (
          <rect
            key={idx}
            x={idx * 12}
            y={0}
            width={30}
            height={42}
            fill="#1a237e"
            stroke="#3949ab"
            strokeWidth="1"
            rx="3"
          />
        ))}
        <text
          x={30}
          y={55}
          textAnchor="middle"
          fill="#888"
          fontSize="10"
        >
          {handSize} cards
        </text>
      </g>

      {/* Score indicator */}
      <text
        x={x}
        y={y + 50}
        textAnchor="middle"
        fill="#888"
        fontSize="11"
      >
        Plot: {(player.plot?.revealed?.length || 0) + (player.plot?.hidden?.length || 0)} cards
      </text>

      {/* Medals */}
      {player.medals > 0 && (
        <text
          x={x + 60}
          y={y - 40}
          fill="#FFD700"
          fontSize="12"
        >
          🏅 {player.medals}
        </text>
      )}
    </g>
  );
}
