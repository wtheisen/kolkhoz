from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from server.kolkhoz_server.contracts import (
    action_from_json,
    controllers_native,
    normalize_controllers,
    normalize_variants,
    variants_native,
)
from server.kolkhoz_server.model import ENGINE_REPLAY_CONTRACT_VERSION

from .c_engine import CEngine


@dataclass(frozen=True)
class OnlineReplayResult:
    player_id: int
    score: int
    rank: int
    won: bool
    rating_before: int


@dataclass(frozen=True)
class OnlineReplayEvent:
    revision: int
    payload: dict[str, Any]


@dataclass(frozen=True)
class OnlineReplayGame:
    session_id: str
    seed: int
    variants: dict[str, Any]
    engine_build_sha: str
    engine_sha256: str
    engine_contract_version: int
    completed_at: str
    results: tuple[OnlineReplayResult, ...]
    events: tuple[OnlineReplayEvent, ...]


class ReplayCompatibilityError(RuntimeError):
    pass


def load_online_replay_games(
    database_url: str,
    *,
    engine_build_sha: str,
    engine_sha256: str,
    min_player_rating: int,
    limit_games: int,
    since: str | None = None,
) -> list[OnlineReplayGame]:
    if limit_games < 1:
        raise ValueError("limit_games must be positive")
    try:
        import psycopg
    except ImportError as error:
        raise RuntimeError("online trajectory export requires psycopg") from error

    connection = psycopg.connect(
        database_url,
        autocommit=False,
        prepare_threshold=None,
        connect_timeout=5,
        options="-c statement_timeout=30000",
    )
    try:
        rows = connection.execute(
            """
            select games.session_id::text, games.seed, games.variants,
                   games.engine_build_sha, games.engine_sha256,
                   games.engine_contract_version, max(results.completed_at)::text
              from server_games games
              join server_sessions sessions using (session_id)
              join server_game_results results using (session_id)
             where sessions.status = 'finished'
               and games.engine_build_sha = %s
               and games.engine_sha256 = %s
               and games.engine_contract_version = %s
               and games.variants->'controllers'
                   = '["human","human","human","human"]'::jsonb
               and not exists (
                   select 1
                     from server_game_events automatic_event
                    where automatic_event.session_id = games.session_id
                      and automatic_event.kind = 'action'
                      and automatic_event.payload->>'source' = 'automatic'
                      and (automatic_event.payload->>'kind')::integer not in (10, 11)
               )
               and (%s::timestamptz is null or results.completed_at >= %s::timestamptz)
             group by games.session_id
            having count(*) = 4
               and count(distinct results.player_id) = 4
               and bool_and(results.controller = 'human')
               and count(results.display_rating_before) = 4
               and min(results.display_rating_before) >= %s
             order by max(results.completed_at) desc
             limit %s
            """,
            (
                engine_build_sha,
                engine_sha256,
                ENGINE_REPLAY_CONTRACT_VERSION,
                since,
                since,
                min_player_rating,
                limit_games,
            ),
        ).fetchall()
        games: list[OnlineReplayGame] = []
        for row in rows:
            session_id = str(row[0])
            result_rows = connection.execute(
                """
                select player_id, score, rank, won, display_rating_before
                  from server_game_results
                 where session_id = %s::uuid
                 order by player_id
                """,
                (session_id,),
            ).fetchall()
            event_rows = connection.execute(
                """
                select revision, payload
                  from server_game_events
                 where session_id = %s::uuid and kind = 'action'
                 order by revision
                """,
                (session_id,),
            ).fetchall()
            games.append(
                OnlineReplayGame(
                    session_id=session_id,
                    seed=int(row[1]),
                    variants=dict(row[2]),
                    engine_build_sha=str(row[3]),
                    engine_sha256=str(row[4]),
                    engine_contract_version=int(row[5]),
                    completed_at=str(row[6]),
                    results=tuple(
                        OnlineReplayResult(
                            player_id=int(result[0]),
                            score=int(result[1]),
                            rank=int(result[2]),
                            won=bool(result[3]),
                            rating_before=int(result[4]),
                        )
                        for result in result_rows
                    ),
                    events=tuple(
                        OnlineReplayEvent(int(event[0]), dict(event[1]))
                        for event in event_rows
                    ),
                )
            )
        return games
    finally:
        connection.close()


