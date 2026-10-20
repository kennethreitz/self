# Glance on Dokploy

[Glance](https://github.com/glanceapp/glance) as a Dokploy compose stack behind Traefik.

## Compose sketch

```yaml
services:
  glance:
    image: glanceapp/glance:<pinned-version>
    restart: unless-stopped
    mem_limit: 128m
    environment:
      GLANCE_SECRET_KEY: ${GLANCE_SECRET_KEY}
      GLANCE_USER: ${GLANCE_USER}
      GLANCE_PASSWORD: ${GLANCE_PASSWORD}
      DOKPLOY_API_KEY: ${DOKPLOY_API_KEY}
      WEATHER_LOCATION: ${WEATHER_LOCATION}
    volumes:
      - /var/lib/glance:/app/config          # glance.yml (chmod 600)
      - /proc:/host/proc:ro                  # server-stats
      - /:/host/root:ro                      # disk usage (narrow if possible)
    # docker-containers widget: point DOCKER_HOST at a socket proxy instead of mounting the socket
```

Give it a domain in Dokploy (container port 8080) and attach the Traefik security middlewares.

## Config

Start from [`glance/glance.example.yml`](../glance/glance.example.yml). Edit, then
`docker restart <glance container>` and check `docker logs` for `Starting server on :8080`.

- `auth.secret-key` must be exactly 64 bytes base64, or Glance won't start.
- `monitor` sites: `url` is the link, `check-url` is the probe.

## Hardening checklist

1. Secrets via env vars, never literal in `glance.yml`; `chmod 600` the config.
2. Scoped/read-only Dokploy API key for the custom-api widget.
3. Docker socket via [docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy) (`CONTAINERS=1`)
   — a read-only socket mount is still root-equivalent.
4. Pin the image tag, set a memory limit.
5. Rate-limit `/login` at Traefik; expect periodic credential probes.
