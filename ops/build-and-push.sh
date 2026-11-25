#!/bin/bash
# Build the image on this machine. The server only pulls.
set -euo pipefail
cd "$(dirname "$0")/.."

tag="${SPV_BOOKING_IMAGE:-spv-booking:local}"

docker build \
  -f Dockerfile.docker \
  --target release-slim \
  -t "$tag" \
  .

echo "Built $tag"
if [ -n "${SPV_REGISTRY_PUSH:-}" ]; then
  docker push "$tag"
  echo "Pushed $tag"
else
  echo "Not pushed. Set SPV_REGISTRY_PUSH=1 and a tag you can push, then run again."
  echo "Fallback without a registry: docker save $tag | ssh <host> docker load"
fi
