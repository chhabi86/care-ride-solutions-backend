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

---

## DigitalOcean Droplet Deployment (Step‑by‑Step)

The following opinionated guide describes deploying BOTH backend (Spring Boot WAR runnable directly) and frontend (Angular static build) onto a single Ubuntu droplet using systemd + nginx + Let's Encrypt. Adjust as needed for scaling.

### 1. Architecture Summary
Component | Purpose | Port
--------- | ------- | ----
Spring Boot (app.war) | REST API `/api` | 8080 (localhost only via nginx)
Angular static build | SPA | served by nginx (`/`)
nginx | Reverse proxy + TLS | 80 / 443
Certbot | ACME client (TLS certs) | n/a

Optional: External Tomcat instead of direct Spring Boot execution. (Direct execution via `java -jar` is simpler.)

### 2. Prerequisites
1. Domain A record points to droplet public IP.
2. GitHub repos accessible (public or deploy key / PAT configured).
3. Production secrets ready (DB, mail, JWT secret, etc.).

### 3. Create Deploy User
```bash
adduser deploy
usermod -aG sudo deploy
mkdir -p /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
nano /home/deploy/.ssh/authorized_keys   # paste your public key
chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh
```

### 4. Base Packages & Runtimes
```bash
apt update && apt -y upgrade
apt install -y nginx git curl unzip ufw software-properties-common
apt install -y openjdk-17-jdk
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
npm install -g @angular/cli
```

### 5. Firewall
```bash
ufw allow OpenSSH
ufw allow http
ufw allow https
ufw --force enable
ufw status
```

### 6. Clone Repositories
```bash
cd /opt
git clone https://github.com/chhabi86/care-ride-solutions-backend.git backend
git clone https://github.com/chhabi86/care-ride-solutions-frontend.git frontend
chown -R deploy:deploy backend frontend
```

### 7. Build Backend
```bash
cd /opt/backend
./mvnw -q clean package -DskipTests || mvn -q clean package -DskipTests
cp target/care-ride-backend-0.0.1.war /opt/backend/app.war
```

### 8. Environment File
Create `/opt/backend/app.env` (chmod 600, owner deploy):
```
SPRING_PROFILES_ACTIVE=prod
SERVER_PORT=8080
JWT_SECRET=CHANGE_ME
SPRING_DATASOURCE_URL=jdbc:postgresql://<db_host>:5432/<db>
SPRING_DATASOURCE_USERNAME=<user>
SPRING_DATASOURCE_PASSWORD=<pass>
SPRING_MAIL_HOST=smtp.mail.us-east-1.awsapps.com
SPRING_MAIL_USERNAME=<aws_workmail_user>
SPRING_MAIL_PASSWORD=<aws_workmail_pass>
```

### 9. systemd Service
File `/etc/systemd/system/care-ride-backend.service`:
```
[Unit]
Description=Care Ride Spring Boot Backend
After=network.target

[Service]
User=deploy
WorkingDirectory=/opt/backend
EnvironmentFile=/opt/backend/app.env
ExecStart=/usr/bin/java -jar /opt/backend/app.war
SuccessExitStatus=143
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```
Enable + start:
```bash
systemctl daemon-reload
systemctl enable --now care-ride-backend
systemctl status care-ride-backend --no-pager
```

### 10. Frontend Build & Install
```bash
cd /opt/frontend
npm ci || npm install
ng build --configuration production
mkdir -p /var/www/care-ride-frontend
rsync -a --delete dist/care-ride-frontend/ /var/www/care-ride-frontend/
chown -R www-data:www-data /var/www/care-ride-frontend
```

### 11. nginx Configuration (Static SPA + /api proxy)
File `/etc/nginx/sites-available/care-ride.conf`:
```
upstream backend_api { server 127.0.0.1:8080; }
server {
	listen 80;
	server_name yourdomain.com www.yourdomain.com;
	root /var/www/care-ride-frontend;
	index index.html;
	location /api/ {
		proxy_pass http://backend_api/;
		proxy_set_header Host $host;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
	}
	location / { try_files $uri $uri/ /index.html; }
	add_header X-Frame-Options SAMEORIGIN always;
	add_header X-Content-Type-Options nosniff always;
	add_header Referrer-Policy strict-origin-when-cross-origin always;
}
```
Enable:
```bash
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/care-ride.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

### 12. HTTPS via Let's Encrypt
```bash
apt install -y certbot python3-certbot-nginx
certbot --nginx -d yourdomain.com -d www.yourdomain.com --redirect --agree-tos -m you@example.com
systemctl list-timers | grep certbot
```

### 13. Deployment Scripts (Optional)
`/opt/deploy-backend.sh`:
```
#!/usr/bin/env bash
set -euo pipefail
cd /opt/backend
git fetch --all
git reset --hard origin/main
./mvnw -q clean package -DskipTests || mvn -q clean package -DskipTests
cp target/care-ride-backend-0.0.1.war /opt/backend/app.war
systemctl restart care-ride-backend
```

`/opt/deploy-frontend.sh`:
```
#!/usr/bin/env bash
set -euo pipefail
cd /opt/frontend
git fetch --all
git reset --hard origin/main
npm ci || npm install
ng build --configuration production
rsync -a --delete dist/care-ride-frontend/ /var/www/care-ride-frontend/
systemctl reload nginx
```
`chmod +x /opt/deploy-*.sh`

### 14. Verification
```bash
curl -I http://yourdomain.com
curl -s http://yourdomain.com/api/actuator/health | jq
journalctl -u care-ride-backend -n 50 --no-pager
tail -f /var/log/nginx/access.log
```

### 15. Rollback Strategy
Keep previous build copy before overwriting `app.war`:
```bash
cp /opt/backend/app.war /opt/backend/app.war.$(date +%s)
# To rollback:
mv /opt/backend/app.war.<timestamp> /opt/backend/app.war
systemctl restart care-ride-backend
```

### 16. Hardening (Next Steps)
- Move secrets to managed secret store / Vault.
- Add CSP refinement (remove 'unsafe-inline').
- Enable gzip/brotli: `apt install nginx-extras` and configure.
- Add fail2ban & rate limiting.
- External managed Postgres (DigitalOcean Managed DB or RDS).

### 17. Using External Tomcat (Alternative)
If you prefer container deployment inside Tomcat:
```bash
apt install -y tomcat10
cp /opt/backend/target/care-ride-backend-0.0.1.war /var/lib/tomcat10/webapps/ROOT.war
systemctl restart tomcat10
```
Then adjust nginx upstream: `upstream backend_api { server 127.0.0.1:8080; }` (Tomcat default) — unchanged if same port.

---
End of DigitalOcean section.

