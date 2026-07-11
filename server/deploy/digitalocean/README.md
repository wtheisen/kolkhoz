# Current DigitalOcean VPS shadow deployment

This package installs the greenfield server alongside—not over—the live legacy server
on `192.241.150.25`. It never reads or writes `/opt/kolkhoz`, never changes Caddy, and
never binds the public interface. The separate checkout is `/opt/kolkhoz-greenfield`
and the shadow endpoint is `127.0.0.1:18787`.

The current VPS has only 1 vCPU and roughly 1 GB RAM. This is therefore a correctness
shadow, not a capacity environment. One combined process owns gateways, all 16 command
partitions, and the three schedulers. systemd caps it at 25% CPU and 300 MB memory.
A dedicated Redis instance binds `127.0.0.1:16379`, uses database 15, has a 64 MB
`noeviction` cap, and is separately resource limited. Do not expose either port.

The installer reuses the database and production Supabase authentication settings from
`/etc/kolkhoz-online.env`. It maps `KOLKHOZ_ONLINE_DATABASE_URL` to `DATABASE_URL`
without printing values. The five additive greenfield schemas are applied explicitly
with `ON_ERROR_STOP`; application startup never migrates the database.

## Dry run

Use an immutable commit SHA or signed tag. Dry-run is the default and performs no
package, checkout, service, environment, Redis, or database changes:

```bash
sudo server/deploy/digitalocean/bootstrap.sh \
  --repo https://github.com/OWNER/kolkhoz.git \
  --ref IMMUTABLE_COMMIT_SHA
```

It refuses a non-git or dirty shadow path, a different origin, missing production
environment keys, ports owned by unrelated processes, less than 350 MB currently
available memory, or less than 2 GB free disk under `/opt`. An already installed clean
shadow may be rerun safely at the same or a new immutable ref. If Redis is newly
installed, the installer disables the package's uncapped default port-6379 service;
it never stops a pre-existing Redis installation.

## Apply and verify

Only after reviewing the dry run:

```bash
sudo server/deploy/digitalocean/bootstrap.sh \
  --repo https://github.com/OWNER/kolkhoz.git \
  --ref IMMUTABLE_COMMIT_SHA --apply
curl --fail --silent http://127.0.0.1:18787/ready
curl --fail --silent http://127.0.0.1:18787/metrics/prometheus | head
systemctl status kolkhoz-greenfield kolkhoz-greenfield-redis
```

The service is intentionally not routed through Caddy. Use SSH port forwarding for
inspection. Run at most the 25-session smoke tier documented in `../staging/README.md`;
the VPS preflight rejects 1K/5K/10K capacity tiers.

## Stop or uninstall

Stopping preserves everything:

```bash
sudo systemctl stop kolkhoz-greenfield kolkhoz-greenfield-redis
```

`uninstall.sh` is also dry-run by default. `uninstall.sh --apply` removes only the two
greenfield unit files and preserves the checkout, secret environment, Redis data, and
additive database schemas for recovery. It never touches the live legacy service.
