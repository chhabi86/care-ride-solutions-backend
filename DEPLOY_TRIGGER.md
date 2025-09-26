# Deployment Trigger

This file is used to trigger GitHub Actions deployments.

Last deployment trigger: 2025-09-26 00:00:00 UTC - Cleanup for SES-only email delivery

We removed all SendGrid code and references. Email delivery path is now:
1. SMTP (if configured locally)
2. AWS SES HTTP API (production fallback; preferred in DO where SMTP is blocked)

Debug endpoints:
- /api/debug/smtp
- /api/debug/ses

Environment variables used in production:
- MAIL_HOST, MAIL_PORT, MAIL_USERNAME, MAIL_PASSWORD, MAIL_FROM
- AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_SES_FROM_EMAIL
