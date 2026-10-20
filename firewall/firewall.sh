#!/bin/sh
# Block public access to admin/Swarm ports on the external interface. Idempotent.
# Docker-published ports bypass ufw/INPUT, so those are filtered in DOCKER-USER.
set -e
IF="${EXT_IF:-eth0}"
for T in iptables ip6tables; do
  # Host-bound Swarm ports (single node: nothing external needs them)
  $T -N SELF-INPUT 2>/dev/null || true; $T -F SELF-INPUT
  $T -A SELF-INPUT -i "$IF" -p tcp -m multiport --dports 2377,7946 -j DROP
  $T -A SELF-INPUT -i "$IF" -p udp -m multiport --dports 7946,4789 -j DROP
  $T -C INPUT -j SELF-INPUT 2>/dev/null || $T -I INPUT 1 -j SELF-INPUT
  # Docker-published: Dokploy direct (3000) and Traefik insecure API (8080)
  $T -N DOCKER-USER 2>/dev/null || true
  $T -N SELF-DOCKER 2>/dev/null || true; $T -F SELF-DOCKER
  $T -A SELF-DOCKER -i "$IF" -p tcp -m conntrack --ctstate NEW --ctorigdstport 3000 -j DROP
  $T -A SELF-DOCKER -i "$IF" -p tcp -m conntrack --ctstate NEW --ctorigdstport 8080 -j DROP
  $T -C DOCKER-USER -j SELF-DOCKER 2>/dev/null || $T -I DOCKER-USER 1 -j SELF-DOCKER
done
