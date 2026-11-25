#!/bin/bash
# Dump only the booking database. Never the CRM database.
set -euo pipefail
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
out="${1:-/var/backups/spv-booking-$stamp.dump}"
mkdir -p "$(dirname "$out")"
docker exec spv-booking-postgres pg_dump -U booking -d booking -Fc > "$out"
echo "Wrote $out"
