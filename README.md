# Blue/Green Node.js Deployment with Nginx Auto-Failover

This setup deploys two identical Node.js services (Blue and Green) behind Nginx for blue/green deployments with automatic failover on failures (5xx, errors, timeouts). All traffic routes to the active (primary) pool by default, with immediate per-request retries to the backup on failure—ensuring zero failed client requests.

## Prerequisites

- Docker and Docker Compose installed.
- Access to the pre-built images (BLUE_IMAGE and GREEN_IMAGE).

## Quick Start

1. Copy `.env.example` to `.env` and update values (e.g., image URLs, RELEASE_IDs).
2. Run `docker compose up -d`.
3. Verify baseline: `curl -v http://localhost:8080/version` (should return 200 with `X-App-Pool: blue` and `X-Release-Id: <your-blue-id>`).

### Test Failover

- Induce chaos on Blue: `curl -X POST http://localhost:8081/chaos/start?mode=error`
- Check: `curl -v http://localhost:8080/version` (should now show `X-App-Pool: green`).
- All subsequent requests within ~10s should be 200 from Green (95%+ success).

### Recover

- `curl -X POST http://localhost:8081/chaos/stop`.

### Manual Toggle

- Update `ACTIVE_POOL=green` in `.env`, then `docker compose restart nginx` (uses `nginx -s reload` internally via templating).

## Key Behaviors

- **Auto-Failover**: Nginx uses primary/backup upstreams with `proxy_next_upstream` for immediate retries on errors/timeouts/5xx within the same request.
- **Headers**: Upstream headers (`X-App-Pool`, `X-Release-Id`) are forwarded unchanged.
- **Direct Access**: Grader can hit Blue/Green chaos endpoints directly on ports 8081/8082.
- **Timeouts**: Configured for <10s requests; failures detected in ~1-5s.
- **No Downtime Toggle**: Changing `ACTIVE_POOL` and restarting Nginx regenerates config and reloads seamlessly.

## Troubleshooting

- **Logs**: `docker compose logs nginx` or `app_blue`.
- **Health**: Apps use `/healthz` (not directly used in failover; relies on HTTP errors).
- **Custom Port**: Set `PORT` in `.env`.
