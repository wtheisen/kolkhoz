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

Reveal jobs and set trump. Famine year has no trump and advances automatically. AI trump
selection is implemented in the C engine.

### 2. Swap

Each player may exchange at most one hand card with a hidden or revealed plot card when
`allow_swap` is enabled. Human/manual callers submit `swap`, `undoSwap`, and
`confirmSwap` actions; AI turns are automatic.

### 3. Trick

Players play one card each. The engine validates follow-suit, resolves trump/lead-suit
winner, awards a medal, stores `last_trick`, and enters assignment.

### 4. Assignment

The trick winner assigns captured cards to jobs. Legal target suits are only the suits
present in the completed trick. Every unassigned trick card may be assigned to any legal
target suit. Once all cards have pending targets, `submitAssignments` applies work and
claims rewards.

### 5. Year-End Hand Movement

There is no plot-selection phase. When a year is complete, the engine moves remaining
hand cards into hidden plots before requisition.

### 6. Requisition

Failed jobs may reveal and exile matching plot cards. Drunkard, Informant, Party
Official, mice, northern style, and hero immunity behavior all live in the C engine.

### 7. Game Over

After year 5 requisition, the engine calculates final scores and winner.

## Phase Transition Gotchas

### Famine

Famine is year 5. It means:

- 3 tricks instead of 4;
- no trump suit;
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
