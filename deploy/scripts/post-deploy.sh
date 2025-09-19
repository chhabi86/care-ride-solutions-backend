#!/bin/bash
set -e

echo "=== Post-deployment server configuration ==="

# Configuration paths
NGINX_CONFIG_SOURCE="nginx/care-ride.conf"
NGINX_CONFIG_TARGET="/etc/nginx/sites-available/care-ride.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/care-ride.conf"
SYSTEMD_ENV_DIR="/etc/systemd/system/care-ride-backend.service.d"
SYSTEMD_ENV_FILE="$SYSTEMD_ENV_DIR/env.conf"

# Check if we're in the right directory (should contain nginx/ folder)
if [[ ! -f "$NGINX_CONFIG_SOURCE" ]]; then
    echo "Error: $NGINX_CONFIG_SOURCE not found. Run this script from the backend repo root."
    exit 1
fi

echo "1. Updating nginx configuration..."
sudo cp "$NGINX_CONFIG_SOURCE" "$NGINX_CONFIG_TARGET"
sudo chmod 644 "$NGINX_CONFIG_TARGET"

# Ensure nginx config is enabled
if [[ ! -L "$NGINX_ENABLED" ]]; then
    echo "Creating nginx symlink..."
    sudo ln -sf "$NGINX_CONFIG_TARGET" "$NGINX_ENABLED"
fi

# Test nginx configuration
echo "2. Testing nginx configuration..."
sudo nginx -t

echo "3. Reloading nginx..."
sudo systemctl reload nginx

echo "4. Setting up environment variables for backend..."
# Create systemd override directory if it doesn't exist
sudo mkdir -p "$SYSTEMD_ENV_DIR"

# Check if env.conf already exists and has MAIL settings
if [[ -f "$SYSTEMD_ENV_FILE" ]] && grep -q "MAIL_HOST" "$SYSTEMD_ENV_FILE"; then
    echo "Environment file already exists with MAIL settings."
else
    echo "Creating/updating environment configuration..."
    sudo tee "$SYSTEMD_ENV_FILE" > /dev/null <<EOF
[Service]
Environment="MAIL_HOST=${MAIL_HOST:-smtp.mail.us-east-1.awsapps.com}"
Environment="MAIL_PORT=${MAIL_PORT:-587}"
Environment="MAIL_USERNAME=${MAIL_USERNAME:-}"
Environment="MAIL_PASSWORD=${MAIL_PASSWORD:-}"
Environment="MAIL_FROM=${MAIL_FROM:-noreply@careridesolutionspa.com}"
Environment="MAIL_STARTTLS=${MAIL_STARTTLS:-true}"
Environment="MAIL_AUTH=${MAIL_AUTH:-true}"
EOF
    
    echo "5. Restarting backend service to apply new environment..."
    sudo systemctl daemon-reload
    sudo systemctl restart care-ride-backend
    
    echo "Waiting for backend to start..."
    sleep 5
fi

echo "6. Checking service status..."
sudo systemctl is-active care-ride-backend || {
    echo "Backend service failed to start. Checking logs:"
    sudo journalctl -u care-ride-backend -n 20 --no-pager
    exit 1
}

echo "7. Testing endpoints..."
# Test health endpoint
curl -f http://localhost/api/actuator/health > /dev/null && echo "✓ Health endpoint OK" || echo "✗ Health endpoint failed"

# Test contact endpoint with a simple POST
CONTACT_TEST=$(curl -s -w "%{http_code}" -X POST http://localhost/api/contact \
    -H "Content-Type: application/json" \
    -d '{"name":"Test","phone":"123","email":"test@test.com","reason":"Test","message":"Test"}' \
    -o /dev/null)

if [[ "$CONTACT_TEST" == "200" ]]; then
    echo "✓ Contact endpoint OK (200)"
elif [[ "$CONTACT_TEST" == "404" ]]; then
    echo "✗ Contact endpoint still returning 404 - nginx config may not have taken effect"
    exit 1
else
    echo "✓ Contact endpoint responding ($CONTACT_TEST) - may need email config"
fi

echo "=== Post-deployment configuration complete ==="
echo ""
echo "Next steps:"
echo "1. Set MAIL_* environment variables in GitHub Secrets"
echo "2. Re-run deployment to apply email configuration"
echo "3. Test contact form from production domain"
