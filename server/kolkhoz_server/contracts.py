from __future__ import annotations

import ctypes
from http import HTTPStatus
from typing import Iterable, Mapping, Sequence

from research.kolkhoz_research.c_engine import (
    KCAction,
    KCCard,
    KCCardList,
    KCControllers,
    KCEngineSnapshot,
    KCPlayer,
    KCPlotStack,
    KCVariants,
    MAX_YEARS,
    PLAYER_COUNT,
    SUIT_COUNT,
)

from .errors import ServerError
from .model import JsonObject


PHASE_GAME_OVER = 5
CONTROLLER_CODES = {
    "human": 0,
    "heuristicAI": 1,
    "mediumAI": 2,
    "neuralAI": 2,
}
DEFAULT_VARIANTS: JsonObject = {
    "deckType": 52,
    "maxYears": 5,
    "nomenclature": False,
    "allowSwap": True,
    "northernStyle": False,
    "miceVariant": False,
    "ordenNachalniku": False,
    "medalsCount": False,
    "accumulateJobs": False,
    "heroOfSovietUnion": True,
    "wrecker": True,
}


def normalize_variants(value: object) -> JsonObject:
    if value is None:
        return dict(DEFAULT_VARIANTS)
    if not isinstance(value, dict):
        raise ServerError(HTTPStatus.BAD_REQUEST, "invalid variants")
    result = dict(DEFAULT_VARIANTS)
    for key in result:
        if key in value:
            result[key] = value[key]
    return result


def variants_native(variants: Mapping[str, object]) -> KCVariants:
    return KCVariants(
        int(variants["deckType"]),
        int(variants["maxYears"]),
        bool(variants["nomenclature"]),
        bool(variants["allowSwap"]),
        bool(variants["northernStyle"]),
        bool(variants["miceVariant"]),
        bool(variants["ordenNachalniku"]),
        bool(variants["medalsCount"]),
        bool(variants["accumulateJobs"]),
        bool(variants["heroOfSovietUnion"]),
        bool(variants["wrecker"]),
    )


def normalize_controllers(value: object) -> list[str]:
    if value is None:
        controllers = ["human"] * PLAYER_COUNT
    elif isinstance(value, list):
        controllers = [str(item) for item in value[:PLAYER_COUNT]]
    else:
        raise ServerError(HTTPStatus.BAD_REQUEST, "invalid controllers")
    controllers.extend(["human"] * (PLAYER_COUNT - len(controllers)))
    for controller in controllers:
        if controller not in CONTROLLER_CODES:
            raise ServerError(
                HTTPStatus.BAD_REQUEST,
                f"unsupported online controller {controller!r}",
            )
    if "human" not in controllers:
        controllers[0] = "human"
    return controllers


def controllers_native(controllers: Sequence[str]) -> KCControllers:
    native = KCControllers()
    for index, controller in enumerate(controllers[:PLAYER_COUNT]):
        native.seats[index] = CONTROLLER_CODES[controller]
    return native


def action_to_json(action: KCAction, *, source: str | None = None) -> JsonObject:
    value: JsonObject = {
        "kind": int(action.kind),
        "playerID": int(action.player_id),
        "suit": int(action.suit),
        "card": card_to_json(action.card),
        "handCard": card_to_json(action.hand_card),
        "plotCard": card_to_json(action.plot_card),
        "plotZone": int(action.plot_zone),
        "targetSuit": int(action.target_suit),
    }
    if source is not None:
        value["source"] = source
    return value


def action_from_json(value: object) -> KCAction:
    if not isinstance(value, dict):
        raise ServerError(HTTPStatus.BAD_REQUEST, "invalid action")
    return KCAction(
        required_int(value.get("kind"), "kind"),
        required_int(value.get("playerID"), "playerID"),
        optional_int(value.get("suit"), -1),
        card_from_json(value.get("card")),
        card_from_json(value.get("handCard")),
        card_from_json(value.get("plotCard")),
        optional_int(value.get("plotZone"), -1),
        optional_int(value.get("targetSuit"), -1),
    )


