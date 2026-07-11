-- Durable command receipts close the at-least-once delivery gap. The worker's
-- game-event transaction inserts one row using the same command_id and fencing
-- token; a redelivered command can then return result_json without mutating twice.
CREATE TABLE IF NOT EXISTS game_command_receipts (
    command_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    fencing_token BIGINT NOT NULL CHECK (fencing_token > 0),
    result_json JSONB NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

COMMENT ON TABLE game_command_receipts IS
    'Atomic receipts for game.create, game.submit_action, game.set_autopilot, and game.delete. Automatic advancement is a replay-safe sequence of per-event commits, so its retry count is not an exactly-once result.';

CREATE INDEX IF NOT EXISTS game_command_receipts_session_idx
    ON game_command_receipts (session_id, completed_at DESC);

-- Redis Streams is the active retry/dead-letter transport. This table is an
-- optional long-term poison-message archive for operators and incident review.
CREATE TABLE IF NOT EXISTS game_command_dead_letters (
    command_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    fencing_token BIGINT NOT NULL CHECK (fencing_token > 0),
    command_json JSONB NOT NULL,
    attempts INTEGER NOT NULL CHECK (attempts > 0),
    error TEXT NOT NULL,
    failed_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
