#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parent
bootstrap = (root / "bootstrap.sh").read_text()
server = (root / "kolkhoz-greenfield.service").read_text()
redis = (root / "redis-greenfield.conf").read_text()

assert "ROOT=/opt/kolkhoz-greenfield" in bootstrap
assert "LIVE_ROOT=/opt/kolkhoz\n" in bootstrap
assert "KOLKHOZ_ONLINE_DATABASE_URL" in bootstrap
assert bootstrap.count("_schema.sql") == 5
assert "--apply" in bootstrap and "DRY RUN:" in bootstrap
assert "MemAvailable:" in bootstrap and "358400" in bootstrap
assert "2097152" in bootstrap
assert "redis_was_installed" in bootstrap
assert "disable --now redis-server.service" in bootstrap
assert '. "$env_file"' not in bootstrap
assert 'psql "$database_url"' in bootstrap
assert bootstrap.index('psql "$database_url"') < bootstrap.index("unset database_url")
assert "127.0.0.1 --port 18787" in server
assert "CPUQuota=25%" in server
assert "MemoryMax=300M" in server
assert "TasksMax=128" in server and "LimitNOFILE=8192" in server
assert "port 16379" in redis and "bind 127.0.0.1" in redis
assert "maxmemory 64mb" in redis and "maxmemory-policy noeviction" in redis
print("DigitalOcean shadow package invariants valid")
