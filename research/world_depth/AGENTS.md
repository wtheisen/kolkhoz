# World-Depth Research Guidelines

This directory is an isolated art-production research workspace. Its outputs inform the
Figma plate workflow and Flutter camera lab, but they are not production assets.

## Before You Start

Read:

1. `../../design/field-plan-world/DEPTH_CARD_PIPELINE.md`
2. `BRIEF.md`
3. `camera_contract.json`
4. The experiment configuration named by the task, currently `north_bakeoff.json`

Do not read the game-state or phase documentation unless the task expands into gameplay,
engine, server, or production Flutter behavior.

## Ownership

Research workers may edit:

- reusable scripts and tests under `research/world_depth/`;
- ignored outputs under `research/runs/world_depth/`;
- a copied HTML report inside the current ignored run directory.

Preserve unrelated working-tree changes. Never revert another worker's edits.

## Do Not Touch

Without an explicit expansion of scope, do not modify:

- `app/assets/art/field_plan/game/backgrounds/`;
- `app/assets/art/field_plan/world_depth/`;
- `app/lib/` or engine/server code;
- `design/field-plan-world/`;
- the Figma file or its exported nodes.

Do not commit model repositories, checkpoints, virtual environments, caches, or generated
run artifacts. Keep them outside the repository or under ignored paths.

## Research Standard

- Pin model repository revisions and checkpoint identifiers.
- Record code and weight licenses separately.
- Preserve raw numeric outputs before visualization or quantization.
- Normalize reported depth to `0 = far`, `1 = near` and record every transform.
- Use visual evidence from the named source asset; generic benchmark claims are not enough.
- It is valid to conclude that no evaluated model is useful.

## Handoff

Return changed tracked paths, ignored artifact paths, reproduction commands, verification
results, licensing findings, representative evidence, and a concrete recommendation.