def trajectory_records_for_game(
    engine: CEngine,
    game: OnlineReplayGame,
    *,
    input_size: int,
    include_forced_actions: bool = False,
) -> list[dict[str, Any]]:
    from .torch_policy import (
        _action_dict,
        _action_signature,
        _candidate_index_for_action,
        _dense_features_record,
        _phase_name,
    )

    if game.engine_contract_version != ENGINE_REPLAY_CONTRACT_VERSION:
        raise ReplayCompatibilityError(
            f"{game.session_id} uses engine replay contract "
            f"{game.engine_contract_version}, expected {ENGINE_REPLAY_CONTRACT_VERSION}"
        )
    current_sha = engine.provenance().c_sha256
    current_build_sha = engine.provenance().git_sha
    if game.engine_build_sha != current_build_sha:
        raise ReplayCompatibilityError(
            f"{game.session_id} engine build {game.engine_build_sha} "
            f"does not match local build {current_build_sha}"
        )
    if game.engine_sha256 != current_sha:
        raise ReplayCompatibilityError(
            f"{game.session_id} engine digest {game.engine_sha256} "
            f"does not match local engine {current_sha}"
        )
    if len(game.results) != 4:
        raise ReplayCompatibilityError(f"{game.session_id} does not have four results")

    game_variants = game.variants.get("variants", game.variants)
    controllers = normalize_controllers(game.variants.get("controllers"))
    if controllers != ["human"] * 4:
        raise ReplayCompatibilityError(
            f"{game.session_id} is not an all-human trajectory"
        )
    pointer = engine.new_engine(
        game.seed,
        variants=variants_native(normalize_variants(game_variants)),
        controllers=controllers_native(controllers),
    )
    results = {result.player_id: result for result in game.results}
    scores = [results[player_id].score for player_id in range(4)]
    records: list[dict[str, Any]] = []
    try:
        for event in game.events:
            payload = event.payload
            action = action_from_json(payload)
            source = str(payload.get("source") or "manual")
            player_id = int(payload.get("playerID", -1))
            if source != "automatic" and 0 <= player_id < 4:
                candidates = engine.dense_policy_action_features(
                    pointer, player_id=player_id, input_size=input_size
                )
                target_index = _candidate_index_for_action(candidates, action)
                if target_index is None:
                    is_legal = any(
                        _action_signature(candidate) == _action_signature(action)
                        for candidate in engine.legal_actions(pointer)
                    )
                    if len(candidates) > 0 or not is_legal:
                        raise ReplayCompatibilityError(
                            f"{game.session_id} revision {event.revision} "
                            "does not match a trainable local-engine action"
                        )
                elif include_forced_actions or len(candidates) > 1:
                    heuristic = engine.heuristic_action(pointer)
                    heuristic_index = _candidate_index_for_action(
                        candidates, heuristic
                    )
                    if heuristic_index is None:
                        raise ReplayCompatibilityError(
                            f"{game.session_id} revision {event.revision} "
                            "does not contain the local heuristic action"
                        )
                    result = results[player_id]
                    opponent_score = max(
                        score
                        for seat, score in enumerate(scores)
                        if seat != player_id
                    )
                    target_value = (
                        float(result.won)
                        - 0.05 * float(result.rank - 1)
                        + 0.001 * float(result.score - opponent_score)
                    )
                    phase_id = engine.phase(pointer)
                    records.append(
                        {
                            "format": "kolkhoz-supervised-trajectory-v3",
                            "source": "online-human-expert",
                            "source_game": game.session_id,
                            "engine_build_sha": game.engine_build_sha,
                            "engine_sha256": game.engine_sha256,
                            "engine_contract_version": game.engine_contract_version,
                            "seed": game.seed,
                            "action_index": event.revision,
                            "phase_id": phase_id,
                            "phase": _phase_name(phase_id),
                            "player_id": player_id,
                            "player_rating_before": result.rating_before,
                            "target_index": target_index,
                            "heuristic_index": heuristic_index,
                            "baseline_index": heuristic_index,
                            "target_value": target_value,
                            "target_action": _action_dict(action),
                            "heuristic_action": _action_dict(heuristic),
                            "baseline_action": _action_dict(heuristic),
                            "features": _dense_features_record(
                                candidates,
                                engine.dense_object_tokens(
                                    pointer, perspective_player=player_id
                                ),
                            ),
                        }
                    )
            if source == "automatic":
                engine.apply_ai_action(pointer, action)
            else:
                engine.apply_action(pointer, action)
        if engine.phase(pointer) != 5:
            raise ReplayCompatibilityError(
                f"{game.session_id} replay ended in phase {engine.phase(pointer)}, not game over"
            )
        if engine.final_scores(pointer) != scores:
            raise ReplayCompatibilityError(
                f"{game.session_id} replay scores do not match stored results"
            )
        return records
    finally:
        engine.free_engine(pointer)


def export_online_trajectories(
    database_url: str,
    output_path: Path,
    *,
    engine: CEngine,
    min_player_rating: int,
    limit_games: int,
    input_size: int,
    since: str | None = None,
    include_forced_actions: bool = False,
) -> dict[str, Any]:
    provenance = engine.provenance()
    games = load_online_replay_games(
        database_url,
        engine_build_sha=provenance.git_sha,
        engine_sha256=provenance.c_sha256,
        min_player_rating=min_player_rating,
        limit_games=limit_games,
        since=since,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    record_count = 0
    phase_counts: dict[str, int] = {}
    with output_path.open("w", encoding="utf-8") as handle:
        for game in games:
            for record in trajectory_records_for_game(
                engine,
                game,
                input_size=input_size,
                include_forced_actions=include_forced_actions,
            ):
                handle.write(json.dumps(record, sort_keys=True))
                handle.write("\n")
                record_count += 1
                phase = str(record["phase"])
                phase_counts[phase] = phase_counts.get(phase, 0) + 1
    return {
        "kind": "online_human_trajectory_export",
        "output": str(output_path),
        "games": len(games),
        "records": record_count,
        "min_player_rating": min_player_rating,
        "engine_build_sha": provenance.git_sha,
        "engine_sha256": provenance.c_sha256,
        "engine_contract_version": ENGINE_REPLAY_CONTRACT_VERSION,
        "phase_counts": dict(sorted(phase_counts.items())),
    }
