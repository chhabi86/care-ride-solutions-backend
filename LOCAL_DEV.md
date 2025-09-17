# Care Ride Backend – Local Development Quick Start

You saw `localhost:8080` connection refused. That just means the Spring Boot app is **not actually running/listening** yet. Follow one of the two paths below.

## 1. Run with Docker Compose (recommended)
```bash
cd backend
# 1. Create env file if missing
[ -f backend.env ] || cp backend.env.example backend.env
# 2. Start only db + backend
docker compose up --build backend
# (Add -d to detach)
```
Then visit: http://localhost:8080/api/services (will 200/[] once DB ready)  
Logs (new terminal):
```bash
docker compose logs -f backend
```
Stop:
```bash
docker compose down
```

If you forgot to create `backend.env`, the backend container will try to use `localhost` for the DB (inside the container) and fail, then exit → port 8080 stays closed.

## 2. Run directly on host (needs Java 17 + Maven)
```bash
brew install maven # if not installed
cd backend
cp backend.env.example backend.env   # still useful for reference
# Start a Postgres container separately (if you don't have local one)
docker run --name caredb -e POSTGRES_DB=caredb -e POSTGRES_USER=careuser -e POSTGRES_PASSWORD=changeme_db_password -p 5432:5432 -d postgres:15
# Run Spring Boot
env SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/caredb \
    SPRING_DATASOURCE_USERNAME=careuser \
    SPRING_DATASOURCE_PASSWORD=changeme_db_password \
    mvn spring-boot:run
```
Visit: http://localhost:8080/api/services

## Verifying Something Is Listening
```bash
lsof -i :8080 || netstat -an | grep 8080
```
If no process/container → browser will show connection refused.

## Common Issues
| Symptom | Cause | Fix |
|---------|-------|-----|
| Connection refused | Container crashed (DB unreachable) | Ensure `backend.env` exists; `docker compose logs backend` |
| HTTP 500 on first request | DB still starting | Wait a few seconds; Flyway disabled so just retry |
| Different app on 8080 | Another process using port | Stop that process or change `server.port` |
| `./mvnw: not found` | Maven wrapper script not committed | Use `mvn` (install Maven) |

## Useful Endpoints
- `GET /api/services` – simple read check
- `POST /api/contact` – requires JSON body, sends/stores contact

## Next Steps
Consider adding Actuator for health checks: add dependency `spring-boot-starter-actuator` and hit `/actuator/health`.

---
This file is generated to streamline local setup troubleshooting.
