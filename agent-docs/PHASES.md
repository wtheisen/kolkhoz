# Game Phases & Transitions

Phase flow is owned by the C engine in `engine/KolkhozCEngine/`. Flutter renders the
current projected phase and submits legal C actions. Research code consumes the same
phase flow through the Python `ctypes` wrapper.

## Phase Flow Diagram

```text
                        +--------------+
                        |   planning   |
                        |  set trump   |
                        +------+-------+
                               |
              +----------------+----------------+
              | year > 1 && pass variant?       |
              +----------------+----------------+
                    yes        |        no
                     v         |         |
              +----------+     |         |
              |   pass   |-----+         |
              +----+-----+               |
                   |                     |
                   v                     v
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

Reveal jobs and set trump. With Final Year Trump enabled, the fifth-year leftover deal
card is public and sets trump automatically; a revealed Saboteur means no trump. The card
is then sent North and has no other effect. Otherwise famine has no trump and advances
automatically. AI trump selection is implemented in the C engine.

### 2. Pass

When enabled, every player privately selects one hand card in years 2-5. Selections lock
independently and all four cards move simultaneously: left in years 2 and 4, right in
years 3 and 5. Any card, including Saboteur, may be passed.

### 3. Swap

Each player may exchange at most one hand card with a hidden or revealed plot card when
`allow_swap` is enabled. Human/manual callers submit `swap`, `undoSwap`, and
`confirmSwap` actions; AI turns are automatic.

### 4. Trick

Players play one card each. The engine validates follow-suit, resolves trump/lead-suit
winner, awards a medal, stores `last_trick`, and enters assignment.

### 5. Assignment

The trick winner assigns captured cards to jobs. Legal target suits are only the suits
present in the completed trick. Every unassigned trick card may be assigned to any legal
target suit. Once all cards have pending targets, `submitAssignments` applies work and
claims rewards.

### 6. Year-End Hand Movement

There is no plot-selection phase. When a year is complete, the engine moves remaining
hand cards into hidden plots before requisition.

### 7. Requisition

Failed jobs may reveal and exile matching plot cards. Drunkard, Informant, Party
Official, mice, northern style, and hero immunity behavior all live in the C engine.

With Highest Cards Requisition, each vulnerable player's quota is the number of active
failed crop suits and the engine takes that player's highest cards across the combined
eligible suits. Party Official adds one to the quota. Drunkard removes its crop from both
the pool and the quota. A selected hidden card is revealed by being sent North; there is
no separate reveal step for cards selected for exile.

### 8. Game Over

After year 5 requisition, the engine calculates final scores and winner.

## Phase Transition Gotchas

### Famine

Famine is year 5. It means:

- 3 tricks instead of 4;
- normally no trump suit, unless Final Year Trump reveals an ordinary crop card;
- 4 cards dealt per player instead of 5.

### Assignment Targets

Legal assignment targets are only the suits present in the completed trick. Do not
reintroduce older assignment rules.

Saboteur counts as matching every crop suit for this check. A completed trick containing
Saboteur makes every crop suit a legal assignment target even though Saboteur is not a fifth
job suit.

### Requisition Timing

The engine records exiled cards and events immediately, but plot cards remain visible for
the requisition screen until the user continues.

A job containing Saboteur is requisitioned as failed even if it reached 40 work hours and
claimed its reward. A plot Saboteur matches any failed job, but a specific Saboteur card is
exiled only once in a year's requisition report.

### Swap Is Sequential

The app processes swap confirmations in player order. AI players are automatic.

### Pass Is Simultaneous

Pass selections are private until all four players have locked a card. The server redacts
each selection from other viewers, and the engine resolves all four transfers together.

## Debugging Phase Issues

Check:

```text
phase
year and trick_count
trump and famine
current_player and lead
hand counts
current_trick and last_trick counts
pending_assignment_targets
```
