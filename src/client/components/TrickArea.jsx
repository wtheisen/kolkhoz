import React from 'react';
import { CardSVG } from './CardSVG.jsx';
import { PlayerArea } from './PlayerArea.jsx';

export function TrickArea({ trick, numPlayers, lead, centerX = 960, centerY = 450, scale = 1, year, trump, phase, isMyTurn, currentPlayerName, showInfo = false, players, currentPlayer, brigadeLeader }) {
  const suitSymbols = { Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' };
  // Rectangular trick area dimensions - fits visible area
  const width = 1100 * scale;
  const height = 540 * scale;
  const cardWidth = 220 * scale;
  const cardHeight = cardWidth * 1.4;
  const cardSpacing = 265 * scale;

  // Card positions in a horizontal line - shifted down to make room for bot areas
  // Order: player 1, player 2, player 3, player 0 (human last on right)
  const cardYOffset = 85 * scale; // Cards below bots with small gap
  const getCardPosition = (playerIdx) => {
    // Map player index to slot position (0-3 from left to right)
    const slotOrder = [3, 0, 1, 2]; // player 0 -> slot 3, player 1 -> slot 0, etc.
    const slot = slotOrder[playerIdx];
    const startX = -1.5 * cardSpacing; // Center the 4 cards
    return { x: startX + slot * cardSpacing, y: cardYOffset };
  };

  // Scaled values for borders and text
  const borderInset = 6 * scale;
  const outerRadius = 10 * scale;
  const innerRadius = 6 * scale;

  // Info positioning inside the trick area
  const infoY = centerY - height / 2 + 38 * scale;
  const infoFontSize = 24 * scale;
  const suitFontSize = 20 * scale;
  const leftEdge = centerX - width / 2 + 20 * scale;
  const rightEdge = centerX + width / 2 - 20 * scale;

  return (
    <g className="trick-area">
      {/* Rectangular table - Soviet theme */}
      <rect
        x={centerX - width / 2}
        y={centerY - height / 2}
        width={width}
        height={height}
        fill="#1a1a1a"
        stroke="#d4a857"
        strokeWidth={3 * scale}
        rx={outerRadius}
      />
      <rect
        x={centerX - width / 2 + borderInset}
        y={centerY - height / 2 + borderInset}
        width={width - borderInset * 2}
        height={height - borderInset * 2}
        fill="none"
        stroke="#8b0000"
        strokeWidth={2 * scale}
        rx={innerRadius}
      />

      {/* Info bar inside trick area - top edge */}
      <g className="trick-info-bar">
        {/* Left side: Year and Trump (or Lead if trick started) */}
        {showInfo ? (
          <>
            <text
              x={leftEdge}
              y={infoY}
              textAnchor="start"
              fill="#d4a857"
              fontSize={infoFontSize}
              fontFamily="'Oswald', sans-serif"
            >
              <title>Year {year} of 5</title>
              Год {year}/5
            </text>
            <text
              x={leftEdge + 100 * scale}
              y={infoY}
              textAnchor="start"
              fill="#888"
              fontSize={infoFontSize}
              fontFamily="'Oswald', sans-serif"
            >
              <title>Trump suit</title>
              Задача:
            </text>
            <text
              x={leftEdge + 175 * scale}
              y={infoY}
              textAnchor="start"
              fill={trump === 'Hearts' || trump === 'Diamonds' ? '#c41e3a' : '#e8dcc4'}
              fontSize={suitFontSize}
              fontFamily="'Oswald', sans-serif"
            >
              {trump ? suitSymbols[trump] : '?'}
            </text>
          </>
        ) : null}

        {/* Center: Lead suit if trick has started */}
        {trick.length > 0 && (
          <>
            <text
              x={centerX - 30 * scale}
              y={infoY}
              textAnchor="end"
              fill="#888"
              fontSize={infoFontSize}
              fontFamily="'Oswald', sans-serif"
            >
              <title>Lead suit</title>
              Ведёт:
            </text>
            <text
              x={centerX - 22 * scale}
              y={infoY}
              textAnchor="start"
              fill={trick[0][1].suit === 'Hearts' || trick[0][1].suit === 'Diamonds' ? '#c41e3a' : '#e8dcc4'}
              fontSize={suitFontSize}
            >
              {suitSymbols[trick[0][1].suit]}
            </text>
          </>
        )}

        {/* Right side: Turn indicator */}
        {showInfo && (
          <text
            x={rightEdge}
            y={infoY}
            textAnchor="end"
            fill={isMyTurn ? '#4CAF50' : '#e8dcc4'}
            fontSize={infoFontSize}
            fontWeight={isMyTurn ? 'bold' : 'normal'}
            fontFamily="'Oswald', sans-serif"
          >
            <title>{isMyTurn ? 'Your turn' : `${currentPlayerName}'s turn`}</title>
            {isMyTurn ? 'Ваш ход' : currentPlayerName}
          </text>
        )}
      </g>

      {/* Empty slots for players who haven't played */}
      {Array.from({ length: numPlayers }).map((_, idx) => {
        const hasPlayed = trick.some(([pid]) => pid === idx);
        if (hasPlayed) return null;

        const pos = getCardPosition(idx);
        return (
          <rect
            key={`slot-${idx}`}
            x={centerX + pos.x - cardWidth / 2}
            y={centerY + pos.y - cardHeight / 2}
            width={cardWidth}
            height={cardHeight}
            fill="none"
            stroke="rgba(255,255,255,0.15)"
            strokeWidth={1 * scale}
            strokeDasharray={`${4 * scale},${4 * scale}`}
            rx={4 * scale}
          />
        );
      })}

      {/* Cards played - rendered after slots so they appear on top */}
      {trick.map(([playerIdx, card], idx) => {
        const pos = getCardPosition(playerIdx);
        return (
          <CardSVG
            key={`${card.suit}-${card.value}`}
            card={card}
            x={centerX + pos.x}
            y={centerY + pos.y}
            width={cardWidth}
          />
        );
      })}

      {/* All player areas - positioned just below info bar */}
      {players && [0, 1, 2, 3].map((playerIdx) => {
        const pos = getCardPosition(playerIdx);
        const areaY = centerY - height / 2 + 115 * scale; // Just below info bar
        return (
          <PlayerArea
            key={`player-${playerIdx}`}
            player={players[playerIdx]}
            position={{ x: centerX + pos.x, y: areaY }}
            isActive={currentPlayer === playerIdx}
            isBrigadeLeader={brigadeLeader === playerIdx}
            playerIndex={playerIdx}
            scale={scale}
            isHuman={playerIdx === 0}
          />
        );
      })}
    </g>
  );
}
