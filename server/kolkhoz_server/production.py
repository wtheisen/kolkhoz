"""Production process entry point for the PostgreSQL-backed server runtime."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

from research.kolkhoz_research.model import PolicyArtifact

from .ai import AutomaticAdvancer, ModelCache
from .api import OnlineApplication
from .auth import SupabaseAuthVerifier
from .gateway import Gateway
from .lobby import PostgresLobbyRepository
from .runtime import GameRuntime
from .social import PostgresSocialRepository, SocialService
from .store import ConnectionPool, PostgresEventStore


def main() -> None:
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
    args = parser.parse_args()
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        parser.error("DATABASE_URL is required")

    try:
        import psycopg
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
    )
    store = PostgresEventStore(pool=pool)
    lobby = PostgresLobbyRepository(pool)
    social = PostgresSocialRepository(pool=pool)
    repo_root = Path(__file__).resolve().parents[2]
    policy_paths = {
        "mediumAI": Path(
            os.environ.get(
                "KOLKHOZ_MEDIUM_POLICY_PATH",
                repo_root / "clients/flutter_app/assets/policies/medium_policy.json",
            )
        ),
        "neuralAI": Path(
            os.environ.get(
                "KOLKHOZ_NEURAL_POLICY_PATH",
                repo_root / "clients/flutter_app/assets/policies/hard_policy.json",
            )
        ),
    }
    models = ModelCache(policy_paths, lambda path: PolicyArtifact.load(path).c_buffer())
    runtime = GameRuntime(
        store,
        shard_count=args.shards,
        automatic_advancer=AutomaticAdvancer(models),
    )
    application = OnlineApplication(
        runtime,
        lobby,  # type: ignore[arg-type]
        auth=SupabaseAuthVerifier.from_environment(),
        social=SocialService(social),
    )
    server = Gateway((args.host, args.port), runtime, application=application)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        runtime.close()
        pool.close()


if __name__ == "__main__":
    main()
