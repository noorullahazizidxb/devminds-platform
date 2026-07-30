# Edge gateway (external Nginx)

Separate Docker Compose stack that binds public **80/443** and routes:

| Host | Upstream (default) |
|------|--------------------|
| `ticket.newlinkaf.com` | `host.docker.internal:9080` / `:9443` |
| `*.devminds.net`, `marketplace.devminds.com` | `host.docker.internal:8080` / `:8443` |

```bash
cp -n .env.example .env
docker compose up -d
```

Full runbook: [docs/GATEWAY.md](../docs/GATEWAY.md).
