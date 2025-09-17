#!/bin/bash
# SSL Certificate Setup Script
# - Installs nginx + certbot
# - Configures HTTP -> HTTPS redirect
# - Issues Let's Encrypt cert for DOMAIN
# - Serves static frontend from SITE_ROOT and proxies /api to localhost:8080
#
# Usage (recommended):
#   sudo DOMAIN="careridesolutionspa.com" SITE_ROOT="/var/www/care-ride-frontend" EMAIL="admin@careridesolutionspa.com" ./setup-ssl.sh
#
# Defaults:
#   DOMAIN=${DOMAIN:-careridesolutionspa.com}
#   SITE_ROOT=${SITE_ROOT:-/var/www/care-ride-frontend}
#   EMAIL=${EMAIL:-admin@${DOMAIN}}

set -euo pipefail

DOMAIN=${DOMAIN:-careridesolutionspa.com}
SITE_ROOT=${SITE_ROOT:-/var/www/care-ride-frontend}
EMAIL=${EMAIL:-admin@${DOMAIN}}

echo "🔒 SSL Certificate Setup for ${DOMAIN}"
echo "=================================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "✅ Running as root"
else
    echo "❌ Please run as root: sudo DOMAIN=example.com SITE_ROOT=/var/www/app EMAIL=admin@example.com $0"
    exit 1
fi

# Update system packages
echo "📦 Updating system packages..."
apt update
apt upgrade -y

# Install required packages
echo "🛠️ Installing required packages..."
apt install -y nginx certbot python3-certbot-nginx ufw curl

# Check if nginx is running
echo "🔍 Checking nginx status..."
systemctl status nginx --no-pager || {
    echo "Starting nginx..."
    systemctl start nginx
    systemctl enable nginx
}

# Configure firewall
echo "🔥 Configuring firewall..."
ufw allow 22/tcp
ufw allow 80/tcp  
ufw allow 443/tcp
ufw --force enable

# Backup existing nginx config
echo "💾 Backing up nginx configuration..."
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup.$(date +%s)

# Create nginx configuration for ${DOMAIN}
echo "📝 Creating nginx configuration..."
cat > /etc/nginx/sites-available/${DOMAIN} << EOF
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    
    # Redirect all HTTP requests to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN} www.${DOMAIN};
    
    # SSL Configuration (will be updated by certbot)
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    
    # Frontend static files
    root ${SITE_ROOT};
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Backend API proxy
    location /api/ {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Remove default nginx site and enable new one
echo "🔄 Configuring nginx sites..."
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/

# Test nginx configuration
echo "🧪 Testing nginx configuration..."
nginx -t || {
    echo "❌ Nginx configuration test failed!"
    exit 1
}

# Create temporary HTTP-only config for certificate generation
echo "🔧 Creating temporary HTTP config for SSL certificate..."
cat > /etc/nginx/sites-available/temp-http << EOF
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    
    # Allow Let's Encrypt challenges
    location /.well-known/acme-challenge/ {
        root ${SITE_ROOT};
    }
    
    # Frontend static files
    root ${SITE_ROOT};
    index index.html;
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    # Backend API proxy
    location /api/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Switch to temporary config
rm -f /etc/nginx/sites-enabled/${DOMAIN}
ln -sf /etc/nginx/sites-available/temp-http /etc/nginx/sites-enabled/
systemctl reload nginx

# Obtain SSL certificate
echo "🔐 Obtaining SSL certificate from Let's Encrypt..."
certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email ${EMAIL} --redirect

# Switch back to HTTPS config
echo "🔄 Switching to HTTPS configuration..."
rm -f /etc/nginx/sites-enabled/temp-http
ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/

# Test and reload nginx
nginx -t && systemctl reload nginx

# Set up automatic certificate renewal
echo "🔄 Setting up automatic certificate renewal..."
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

# Display status
echo ""
echo "✅ SSL Certificate Setup Complete!"
echo "=================================="
echo ""
echo "🔍 Certificate Status:"
certbot certificates || true

echo ""
echo "🌐 Testing HTTPS:"
curl -I https://${DOMAIN}/ || echo "⚠️ HTTPS test failed"

echo ""
echo "📋 Next Steps:"
echo "1. Test your website: https://${DOMAIN}"
echo "2. Test contact form: https://${DOMAIN}/contact"
echo "3. Verify certificate auto-renewal: certbot renew --dry-run"
echo ""
echo "🔧 Configuration Files:"
echo "- Nginx config: /etc/nginx/sites-available/${DOMAIN}"
echo "- SSL certificates: /etc/letsencrypt/live/${DOMAIN}/"
echo ""
echo "🚨 If you have issues:"
echo "- Check nginx logs: journalctl -u nginx"
echo "- Check certbot logs: /var/log/letsencrypt/"
echo "- Verify DNS: dig ${DOMAIN}"
