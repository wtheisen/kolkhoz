#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path
from urllib.parse import urlparse


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--env", type=Path, default=Path(__file__).with_name("benchmark.env")
    )
    parser.add_argument(
        "--tier", choices=("smoke", "1000", "5000", "10000"), default="smoke"
    )
    args = parser.parse_args()
    values = {}
    for line in args.env.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    errors = []
    database = urlparse(values.get("DATABASE_URL", ""))
    redis = urlparse(values.get("REDIS_URL", ""))
    if "benchmark" not in database.path.lower():
        errors.append("DATABASE_URL database name must contain 'benchmark'")
    if redis.scheme not in {"redis", "rediss"} or redis.path in {"", "/", "/0"}:
        errors.append("REDIS_URL must use a dedicated non-zero database")
    if values.get("BENCHMARK_PORT", "19080") in {"80", "443", "8787", "18080"}:
        errors.append("BENCHMARK_PORT overlaps a conventional/live port")
    cpu = os.cpu_count() or 0
    memory = os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES")
    disk = shutil.disk_usage(args.env.parent).free
    soft_fd = __import__("resource").getrlimit(__import__("resource").RLIMIT_NOFILE)[0]
    requirements = {
        "smoke": (1, 768 * 1024**2, 2 * 1024**3, 4096),
        "1000": (8, 16 * 1024**3, 20 * 1024**3, 65536),
        "5000": (16, 32 * 1024**3, 40 * 1024**3, 131072),
        "10000": (24, 48 * 1024**3, 80 * 1024**3, 262144),
    }
    need_cpu, need_memory, need_disk, need_fd = requirements[args.tier]
    if cpu < need_cpu:
        errors.append(f"tier {args.tier} needs >={need_cpu} CPU, found {cpu}")
    if memory < need_memory:
        errors.append(f"tier {args.tier} needs >={need_memory / 1024**3:g} GiB RAM")
    if disk < need_disk:
        errors.append(f"tier {args.tier} needs >={need_disk / 1024**3:g} GiB free disk")
    if soft_fd < need_fd:
        errors.append(f"tier {args.tier} needs nofile >={need_fd}, found {soft_fd}")
    if args.tier != "smoke" and shutil.which("docker") is None:
        errors.append("capacity tiers require docker")
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    if errors:
        return 1
    print(
        f"{args.tier} preflight passed: cpu={cpu} memoryGiB={memory / 1024**3:.1f} diskGiB={disk / 1024**3:.1f} nofile={soft_fd}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
