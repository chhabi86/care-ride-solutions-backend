# Deployment Overview

Repository root = backend module. Frontend is now sourced from external repo (https://github.com/chhabi86/care-ride), built during deploy, and served as static files by host nginx (no frontend container).

## Components
| Service | Port (host) | Purpose |
|---------|-------------|---------|
| db (Postgres 15) | internal only | Persistence |
| backend (Spring Boot) | 8080 | REST API under /api |
| nginx (host service) | 80/443 | Serves Angular static SPA (root) + proxies /api -> backend |

## deploy.sh Steps
1. Require `DOMAIN` (for nginx + optional certbot TLS).  
2. Update/Install packages + Docker.  
3. Create `backend.env` if absent (copy from example).  
4. `docker compose build` backend image.  
5. Bring up db + backend (pgAdmin optional via `PROFILE_PGADMIN=1`).  
6. Clone/update external Angular repo, install deps, run production build, sync dist to `/var/www/care-ride-frontend`.  
7. Install / refresh nginx site config (`nginx/care-ride.conf`) or generate minimal default.  
8. (Attempt) issue/renew TLS cert via certbot.  

## Environment Files
`backend.env.example` -> copy to `backend.env` and edit with production secrets (DB creds, mail, JWT secret). Never commit real secrets.  
`.env` holds `COMPOSE_PROJECT_NAME` only.

## Frontend (Static External Repo)
External Angular repo cloned to `/opt/care-ride-frontend-src` then built with `npx ng build --configuration production`.
Build output synced to `/var/www/care-ride-frontend` which nginx serves with SPA fallback `try_files $uri $uri/ /index.html;`.
Override repo URL:
```bash
FRONTEND_REPO_URL=https://github.com/your/fork.git DOMAIN=example.com ./deploy.sh
```

## Nginx
`nginx/care-ride.conf` (preferred) or generated default example:
```
upstream backend_api { server 127.0.0.1:8080; }
server {
	listen 80;
	server_name example.com www.example.com;
	root /var/www/care-ride-frontend;
	index index.html;
	location /api/ { proxy_pass http://backend_api/; }
	location / { try_files $uri $uri/ /index.html; }
}
```

## Optional pgAdmin
Enable by exporting `PROFILE_PGADMIN=1` before running `deploy.sh` (will attach override file if port free).

## First-Time Manual Run (local dev)
```bash
cd backend
cp backend.env.example backend.env
docker compose up --build
# Visit: http://localhost (frontend) and http://localhost/api/services (proxied API)
```

## CI/CD
GitHub Actions workflow `.github/workflows/remote-deploy.yml` handles remote update via SSH + `deploy.sh`.

## Troubleshooting
```bash
docker compose ps
docker compose logs backend --tail=100
sudo nginx -t
ls -1 /var/www/care-ride-frontend | head
```

Common issues:
- 502 from nginx: one of upstream containers not yet ready or crashed.
- Connection refused on /api: backend container exited (check DB credentials in `backend.env`).

## Future Improvements
- Cache node_modules between deploys for speed.
- Add health checks & monitoring.
- Harden nginx security headers & rate limiting.

