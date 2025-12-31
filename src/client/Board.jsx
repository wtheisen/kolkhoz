import React, { useState, useEffect, useRef } from 'react';
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

  // State for swap phase
  const [selectedHandCard, setSelectedHandCard] = useState(null);
  const [selectedPlotCard, setSelectedPlotCard] = useState(null);
  const [selectedPlotType, setSelectedPlotType] = useState(null); // 'hidden' or 'revealed'

  // Track if user has confirmed swap locally (to prevent modal reappearing due to race conditions)
  const [swapConfirmedLocally, setSwapConfirmedLocally] = useState(false);
  const lastYearRef = useRef(G.year);

  // Reset local swap confirmation when year changes
  useEffect(() => {
    if (G.year !== lastYearRef.current) {
      setSwapConfirmedLocally(false);
      lastYearRef.current = G.year;
    }
  }, [G.year]);

  // Handle card play
  const handlePlayCard = (cardIndex) => {
    if (phase === 'trick' && isMyTurn) {
      moves.playCard(cardIndex);
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

  // Handle swap phase
  const handleSwap = () => {
    if (selectedHandCard !== null && selectedPlotCard !== null && selectedPlotType !== null) {
      moves.swapCard(selectedPlotCard, selectedHandCard, selectedPlotType);
      setSelectedHandCard(null);
      setSelectedPlotCard(null);
      setSelectedPlotType(null);
    }
  };

  // Handle plot card selection for swap
  const handleSelectPlotCard = (idx, type) => {
    if (selectedPlotCard === idx && selectedPlotType === type) {
      // Deselect
      setSelectedPlotCard(null);
      setSelectedPlotType(null);
    } else {
      setSelectedPlotCard(idx);
      setSelectedPlotType(type);
    }
  };

  const handleConfirmSwap = () => {
    setSwapConfirmedLocally(true);
    moves.confirmSwap();
  };

  // Center of play area (between jobs on left and sidebar on right)
  const playCenterX = 1080;
  const playCenterY = 450;

  // Get player positions around the board - closer to center
  const getPlayerPosition = (idx, total) => {
    // Position players around the play area, closer to center
    // Player 0 (human) at bottom (not shown in SVG, uses Hand component)
    const positions = [
      { x: playCenterX, y: 800 },       // Bottom (human) - not rendered
      { x: playCenterX - 380, y: 450 }, // Left
      { x: playCenterX, y: 120 },       // Top
      { x: playCenterX + 380, y: 450 }, // Right
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
        canPlay={phase === 'trick' && isMyTurn}
        leadSuit={G.currentTrick[0]?.[1]?.suit}
        trump={G.trump}
        validIndices={getValidIndices(G, currentPlayer, phase)}
      />

      {/* Assignment phase UI */}
      {phase === 'assignment' && G.lastWinner === currentPlayer && (() => {
        // Get all suits represented in the trick
        const suitsInTrick = [...new Set(G.lastTrick.map(([, c]) => c.suit))];
        return (
          <div className="assignment-ui">
            <h3>Assign cards to jobs</h3>
            <p>Assign each card to a job from this trick</p>
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
                      {suitsInTrick.map((s) => (
                        <option key={s} value={s}>{s}</option>
                      ))}
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
        );
      })()}

      {/* Swap phase UI */}
      {phase === 'swap' && !G.swapConfirmed?.[currentPlayer] && !swapConfirmedLocally && (
        <div className="swap-ui">
          <h3>Swap Cards (Year {G.year})</h3>
          <p>Select a card from your hand and one from your plot to swap, or skip</p>

          <div className="swap-section">
            <h4>Your Hand</h4>
            <div className="swap-cards">
              {G.players[currentPlayer]?.hand.map((card, idx) => (
                <div
                  key={`hand-${idx}`}
                  className={`swap-card ${selectedHandCard === idx ? 'selected' : ''}`}
                  onClick={() => setSelectedHandCard(selectedHandCard === idx ? null : idx)}
                >
                  <CardSVG card={card} width={80} />
                </div>
              ))}
            </div>
          </div>

          {G.players[currentPlayer]?.plot.revealed.length > 0 && (
            <div className="swap-section">
              <h4>Your Revealed Cards (Rewards)</h4>
              <div className="swap-cards">
                {G.players[currentPlayer]?.plot.revealed.map((card, idx) => (
                  <div
                    key={`revealed-${idx}`}
                    className={`swap-card ${selectedPlotCard === idx && selectedPlotType === 'revealed' ? 'selected' : ''}`}
                    onClick={() => handleSelectPlotCard(idx, 'revealed')}
                  >
                    <CardSVG card={card} width={80} />
                  </div>
                ))}
              </div>
            </div>
          )}

          {G.players[currentPlayer]?.plot.hidden.length > 0 && (
            <div className="swap-section">
              <h4>Your Hidden Plot</h4>
              <div className="swap-cards">
                {G.players[currentPlayer]?.plot.hidden.map((card, idx) => (
                  <div
                    key={`hidden-${idx}`}
                    className={`swap-card ${selectedPlotCard === idx && selectedPlotType === 'hidden' ? 'selected' : ''}`}
                    onClick={() => handleSelectPlotCard(idx, 'hidden')}
                  >
                    <CardSVG card={card} width={80} />
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="swap-buttons">
            <button
              onClick={handleSwap}
              disabled={selectedHandCard === null || selectedPlotCard === null || selectedPlotType === null}
            >
              Swap Selected Cards
            </button>
            <button onClick={handleConfirmSwap}>
              Done Swapping
            </button>
          </div>
        </div>
      )}

      {/* Waiting for others during swap */}
      {phase === 'swap' && (G.swapConfirmed?.[currentPlayer] || swapConfirmedLocally) && (
        <div className="swap-ui">
          <h3>Waiting for other players...</h3>
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
            <div key={`h-${idx}`} className="hidden-plot-card" title="Hover to reveal">
              <CardSVG card={card} width={60} faceDown className="card-back" />
              <CardSVG card={card} width={60} className="card-front" />
            </div>
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
