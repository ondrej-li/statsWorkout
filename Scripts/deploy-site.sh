#!/usr/bin/env bash
#
# Publishes Website/ to https://stats-workout.ondralinek.cz/
#
# Usage:
#   Scripts/deploy-site.sh
#
# Environment:
#   DEPLOY_HOST  ssh target (default: deploy@2.31.33.21)
#   DEPLOY_PATH  remote web root (default: /var/www/stats-workout)
#
set -euo pipefail

HOST="${DEPLOY_HOST:-deploy@2.31.33.21}"
REMOTE_PATH="${DEPLOY_PATH:-/var/www/stats-workout}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -d "$ROOT/Website" ]; then
    echo "error: Website/ not found next to Scripts/" >&2
    exit 1
fi

echo "==> Uploading Website/ to $HOST:$REMOTE_PATH"
rsync -az --delete \
    -e "ssh -o BatchMode=yes" \
    "$ROOT/Website/" \
    "$HOST:$REMOTE_PATH/"

echo "==> Checking the live site"
curl -fsS -o /dev/null -w "   https://stats-workout.ondralinek.cz/ -> %{http_code}\n" \
    https://stats-workout.ondralinek.cz/
curl -fsS -o /dev/null -w "   https://stats-workout.ondralinek.cz/privacy.html -> %{http_code}\n" \
    https://stats-workout.ondralinek.cz/privacy.html
echo "==> Done"
