from __future__ import annotations

import pytest

from server.kolkhoz_server.errors import ServerError
from server.kolkhoz_server.session import SessionAggregate


def session(**overrides: object) -> SessionAggregate:
    values = {
        "session_id": "game-1",
        "invite_code": "ABC123",
        "seed": 7,
        "variants": {"wrecker": True},
        "controllers": ["human"] * 4,
        "created_by_user_id": "host",
        "created_at": 10.0,
        "lobby_countdown_seconds": 30.0,
    }
    values.update(overrides)
    return SessionAggregate(**values)  # type: ignore[arg-type]


def join(aggregate: SessionAggregate, user: str, player: int, now: float) -> str:
    selected, token, _ = aggregate.join(
        user_id=user,
        preferred_player_id=player,
        via_invite_code=True,
        token=f"token-{user}",
        now=now,
    )
    assert selected == player
    return token


def test_full_lobby_counts_down_starts_and_replays() -> None:
    aggregate = session()
    emitted = []
    for player, user in enumerate(("host", "two", "three", "four")):
        _, _, events = aggregate.join(
            user_id=user,
            preferred_player_id=player,
            via_invite_code=True,
            token=f"token-{user}",
            now=20.0 + player,
        )
        emitted.extend(events)

    assert aggregate.lobby_countdown_ends_at == 53.0
    assert aggregate.sync_lobby(52.9) == []
    emitted.extend(aggregate.sync_lobby(53.0))
    assert aggregate.started
    assert emitted[-1].kind == "session_started"

    rebuilt = SessionAggregate.replay(
        events=emitted,
        session_id="game-1",
        invite_code="ABC123",
        seed=7,
        variants={"wrecker": True},
        controllers=["human"] * 4,
        created_by_user_id="host",
        created_at=10.0,
    )
    assert rebuilt.listing(54.0) == aggregate.listing(54.0)


def test_leaving_or_kicking_cancels_countdown_and_clears_seat() -> None:
    aggregate = session()
    tokens = [
        join(aggregate, user, i, 20.0 + i)
        for i, user in enumerate(("host", "u1", "u2", "u3"))
    ]
    events = aggregate.kick(
        host_player_id=0,
        target_player_id=3,
        token=tokens[0],
        user_id="host",
        now=25.0,
    )
    assert [event.kind for event in events] == ["seat_kicked", "lobby_countdown_set"]
    assert aggregate.lobby_countdown_ends_at is None

    token = join(aggregate, "replacement", 3, 26.0)
    events = aggregate.leave(player_id=3, token=token, user_id="replacement", now=27.0)
    assert [event.kind for event in events] == ["seat_left", "lobby_countdown_set"]


def test_private_invites_require_host_comrades_and_are_consumed() -> None:
    aggregate = session(browser_joinable=False)
    join(aggregate, "host", 0, 11.0)
    events = aggregate.invite(
        actor_user_id="host",
        user_ids=["friend"],
        comrade_user_ids={"friend"},
        now=12.0,
    )
    assert events[0].kind == "users_invited"
    assert aggregate.pending_invite("friend")
    _, _, events = aggregate.join(user_id="friend", now=13.0, token="friend-token")
    assert "invite_consumed" in [event.kind for event in events]
    assert not aggregate.pending_invite("friend")

    with pytest.raises(ServerError, match="only the host"):
        aggregate.invite(
            actor_user_id="friend",
            user_ids=["other"],
            comrade_user_ids={"other"},
            now=14.0,
        )


def test_declined_invite_cannot_be_joined_through_private_listing() -> None:
    aggregate = session(browser_joinable=False)
    aggregate.invite(
        actor_user_id="host", user_ids=["friend"], comrade_user_ids={"friend"}, now=11.0
    )
    aggregate.decline_invite(user_id="friend", now=12.0)
    assert not aggregate.pending_invite("friend")
    with pytest.raises(ServerError, match="not invited"):
        aggregate.join(user_id="friend", now=13.0)


def test_presence_deadline_timeout_and_abandonment_lifecycle() -> None:
    aggregate = session(lobby_countdown_seconds=0.0)
    tokens = [join(aggregate, f"u{i}", i, 20.0) for i in range(4)]
    aggregate.sync_lobby(20.0)
    aggregate.set_waiting_player(1, now=21.0)
    assert aggregate.turn_deadline_at == 111.0
    assert aggregate.seat_presence(41.0)[1]["connected"] is False
    aggregate.mark_seen(player_id=1, now=41.0)
    assert aggregate.seat_presence(41.0)[1]["connected"] is True

    with pytest.raises(ServerError, match="has not elapsed"):
        aggregate.record_timeout(player_id=1, now=110.0)
    aggregate.record_timeout(player_id=1, now=111.0)
    assert aggregate.seats[1].timeouts == 1
    aggregate.set_waiting_player(1, now=112.0)
    events = aggregate.record_timeout(player_id=1, now=202.0)
    assert [event.kind for event in events] == [
        "seat_timeout_recorded",
        "seat_abandoned",
        "turn_deadline_set",
    ]
    assert aggregate.seats[1].autopilot
    assert aggregate.seats[1].abandoned

    leave_events = aggregate.leave(
        player_id=1, token=tokens[1], user_id="u1", now=203.0
    )
    assert leave_events[0].kind == "seat_abandoned"


def test_reactions_revision_listing_and_update_input() -> None:
    aggregate = session(lobby_countdown_seconds=0.0)
    tokens = [join(aggregate, f"u{i}", i, 20.0) for i in range(4)]
    aggregate.sync_lobby(20.0)
    aggregate.advance_action_revision(expected=0, now=21.0)
    aggregate.set_waiting_player(2, now=22.0)
    aggregate.react(
        player_id=0,
        token=tokens[0],
        user_id="u0",
        reaction_id="comrade",
        year=3,
        phase=2,
        now=23.0,
    )
    listing = aggregate.listing(23.0)
    update = aggregate.update_input(viewer_id=2, now=23.0)
    assert listing["actionLogCount"] == 1
    assert update["isViewerTurn"] is True
    assert update["reactions"][0]["reactionID"] == "comrade"
    with pytest.raises(ServerError, match="stale action"):
        aggregate.advance_action_revision(expected=0, now=24.0)


def test_tokens_are_hashed_and_wrong_identity_is_rejected() -> None:
    aggregate = session()
    token = join(aggregate, "host", 0, 11.0)
    assert aggregate.seats[0].token_hash != token
    with pytest.raises(ServerError, match="invalid seat token"):
        aggregate.authenticate(0, "wrong", "host")
    with pytest.raises(ServerError, match="invalid auth token") as rejected:
        aggregate.authenticate(0, token, "impostor")
    assert rejected.value.status == 401
