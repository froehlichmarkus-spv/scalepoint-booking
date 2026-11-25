#!/bin/bash
# Installs the booking stack beside the live CRM. Does not build on the server.
# Does not restart CRM, portal, Redis, or their databases.
set -euo pipefail

if [ "${SPV_SNAPSHOT_CONFIRMED:-}" != "yes" ]; then
  echo "Refusing to continue. Take a Hetzner snapshot, then export SPV_SNAPSHOT_CONFIRMED=yes."
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/deploy"

if grep -Eiq 'twenty|oldorff|redis' compose.yml; then
  echo "Refusing to continue. deploy/compose.yml names a service this stack must not touch."
  exit 1
fi

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p /var/backups
{
  echo "# preflight $stamp"
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
  echo
  docker volume ls
  echo
  df -h
  echo
  free -h
} > "/var/backups/spv-booking-preflight-$stamp.txt"

docker compose -p spv-booking -f compose.yml pull
docker compose -p spv-booking -f compose.yml up -d --no-build

site_dir="${CADDY_SITE_DIR:-/etc/caddy/sites}"
caddyfile="${CADDYFILE:-/etc/caddy/Caddyfile}"
sudo mkdir -p "$site_dir"
sudo cp "$root/deploy/Caddyfile.book" "$site_dir/book.caddy"
sudo cp "$caddyfile" "$caddyfile.bak-$stamp"

if ! grep -q 'BEGIN spv-booking' "$caddyfile"; then
  printf '\n# BEGIN spv-booking\nimport %s/book.caddy\n# END spv-booking\n' "$site_dir" | sudo tee -a "$caddyfile" >/dev/null
fi

if ! sudo caddy validate --config "$caddyfile"; then
  sudo cp "$caddyfile.bak-$stamp" "$caddyfile"
  echo "Caddy config rejected. Restored the previous file. Containers were still started on 127.0.0.1:4473."
  exit 1
fi

sudo caddy reload --config "$caddyfile"
echo "Booking stack is up. CRM containers were not restarted. Preflight: /var/backups/spv-booking-preflight-$stamp.txt"
