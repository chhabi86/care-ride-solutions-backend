#!/bin/bash
# Force systemd environment update script

echo "=== Manual systemd environment update ==="

# SSH into production and manually update environment
ssh root@134.209.33.238 "
set -e
echo 'Stopping care-ride-backend service...'
systemctl stop care-ride-backend

echo 'Updating systemd environment file...'
mkdir -p /etc/systemd/system/care-ride-backend.service.d

cat > /etc/systemd/system/care-ride-backend.service.d/env.conf << 'EOF'
[Service]
Environment=\"MAIL_HOST=smtp.mail.us-east-1.awsapps.com\"
Environment=\"MAIL_PORT=465\"
Environment=\"MAIL_USERNAME=info@careridesolutionspa.com\"
Environment=\"MAIL_PASSWORD=Transportation1@@\"
Environment=\"MAIL_FROM=noreply@careridesolutionspa.com\"
Environment=\"MAIL_DEBUG=false\"
EOF

echo 'Systemd environment file contents:'
cat /etc/systemd/system/care-ride-backend.service.d/env.conf

echo 'Reloading systemd daemon...'
systemctl daemon-reload

echo 'Starting care-ride-backend service...'
systemctl start care-ride-backend

echo 'Waiting for service to start...'
sleep 10

echo 'Service status:'
systemctl status care-ride-backend --no-pager
"

echo "=== Manual update complete ==="
