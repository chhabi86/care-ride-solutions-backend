#!/usr/bin/env bash
set -euo pipefail

# Simple frontend redeploy script. Assumes frontend repo checked out under /opt/frontend
# and Angular CLI installed globally (or devDependency).

REPO_DIR=/opt/frontend
DIST_DIR=/var/www/care-ride-frontend

cd "$REPO_DIR"

echo "[deploy-frontend] Fetching latest main..."
git fetch --all
LATEST=$(git rev-parse origin/main)
CURRENT=$(git rev-parse HEAD || echo 'none')
if [ "$LATEST" = "$CURRENT" ]; then
  echo "[deploy-frontend] Already up to date ($CURRENT)"
else
  git reset --hard origin/main
  echo "[deploy-frontend] Installing deps..."
  if command -v npm >/dev/null 2>&1; then
    (npm ci || npm install)
  else
    echo "npm not found" >&2; exit 1
  fi
  echo "[deploy-frontend] Building production bundle..."
  npx ng build --configuration production
  mkdir -p "$DIST_DIR"
  rsync -a --delete dist/care-ride-frontend/ "$DIST_DIR"/
  chown -R www-data:www-data "$DIST_DIR"
  echo "[deploy-frontend] Reloading nginx..."
  systemctl reload nginx || true
  echo "[deploy-frontend] Done. New revision: $(git rev-parse HEAD)"
fi
