import React from 'react';
import { CardSVG } from './CardSVG.jsx';
import { PlayerArea } from './PlayerArea.jsx';
import { getCardImagePath } from '../../game/Card.js';

const SUITS = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];

export function TrickArea({
  trick, numPlayers, lead, centerX = 960, centerY = 450, scale = 1,
  year, trump, phase, isMyTurn, currentPlayerName, showInfo = false,
  players, currentPlayer, brigadeLeader,
  displayMode = 'game', // 'game' | 'jobs' | 'gulag' | 'plot'
  workHours, claimedJobs, jobBuckets, revealedJobs, exiled, playerPlot
}) {
  const suitSymbols = { Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' };
  // Rectangular trick area dimensions - expanded to fill more space
  const width = 1700 * scale;
  const height = 750 * scale;
  const cardWidth = 280 * scale;
  const cardHeight = cardWidth * 1.4;
  const cardSpacing = 350 * scale;

  // Card positions in a horizontal line - shifted down to make room for bot areas
  // Order: player 1, player 2, player 3, player 0 (human last on right)
  const cardYOffset = 120 * scale; // Cards below bots with small gap
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
  const infoY = centerY - height / 2 + 45 * scale;
  const infoFontSize = 30 * scale;
  const suitFontSize = 26 * scale;
  const leftEdge = centerX - width / 2 + 30 * scale;
  const rightEdge = centerX + width / 2 - 30 * scale;

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

        {/* Lead suit next to trump */}
        {trick.length > 0 && (
          <>
            <text
              x={leftEdge + 200 * scale}
              y={infoY}
              textAnchor="start"
              fill="#888"
              fontSize={infoFontSize}
              fontFamily="'Oswald', sans-serif"
            >
              <title>Lead suit</title>
              Ведёт:
            </text>
            <text
              x={leftEdge + 268 * scale}
              y={infoY}
              textAnchor="start"
              fill={trick[0][1].suit === 'Hearts' || trick[0][1].suit === 'Diamonds' ? '#c41e3a' : '#e8dcc4'}
              fontSize={suitFontSize}
            >
              {suitSymbols[trick[0][1].suit]}
            </text>
          </>
        )}

        {/* Job progress indicators (after lead suit) */}
        {showInfo && workHours && (
          <g className="job-progress-bar">
            {SUITS.map((suit, idx) => {
              const hours = workHours[suit] || 0;
              const isClaimed = claimedJobs?.includes(suit);
              const isTrump = suit === trump;
              const spacing = 70 * scale;
              const startX = leftEdge + 320 * scale; // After year, trump, and lead
              const x = startX + idx * spacing;

              return (
                <g key={suit}>
                  <text
                    x={x}
                    y={infoY}
                    textAnchor="middle"
                    fill={suit === 'Hearts' || suit === 'Diamonds' ? '#c41e3a' : '#e8dcc4'}
                    fontSize={suitFontSize}
                    opacity={isTrump ? 1 : 0.7}
                  >
                    {suitSymbols[suit]}
                  </text>
                  <text
                    x={x + 16 * scale}
                    y={infoY}
                    textAnchor="start"
                    fill={isClaimed ? '#4CAF50' : '#888'}
                    fontSize={suitFontSize}
                    fontFamily="'Oswald', sans-serif"
                  >
                    {isClaimed ? '✓' : `${hours}/40`}
                  </text>
                </g>
              );
            })}
          </g>
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

      {/* GAME MODE CONTENT */}
      {displayMode === 'game' && (
        <>
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

          {/* All player areas - positioned below info bar */}
          {players && [0, 1, 2, 3].map((playerIdx) => {
            const pos = getCardPosition(playerIdx);
            const areaY = centerY - height / 2 + 160 * scale; // Below info bar with gap
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
        </>
      )}

      {/* JOBS MODE CONTENT - Horizontal rows */}
      {displayMode === 'jobs' && (
        <g className="jobs-content">
          {/* Title centered below info bar */}
          <text
            x={centerX}
            y={centerY - height / 2 + 70 * scale}
            textAnchor="middle"
            fill="#d4a857"
            fontSize={24 * scale}
            fontFamily="'Russo One', 'Oswald', sans-serif"
          >
            Работы
          </text>

          {/* 4 suit rows */}
          {SUITS.map((suit, suitIdx) => {
            const hours = workHours?.[suit] || 0;
            const isClaimed = claimedJobs?.includes(suit);
            const isTrump = suit === trump;
            const bucket = jobBuckets?.[suit] || [];
            const jobCard = revealedJobs?.[suit];
            const jobCards = Array.isArray(jobCard) ? jobCard : jobCard ? [jobCard] : [];
            const progressPct = Math.min(100, (hours / 40) * 100);

            const rowHeight = 95 * scale;
            const rowSpacing = 100 * scale;
            const rowY = centerY - height / 2 + 95 * scale + suitIdx * rowSpacing;
            const rowLeft = centerX - width / 2 + 20 * scale;
            const rowWidth = width - 40 * scale;
            const jobCardWidth = 55 * scale;
            const jobCardHeight = jobCardWidth * 1.4;
            const cardSpacing = 42 * scale;

            // Cards area starts after info section
            const cardsStartX = rowLeft + 140 * scale;

            return (
              <g key={suit} className={`job-row ${isTrump ? 'trump' : ''}`}>
                {/* Row background */}
                <rect
                  x={rowLeft}
                  y={rowY}
                  width={rowWidth}
                  height={rowHeight}
                  fill={isTrump ? 'rgba(196, 30, 58, 0.15)' : 'rgba(30,30,30,0.5)'}
                  stroke={isClaimed ? '#4CAF50' : isTrump ? '#c41e3a' : '#444'}
                  strokeWidth={isClaimed ? 2 : 1}
                  rx={4 * scale}
                />

                {/* Suit symbol above progress text */}
                <text
                  x={rowLeft + 25 * scale}
                  y={rowY + 35 * scale}
                  textAnchor="middle"
                  fill={suit === 'Hearts' || suit === 'Diamonds' ? '#c41e3a' : '#e8dcc4'}
                  fontSize={28 * scale}
                >
                  {suitSymbols[suit]}
                </text>

                {/* Progress text below suit */}
                <text
                  x={rowLeft + 25 * scale}
                  y={rowY + 65 * scale}
                  textAnchor="middle"
                  fill={isClaimed ? '#4CAF50' : '#e8dcc4'}
                  fontSize={12 * scale}
                  fontFamily="'Oswald', sans-serif"
                >
                  {isClaimed ? '✓' : `${hours}/40`}
                </text>

                {/* Reward card */}
                {jobCards.length > 0 && !isClaimed ? (
                  <image
                    href={getCardImagePath(jobCards[0])}
                    x={rowLeft + 55 * scale}
                    y={rowY + (rowHeight - jobCardHeight) / 2}
                    width={jobCardWidth}
                    height={jobCardHeight}
                  />
                ) : (
                  <image
                    href="assets/cards/back.svg"
                    x={rowLeft + 55 * scale}
                    y={rowY + (rowHeight - jobCardHeight) / 2}
                    width={jobCardWidth}
                    height={jobCardHeight}
                    opacity={isClaimed ? 0.3 : 0.5}
                  />
                )}

                {/* Separator line */}
                <line
                  x1={rowLeft + 120 * scale}
                  y1={rowY + 10 * scale}
                  x2={rowLeft + 120 * scale}
                  y2={rowY + rowHeight - 10 * scale}
                  stroke="#555"
                  strokeWidth={1}
                />

                {/* Assigned cards - horizontal spread */}
                {bucket.slice(0, 16).map((card, idx) => (
                  <image
                    key={`assigned-${idx}`}
                    href={getCardImagePath(card)}
                    x={cardsStartX + idx * cardSpacing}
                    y={rowY + (rowHeight - jobCardHeight) / 2}
                    width={jobCardWidth}
                    height={jobCardHeight}
                  />
                ))}
                {bucket.length > 16 && (
                  <text
                    x={cardsStartX + 16 * cardSpacing + jobCardWidth / 2}
                    y={rowY + rowHeight / 2 + 5 * scale}
                    textAnchor="middle"
                    fill="#888"
                    fontSize={11 * scale}
                  >
                    +{bucket.length - 16}
                  </text>
                )}

                {/* Empty slot indicator if no assigned cards */}
                {bucket.length === 0 && (
                  <rect
                    x={cardsStartX}
                    y={rowY + (rowHeight - jobCardHeight) / 2}
                    width={jobCardWidth}
                    height={jobCardHeight}
                    fill="none"
                    stroke="rgba(255,255,255,0.1)"
                    strokeDasharray={`${4 * scale},${4 * scale}`}
                    rx={4 * scale}
                  />
                )}
              </g>
            );
          })}
        </g>
      )}

      {/* GULAG MODE CONTENT - Horizontal rows */}
      {displayMode === 'gulag' && (
        <g className="gulag-content">
          {/* Title centered below info bar */}
          <text
            x={centerX}
            y={centerY - height / 2 + 70 * scale}
            textAnchor="middle"
            fill="#d4a857"
            fontSize={24 * scale}
            fontFamily="'Russo One', 'Oswald', sans-serif"
          >
            Север
          </text>

          {/* 5 year rows */}
          {[1, 2, 3, 4, 5].map((yr, yrIdx) => {
            const yearCards = exiled?.[yr] || [];
            const isCurrent = yr === year;
            const isPast = yr < year;

            const rowHeight = 80 * scale;
            const rowSpacing = 85 * scale;
            const rowY = centerY - height / 2 + 90 * scale + yrIdx * rowSpacing;
            const rowLeft = centerX - width / 2 + 20 * scale;
            const rowWidth = width - 40 * scale;
            const gulagCardWidth = 50 * scale;
            const gulagCardHeight = gulagCardWidth * 1.4;
            const cardSpacing = 38 * scale;

            // Cards area starts after year number
            const cardsStartX = rowLeft + 80 * scale;

            const parseCardKey = (cardKey) => {
              const [suit, value] = cardKey.split('-');
              return { suit, value: parseInt(value, 10) };
            };

            return (
              <g key={yr} className={`year-row ${isCurrent ? 'current' : ''}`}>
                {/* Row background */}
                <rect
                  x={rowLeft}
                  y={rowY}
                  width={rowWidth}
                  height={rowHeight}
                  fill={isCurrent ? 'rgba(196, 30, 58, 0.2)' : isPast ? 'rgba(50,50,50,0.3)' : 'rgba(30,30,30,0.5)'}
                  stroke={isCurrent ? '#c41e3a' : '#444'}
                  strokeWidth={isCurrent ? 2 : 1}
                  rx={4 * scale}
                />

                {/* Year number */}
                <text
                  x={rowLeft + 35 * scale}
                  y={rowY + rowHeight / 2 + 10 * scale}
                  textAnchor="middle"
                  fill={isCurrent ? '#c41e3a' : isPast ? '#666' : '#e8dcc4'}
                  fontSize={28 * scale}
                  fontFamily="'Russo One', 'Oswald', sans-serif"
                  fontWeight={isCurrent ? 'bold' : 'normal'}
                >
                  {yr}
                </text>

                {/* Card count badge */}
                {yearCards.length > 0 && (
                  <g>
                    <circle
                      cx={rowLeft + 60 * scale}
                      cy={rowY + 20 * scale}
                      r={12 * scale}
                      fill="#c41e3a"
                    />
                    <text
                      x={rowLeft + 60 * scale}
                      y={rowY + 24 * scale}
                      textAnchor="middle"
                      fill="#fff"
                      fontSize={11 * scale}
                      fontWeight="bold"
                    >
                      {yearCards.length}
                    </text>
                  </g>
                )}

                {/* Exiled cards - horizontal spread */}
                {yearCards.length > 0 ? (
                  yearCards.slice(0, 15).map((cardKey, idx) => {
                    const card = parseCardKey(cardKey);
                    return (
                      <image
                        key={idx}
                        href={getCardImagePath(card)}
                        x={cardsStartX + idx * cardSpacing}
                        y={rowY + (rowHeight - gulagCardHeight) / 2}
                        width={gulagCardWidth}
                        height={gulagCardHeight}
                      />
                    );
                  })
                ) : (
                  <rect
                    x={cardsStartX}
                    y={rowY + (rowHeight - gulagCardHeight) / 2}
                    width={gulagCardWidth}
                    height={gulagCardHeight}
                    fill="none"
                    stroke="rgba(255,255,255,0.1)"
                    strokeDasharray={`${4 * scale},${4 * scale}`}
                    rx={4 * scale}
                  />
                )}
                {yearCards.length > 15 && (
                  <text
                    x={cardsStartX + 15 * cardSpacing + gulagCardWidth / 2}
                    y={rowY + rowHeight / 2 + 5 * scale}
                    textAnchor="middle"
                    fill="#888"
                    fontSize={11 * scale}
                  >
                    +{yearCards.length - 15}
                  </text>
                )}
              </g>
            );
          })}
        </g>
      )}

      {/* PLOT MODE CONTENT - Player's private plot */}
      {displayMode === 'plot' && (
        <g className="plot-content">
          {/* Title centered below info bar */}
          <text
            x={centerX}
            y={centerY - height / 2 + 70 * scale}
            textAnchor="middle"
            fill="#d4a857"
            fontSize={24 * scale}
            fontFamily="'Russo One', 'Oswald', sans-serif"
          >
            Подвал
          </text>

          {/* Revealed cards row (rewards) */}
          {(() => {
            const revealedCards = playerPlot?.revealed || [];
            const rowHeight = 120 * scale;
            const rowY = centerY - height / 2 + 95 * scale;
            const rowLeft = centerX - width / 2 + 20 * scale;
            const rowWidth = width - 40 * scale;
            const plotCardWidth = 70 * scale;
            const plotCardHeight = plotCardWidth * 1.4;
            const cardSpacing = 55 * scale;
            const cardsStartX = rowLeft + 120 * scale;

            return (
              <g className="revealed-row">
                {/* Row background */}
                <rect
                  x={rowLeft}
                  y={rowY}
                  width={rowWidth}
                  height={rowHeight}
                  fill="rgba(76, 175, 80, 0.1)"
                  stroke="#4CAF50"
                  strokeWidth={1}
                  rx={4 * scale}
                />

                {/* Row label */}
                <text
                  x={rowLeft + 15 * scale}
                  y={rowY + 35 * scale}
                  textAnchor="start"
                  fill="#4CAF50"
                  fontSize={14 * scale}
                  fontFamily="'Oswald', sans-serif"
                >
                  Награды
                </text>
                <text
                  x={rowLeft + 15 * scale}
                  y={rowY + 55 * scale}
                  textAnchor="start"
                  fill="#888"
                  fontSize={12 * scale}
                  fontFamily="'Oswald', sans-serif"
                >
                  (Revealed)
                </text>

                {/* Separator */}
                <line
                  x1={rowLeft + 100 * scale}
                  y1={rowY + 10 * scale}
                  x2={rowLeft + 100 * scale}
                  y2={rowY + rowHeight - 10 * scale}
                  stroke="#555"
                  strokeWidth={1}
                />

                {/* Revealed cards */}
                {revealedCards.map((card, idx) => (
                  <image
                    key={`revealed-${idx}`}
                    href={getCardImagePath(card)}
                    x={cardsStartX + idx * cardSpacing}
                    y={rowY + (rowHeight - plotCardHeight) / 2}
                    width={plotCardWidth}
                    height={plotCardHeight}
                    className="plot-card"
                    data-type="revealed"
                    data-index={idx}
                  />
                ))}

                {/* Empty slot if no cards */}
                {revealedCards.length === 0 && (
                  <rect
                    x={cardsStartX}
                    y={rowY + (rowHeight - plotCardHeight) / 2}
                    width={plotCardWidth}
                    height={plotCardHeight}
                    fill="none"
                    stroke="rgba(255,255,255,0.1)"
                    strokeDasharray={`${4 * scale},${4 * scale}`}
                    rx={4 * scale}
                  />
                )}
              </g>
            );
          })()}

          {/* Hidden cards row */}
          {(() => {
            const hiddenCards = playerPlot?.hidden || [];
            const rowHeight = 120 * scale;
            const rowY = centerY - height / 2 + 230 * scale;
            const rowLeft = centerX - width / 2 + 20 * scale;
            const rowWidth = width - 40 * scale;
            const plotCardWidth = 70 * scale;
            const plotCardHeight = plotCardWidth * 1.4;
            const cardSpacing = 55 * scale;
            const cardsStartX = rowLeft + 120 * scale;

            return (
              <g className="hidden-row">
                {/* Row background */}
                <rect
                  x={rowLeft}
                  y={rowY}
                  width={rowWidth}
                  height={rowHeight}
                  fill="rgba(196, 30, 58, 0.1)"
                  stroke="#c41e3a"
                  strokeWidth={1}
                  rx={4 * scale}
                />

                {/* Row label */}
                <text
                  x={rowLeft + 15 * scale}
                  y={rowY + 35 * scale}
                  textAnchor="start"
                  fill="#c41e3a"
                  fontSize={14 * scale}
                  fontFamily="'Oswald', sans-serif"
                >
                  Скрытые
                </text>
                <text
                  x={rowLeft + 15 * scale}
                  y={rowY + 55 * scale}
                  textAnchor="start"
                  fill="#888"
                  fontSize={12 * scale}
                  fontFamily="'Oswald', sans-serif"
                >
                  (Hidden)
                </text>

                {/* Separator */}
                <line
                  x1={rowLeft + 100 * scale}
                  y1={rowY + 10 * scale}
                  x2={rowLeft + 100 * scale}
                  y2={rowY + rowHeight - 10 * scale}
                  stroke="#555"
                  strokeWidth={1}
                />

                {/* Hidden cards - shown face up since this is YOUR plot */}
                {hiddenCards.map((card, idx) => (
                  <image
                    key={`hidden-${idx}`}
                    href={getCardImagePath(card)}
                    x={cardsStartX + idx * cardSpacing}
                    y={rowY + (rowHeight - plotCardHeight) / 2}
                    width={plotCardWidth}
                    height={plotCardHeight}
                    className="plot-card"
                    data-type="hidden"
                    data-index={idx}
                  />
                ))}

                {/* Empty slot if no cards */}
                {hiddenCards.length === 0 && (
                  <rect
                    x={cardsStartX}
                    y={rowY + (rowHeight - plotCardHeight) / 2}
                    width={plotCardWidth}
                    height={plotCardHeight}
                    fill="none"
                    stroke="rgba(255,255,255,0.1)"
                    strokeDasharray={`${4 * scale},${4 * scale}`}
                    rx={4 * scale}
                  />
                )}
              </g>
            );
          })()}

          {/* Total points display */}
          {(() => {
            const revealed = playerPlot?.revealed || [];
            const hidden = playerPlot?.hidden || [];
            const totalPoints = revealed.reduce((sum, c) => sum + c.value, 0) +
                               hidden.reduce((sum, c) => sum + c.value, 0);
            const rowY = centerY - height / 2 + 365 * scale;

            return (
              <text
                x={centerX}
                y={rowY}
                textAnchor="middle"
                fill={totalPoints > 0 ? '#c41e3a' : '#888'}
                fontSize={18 * scale}
                fontFamily="'Oswald', sans-serif"
              >
                Total: {totalPoints} points ({revealed.length + hidden.length} cards)
              </text>
            );
          })()}
        </g>
      )}
    </g>
  );
}
