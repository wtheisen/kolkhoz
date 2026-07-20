"""Production process entry point for the PostgreSQL-backed server runtime."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from .ai import AutomaticAdvancer
from .automatic_scheduler import AutomaticTurnScheduler
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
from .preflight import verify_production_assets
from .commerce import (
    ApplePurchaseVerifier,
    CommerceService,
    PostgresEntitlementRepository,
)
from .runtime import GameRuntime, GatewayRuntimeContext
from .results import PostgresResultsRepository
from .scheduler import DeadlineScheduler
from .lifecycle import LifecycleReconciler
from .social import LobbyPresenceReader, PostgresSocialRepository, SocialService
from .store import ConnectionPool, PostgresEventStore
from .notifications import (
    FirebasePushTransport,
    NotificationService,
    NotificationWorker,
    NotificationWorkerService,
    PostgresNotificationRepository,
)
from .operations import PostgresOperationsRepository
from .tournament import PostgresTournamentRepository, TournamentScheduler
from .accounts import (
    AccountDeletionService,
    PostgresAccountCleaner,
    SupabaseAccountDeleter,
)
from .identity import (
    CompositeAuthVerifier,
    IdentitySessionVerifier,
    identity_service_from_environment,
)


def _production_auth_verifier() -> CachingAuthVerifier | StagingAuthVerifier | None:
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
        return None
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
    legacy_auth_verifier = _production_auth_verifier()
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
            keepalives=1,
            keepalives_idle=10,
            keepalives_interval=5,
            keepalives_count=3,
            tcp_user_timeout=15_000,
            options="-c statement_timeout=5000 -c lock_timeout=3000",
        ),
        size=args.db_pool_size,
        metrics=metrics,
    )
    identity = identity_service_from_environment(pool)
    auth_verifier = CompositeAuthVerifier(
        IdentitySessionVerifier(identity.repository),
        *(() if legacy_auth_verifier is None else (legacy_auth_verifier,)),
    )
    store = PostgresEventStore(pool=pool)
    lobby = PostgresLobbyRepository(pool)
    social = PostgresSocialRepository(pool=pool)
    results = PostgresResultsRepository(pool=pool, json_value=Jsonb)
    tournaments = PostgresTournamentRepository(
        pool,
        weekday=int(os.environ.get("KOLKHOZ_TOURNAMENT_WEEKDAY", "5")),
        hour=int(os.environ.get("KOLKHOZ_TOURNAMENT_HOUR", "19")),
        timezone_name=os.environ.get(
            "KOLKHOZ_TOURNAMENT_TIMEZONE", "America/Indiana/Indianapolis"
        ),
    )
    notification_repository = PostgresNotificationRepository(pool)
    notifications = NotificationService(notification_repository)
    apple_verifier = ApplePurchaseVerifier.from_environment()
    commerce = CommerceService(
        PostgresEntitlementRepository(pool),
        {"apple": apple_verifier} if apple_verifier is not None else {},
    )
    account_deleter = SupabaseAccountDeleter.from_environment()
    accounts = (
        AccountDeletionService(account_deleter, PostgresAccountCleaner(pool))
        if account_deleter is not None
        else None
    )
    notification_worker = None
    firebase_project_id = os.environ.get("KOLKHOZ_FIREBASE_PROJECT_ID")
    if firebase_project_id and _enabled("KOLKHOZ_RUN_NOTIFICATION_WORKER"):
        notification_worker = NotificationWorkerService(
            NotificationWorker(
                notification_repository,
                FirebasePushTransport(project_id=firebase_project_id),
                metrics=metrics,
            ),
            interval_seconds=float(
                os.environ.get("KOLKHOZ_NOTIFICATION_INTERVAL_SECONDS", "1")
            ),
        )
    redis_url = os.environ.get("REDIS_URL")
    if not redis_url:
        parser.error("REDIS_URL is required")
    realtime_bus = RedisRealtimeBus.from_url(redis_url, metrics=metrics)
    run_command_worker = _enabled("KOLKHOZ_RUN_COMMAND_WORKER")
    run_automatic_scheduler = _enabled(
        "KOLKHOZ_RUN_AUTOMATIC_SCHEDULER", run_command_worker
    )
    owner_id = os.environ.get("KOLKHOZ_WORKER_ID") or "gateway"
    if run_command_worker:
        repo_root = Path(__file__).resolve().parents[2]
        models = verify_production_assets(repo_root)
        local_runtime: GameRuntime | GatewayRuntimeContext = GameRuntime(
            store,
            shard_count=args.shards,
            event_hub=EventHub(realtime_bus),
            automatic_advancer=AutomaticAdvancer(models),
            lease_repository=PostgresSessionLeaseRepository(pool=pool),
            owner_id=owner_id,
            lease_ttl_seconds=float(os.environ.get("KOLKHOZ_LEASE_TTL_SECONDS", "15")),
            metrics=metrics,
        )
    else:
        local_runtime = GatewayRuntimeContext(store, EventHub(realtime_bus), owner_id)
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
    command_workers: list[CommandWorkerService] = []
    if run_command_worker:
        worker_count = min(
            len(partitions),
            max(1, int(os.environ.get("KOLKHOZ_COMMAND_WORKER_THREADS", "8"))),
        )
        partition_groups = [
            partitions[index::worker_count] for index in range(worker_count)
        ]
        try:
            for index, partition_group in enumerate(partition_groups):
                service = CommandWorkerService(
                    CommandWorker(
                        command_broker,
                        f"{worker_id}:{index}",
                        partition_group,
                        RuntimeCommandHandler(local_runtime, lobby),
                    )
                )
                service.start()
                command_workers.append(service)
        except Exception:
            for service in command_workers:
                service.close()
            local_runtime.close()
            realtime_bus.close()
            pool.close()
            raise
    runtime = RoutedGameRuntime(
        local_runtime,
        CommandClient(command_broker),
        timeout_seconds=float(os.environ.get("KOLKHOZ_COMMAND_TIMEOUT_SECONDS", "10")),
        owns_all_partitions=(
            bool(command_workers) and set(partitions) == set(range(command_partitions))
        ),
    )
    application = OnlineApplication(
        runtime,
        lobby,  # type: ignore[arg-type]
        auth=auth_verifier,
        social=SocialService(
            social,
            presence=LobbyPresenceReader(
                lobby,
                ttl_seconds=float(os.environ.get("KOLKHOZ_PRESENCE_TTL_SECONDS", "60")),
            ),
        ),
        results=results,
        tournaments=tournaments,
        notifications=notifications,
        notification_repository=notification_repository,
        operations=PostgresOperationsRepository(pool),
        commerce=commerce,
        accounts=accounts,
        identity=identity,
        require_full_game=_enabled("KOLKHOZ_ENFORCE_FULL_GAME", False),
        admin_user_ids=frozenset(
            value.strip()
            for value in os.environ.get("KOLKHOZ_ADMIN_USER_IDS", "").split(",")
            if value.strip()
        ),
        deployment_version=os.environ.get("KOLKHOZ_DEPLOYMENT_VERSION", "unknown"),
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
        on_state=application.finalize_runtime_state,
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
        metrics=metrics,
        health_timeout_seconds=float(
            os.environ.get("KOLKHOZ_POPULATION_HEALTH_TIMEOUT", "300")
        ),
    )
    if _enabled("KOLKHOZ_RUN_POPULATION_SCHEDULER"):
        population.start(
            interval_seconds=float(os.environ.get("KOLKHOZ_POPULATION_INTERVAL", "1"))
        )
    tournament_scheduler = TournamentScheduler(
        tournaments, application.provision_tournament_table
    )
    if _enabled("KOLKHOZ_RUN_TOURNAMENT_SCHEDULER"):
        tournament_scheduler.start(
            interval_seconds=float(os.environ.get("KOLKHOZ_TOURNAMENT_INTERVAL", "1"))
        )
    lifecycle = LifecycleReconciler(
        lobby,
        runtime,
        owner_id=os.environ.get("KOLKHOZ_LIFECYCLE_ID"),
        batch_size=int(os.environ.get("KOLKHOZ_LIFECYCLE_BATCH_SIZE", "64")),
        metrics=metrics,
    )
    if _enabled("KOLKHOZ_RUN_LIFECYCLE_RECONCILER"):
        lifecycle.start(
            interval_seconds=float(os.environ.get("KOLKHOZ_LIFECYCLE_INTERVAL", "1"))
        )
    automatic = AutomaticTurnScheduler(
        lobby,
        application.advance_automatic_session,
        batch_size=int(os.environ.get("KOLKHOZ_AUTOMATIC_BATCH_SIZE", "64")),
        metrics=metrics,
    )
    if run_automatic_scheduler:
        automatic.start(
            interval_seconds=float(os.environ.get("KOLKHOZ_AUTOMATIC_INTERVAL", "1"))
        )

    def shutdown() -> None:
        if notification_worker is not None:
            notification_worker.close()
        automatic.close()
        lifecycle.close()
        population.close()
        tournament_scheduler.close()
        scheduler.close()
        for command_worker in command_workers:
            command_worker.close()
        local_runtime.close()
        realtime_bus.close()
        pool.close()

    def readiness() -> dict[str, bool]:
        checks = {
            "postgres": False,
            "redisCommands": False,
            "redisRealtime": False,
            "policyModels": not run_command_worker or models.sha256() is not None,
            "population": population.healthy,
            "tournaments": tournament_scheduler.healthy,
            "lifecycle": lifecycle.healthy,
            "automaticProgress": False,
            "automaticScheduler": not run_automatic_scheduler or automatic.healthy,
        }
        try:
            with pool.connection() as connection:
                row = connection.execute("select 1").fetchone()  # type: ignore[attr-defined]
                checks["postgres"] = row is not None and int(row[0]) == 1
                stalled = connection.execute(  # type: ignore[attr-defined]
                    """select 1 from server_sessions
                         where status = 'active' and turn_player_id is null
                           and expires_at > now()
                           and updated_at < now() - interval '30 seconds'
                         limit 1"""
                ).fetchone()
                checks["automaticProgress"] = stalled is None
        except Exception:
            pass
        try:
            command_broker.readiness_check()
            checks["redisCommands"] = (
                command_broker.partition_ownership_ready()
                and all(worker.ownership_healthy for worker in command_workers)
            )
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
        max_request_body_bytes=int(
            os.environ.get("KOLKHOZ_HTTP_MAX_BODY_BYTES", "1048576")
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
