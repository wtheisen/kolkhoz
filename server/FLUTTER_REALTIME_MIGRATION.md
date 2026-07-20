# Flutter realtime migration contract

The production server must **not** insert compatibility rows into
`public.game_updates`. That table is coupled by foreign keys and RLS to the legacy
`public.game_sessions` and `public.game_seats` authority. Dual-writing enough legacy
state to make those notifications visible would create two session authorities and
reintroduce cross-model transactions into the gameplay write path.

Flutter should replace only its Supabase `game_updates` subscription. HTTP response
models and action submission remain unchanged.

## Connection

```text
WS /sessions/{sessionID}/realtime
  ?viewerID={playerID}
  &afterRevision={lastAppliedActionLogCount}
Authorization: Bearer {supabaseAccessToken}
X-Kolkhoz-Seat-Token: {seatToken}
```

Use `wss` when the HTTP API uses `https`. Both credentials are mandatory. A missing,
invalid, or mismatched credential closes the socket with code `1008`.

## Frames

The server sends JSON frames in this order:

1. `{"type":"state","update": OnlineGameUpdate}` immediately after accepting.
2. `{"type":"catchUp","updates": OnlineGameUpdatesSince}` when
   `afterRevision` is behind the current revision.
3. `{"type":"committed","revision":N,"updates":OnlineGameUpdatesSince}` for
   newly committed gameplay actions.

Flutter may use these frames directly, but the smallest behavior-preserving migration
is to treat them as revision-aware refresh notifications:

- apply `state.update` through the existing newest-revision guard;
- for `catchUp` and `committed`, feed `updates`, `reactions`, and `resyncUpdate` through
  the existing incremental-update path;
- never move local `actionLogCount` backwards;
- reconnect using the last successfully applied `actionLogCount`;
- on close `1013`, reconnect and recover from the durable revision rather than retrying
  buffered frames.

Duplicate Redis deliveries are suppressed by event ID, and the HTTP catch-up endpoint
is the durable source of truth. Frames contain the authenticated viewer's projection;
clients must not change `viewerID` without opening a new authenticated connection.

## Metadata and reactions

The current WebSocket wake-up stream is action-revision based. Lobby seat changes,
invites, countdown changes, presence, and reactions do not increment that revision.
Until the server gains a separate monotonic metadata/reaction cursor, Flutter must keep
its existing periodic HTTP refresh while connected. This is the same correctness
fallback it already uses after subscribing to Supabase, and it prevents a realtime
transport migration from weakening behavior.

Removing that connected polling is a later optimization, not a parity requirement.
It requires a durable cursor for non-action changes; publishing same-revision wake-ups
would be lossy under reconnect and therefore is not an acceptable substitute.
