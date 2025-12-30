import React from 'react';
import { CardSVG } from './components/CardSVG.jsx';
import { Hand } from './components/Hand.jsx';
import { TrickArea } from './components/TrickArea.jsx';
import { JobPilesArea } from './components/JobPilesArea.jsx';
import { PlayerArea } from './components/PlayerArea.jsx';
import { RightSidebar } from './components/RightSidebar.jsx';
import { SUITS } from '../game/constants.js';

export function Board({ G, ctx, moves, playerID }) {
  const currentPlayer = parseInt(playerID, 10);
  const isMyTurn = ctx.currentPlayer === playerID;
  const phase = ctx.phase;

  // Handle card play
  const handlePlayCard = (cardIndex) => {
    if (phase === 'trick' && isMyTurn) {
      moves.playCard(cardIndex);
    } else if (phase === 'plotSelection') {
      moves.selectPlotCard(cardIndex);
    }
  };

  // Handle trump selection
  const handleSetTrump = (suit) => {
    if (phase === 'planning') {
      moves.setTrump(suit);
    }
  };

  // Handle assignment
  const handleAssign = (cardKey, targetSuit) => {
    moves.assignCard(cardKey, targetSuit);
  };

  const handleSubmitAssignments = () => {
    moves.submitAssignments();
  };

  // Center of play area (between jobs on left and sidebar on right)
  const playCenterX = 1000;
  const playCenterY = 450;

  // Get player positions around the board - closer to center
  const getPlayerPosition = (idx, total) => {
    // Position players around the play area, closer to center
    // Player 0 (human) at bottom (not shown in SVG, uses Hand component)
    const positions = [
      { x: playCenterX, y: 750 },       // Bottom (human) - not rendered
      { x: playCenterX - 280, y: 450 }, // Left
      { x: playCenterX, y: 150 },       // Top
      { x: playCenterX + 280, y: 450 }, // Right
    ];
    return positions[idx] || positions[0];
  };

  // Render game over screen
  if (ctx.gameover) {
    const { winner, scores } = ctx.gameover;
    return (
      <div className="game-over">
        <h1>Game Over!</h1>
        <h2>Winner: {G.players[winner].name}</h2>
        <div className="final-scores">
          {G.players.map((p, idx) => (
            <div key={idx} className={idx === winner ? 'winner' : ''}>
              {p.name}: {scores[idx]} points
            </div>
          ))}
        </div>
        <p>(Lowest score wins)</p>
      </div>
    );
  }

  return (
    <div className="game-board">
      {/* Trump selection UI */}
      {phase === 'planning' && !G.trump && (
        <div className="trump-selection">
          <h3>Select Trump Suit</h3>
          <div className="suit-buttons">
            {SUITS.map((suit) => (
              <button
                key={suit}
                onClick={() => handleSetTrump(suit)}
                className={`suit-btn ${suit.toLowerCase()}`}
              >
                {getSuitSymbol(suit)} {suit}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Main SVG board */}
      <svg viewBox="0 0 1920 1080" className="board-svg">
        {/* Job Piles (left side) */}
        <JobPilesArea
          revealedJobs={G.revealedJobs}
          workHours={G.workHours}
          jobBuckets={G.jobBuckets}
          claimedJobs={G.claimedJobs}
          trump={G.trump}
          phase={phase}
          pendingAssignments={G.pendingAssignments}
          onAssign={handleAssign}
          lastTrick={G.lastTrick}
        />

        {/* Trick Area (center) */}
        <TrickArea
          trick={phase === 'assignment' ? G.lastTrick : G.currentTrick}
          numPlayers={G.numPlayers}
          lead={G.lead}
          centerX={playCenterX}
          centerY={playCenterY}
        />

        {/* Other players */}
        {G.players.map((player, idx) => {
          if (idx === currentPlayer) return null;
          const pos = getPlayerPosition(idx, G.numPlayers);
          return (
            <PlayerArea
              key={idx}
              player={player}
              position={pos}
              isActive={parseInt(ctx.currentPlayer, 10) === idx}
              isBrigadeLeader={player.brigadeLeader}
            />
          );
        })}

        {/* Right Sidebar with game info and gulag */}
        <RightSidebar
          year={G.year}
          trump={G.trump}
          phase={phase}
          currentPlayer={ctx.currentPlayer}
          players={G.players}
          isMyTurn={isMyTurn}
          exiled={G.exiled}
        />
      </svg>

      {/* Player's hand (HTML for interactivity) */}
      <Hand
        cards={G.players[currentPlayer]?.hand || []}
        onPlayCard={handlePlayCard}
        canPlay={
          (phase === 'trick' && isMyTurn) ||
          phase === 'plotSelection'
        }
        leadSuit={G.currentTrick[0]?.[1]?.suit}
        trump={G.trump}
        validIndices={getValidIndices(G, currentPlayer, phase)}
      />

      {/* Assignment phase UI */}
      {phase === 'assignment' && G.lastWinner === currentPlayer && (
        <div className="assignment-ui">
          <h3>Assign cards to jobs</h3>
          <p>Drag cards to job piles or click to assign</p>
          <div className="assignment-cards">
            {G.lastTrick.map(([pid, card], idx) => {
              const cardKey = `${card.suit}-${card.value}`;
              const assigned = G.pendingAssignments?.[cardKey];
              return (
                <div key={idx} className="assignment-card">
                  <CardSVG card={card} width={80} />
                  <select
                    value={assigned || card.suit}
                    onChange={(e) => handleAssign(cardKey, e.target.value)}
                  >
                    {card.suit === G.trump ? (
                      SUITS.map((s) => (
                        <option key={s} value={s}>{s}</option>
                      ))
                    ) : (
                      <option value={card.suit}>{card.suit}</option>
                    )}
                  </select>
                </div>
              );
            })}
          </div>
          <button
            onClick={handleSubmitAssignments}
            disabled={Object.keys(G.pendingAssignments || {}).length !== G.lastTrick.length}
          >
            Submit Assignments
          </button>
        </div>
      )}

      {/* Player's plot */}
      <div className="player-plot">
        <h4>Your Plot</h4>
        <div className="plot-cards">
          {G.players[currentPlayer]?.plot.revealed.map((card, idx) => (
            <CardSVG key={`r-${idx}`} card={card} width={60} />
          ))}
          {G.players[currentPlayer]?.plot.hidden.map((card, idx) => (
            <CardSVG key={`h-${idx}`} card={card} width={60} faceDown />
          ))}
        </div>
      </div>
    </div>
  );
}

// Helper to get suit symbol
function getSuitSymbol(suit) {
  const symbols = {
    Hearts: '♥',
    Diamonds: '♦',
    Clubs: '♣',
    Spades: '♠',
  };
  return symbols[suit] || suit;
}

// Helper to get valid card indices
function getValidIndices(G, playerIdx, phase) {
  if (phase !== 'trick') return null;

  const player = G.players[playerIdx];
  if (!player || !player.hand) return [];

  if (G.currentTrick.length === 0) {
    // First card - all valid
    return player.hand.map((_, i) => i);
  }

  const leadSuit = G.currentTrick[0][1].suit;
  const hasLeadSuit = player.hand.some((c) => c.suit === leadSuit);

  if (hasLeadSuit) {
    return player.hand
      .map((c, i) => (c.suit === leadSuit ? i : -1))
      .filter((i) => i >= 0);
  }

  // Can't follow suit - all valid
  return player.hand.map((_, i) => i);
}
