# Care Ride Platform

Backend (Spring Boot) + Frontend (Angular static build from external repo) deployed via Docker Compose (backend/db) and served by host nginx.

## Quick Start (Local)
```bash
cd backend
cp backend.env.example backend.env  # once
docker compose up --build
# Browser: http://localhost (static Angular once built separately) ; http://localhost/api/services (API)
```
Stop:
```bash
docker compose down
```

## Services
| Name | Port | Notes |
|------|------|-------|
| db | internal | Postgres 15 |
| backend | 8080 | Spring API (/api) |
| nginx (host) | 80/443 | Public entrypoint |

## Deploy (Remote)
Handled by GitHub Actions workflow -> SSH -> `deploy.sh`.
Requires secrets: DEPLOY_HOST, DEPLOY_USER, DEPLOY_SSH_PORT, DEPLOY_DOMAIN, DEPLOY_SSH_KEY (or *_B64).

Manual deploy (builds backend + clones & builds frontend repo to static dir):
```bash
sudo DOMAIN=example.com ./deploy.sh
```

## Environment
Edit `backend.env` after copying from example; set secure DB password, mail creds, JWT secret.
Never commit real secrets.

### Production Database Credentials (Managed on Server)
The production droplet now has a PostgreSQL role and database:

- Role (user): `careuser`
- Database: `caredb`
- Current password: (stored only in `/opt/backend/app.env` on the server)

For operational reference (do NOT commit plaintext secrets), the password was last rotated during automation. If you need to rotate again:

```bash
ssh deploy@<host>
PW=$(openssl rand -hex 24)
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER ROLE careuser WITH PASSWORD '$PW';"
sudo sed -i "/^SPRING_DATASOURCE_PASSWORD=/d" /opt/backend/app.env
echo "SPRING_DATASOURCE_PASSWORD=$PW" | sudo tee -a /opt/backend/app.env >/dev/null
sudo systemctl restart care-ride-backend.service
```

Then verify:
```bash
curl -s http://127.0.0.1:8080/actuator/health
```

Security: Never publish the actual password in the repository. Rotate immediately if accidentally exposed.

## Logs
```bash
docker compose logs -f backend
ls -1 /var/www/care-ride-frontend | head
```

## API Test
```bash
curl http://localhost/api/services
```

## Next Ideas
- Cache node_modules for faster frontend builds
- Add actuator health endpoint
- Proper JWT auth & security hardening

