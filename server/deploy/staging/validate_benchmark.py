#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parent
    compose = (root / "compose.benchmark.yaml").read_text()
    owners: dict[int, str] = {}
    for worker, raw in re.findall(
        r"KOLKHOZ_WORKER_ID: (worker-[a-d]).*?KOLKHOZ_COMMAND_PARTITIONS: \"([0-9,]+)\"",
        compose,
    ):
        for value in map(int, raw.split(",")):
            if value in owners:
                raise SystemExit(
                    f"partition {value} owned by both {owners[value]} and {worker}"
                )
            owners[value] = worker
    if set(owners) != set(range(64)):
        raise SystemExit(
            f"partition coverage differs: {sorted(set(range(64)) - set(owners))}"
        )
    if "127.0.0.1:${BENCHMARK_PORT:-19080}:8080" not in compose:
        raise SystemExit("benchmark load balancer must bind only to loopback")
    print(
        "benchmark configuration valid: 64 disjoint partitions, loopback-only endpoint"
    )


if __name__ == "__main__":
    main()
