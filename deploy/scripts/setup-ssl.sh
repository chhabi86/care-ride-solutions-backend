#!/bin/bash

# SSL Certificate Installation Script for Care Ride Solutions
# This script installs Let's Encrypt SSL certificates for the domain

set -e

DOMAIN="careridesolutionspa.com"
EMAIL="info@careridesolutionspa.com"

echo "=== SSL Certificate Installation for $DOMAIN ==="

# 1. Install certbot if not already installed
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
else
    echo "Certbot already installed"
fi

# 2. Stop nginx temporarily for certificate generation
echo "Stopping nginx for certificate generation..."
sudo systemctl stop nginx

# 3. Generate SSL certificate using certbot standalone mode
echo "Generating SSL certificate for $DOMAIN..."
sudo certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    -d "$DOMAIN" \
    -d "www.$DOMAIN"

# 4. Update nginx configuration to use SSL
echo "Updating nginx configuration for SSL..."
sudo tee /etc/nginx/sites-available/care-ride.conf > /dev/null << 'EOF'
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name careridesolutionspa.com www.careridesolutionspa.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name careridesolutionspa.com www.careridesolutionspa.com;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/careridesolutionspa.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/careridesolutionspa.com/privkey.pem;
    
    # SSL security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;

    # Frontend (Angular) - serve static files
    location / {
        root /var/www/html;
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # Backend API proxy
    location /api {
        proxy_pass http://localhost:8080$request_uri;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeout settings
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Health check endpoint
    location /actuator/health {
        proxy_pass http://localhost:8080/actuator/health;
        proxy_set_header Host $host;
        access_log off;
    }
}
EOF

# 5. Test nginx configuration
echo "Testing nginx configuration..."
sudo nginx -t

# 6. Start nginx with SSL configuration
echo "Starting nginx with SSL configuration..."
sudo systemctl start nginx
sudo systemctl enable nginx

# 7. Setup automatic certificate renewal
echo "Setting up automatic certificate renewal..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# 8. Test SSL certificate
echo "Testing SSL certificate..."
sleep 5
curl -s -o /dev/null -w "SSL Test: %{http_code}\n" https://$DOMAIN || echo "SSL test failed - certificate may need time to propagate"

echo "=== SSL Certificate Installation Complete ==="
echo "Your site should now be accessible at https://$DOMAIN"
echo "Certificates will auto-renew via systemd timer"