def action_signature(action: KCAction) -> tuple[int, ...]:
    return (
        int(action.kind),
        int(action.player_id),
        int(action.suit),
        int(action.card.suit),
        int(action.card.value),
        int(action.hand_card.suit),
        int(action.hand_card.value),
        int(action.plot_card.suit),
        int(action.plot_card.value),
        int(action.plot_zone),
        int(action.target_suit),
    )


def action_in(action: KCAction, actions: Iterable[KCAction]) -> bool:
    signature = action_signature(action)
    return any(action_signature(candidate) == signature for candidate in actions)


def card_to_json(card: KCCard) -> dict[str, int]:
    return {"suit": int(card.suit), "value": int(card.value)}


def card_from_json(value: object) -> KCCard:
    if not isinstance(value, dict):
        return KCCard(-1, 0)
    return KCCard(
        optional_int(value.get("suit"), -1),
        optional_int(value.get("value"), 0),
    )


def privacy_safe_action_log(
    actions: Iterable[Mapping[str, object]],
    viewer_id: int | None,
    *,
    game_over: bool,
) -> list[JsonObject]:
    result: list[JsonObject] = []
    for action in actions:
        value = dict(action)
        if (
            not game_over
            and optional_int(value.get("playerID")) != viewer_id
            and value.get("kind") in (2, 8)
        ):
            value["handCard"] = {"suit": -1, "value": -1}
            value["plotCard"] = {"suit": -1, "value": -1}
        result.append(value)
    return result


def snapshot_json(
    engine: object, pointer: ctypes.c_void_p, viewer_id: int | None
) -> JsonObject:
    state = engine.snapshot(pointer)
    game_over = int(state.phase) == PHASE_GAME_OVER
    return {
        "year": int(state.year),
        "phase": int(state.phase),
        "currentPlayer": int(state.current_player),
        "waitingPlayer": engine.waiting_player(pointer),
        "waitingForExternalAction": engine.waiting_for_external_action(pointer),
        "lead": int(state.lead),
        "trumpSelector": int(state.trump_selector),
        "trump": int(state.trump),
        "trickCount": int(state.trick_count),
        "isFamine": bool(state.is_famine),
        "players": [
            player_to_json(state.players[i], viewer_id) for i in range(PLAYER_COUNT)
        ],
        "jobPiles": redacted_suit_cards(SUIT_COUNT),
        "revealedJobs": revealed_jobs_json(state),
        "claimedJobs": [s for s in range(SUIT_COUNT) if bool(state.claimed_jobs[s])],
        "workHours": [
            {"suit": s, "value": int(state.work_hours[s])} for s in range(SUIT_COUNT)
        ],
        "jobBuckets": job_buckets_json(state),
        "accumulatedJobCards": redacted_suit_cards(SUIT_COUNT),
        "currentTrick": trick_json(state.current_trick, state.current_trick_count),
        "lastTrick": trick_json(state.last_trick, state.last_trick_count),
        "lastWinner": int(state.last_winner),
        "exiled": suit_card_lists_json(state.exiled, MAX_YEARS + 1),
        "exiledPlayers": [
            {
                "suit": year,
                "values": [
                    int(state.exiled_player_ids[year][index])
                    for index in range(int(state.exiled[year].count))
                ],
            }
            for year in range(MAX_YEARS + 1)
        ],
        "pendingAssignments": pending_assignments_json(state),
        "requisitionEvents": requisition_events_json(state),
        "scores": [
            score_json(engine, pointer, i, viewer_id, game_over)
            for i in range(PLAYER_COUNT)
        ],
        "winnerID": int(state.winner_id),
        "swapConfirmed": [
            i for i in range(PLAYER_COUNT) if bool(state.swap_confirmed[i])
        ],
        "swapCount": [i for i in range(PLAYER_COUNT) if bool(state.swap_count[i])],
    }


