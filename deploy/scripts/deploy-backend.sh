#!/usr/bin/env bash
set -euo pipefail

# Simple backend redeploy script. Assumes:
# - Repo cloned at /opt/backend
# - app.env present
# - systemd unit installed as care-ride-backend.service

REPO_DIR=/opt/backend
cd "$REPO_DIR"

echo "[deploy-backend] Fetching latest main..."
git fetch --all
LATEST=$(git rev-parse origin/main)
CURRENT=$(git rev-parse HEAD || echo 'none')
if [ "$LATEST" = "$CURRENT" ]; then
  echo "[deploy-backend] Already up to date ($CURRENT)"
else
  git reset --hard origin/main
  echo "[deploy-backend] Building..."
  if [ -x ./mvnw ]; then
    ./mvnw -q clean package -DskipTests || mvn -q clean package -DskipTests
  else
    mvn -q clean package -DskipTests
  fi
  cp target/care-ride-backend-0.0.1.war app.war
  echo "[deploy-backend] Restarting service..."
  systemctl restart care-ride-backend
  echo "[deploy-backend] Done. New revision: $(git rev-parse HEAD)"
fi
