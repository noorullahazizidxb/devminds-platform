# Edge gateway (external Nginx)

Separate Docker Compose stack that binds public **80/443** and routes:

| Host | Upstream (default) |
|------|--------------------|
| `ticket.newlinkaf.com` | `host.docker.internal:9080` / `:9443` |
| `*.devminds.net` | `devminds-internal-nginx:80` / `:443` |

```bash
cp -n .env.example .env
docker compose up -d
```

Full runbook: [docs/GATEWAY.md](../docs/GATEWAY.md).
