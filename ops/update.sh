#!/bin/bash
# Pull a new image and recreate the booking containers. No build on the server.
set -euo pipefail
cd "$(dirname "$0")/../deploy"
docker compose -p spv-booking -f compose.yml pull
docker compose -p spv-booking -f compose.yml up -d --no-build
echo "Updated. Database volume was kept."
