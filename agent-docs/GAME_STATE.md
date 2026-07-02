# Game State Reference

The authoritative state is `KolkhozState` in
`ios/KolkhozSwiftUI/Sources/KolkhozCore/Models.swift`. Runtime state is produced by the
C engine through `KolkhozCEngineAdapter` or by online session snapshots, then copied into
`GameStore.state` for SwiftUI rendering.

## Complete State Shape

```swift
public struct KolkhozState {
    public var players: [PlayerState]
    public var lead: Int
    public var year: Int                  // 1...5
    public var trump: Suit?               // nil in famine
    public var jobPiles: [Suit: [Card]]
    public var revealedJobs: [Suit: Card]
    public var claimedJobs: Set<Suit>
    public var workHours: [Suit: Int]
    public var jobBuckets: [Suit: [Card]]
    public var currentTrick: [TrickPlay]
    public var lastTrick: [TrickPlay]
    public var lastWinner: Int?
    public var trickCount: Int
    public var exiled: [Int: [Card]]
    public var isFamine: Bool             // true in year 5
    public var phase: GamePhase
    public var currentPlayer: Int
    public var trumpSelector: Int
    public var pendingAssignments: [String: Suit]
    public var requisitionEvents: [RequisitionEvent]
    public var gameResult: GameResult?
    public var variants: GameVariants
    public var accumulatedJobCards: [Suit: [Card]]
    public var drunkardReplacements: [Card]
    public var swapConfirmed: Set<Int>
    public var swapCount: Set<Int>
    public var lastSwap: SwapRecord?
}
```

## Core Models

```swift
public enum Suit: String, CaseIterable {
    case wheat = "Wheat"
    case sunflower = "Sunflower"
    case potato = "Potato"
    case beet = "Beet"
}

public struct Card: Hashable, Identifiable {
    public let suit: Suit
    public let value: Int       // 1...5 for job rewards, 6...13 for workers
    public var id: String { "\(suit.rawValue)-\(value)" }
}

public enum GamePhase: String {
    case planning
    case swap
    case trick
    case assignment
    case requisition
    case gameOver
}
```

There is no Swift `plotSelection` phase. At year end, the engine immediately moves all
remaining hand cards into hidden plots before entering requisition.

## Players and Plots

Each `PlayerState` has:

- `id`: player index, with `0` as the human.
- `name`, `isHuman`.
- `hand`: cards currently playable or swappable.
- `plot.revealed`: visible plot cards and job rewards.
- `plot.hidden`: hidden plot cards.
- `plot.medals`: medals banked from previous years.
- `plot.stacks`: 36-card `ordenNachalniku` stacked rewards.
- `brigadeLeader`: true for the most recent trick winner.
- `hasWonTrickThisYear`: used for requisition vulnerability.
- `medals`: current-year trick wins.

## Variants

```swift
public struct GameVariants {
    public var deckType: Int              // 52 or 36
    public var nomenclature: Bool         // J/Q/K trump effects
    public var allowSwap: Bool            // years 2-5 swap phase
    public var northernStyle: Bool        // no job rewards, all vulnerable
    public var miceVariant: Bool          // reveal all matching hidden cards
    public var ordenNachalniku: Bool      // 36-card stacked job rewards
    public var medalsCount: Bool          // medals add to score
    public var accumulateJobs: Bool       // unclaimed rewards carry over
    public var heroOfSovietUnion: Bool    // all-trick winner is immune
}
```

Built-in presets are `kolkhoz`, `littleKolkhoz`, `campStyle`, and `custom`.

## Key State Mutations

### New Game

`KolkhozCEngineAdapter.init` and `newGame`:

- Make one human and three AI players.
- Randomize initial lead and trump selector.
- Build job piles.
- Reveal one job per suit.
- Set `isFamine` when `year == 5`.
- Deal 5 cards per player in normal years or 4 in famine.
- Process any automatic AI planning/trick/assignment actions in the C engine.

### Playing a Card

```swift
try engine.apply(KolkhozEngineAction(kind: .playCard, playerID: ..., card: ...))
```

When the trick reaches `state.numPlayers`, the C engine sets `lastWinner`, copies
`currentTrick` to `lastTrick`, increments `trickCount`, updates `lead`, awards a medal,
and enters `assignment`.

### Assigning Work

Assignments are keyed by `card.id`:

```swift
state.pendingAssignments[card.id] = targetSuit
```

Legal assignment targets are the suits present in `lastTrick`. A trick card may be
assigned to any of those suits. This is intentionally the current C/app behavior; do not use
the older "trump can go anywhere, non-trump to own suit" rule when working on the app.

Submitting assignments adds each card to `jobBuckets[targetSuit]` and adds work hours.
Trump Jack contributes 0 work when `nomenclature` is enabled.

### Completing a Job

When `workHours[suit] >= 40`, the suit is added to `claimedJobs`.

- 52-card, non-northern games: the current revealed job reward goes to the trick winner.
- `accumulateJobs`: accumulated unclaimed rewards plus the current reward go to the winner.
- 36-card `ordenNachalniku`: the lowest assigned card is revealed in a plot stack and the rest are hidden in that stack.
- `northernStyle`: no job reward is granted.

### Year End

The year is complete when:

- `trickCount >= 4` in normal years.
- `trickCount >= 3` in famine.
- Any player hand is empty.
- Or all players have exactly one hand card left.

At year end, remaining hand cards move to hidden plots, then requisition runs.

### Requisition

For each failed job (`workHours[suit] < 40`):

- If a trump Jack is assigned to that failed job, the Drunkard is exiled and player cards are spared for that job.
- Otherwise, vulnerable players reveal matching hidden cards.
- A player is vulnerable if `northernStyle`, `miceVariant`, an Informant is present, or the player won a trick this year.
- `miceVariant` and Informant reveal all matching hidden cards; otherwise only the highest matching hidden card is revealed.
- One revealed matching card is exiled, or two if a trump King is assigned to the failed job.
- `heroOfSovietUnion` makes a player immune after winning every trick in that year.

Exiled cards are recorded immediately in `state.exiled[state.year]`, but removed from
plots when the player continues after requisition.

### Scoring

`visibleScore` sums revealed plot cards and revealed cards in plot stacks. If
`medalsCount` is enabled, current and banked medals are added.

`finalScore` adds hidden plot cards to `visibleScore`. At game over, the player with the
highest final score wins.

## Validation Checks

### Valid Card Play

```swift
guard let leadSuit = state.currentTrick.first?.card.suit else {
    return true
}
let hasLeadSuit = hand.contains { $0.suit == leadSuit }
return !hasLeadSuit || hand[cardIndex].suit == leadSuit
```

### Valid Assignment

```swift
let legalTargets = Set(state.lastTrick.map(\.card.suit))
guard legalTargets.contains(suit),
      state.lastTrick.contains(where: { $0.card == card }) else {
    throw KolkhozMoveError.invalidAssignment
}
```

### Game Over

After requisition in year 5, the engine transitions past year 5, sets
`phase = .gameOver`, and stores `gameResult`.

## Debugging Tips

Inspect `KolkhozCEngineAdapter.snapshot`, `KolkhozCEngineAdapter.state`, online session
updates, or `GameStore.state`:

```swift
print("Year:", state.year, "Phase:", state.phase)
print("Trump:", String(describing: state.trump), "Famine:", state.isFamine)
print("Trick:", state.trickCount, "Current:", state.currentTrick.count)
print("Lead:", state.lead, "Turn:", state.currentPlayer)
```