def update_json(
    *,
    session_id: str,
    seed: int,
    invite_code: str,
    viewer_id: int | None,
    actions: Sequence[Mapping[str, object]],
    started: bool,
    lobby_countdown_ends_at: float | None,
    reactions: Sequence[Mapping[str, object]],
    variants: Mapping[str, object],
    controllers: Sequence[str],
    ranked: bool,
    browser_joinable: bool,
    player_profiles: Sequence[Mapping[str, object]],
    seat_presence: Sequence[Mapping[str, object]],
    turn_player_id: int | None,
    turn_deadline_at: float | None,
    snapshot: Mapping[str, object],
    legal_actions: Sequence[KCAction] = (),
) -> JsonObject:
    game_over = int(snapshot.get("phase", -1)) == PHASE_GAME_OVER
    waiting = snapshot.get("waitingPlayer")
    return {
        "sessionID": session_id,
        "seed": seed,
        "inviteCode": invite_code,
        "viewerID": viewer_id,
        "actionLogCount": len(actions),
        "started": started,
        "lobbyCountdownEndsAt": lobby_countdown_ends_at,
        "gameLogActions": privacy_safe_action_log(
            actions, viewer_id, game_over=game_over
        ),
        "reactions": [dict(entry) for entry in reactions],
        "isViewerTurn": bool(
            started and viewer_id is not None and waiting == viewer_id
        ),
        "legalActions": [
            action_to_json(action)
            for action in legal_actions
            if action.player_id == viewer_id
        ],
        "variants": dict(variants),
        "controllers": list(controllers),
        "ranked": ranked,
        "browserJoinable": browser_joinable,
        "playerProfiles": [dict(profile) for profile in player_profiles],
        "seatPresence": [dict(presence) for presence in seat_presence],
        "turnPlayerID": turn_player_id,
        "turnDeadlineAt": turn_deadline_at,
        "snapshot": dict(snapshot),
    }


def listing_json(
    *,
    session_id: str,
    invite_code: str,
    open_seats: Sequence[int],
    occupied_seats: Iterable[int],
    controllers: Sequence[str],
    ranked: bool,
    browser_joinable: bool,
    player_profiles: Sequence[Mapping[str, object]],
    seat_presence: Sequence[Mapping[str, object]],
    turn_player_id: int | None,
    turn_deadline_at: float | None,
    action_log_count: int,
    started: bool,
    lobby_countdown_ends_at: float | None,
    created_at: float,
    expires_at: float,
) -> JsonObject:
    return {
        "sessionID": session_id,
        "inviteCode": invite_code,
        "openSeats": list(open_seats),
        "occupiedSeats": sorted(occupied_seats),
        "controllers": list(controllers),
        "ranked": ranked,
        "browserJoinable": browser_joinable,
        "playerProfiles": [dict(profile) for profile in player_profiles],
        "seatPresence": [dict(presence) for presence in seat_presence],
        "turnPlayerID": turn_player_id,
        "turnDeadlineAt": turn_deadline_at,
        "actionLogCount": action_log_count,
        "started": started,
        "lobbyCountdownEndsAt": lobby_countdown_ends_at,
        "createdAt": created_at,
        "expiresAt": expires_at,
    }


def player_to_json(player: KCPlayer, viewer_id: int | None) -> JsonObject:
    is_viewer = viewer_id == int(player.id)
    return {
        "id": int(player.id),
        "hand": card_list_json(player.hand) if is_viewer else [],
        "revealedPlot": card_list_json(player.plot_revealed),
        "hiddenPlot": card_list_json(player.plot_hidden) if is_viewer else [],
        "hiddenPlotCount": int(player.plot_hidden.count),
        "medals": int(player.medals),
        "bankedMedals": int(player.plot_medals),
        "brigadeLeader": bool(player.brigade_leader),
        "wonTrickThisYear": bool(player.has_won_trick_this_year),
        "stacks": [
            stack_json(player.stacks[i], is_viewer)
            for i in range(int(player.stack_count))
        ],
    }


def stack_json(stack: KCPlotStack, is_viewer: bool) -> JsonObject:
    return {
        "revealed": cards_json(stack.revealed, stack.revealed_count),
        "hidden": cards_json(stack.hidden, stack.hidden_count) if is_viewer else [],
        "hiddenCount": int(stack.hidden_count),
    }


