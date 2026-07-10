# DigitalOcean Online Server

This deploys the C-engine online session server on a small Ubuntu Droplet.

Recommended Droplet shape for the current server:

- Ubuntu 24.04 LTS
- Basic shared CPU
- Regular or Premium AMD/Intel, 1 vCPU / 1 GB RAM is enough to start
- Public IPv4 enabled
- SSH key authentication

On the Droplet:

```bash
curl -fsSL https://raw.githubusercontent.com/wtheisen/kolkhoz/main/deploy/digitalocean/bootstrap_ubuntu.sh -o /root/bootstrap_ubuntu.sh
bash /root/bootstrap_ubuntu.sh
nano /etc/kolkhoz-online.env
systemctl restart kolkhoz-online.service
systemctl status kolkhoz-online.service
```

Use the same bootstrap command for updates. It fast-forwards the configured Git ref,
installs dependencies, builds the C engine, runs the server contract smoke test, installs
the systemd unit, and restarts only after those steps pass. Do not copy individual source
files into `/opt/kolkhoz`; `/health` reports the deployed Git and engine hashes.

`/etc/kolkhoz-online.env` must contain:

```bash
KOLKHOZ_SUPABASE_URL=https://your-project-ref.supabase.co
KOLKHOZ_SUPABASE_PUBLISHABLE_KEY=sb_publishable_your_key
KOLKHOZ_ONLINE_DATABASE_URL=postgresql://postgres.your-project-ref:YOUR_PASSWORD@aws-0-region.pooler.supabase.com:6543/postgres
```

The systemd service binds the Python server to `127.0.0.1:8787`. Put Caddy in front of
it for public HTTPS:

```caddyfile
online.kolkhoz.williamtheisen.com {
    encode zstd gzip
    reverse_proxy 127.0.0.1:8787
}
```

Create an `A` record for `online.kolkhoz.williamtheisen.com` pointing at the Droplet
public IPv4 address. The production Flutter client uses:

```text
https://online.kolkhoz.williamtheisen.com
```
