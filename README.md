# self

Kenneth Reitz's self-hosted setup: one Hetzner VM running [Dokploy](https://dokploy.com)
(Docker Swarm, single node) with Traefik in front, hosting personal sites and tools.

This is the **generic, reusable** part of that setup — scripts, configs and runbooks —
with all secrets, hostnames and personal details replaced by placeholders
(`${SERVER_IP}`, `example.com`, `${DOKPLOY_API_KEY}`, …). Nothing here is tied to a
specific deployment; adapt freely.

## Layout

| Path | What |
|---|---|
| `scripts/api.sh` | Tiny Dokploy API client (`project.all`, `application.deploy`, …); key from env/`.env` |
| `scripts/prune-backups.sh` | Keep-newest-N pruning for Dokploy's MinIO backup objects |
| `firewall/` | iptables script + systemd unit that hides admin/Swarm ports from the internet (Docker-aware) |
| `ssh/00-hardening.conf` | Key-only SSH drop-in |
| `fail2ban/sshd.local` | sshd jail (systemd backend) |
| `traefik/` | File-provider middlewares: security headers, rate limit, www→apex redirect |
| `glance/glance.example.yml` | [Glance](https://github.com/glanceapp/glance) dashboard with a Dokploy status widget |
| `docs/server-setup.md` | Building the server from scratch |
| `docs/security.md` | Hardening runbook with verify + rollback steps |
| `docs/glance.md` | Running Glance safely on Dokploy |

## Quick start

```sh
cp .env.example .env        # fill in DOKPLOY_URL + DOKPLOY_API_KEY
scripts/api.sh project.all | jq '.[].name'
```

## License

MIT — see [LICENSE](LICENSE).
