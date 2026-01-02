# Claude Code Guidelines

## Before You Start

Read the agent documentation in `agent-docs/`:
1. `OVERVIEW.md` - Project structure and quick start
2. `ARCHITECTURE.md` - How the codebase is organized
3. `GAME_STATE.md` - The G object and state mutations
4. `PHASES.md` - Game phase flow and transitions

## Code Principles

**Keep it simple.** This is a card game, not enterprise software. Prefer straightforward solutions over clever abstractions.

**Follow the frameworks:**
- **boardgame.io** - Use phases, moves, and hooks as intended. Don't fight the framework.
- **React** - Functional components, hooks, minimal state. Let boardgame.io manage game state.
- **Vite** - Standard ES modules. No special configuration needed.

**Write minimal code:**
- Fix what's broken, don't refactor what works
- No premature abstractions or "just in case" code
- If three lines work, don't write a utility function
- Delete dead code, don't comment it out

**Test before committing:**
```bash
npm run test:run
npm run build
```

## Frontend Work

**Always use the frontend-design skill** when working on UI/CSS. It helps think through layout problems properly instead of trial-and-error with CSS values.

## Common Patterns

**Game logic** goes in `src/game/` - pure functions that mutate G.

**UI components** go in `src/client/components/` - render state, call moves.

**Phase transitions** use boardgame.io hooks: `onBegin`, `onEnd`, `endIf`, `next`.

**State changes** happen by directly mutating G in moves and hooks (boardgame.io uses Immer).

## When Debugging

Check the phase flow in `agent-docs/PHASES.md`. Most bugs are phase transition issues - wrong `endIf` conditions, missing state resets, or hooks not running.
