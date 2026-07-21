from __future__ import annotations

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1] / "deploy" / "digitalocean"


def test_server_package_invariants() -> None:
    result = subprocess.run(
        ["python3", str(ROOT / "validate.py")],
        check=True,
        capture_output=True,
        text=True,
    )
    assert "invariants valid" in result.stdout


def test_uninstall_defaults_to_non_mutating_dry_run() -> None:
    result = subprocess.run(
        ["sh", str(ROOT / "uninstall.sh")],
        check=True,
        capture_output=True,
        text=True,
    )
    assert "DRY RUN" in result.stdout


def test_bootstrap_requires_explicit_apply_for_mutations() -> None:
    source = (ROOT / "bootstrap.sh").read_text()
    dry_run = source.index("if ! $apply; then")
    first_mutation = source.index("apt-get update")
    assert dry_run < first_mutation
    assert "ROOT=/opt/kolkhoz-server" in source
    assert "SERVER_ENV=/etc/kolkhoz-server.env" in source
    assert "LEGACY_ROOT=/opt/kolkhoz-greenfield" in source
    assert "rollback_legacy" in source
    assert "MemAvailable:" in source
    assert '. "$env_file"' not in source
    assert source.index('psql "$database_url"') < source.index("unset database_url")
    assert source.index("identity_schema.sql") < source.index(
        "retire_legacy_supabase.sql"
    )
    assert "redis_was_installed" in source
    assert "for _ in $(seq 1 30)" in source
    assert 'git -c safe.directory="$ROOT" -C "$ROOT"' in source
    assert source.index('cd "$ROOT"') < source.index(
        "from research.kolkhoz_research.c_engine"
    )


def test_supabase_retirement_is_production_only_and_idempotent() -> None:
    retirement = (ROOT / "retire_legacy_supabase.sql").read_text()
    staging = (ROOT.parent / "staging" / "compose.yaml").read_text()
    assert "drop schema if exists auth cascade" in retirement
    assert "drop table if exists public.game_sessions" in retirement
    assert "retire_legacy_supabase.sql" not in staging
