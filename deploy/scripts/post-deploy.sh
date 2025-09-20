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
sudo systemctl stop care-ride-backend
sleep 5
sudo systemctl start care-ride-backend

echo "Waiting for backend to start..."
sleep 15

echo "6. Showing final systemd environment file:"
sudo cat "$SYSTEMD_ENV_FILE"

echo "7. Showing effective process environment (filtered MAIL_*):"
MAIN_PID=$(systemctl show -p MainPID --value care-ride-backend || true)
if [ -n "$MAIN_PID" ] && [ "$MAIN_PID" != "0" ]; then
    echo "MainPID reported by systemd: $MAIN_PID"
    if command -v strings >/dev/null 2>&1; then
        RAW_ENV=$(sudo strings /proc/$MAIN_PID/environ 2>/dev/null)
    else
        RAW_ENV=$(sudo cat /proc/$MAIN_PID/environ 2>/dev/null | tr '\0' '\n')
    fi
    PROC_ENV=$(echo "$RAW_ENV" | grep '^MAIL_' || true)
    if [ -n "$PROC_ENV" ]; then
        echo "$PROC_ENV"
        MAIL_USER_RUNTIME=$(echo "$PROC_ENV" | grep '^MAIL_USERNAME=' | sed 's/MAIL_USERNAME=//')
        MAIL_PASS_RUNTIME=$(echo "$PROC_ENV" | grep '^MAIL_PASSWORD=' | sed 's/MAIL_PASSWORD=//')
        USER_LEN=${#MAIL_USER_RUNTIME}
        PASS_LEN=${#MAIL_PASS_RUNTIME}
        if [ -n "$MAIL_PASS_RUNTIME" ]; then
            MASKED_PASS=$(echo "$MAIL_PASS_RUNTIME" | sed -E 's/(.).*(.)/\1***\2/' )
        else
            MASKED_PASS='(empty)'
        fi
        echo "Derived lengths -> MAIL_USERNAME length=$USER_LEN, MAIL_PASSWORD length=$PASS_LEN"
        EXPECTED_PASS_LEN=${#MAIL_PASSWORD}
        if [ -n "$MAIL_PASSWORD" ]; then
          echo "Deployed secret password length (from deploy env)=$EXPECTED_PASS_LEN"
          if [ "$EXPECTED_PASS_LEN" -ne "$PASS_LEN" ]; then
            echo "WARNING: Runtime password length ($PASS_LEN) differs from provided secret length ($EXPECTED_PASS_LEN). Environment not updated?" >&2
          fi
        fi
        echo "Masked runtime password: $MASKED_PASS"
    else
        echo "No MAIL_* vars in process environ dump"
    fi
else
    echo "Backend MainPID not found (service may not have started)"
fi

echo "8. Checking service status..."
sudo systemctl is-active care-ride-backend || {
    echo "Backend service failed to start. Checking logs:"
    sudo journalctl -u care-ride-backend -n 20 --no-pager
    exit 1
}

echo "8b. systemd unit & environment summary:"
systemctl show care-ride-backend -p FragmentPath -p ExecStart -p Environment | sed 's/^/  /'
echo "--- unit file (systemctl cat) ---"; systemctl cat care-ride-backend | sed 's/^/  /'

echo "9. Testing endpoints (nginx via port 80)..."
# Retry health up to 10 times
HEALTH_OK=0
for i in {1..10}; do
    if curl -fsS http://localhost/api/actuator/health >/dev/null 2>&1; then
        echo "✓ Health endpoint OK (attempt $i)"
        HEALTH_OK=1; break
    else
        echo "Health attempt $i failed; waiting..."; sleep 3
    fi
done
if [ $HEALTH_OK -ne 1 ]; then
    echo "✗ Health endpoint failed after retries";
    sudo journalctl -u care-ride-backend -n 40 --no-pager | sed 's/^/[journal]/';
fi

echo "10. Testing internal (direct) endpoint attempts..."
# Try common app ports (8080, 8081) directly bypassing nginx
for P in 8080 8081; do
    if curl -fsS http://localhost:$P/actuator/health >/dev/null 2>&1; then
         echo "✓ Direct health OK on port $P"; DIRECT_PORT=$P; break; fi
ten
done || true
if [ -n "$DIRECT_PORT" ]; then
    curl -fsS -o /dev/null -w "Direct contact %s -> HTTP %{http_code}\n" -X POST \
        http://localhost:$DIRECT_PORT/api/contact -H 'Content-Type: application/json' \
        -d '{"name":"DirectTest","phone":"999","email":"d@test.com","reason":"Direct","message":"Direct"}' || true
else
    echo "No direct application port responded to health checks."
fi

# Test contact endpoint with a simple POST (only if health succeeded)
if [ $HEALTH_OK -eq 1 ]; then
    CONTACT_TEST=$(curl -s -w "%{http_code}" -X POST http://localhost/api/contact \
            -H "Content-Type: application/json" \
            -d '{"name":"Test","phone":"123","email":"test@test.com","reason":"Test","message":"Test"}' \
            -o /dev/null)
    if [[ "$CONTACT_TEST" == "200" ]]; then
            echo "✓ Contact endpoint OK (200)"
    elif [[ "$CONTACT_TEST" == "404" ]]; then
            echo "✗ Contact endpoint still returning 404 - nginx config may not have taken effect"; exit 1
    else
            echo "Contact endpoint status: $CONTACT_TEST"
    fi
fi

echo "=== Post-deployment configuration complete ==="
echo ""
echo "Next steps:"
echo "1. Set MAIL_* environment variables in GitHub Secrets"
echo "2. Re-run deployment to apply email configuration"
echo "3. Test contact form from production domain"
