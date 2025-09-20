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
# Backup existing config if it exists
if [[ -f "$NGINX_CONFIG_TARGET" ]]; then
    sudo cp "$NGINX_CONFIG_TARGET" "$NGINX_CONFIG_TARGET.backup.$(date +%Y%m%d_%H%M%S)"
fi

sudo cp "$NGINX_CONFIG_SOURCE" "$NGINX_CONFIG_TARGET"
sudo chmod 644 "$NGINX_CONFIG_TARGET"

# Ensure nginx config is enabled
if [[ ! -L "$NGINX_ENABLED" ]]; then
    echo "Creating nginx symlink..."
    sudo ln -sf "$NGINX_CONFIG_TARGET" "$NGINX_ENABLED"
fi

# Check for duplicate upstream definitions and remove if needed
echo "Checking for upstream conflicts..."
UPSTREAM_COUNT=$(sudo nginx -T 2>/dev/null | grep -c "upstream.*backend_api\|upstream.*care_ride_backend" || echo "0")
if [[ "$UPSTREAM_COUNT" -gt 1 ]]; then
    echo "Warning: Multiple upstream definitions found. Nginx will handle this."
fi

# Test nginx configuration
echo "2. Testing nginx configuration..."
if ! sudo nginx -t; then
    echo "Nginx configuration test failed. Checking for issues..."
    echo "Full nginx config test output:"
    sudo nginx -T 2>&1 | grep -E "emerg|error|duplicate" || true
    
    # Try to restore backup if it exists
    LATEST_BACKUP=$(ls -t "$NGINX_CONFIG_TARGET".backup.* 2>/dev/null | head -1 || echo "")
    if [[ -n "$LATEST_BACKUP" ]]; then
        echo "Restoring previous config from: $LATEST_BACKUP"
        sudo cp "$LATEST_BACKUP" "$NGINX_CONFIG_TARGET"
        if sudo nginx -t; then
            echo "Previous config restored successfully"
            echo "ERROR: New nginx config has issues. Deployment stopped."
            exit 1
        fi
    fi
    echo "ERROR: Nginx configuration is invalid and cannot be fixed automatically"
    exit 1
fi

echo "3. Reloading nginx..."
sudo systemctl reload nginx

echo "4. Setting up environment variables for backend..."
# Temporary debug to verify password is being passed (REMOVE AFTER TESTING)
echo "DEBUG: MAIL_PASSWORD length: ${#MAIL_PASSWORD}"
echo "DEBUG: MAIL_PASSWORD first 3 chars: ${MAIL_PASSWORD:0:3}"
echo "DEBUG: MAIL_PASSWORD last 3 chars: ${MAIL_PASSWORD: -3}"

# Create systemd override directory if it doesn't exist
sudo mkdir -p "$SYSTEMD_ENV_DIR"

# Always recreate the environment file to ensure latest values
echo "Creating/updating environment configuration..."
sudo tee "$SYSTEMD_ENV_FILE" > /dev/null <<EOF
[Service]
Environment="MAIL_HOST=${MAIL_HOST:-smtp.mail.us-east-1.awsapps.com}"
Environment="MAIL_PORT=${MAIL_PORT:-465}"
Environment="MAIL_USERNAME=${MAIL_USERNAME:-}"
Environment="MAIL_PASSWORD=${MAIL_PASSWORD:-}"
Environment="MAIL_FROM=${MAIL_FROM:-noreply@careridesolutionspa.com}"
Environment="MAIL_DEBUG=${MAIL_DEBUG:-false}"
EOF
    
echo "5. Restarting backend service to apply new environment..."
sudo systemctl daemon-reload
sudo systemctl restart care-ride-backend

echo "Waiting for backend to start..."
sleep 5

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
