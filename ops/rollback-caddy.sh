#!/bin/bash
# Removes the booking site from Caddy and reloads. Does not delete the database.
set -euo pipefail

caddyfile="${CADDYFILE:-/etc/caddy/Caddyfile}"
site="${CADDY_SITE_DIR:-/etc/caddy/sites}/book.caddy"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"

sudo cp "$caddyfile" "$caddyfile.bak-$stamp"
sudo rm -f "$site"
sudo python3 - "$caddyfile" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
start = text.find("# BEGIN spv-booking")
end = text.find("# END spv-booking")
if start != -1 and end != -1:
    text = text[:start] + text[end + len("# END spv-booking"):]
    path.write_text(text)
PY

sudo caddy validate --config "$caddyfile"
sudo caddy reload --config "$caddyfile"

if [ "${SPV_STOP_STACK:-}" = "yes" ]; then
  docker compose -p spv-booking -f "$(dirname "$0")/../deploy/compose.yml" down
  echo "Containers stopped. Volumes were kept."
else
  echo "Caddy site removed. Containers are still running on 127.0.0.1:4473."
fi
