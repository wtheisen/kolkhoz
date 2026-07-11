"""Production process entry point for the PostgreSQL-backed server runtime."""

from __future__ import annotations

import argparse
import os

from .gateway import Gateway
from .runtime import GameRuntime
from .store import PostgresEventStore


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

    store = PostgresEventStore(database_url, pool_size=args.db_pool_size)
    runtime = GameRuntime(store, shard_count=args.shards)
    server = Gateway((args.host, args.port), runtime)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        runtime.close()


if __name__ == "__main__":
    main()
