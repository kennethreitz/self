# Server setup

Reference build for a single-node Dokploy host. Replace `${SERVER_IP}`, `example.com`.

## 1. VM

- Hetzner Cloud (any x86 CCX/CPX works; 4 vCPU / 16 GB is comfortable for a dozen apps).
- Ubuntu LTS, SSH key added at creation. Add a **Hetzner Cloud Firewall** allowing only
  22, 80, 443 (tcp + udp for HTTP/3) — the host rules in `firewall/` are a second layer.
- Add swap (e.g. 4 GB `/swapfile`) so builds don't OOM.

## 2. Dokploy

```sh
curl -sSL https://dokploy.com/install.sh | sh
```

- Dokploy, its Postgres and Redis run as Swarm services; Traefik is a plain container.
- Point `dokploy.example.com` at `${SERVER_IP}`, set it as the panel domain (Let's Encrypt),
  then stop using `http://${SERVER_IP}:3000` (the firewall blocks it; use an SSH tunnel if needed).
- Create an API key (Settings → API/CLI) and put it in `.env` for `scripts/api.sh`.

## 3. Apps

- Each app/compose stack gets a domain in Dokploy; Traefik routes `Host(...)` and gets certs
  via the `letsencrypt` resolver. Custom routers/middlewares go in
  `/etc/dokploy/traefik/dynamic/*.yml` (see `traefik/`) and survive redeploys.
- Pin image tags for third-party apps; add memory limits for anything hungry.

## 4. Backups

- Enable Dokploy scheduled backups (web server + each database) to an S3 destination.
- **Use an off-site destination** — a bucket on the same box doesn't survive losing the box.
- If backups land on a local MinIO, prune with `scripts/prune-backups.sh` from cron:
  `0 4 * * * root KEEP=7 /usr/local/bin/prune-backups.sh >> /var/log/prune-backups.log 2>&1`
- Test a restore periodically.

## 5. Hardening

Follow [security.md](security.md): key-only SSH, fail2ban, firewall unit.

## 6. Ops gotchas

- Keep the root disk under ~80%: a full disk takes Swarm down. `docker system df`,
  prune build cache and old images regularly.
- Dokploy/Docker build cache can serve stale templates — rebuild without cache if a deploy
  doesn't reflect changes.
- Updating `containerd`/`docker` restarts every container; do it in a quiet window.
