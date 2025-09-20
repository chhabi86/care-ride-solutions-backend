#!/bin/bash
# Force systemd environment update script

echo "=== Manual systemd environment update ==="

# SSH into production and manually update environment
ssh care-ride@134.209.33.238 "
set -e
echo 'Stopping care-ride-backend service...'
sudo systemctl stop care-ride-backend

echo 'Updating systemd environment file...'
sudo mkdir -p /etc/systemd/system/care-ride-backend.service.d

sudo tee /etc/systemd/system/care-ride-backend.service.d/env.conf > /dev/null << 'EOF'
[Service]
Environment=\"MAIL_HOST=smtp.mail.us-east-1.awsapps.com\"
Environment=\"MAIL_PORT=465\"
Environment=\"MAIL_USERNAME=info@careridesolutionspa.com\"
Environment=\"MAIL_PASSWORD=Transportation1@@\"
Environment=\"MAIL_FROM=noreply@careridesolutionspa.com\"
Environment=\"MAIL_DEBUG=false\"
EOF

echo 'Systemd environment file contents:'
sudo cat /etc/systemd/system/care-ride-backend.service.d/env.conf

echo 'Reloading systemd daemon...'
sudo systemctl daemon-reload

echo 'Starting care-ride-backend service...'
sudo systemctl start care-ride-backend

echo 'Waiting for service to start...'
sleep 10

echo 'Service status:'
sudo systemctl status care-ride-backend --no-pager
"

echo "=== Manual update complete ==="
