# Care Ride Solutions - AI Agent Instructions

## Project Overview
**Care Ride Solutions** is a medical transportation platform with a Spring Boot backend and Angular frontend deployed as separate repositories. The backend serves REST APIs under `/api`, while the frontend is a static Angular SPA served by nginx with API proxying.

## Architecture & Key Patterns

### Multi-Repository Structure
- **Backend**: `care-ride-solutions-backend` (this repo) - Spring Boot WAR deployed via systemd
- **Frontend**: `care-ride-solutions-frontend` (separate repo) - Angular SPA built and deployed to `/var/www/care-ride-frontend`
- **Deployment**: GitHub Actions trigger deployments independently; frontend workflow checks backend health

### Spring Boot Specifics
- **WAR Packaging**: Uses `ServletInitializer` for external Tomcat deployment (though currently uses embedded Tomcat via systemd)
- **Profile Strategy**: `application.yml` (base) + `application-local.yml` (local dev overrides)
- **Security**: Public APIs with CSRF disabled (`SecurityConfig` permits all requests)
- **Data Layer**: JPA entities in `com.care.ride.domain`, repos in `com.care.ride.repo`, simple CRUD pattern

### Email Integration Critical Pattern
The `EmailService` implements **multi-transport fallback** for SMTP reliability:
```java
// Attempts STARTTLS 587 → SSL 465 → plain 25 with detailed logging
public boolean sendContactEmail(String to, String subject, String text)
```
- **Current Production**: Microsoft 365 SMTP (`smtp.office365.com:587` with STARTTLS)
- **Configuration**: Environment variables override Spring properties (`MAIL_HOST`, `MAIL_PASSWORD`, etc.)
- **Debugging**: `/api/debug/smtp` endpoint tests connections without sending emails

### Frontend-Backend Communication
- **API Base**: Frontend uses `/api` (proxied by nginx to `localhost:8080`)
- **CORS**: `PublicController` explicitly allows frontend domains
- **Data Flow**: Contact form → `/api/contact` → saves to DB + sends email asynchronously
- **Angular Pattern**: Standalone components, no modules, uses `provideHttpClient()`

## Development Workflows

### Local Development Commands
```bash
# Backend (Docker Compose)
cd backend && cp backend.env.example backend.env
docker compose up --build
# Access: http://localhost/api/services

# Backend (Maven, local profile)
mvn spring-boot:run -Dspring-boot.run.profiles=local
# Note: application-local.yml overrides default mail settings

# Frontend (separate repo)
npm start  # Uses proxy.conf.json to route /api to localhost:8080
```

### Email Testing Strategy
**Local**: Export `MAIL_*` environment variables or create `application-local-mail.yml` (gitignored)
**Production**: GitHub Actions injects secrets as systemd environment variables
**Debugging**: Always check `/api/debug/smtp` for connection status and auth verification

### Deployment Process
1. **Backend**: Push to main → GitHub Actions → SSH to server → Maven build → systemd restart
2. **Frontend**: Push to main → GitHub Actions → build Angular → rsync to `/var/www/care-ride-frontend` → nginx reload
3. **Environment**: Secrets managed via GitHub repository secrets, injected as systemd environment

## Critical Files & Patterns

### Configuration Hierarchy
- `application.yml`: Base configuration with Microsoft 365 SMTP defaults
- `application-local.yml`: Local development overrides (H2 database, different mail settings)
- `/opt/backend/app.env`: Production environment file (systemd EnvironmentFile)

### API Endpoints
- `/api/services`: Returns `ServiceType` entities for booking form
- `/api/contact`: Accepts contact form, saves to `Contact` entity, sends email
- `/api/bookings`: Creates `Booking` entity with validation, sends notification email
- `/api/ping`: Health check endpoint
- `/api/debug/smtp`: SMTP connection testing (production diagnostics)

### Database Patterns
- **Local**: H2 in-memory database via `application-local.yml`
- **Production**: PostgreSQL with connection pooling
- **Entities**: Simple JPA entities with basic validation (`@NotBlank`, `@NotNull`)
- **Repos**: Extend `JpaRepository` with no custom queries
- **Data Loading**: `DevDataLoader` creates default `ServiceType` on startup

### Deployment Infrastructure
- **nginx**: Serves Angular SPA + proxies `/api/*` to backend on port 8080
- **systemd**: Manages backend as `care-ride-backend.service` with environment file
- **GitHub Actions**: Separate workflows for backend and frontend with health checks
- **SSL**: Automated via Let's Encrypt (certbot) during deployment

## Common Issues & Solutions

### Email Failures
- **Symptom**: Contact form succeeds but no email sent
- **Check**: `/api/debug/smtp` endpoint for authentication errors
- **Fix**: Ensure Microsoft 365 "Authenticated SMTP" is enabled in admin portal

### Frontend 502 Errors
- **Symptom**: Angular loads but API calls return 502 Bad Gateway
- **Cause**: Backend systemd service down or not listening on port 8080
- **Fix**: `sudo systemctl restart care-ride-backend` and check logs

### Profile Configuration Issues
- **Symptom**: Local development uses production database or mail settings
- **Cause**: `application-local.yml` not loaded or Spring profile not set
- **Fix**: Ensure `-Dspring-boot.run.profiles=local` or `SPRING_PROFILES_ACTIVE=local`

### GitHub Actions Deployment Failures
- **Frontend**: Usually backend health check timeout → make health check optional
- **Backend**: Often environment variable injection issues → verify secrets are set

## Agent Mode Troubleshooting

If agent mode is not working:
1. **VS Code Settings**: Ensure GitHub Copilot extension is enabled and authenticated
2. **Workspace Context**: Make sure you're in the correct repository workspace
3. **File Association**: This `.github/copilot-instructions.md` should be recognized automatically
4. **Copilot Chat**: Try using `@workspace` prefix in Copilot Chat to activate workspace context

For optimal agent assistance, always specify:
- Which repository you're working in (backend vs frontend)
- Current environment (local development vs production)
- Specific error messages or logs when debugging issues
