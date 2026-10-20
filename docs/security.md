# Security runbook

Always keep an existing SSH session open and verify a **new** session works after each change.

## 1. SSH: key-only

```sh
install -m 644 ssh/00-hardening.conf /etc/ssh/sshd_config.d/00-hardening.conf
sshd -t && systemctl reload ssh
sshd -T | grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin) '
```

Verify from your laptop:

```sh
ssh root@${SERVER_IP} true                                      # works
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password root@${SERVER_IP} true
# -> Permission denied (publickey).
```

Rollback: `rm /etc/ssh/sshd_config.d/00-hardening.conf && sshd -t && systemctl reload ssh`
(from an open session or the provider's web console).

## 2. fail2ban

```sh
apt-get install -y fail2ban
sed "s/\${ADMIN_IP}/<your-ip>/" fail2ban/sshd.local > /etc/fail2ban/jail.d/sshd.local
systemctl enable --now fail2ban && systemctl restart fail2ban
fail2ban-client status sshd
```

Unban: `fail2ban-client set sshd unbanip <ip>` · Rollback: `systemctl disable --now fail2ban`.

## 3. Firewall (Docker-aware)

ufw doesn't see Docker-published ports, so `firewall/firewall.sh` uses:

- `SELF-INPUT` (from `INPUT`): drop tcp 2377/7946 and udp 7946/4789 on the external interface.
- `SELF-DOCKER` (first in `DOCKER-USER`): drop NEW connections whose *original* dst port is
  3000 (Dokploy direct) or 8080 (Traefik insecure API).

Only the external interface (`EXT_IF`, default `eth0`) is filtered, so container-to-container
traffic is unaffected. IPv4 and IPv6 both.

```sh
install -m 755 firewall/firewall.sh /usr/local/sbin/self-firewall.sh
install -m 644 firewall/self-firewall.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now self-firewall.service
```

The unit is `PartOf=docker.service` and wanted by it, so rules are reapplied whenever Docker restarts.

Verify (from outside): `for p in 3000 8080 2377 7946; do nc -z -G4 ${SERVER_IP} $p && echo "$p OPEN"; done`
and check counters with `iptables -nvL SELF-DOCKER`.

Rollback:

```sh
systemctl disable --now self-firewall.service
for T in iptables ip6tables; do
  $T -D INPUT -j SELF-INPUT; $T -F SELF-INPUT; $T -X SELF-INPUT
  $T -D DOCKER-USER -j SELF-DOCKER; $T -F SELF-DOCKER; $T -X SELF-DOCKER
done
```

## 4. Traefik

- Load `traefik/security-middlewares.yml` and attach `secure-headers@file,rate-limit@file`
  to public routers. Test before relying on HSTS.
- Don't expose `api.insecure` (port 8080) publicly.
- Behind Traefik, apps see Traefik's overlay IP; configure forwarded headers if apps need real client IPs.

## 5. Secrets hygiene

- Never commit `.env`; keep secrets in Dokploy env vars and reference them as `${VAR}`.
- Prefer scoped/read-only API keys for dashboards and widgets.
- Run `gitleaks git .` before pushing.
