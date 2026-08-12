#!/bin/bash
set -euo pipefail

VERSION=${1:-}
IMAGE=spip

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version|latest>"
  exit 1
fi

if [ "$VERSION" = "latest" ]; then
  CONTEXT=4.4
else
  CONTEXT=$VERSION
fi

if [ ! -f "$CONTEXT/Dockerfile" ]; then
  echo >&2 "ERROR: no Dockerfile found in ./$CONTEXT"
  exit 1
fi

# Full package version (e.g. 4.4.18) read from the generated Dockerfile
PACKAGE=$(grep -E '^ENV SPIP_PACKAGE=' "$CONTEXT/Dockerfile" | cut -d '=' -f 2)

docker build --progress=plain \
  -t "ipeos/$IMAGE:$VERSION" \
  -t "ipeos/$IMAGE:$PACKAGE" \
  -t "ipeos/$IMAGE:latest" \
  "$CONTEXT"

echo "Built ipeos/$IMAGE:$VERSION, ipeos/$IMAGE:$PACKAGE and ipeos/$IMAGE:latest"
