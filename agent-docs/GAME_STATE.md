# Game State Reference

The authoritative state is the `KCEngine` struct in
`engine/KolkhozCEngine/include/KolkhozCEngine.h`. Runtime state is produced by the C
engine, then projected into Dart table models for Flutter rendering.

## Core State Shape

The engine tracks:

- players, hands, revealed plots, hidden plots, medals, and stacked rewards;
- year, famine flag, trump suit, lead player, current player, and trump selector;
- job piles, revealed jobs, claimed jobs, work hours, and job buckets;
- current trick, last trick, last winner, trick count, and pending assignments;
- exiled cards and requisition events;
- variants, swap confirmations, staged swaps, and game result.

The Flutter projection mirrors only what the app needs to render and act on. Keep hidden
information redaction at the engine/server boundary when adding online behavior.

## Suits And Cards

The C engine uses numeric suit codes:

```text
0 wheat
1 sunflower
2 potato
3 beet
4 wrecker
```

Cards use a suit plus value. Normally values `1...5` are job rewards and values `6...13`
are worker cards. With Lotto Rewards, each crop instead uses `1...4` plus one seeded
random value from `5...13` as rewards; the selected lotto card is removed from the worker
deck. Face cards are `11` jack, `12` queen, and `13` king. The Saboteur variant
adds a special `wrecker-14` worker card. It counts as matching every crop suit, but it
does not add a fifth job suit or a fifth job pile.

Saboteur-specific behavior:

- default Kolkhoz enables `wrecker`;
- Saboteur is shuffled into the worker deck when no already-used Saboteur exists;
- Saboteur satisfies follow-suit for every crop suit;
- when Saboteur is the lead card, the trick has no ordinary lead suit;
- Saboteur has value `14` for trick ranking, work hours, and score if it reaches a plot;
- Saboteur can make any crop suit a legal assignment target because it matches every suit;
- a job containing Saboteur can claim its reward at 40 hours, but requisition still treats
  that job as failed;
- a plot Saboteur matches any failed job, but the same card is exiled only once per year.

## Phases

```text
0 planning
1 swap
2 trick
3 assignment
4 requisition
5 gameOver
6 pass
```

There is no separate plot-selection phase. At year end, the engine immediately moves all
remaining hand cards into hidden plots before entering requisition.

## Variants

The C `KCVariants` struct owns:

- `deck_type`
- `max_years`
- `nomenclature`
- `allow_swap`
- `northern_style`
- `mice_variant`
- `orden_nachalniku`
- `medals_count`
- `accumulate_jobs`
- `hero_of_soviet_union`
- `wrecker`
- `final_year_trump`
- `pass_cards`
- `highest_cards_requisition`
- `lotto_rewards`

## Key State Mutations

### New Game

The C engine initializes one human/default external seat plus AI seats depending on the
caller, randomizes initial lead/trump selector, builds job piles, reveals jobs, sets
famine for year 5, deals worker cards, and processes automatic AI turns as configured.

### Playing A Card

Card play is submitted as a C action. The engine validates follow-suit, mutates the
current trick, determines the winner when the trick completes, awards a medal, sets the
next lead, and enters assignment.

Saboteur counts as every crop suit for follow-suit and trump matching. A player with
Saboteur is considered able to follow any ordinary lead suit. If Saboteur itself leads, the
trick has no lead suit, so the highest card wins unless trump is present.

### Assigning Work

Assignments are stored by last-trick index in `pending_assignment_targets`. Legal target
suits are the suits present in `last_trick`. Any unassigned trick card may be assigned to
any legal target suit.

Submitting assignments moves cards into job buckets, adds work hours, claims completed
jobs, grants rewards, and advances to either the next trick or year-end requisition.

Saboteur can be assigned to any legal target job because it matches every crop suit. It
adds 14 work hours when assigned.

### Year End

The year is complete when:

- `trick_count >= 4` in normal years;
- `trick_count >= 3` in famine;
- any player hand is empty;
- or all players have exactly one hand card left.

At year end, remaining hand cards move to hidden plots, then requisition runs.

### Requisition

For each failed job (`work_hours[suit] < 40`):

- a trump jack assigned to the failed job is the Drunkard and is exiled instead of player cards;
- a trump queen assigned to the failed job is the Informant and reveals all matching hidden cards;
- a trump king assigned to the failed job is the Party Official and can exile two matching revealed cards;
- vulnerable players reveal/exile matching plot cards according to the active variants.

A job containing Saboteur is processed as failed even when its work hours reached 40 and
its reward was already claimed. Saboteur plot cards match every failed job, but the engine
does not exile the same Saboteur card more than once in the same year.

Exiled cards are recorded immediately, then removed from plots when requisition continues.

### Scoring

Visible score sums revealed plot cards and visible stacked rewards. Final score includes
hidden plot cards. Medals are included when `medals_count` is enabled.

## Validation Checks

### Valid Card Play

If a lead suit exists and the player has that suit, the played card must match the lead
suit. Otherwise any card in hand is legal.

Saboteur matches every lead suit. If Saboteur is the first card in the trick, there is no
lead suit to follow.

### Valid Assignment

The target suit must be present in the completed trick, and the card must be one of the
currently unassigned `last_trick` cards.

Because Saboteur matches every crop suit, a completed trick containing Saboteur makes every
crop suit a legal assignment target.

### Game Over

After requisition in year 5, the engine transitions to `gameOver` and stores final
scores/winner.

## Debugging Tips

Inspect the C engine through:

- `app/lib/src/c_engine_bridge.dart` accessors for Flutter behavior;
- `research/kolkhoz_research/c_engine.py` for Python/research behavior;
- temporary C-side logging only when necessary.

Useful values to print or expose in a test:

```text
phase, year, trick_count, trump, is_famine
current_player, lead, last_winner
current_trick_count, last_trick_count
pending_assignment_targets
hand counts and job work hours
```
