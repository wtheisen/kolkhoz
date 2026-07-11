-- Coordination state is intentionally separate from replayable game events.
-- Fencing tokens never reset: deleting rows on release would permit stale
-- owners to collide with a future token, so release expires the row instead.
CREATE TABLE IF NOT EXISTS game_session_leases (
    session_id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL,
    fencing_token BIGINT NOT NULL CHECK (fencing_token > 0),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS game_session_leases_expiry_idx
    ON game_session_leases (expires_at);