def card_list_json(cards: KCCardList) -> list[dict[str, int]]:
    return cards_json(cards.cards, cards.count)


def cards_json(cards: object, count: int) -> list[dict[str, int]]:
    return [card_to_json(cards[i]) for i in range(int(count))]


def suit_card_lists_json(cards_by_suit: object, count: int) -> list[JsonObject]:
    return [
        {"suit": suit, "cards": card_list_json(cards_by_suit[suit])}
        for suit in range(count)
    ]


def redacted_suit_cards(count: int) -> list[JsonObject]:
    return [{"suit": suit, "cards": []} for suit in range(count)]


def revealed_jobs_json(state: KCEngineSnapshot) -> list[JsonObject]:
    return [
        {
            "suit": suit,
            "cards": [card_to_json(state.revealed_jobs[suit])]
            if bool(state.has_revealed_job[suit])
            else [],
        }
        for suit in range(SUIT_COUNT)
    ]


def job_buckets_json(state: KCEngineSnapshot) -> list[JsonObject]:
    return [
        {
            "suit": suit,
            "cards": [
                {
                    **card_to_json(state.job_buckets[suit].cards[i]),
                    "assignmentRound": int(state.job_bucket_tricks[suit][i]),
                }
                for i in range(int(state.job_buckets[suit].count))
            ],
        }
        for suit in range(SUIT_COUNT)
    ]


def trick_json(plays: object, count: int) -> list[JsonObject]:
    return [
        {"playerID": int(plays[i].player_id), "card": card_to_json(plays[i].card)}
        for i in range(int(count))
    ]


def pending_assignments_json(state: KCEngineSnapshot) -> list[JsonObject]:
    return [
        {
            "card": card_to_json(state.last_trick[i].card),
            "targetSuit": int(state.pending_assignment_targets[i]),
        }
        for i in range(int(state.last_trick_count))
        if int(state.pending_assignment_targets[i]) >= 0
    ]


def requisition_events_json(state: KCEngineSnapshot) -> list[JsonObject]:
    return [
        {
            "playerID": int(event.player_id),
            "suit": int(event.suit),
            "card": card_to_json(event.card),
            "message": requisition_message(int(event.message_kind)),
        }
        for event in (
            state.requisition_events[i]
            for i in range(int(state.requisition_event_count))
        )
    ]


def requisition_message(kind: int) -> str:
    return {
        1: "Card sent north.",
        2: "No matching card found.",
        3: "Drunkard exiled.",
        4: "Protected from requisition.",
    }.get(kind, "Requisition resolved.")


def score_json(
    engine: object,
    pointer: ctypes.c_void_p,
    player_id: int,
    viewer_id: int | None,
    game_over: bool,
) -> dict[str, int]:
    visible = int(engine.lib.kc_visible_score(pointer, ctypes.c_int32(player_id)))
    final = int(engine.lib.kc_final_score(pointer, ctypes.c_int32(player_id)))
    if not game_over and viewer_id != player_id:
        final = visible
    return {"playerID": player_id, "visibleScore": visible, "finalScore": final}


def optional_int(value: object, default: int | None = None) -> int | None:
    if value is None:
        return default
    if isinstance(value, bool):
        raise ServerError(HTTPStatus.BAD_REQUEST, "expected integer")
    try:
        return int(value)
    except (TypeError, ValueError) as error:
        raise ServerError(HTTPStatus.BAD_REQUEST, "expected integer") from error


def required_int(value: object, field: str) -> int:
    result = optional_int(value)
    if result is None:
        raise ServerError(HTTPStatus.BAD_REQUEST, f"missing {field}")
    return result


def optional_bool(value: object, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "1", "yes"}:
            return True
        if lowered in {"false", "0", "no"}:
            return False
    raise ServerError(HTTPStatus.BAD_REQUEST, "expected boolean")


def string_list(value: object) -> list[str]:
    values = [] if value is None else value if isinstance(value, list) else [value]
    return [text for item in values if (text := str(item).strip())]
