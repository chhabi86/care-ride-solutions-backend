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

## Email Delivery (Production)
- Primary: SMTP if configured locally (Office365/WorkMail).
- Fallback: AWS SES HTTP API (bypasses SMTP port blocks on hosting providers like DigitalOcean).

Environment variables consumed:
- MAIL_HOST, MAIL_PORT, MAIL_USERNAME, MAIL_PASSWORD, MAIL_FROM
- AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_SES_FROM_EMAIL

Diagnostics in production:
- curl http(s)://<domain>/api/debug/smtp
- curl http(s)://<domain>/api/debug/ses

## AWS Deployment
We provide AWS ECS Fargate deployment via GitHub Actions.

- See `deploy/aws/README.md` for required AWS resources and secrets
- Workflow: `.github/workflows/aws-ecs-deploy.yml` (trigger via Actions → "backend: deploy to AWS ECS")

## Next Ideas
- Cache node_modules for faster frontend builds
- Add actuator health endpoint
- Proper JWT auth & security hardening


## Go-live checklist (AWS Frontend + API)

Use this checklist when switching production traffic to AWS hosting.

- CloudFront (frontend)
	- Alternate domain: careridesolutionspa.com attached, ACM cert in us-east-1
	- Origin Access Control (OAC) attached to S3 origin
	- Error responses (SPA routing): 403 → 200 /index.html, 404 → 200 /index.html, TTL 0

- S3 bucket (care-ride-frontend)
	- Block public access: ON
	- Bucket policy allows only CloudFront OAC

	Example policy (replace Distribution ID if changed):

	```json
	{
		"Version": "2012-10-17",
		"Statement": [
			{
				"Sid": "AllowCloudFrontAccessOnly",
				"Effect": "Allow",
				"Principal": { "Service": "cloudfront.amazonaws.com" },
				"Action": "s3:GetObject",
				"Resource": "arn:aws:s3:::care-ride-frontend/*",
				"Condition": {
					"StringEquals": {
						"AWS:SourceArn": "arn:aws:cloudfront::726591790830:distribution/E1JZLO2VIYSVJ7"
					}
				}
			}
		]
	}
	```

- Route53 (DNS)
	- Apex careridesolutionspa.com → Alias A/AAAA to CloudFront distribution
	- api.careridesolutionspa.com → Alias A/AAAA to your ALB (fronting ECS, port 443). Remove any placeholder A record IPs.

- Backend IAM (ECS task execution)
	- ssm:GetParameter(s) for /SPRING_DATASOURCE_URL, /SPRING_DATASOURCE_USERNAME, /SPRING_DATASOURCE_PASSWORD, /JWT_SECRET
	- kms:Decrypt if using SecureString parameters

- Smoke tests
	- https://careridesolutionspa.com returns 200 (no 403)
	- https://api.careridesolutionspa.com/api/ping returns OK
	- https://api.careridesolutionspa.com/api/services returns JSON
	- /api/debug/ses shows credentials loaded
	- Contact form sends email via SES

# Trigger backend deployment
# Force deployment with updated infrastructure Wed Oct  1 07:45:27 EDT 2025
# Trigger deployment with corrected cluster/service names Wed Oct  1 10:53:27 EDT 2025
