# Game Phases & Transitions

The app uses `GamePhase` values adapted from the C engine through
`KolkhozCEngineAdapter`. It does not use boardgame.io hooks. Automatic AI turns are
processed by the C engine.

## Phase Flow Diagram

```text
                        +--------------+
                        |   planning   | <- game starts here
                        |  set trump   |
                        +------+-------+
                               |
              +----------------+----------------+
              | year > 1 && allowSwap variant?  |
              +----------------+----------------+
                    yes        |        no
                     v         |         v
              +----------+     |    +----------+
              |   swap   |-----+--->|  trick   |
              +----+-----+          +----+-----+
                   |                     |
                   +---------------------+
                               |
                               v
                        +--------------+
                        |    trick     |<----------+
                        | play cards   |           |
                        +------+-------+           |
                               |                   |
                               v                   |
                        +--------------+           |
                        | assignment   |           |
                        | assign work  |           |
                        +------+-------+           |
                               |                   |
              +----------------+----------------+  |
              | year complete?                  |  |
              | 4 normal tricks, 3 famine       |  |
              +----------------+----------------+  |
                    yes        |        no         |
                     v         |         +---------+
              +---------------+
              | move hands to |
              | hidden plots  |
              +-------+-------+
                      |
                      v
              +---------------+
              | requisition   |
              | exile cards   |
              +-------+-------+
                      |
        +-------------+-------------+
        | year after increment <= 5 |
        +-------------+-------------+
              yes     |      no
               v      |       v
        +----------+  |  +----------+
        | planning |  |  | gameOver |
        +----------+  |  +----------+
```

## Phase Definitions

### 1. Planning

**Purpose:** Reveal jobs for the year and set trump.

**Human actions:** `setTrump(_:)` if the human is the current trump selector and the
year is not famine.

**Automatic behavior:**

- Famine is `year == 5`.
- In famine, `trump` is set to `nil` and planning advances automatically.
- If an AI is the trump selector, it chooses a suit based on hand composition and high cards.
- After planning, the engine enters `swap` when `allowSwap && year > 1`; otherwise it enters `trick`.

**Key logic locations:**

- C engine setup/deal/reveal logic in `Sources/KolkhozCEngine/`
- Swift snapshot/action bridge in `KolkhozHeadlessEngine.swift`

### 2. Swap

**Purpose:** Let each player exchange at most one hand card with a hidden or revealed
plot card before tricks begin.

**Human actions:** `swap(handCard:plotCard:revealed:)`, `undoSwap()`, `confirmSwap()`.

**Automatic behavior:**

- The human acts first.
- Each AI then optionally swaps its lowest hand card for its best plot card if the plot card is meaningfully better.
- Each player may stage only one swap.
- When all players are confirmed, the engine enters `trick` with `currentPlayer = lead`.

**Key logic locations:**

- C engine swap and automatic turn logic in `Sources/KolkhozCEngine/`
- `KolkhozEngineAction(kind: .swap/.confirmSwap/.undoSwap, ...)`

### 3. Trick

**Purpose:** Players play one card each and determine a brigade leader.

**Human action:** `playCard(_:)`.

**Automatic behavior:**

- AI players choose a legal card automatically.
- Players must follow the lead suit if able.
- Trump beats lead suit.
- Highest card in the winning suit wins.
- Winner becomes brigade leader, gains a medal, leads the next trick, and enters assignment.

**Key logic locations:**

- C engine trick, winner, and legal-action logic in `Sources/KolkhozCEngine/`
- `KolkhozCEngineAdapter.legalActions()` and `apply(_:)`

### 4. Assignment

**Purpose:** The trick winner assigns captured work to jobs.

**Human actions:** `assign(card:to:)`, then `submitAssignments()` if the human won the
trick.

**Automatic behavior:**

- If an AI won the trick, it assigns automatically.
- Every trick enters assignment; there is no same-suit auto-assignment bypass in the Swift app.
- Legal target suits are the suits present in `lastTrick`.
- Each trick card may be assigned to any legal target suit.
- AI picks one best legal suit and assigns every trick card there.
- Work hours are applied, and any job reaching 40 hours is claimed immediately.

**Key logic locations:**

- C engine assignment and job-claim logic in `Sources/KolkhozCEngine/`
- `KolkhozEngineAction(kind: .assign/.submitAssignments, ...)`

### 5. Year-End Hand Movement

There is no `plotSelection` phase in Swift. When the year is complete, the engine calls
`moveRemainingHandsToPlots()` before requisition.

The year is complete when:

- `trickCount >= 4` in normal years.
- `trickCount >= 3` in famine.
- Any player has an empty hand.
- Or all players have exactly one card left.

### 6. Requisition

**Purpose:** Failed jobs may reveal and exile plot cards.

**Human action:** `continueAfterRequisition()`.

**Automatic behavior:**

- Requisition runs when entering the phase and records events for the UI.
- Failed jobs are those with `workHours[suit] < 40`.
- Trump Jack assigned to a failed job is the Drunkard and is exiled instead of player cards.
- Trump Queen assigned to a failed job is the Informant and reveals all players' matching hidden cards.
- Trump King assigned to a failed job is the Party Official and exiles two matching revealed cards instead of one.
- `northernStyle`, `miceVariant`, Informant, or having won a trick make a player vulnerable.
- `heroOfSovietUnion` grants immunity to a player who won every trick that year.
- Continuing removes exiled plot cards and transitions to the next year or game over.

**Key logic locations:**

- C engine requisition and continue logic in `Sources/KolkhozCEngine/`
- `KolkhozEngineAction(kind: .continueAfterRequisition, ...)`

### 7. Game Over

After requisition in year 5, the C engine transitions past year 5, calculates final
scores, and picks the player with the highest final plot score as the winner.

## Phase Transition Gotchas

### Famine

Famine is year 5 in the app. It is not based on revealing an Ace of Clubs.

Famine means:

- 3 tricks instead of 4.
- No trump suit.
- 4 cards dealt per player instead of 5.

### Assignment Targets

Legal assignment targets are only the suits present in the completed trick. This differs
from older docs/rules that said trump cards can go to any job.

### Requisition Timing

The engine records exiled cards and events, but plot cards remain visible for the
requisition screen. Removal is applied when the user continues.

### Swap Is Sequential

The app processes swap confirmations in player order. AI players are automatic, but the
implementation is not simultaneous `activePlayers` behavior.

## Debugging Phase Issues

```swift
print("[DEBUG] phase:", state.phase)
print("[DEBUG] year:", state.year, "trick:", state.trickCount)
print("[DEBUG] trump:", String(describing: state.trump), "famine:", state.isFamine)
print("[DEBUG] hands:", state.players.map { $0.hand.count })
```
