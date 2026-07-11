"""Production process entry point for the PostgreSQL-backed server runtime."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from research.kolkhoz_research.model import PolicyArtifact

from .ai import AutomaticAdvancer, ModelCache
from .api import OnlineApplication
from .asgi import ASGIApplication
from .auth import CachingAuthVerifier, StagingAuthVerifier, SupabaseAuthVerifier
from .commands import (
    CommandClient,
    CommandWorker,
    CommandWorkerService,
    RedisStreamsCommandBroker,
    RoutedGameRuntime,
    RuntimeCommandHandler,
)
from .distributed import PostgresSessionLeaseRepository, RedisRealtimeBus
from .events import EventHub
from .lobby import PostgresLobbyRepository
from .metrics import ServerMetrics
from .population import PopulationScheduler, PostgresPopulationRepository
from .runtime import GameRuntime
from .results import PostgresResultsRepository
from .scheduler import DeadlineScheduler
from .lifecycle import LifecycleReconciler
from .social import LobbyPresenceReader, PostgresSocialRepository, SocialService
from .store import ConnectionPool, PostgresEventStore


def _production_auth_verifier() -> CachingAuthVerifier | StagingAuthVerifier:
    static_tokens = os.environ.get("KOLKHOZ_STAGING_STATIC_AUTH_TOKENS")
    if static_tokens is not None:
        if os.environ.get("KOLKHOZ_ENVIRONMENT") != "staging":
            raise RuntimeError(
                "staging authentication requires KOLKHOZ_ENVIRONMENT=staging"
            )
        decoded = json.loads(static_tokens)
        if (
            not isinstance(decoded, dict)
            or not decoded
            or not all(
                isinstance(token, str)
                and token
                and isinstance(user_id, str)
                and user_id
                for token, user_id in decoded.items()
            )
        ):
            raise RuntimeError(
                "KOLKHOZ_STAGING_STATIC_AUTH_TOKENS must be a non-empty JSON object"
            )
        return StagingAuthVerifier(decoded)
    verifier = SupabaseAuthVerifier.from_environment()
    if verifier is None:
        raise RuntimeError(
            "KOLKHOZ_SUPABASE_URL and KOLKHOZ_SUPABASE_PUBLISHABLE_KEY "
            "are required in production"
        )
    return CachingAuthVerifier(
        verifier,
        ttl_seconds=float(os.environ.get("KOLKHOZ_AUTH_CACHE_TTL_SECONDS", "30")),
        capacity=int(os.environ.get("KOLKHOZ_AUTH_CACHE_CAPACITY", "100000")),
    )


def _enabled(name: str, default: bool = True) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def create_asgi_application() -> ASGIApplication:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default=os.environ.get("KOLKHOZ_HOST", "127.0.0.1"))
    parser.add_argument(
        "--port", type=int, default=int(os.environ.get("KOLKHOZ_PORT", "8787"))
    )
    parser.add_argument(
        "--shards", type=int, default=int(os.environ.get("KOLKHOZ_SHARDS", "16"))
    )
    parser.add_argument(
        "--db-pool-size",
        type=int,
        default=int(os.environ.get("KOLKHOZ_DB_POOL_SIZE", "16")),
    )
    args, _ = parser.parse_known_args()
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        parser.error("DATABASE_URL is required")
    auth_verifier = _production_auth_verifier()
    metrics = ServerMetrics()

    try:
        import psycopg
        from psycopg.types.json import Jsonb
    except ImportError as error:
        raise RuntimeError("production server requires psycopg[binary]>=3.2") from error

    pool = ConnectionPool(
        lambda: psycopg.connect(
            database_url,
            autocommit=False,
            prepare_threshold=None,
            connect_timeout=5,
            options="-c statement_timeout=5000 -c lock_timeout=3000",
        ),
        size=args.db_pool_size,
        metrics=metrics,
    )
    store = PostgresEventStore(pool=pool)
    lobby = PostgresLobbyRepository(pool)
    social = PostgresSocialRepository(pool=pool)
    results = PostgresResultsRepository(pool=pool, json_value=Jsonb)
    repo_root = Path(__file__).resolve().parents[2]
    policy_paths = {
        "mediumAI": Path(
            os.environ.get(
                "KOLKHOZ_MEDIUM_POLICY_PATH",
                repo_root / "policies/medium_policy.json",
            )
        ),
        "neuralAI": Path(
            os.environ.get(
                "KOLKHOZ_NEURAL_POLICY_PATH",
                repo_root / "policies/hard_policy.json",
            )
        ),
    }
    models = ModelCache(policy_paths, lambda path: PolicyArtifact.load(path).c_buffer())
    lease_repository = PostgresSessionLeaseRepository(pool=pool)
    redis_url = os.environ.get("REDIS_URL")
    if not redis_url:
        parser.error("REDIS_URL is required")
    realtime_bus = RedisRealtimeBus.from_url(redis_url, metrics=metrics)
    local_runtime = GameRuntime(
        store,
        shard_count=args.shards,
        event_hub=EventHub(realtime_bus),
        automatic_advancer=AutomaticAdvancer(models),
        lease_repository=lease_repository,
        owner_id=os.environ.get("KOLKHOZ_WORKER_ID"),
        lease_ttl_seconds=float(os.environ.get("KOLKHOZ_LEASE_TTL_SECONDS", "15")),
        metrics=metrics,
    )
    command_partitions = int(os.environ.get("KOLKHOZ_COMMAND_PARTITION_COUNT", "256"))
    command_broker = RedisStreamsCommandBroker.from_url(
        redis_url,
        partition_count=command_partitions,
        max_stream_length=int(
            os.environ.get("KOLKHOZ_COMMAND_PARTITION_CAPACITY", "100000")
        ),
        max_attempts=int(os.environ.get("KOLKHOZ_COMMAND_MAX_ATTEMPTS", "5")),
        visibility_timeout_seconds=float(
            os.environ.get("KOLKHOZ_COMMAND_VISIBILITY_SECONDS", "30")
        ),
        metrics=metrics,
    )
    assigned = os.environ.get("KOLKHOZ_COMMAND_PARTITIONS")
    partitions = (
        tuple(int(value) for value in assigned.split(",") if value.strip())
        if assigned
        else tuple(range(command_partitions))
    )
    worker_id = local_runtime.owner_id
    command_worker = None
    if _enabled("KOLKHOZ_RUN_COMMAND_WORKER"):
        command_worker = CommandWorkerService(
            CommandWorker(
                command_broker,
                worker_id,
                partitions,
                RuntimeCommandHandler(local_runtime),
            )
        )
        command_worker.start()
    runtime = RoutedGameRuntime(
        local_runtime,
        CommandClient(command_broker),
        timeout_seconds=float(os.environ.get("KOLKHOZ_COMMAND_TIMEOUT_SECONDS", "10")),
    )
    application = OnlineApplication(
        runtime,
        lobby,  # type: ignore[arg-type]
        auth=auth_verifier,
        social=SocialService(
            social,
            presence=LobbyPresenceReader(
                lobby,
                ttl_seconds=float(
                    os.environ.get("KOLKHOZ_PRESENCE_TTL_SECONDS", "60")
                ),
            ),
        ),
        results=results,
        session_ttl_seconds=float(
            os.environ.get("KOLKHOZ_SESSION_TTL_SECONDS", "1800")
        ),
        presence_ttl_seconds=float(
            os.environ.get("KOLKHOZ_PRESENCE_TTL_SECONDS", "60")
        ),
        lobby_countdown_seconds=float(
            os.environ.get("KOLKHOZ_LOBBY_COUNTDOWN_SECONDS", "30")
        ),
    )
    scheduler = DeadlineScheduler(
        lobby,
        runtime,
        owner_id=os.environ.get("KOLKHOZ_SCHEDULER_ID"),
        batch_size=int(os.environ.get("KOLKHOZ_DEADLINE_BATCH_SIZE", "128")),
        metrics=metrics,
    )
    if _enabled("KOLKHOZ_RUN_DEADLINE_SCHEDULER"):
        scheduler.start(
            interval_seconds=float(os.environ.get("KOLKHOZ_DEADLINE_INTERVAL", "1"))
        )
    population = PopulationScheduler(
        PostgresPopulationRepository(pool),
        owner_id=os.environ.get("KOLKHOZ_POPULATION_ID"),
        batch_size=int(os.environ.get("KOLKHOZ_POPULATION_BATCH_SIZE", "256")),
        on_filled=application.population_seat_filled,
    )
    if _enabled("KOLKHOZ_RUN_POPULATION_SCHEDULER"):
        population.start(
            interval_seconds=float(os.environ.get("KOLKHOZ_POPULATION_INTERVAL", "1"))
        )
    lifecycle = LifecycleReconciler(
        lobby,
        runtime,
        owner_id=os.environ.get("KOLKHOZ_LIFECYCLE_ID"),
        batch_size=int(os.environ.get("KOLKHOZ_LIFECYCLE_BATCH_SIZE", "64")),
    )
    if _enabled("KOLKHOZ_RUN_LIFECYCLE_RECONCILER"):
        lifecycle.start(
            interval_seconds=float(os.environ.get("KOLKHOZ_LIFECYCLE_INTERVAL", "1"))
        )

    def shutdown() -> None:
        lifecycle.close()
        population.close()
        scheduler.close()
        if command_worker is not None:
            command_worker.close()
        local_runtime.close()
        realtime_bus.close()
        pool.close()

    def readiness() -> dict[str, bool]:
        checks = {"postgres": False, "redisCommands": False, "redisRealtime": False}
        try:
            with pool.connection() as connection:
                row = connection.execute("select 1").fetchone()  # type: ignore[attr-defined]
                checks["postgres"] = row is not None and int(row[0]) == 1
        except Exception:
            pass
        try:
            command_broker.readiness_check()
            checks["redisCommands"] = True
        except Exception:
            pass
        try:
            realtime_bus.readiness_check()
            checks["redisRealtime"] = True
        except Exception:
            pass
        return checks

    return ASGIApplication(
        application,
        realtime_bus,
        connection_buffer_size=int(
            os.environ.get("KOLKHOZ_REALTIME_BUFFER_SIZE", "64")
        ),
        max_message_bytes=int(
            os.environ.get("KOLKHOZ_REALTIME_MAX_MESSAGE_BYTES", "1048576")
        ),
        shutdown=shutdown,
        metrics=metrics,
        readiness=readiness,
        readiness_timeout_seconds=float(
            os.environ.get("KOLKHOZ_READINESS_TIMEOUT_SECONDS", "1")
        ),
    )


def main() -> None:
    try:
        import uvicorn
    except ImportError as error:
        raise RuntimeError("production server requires uvicorn>=0.30") from error
    uvicorn.run(
        create_asgi_application(),
        host=os.environ.get("KOLKHOZ_HOST", "127.0.0.1"),
        port=int(os.environ.get("KOLKHOZ_PORT", "8787")),
        ws_max_size=int(
            os.environ.get("KOLKHOZ_REALTIME_MAX_MESSAGE_BYTES", "1048576")
        ),
        ws_ping_interval=20,
        ws_ping_timeout=20,
    )


if __name__ == "__main__":
    main()
