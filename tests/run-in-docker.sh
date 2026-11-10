#!/usr/bin/env bash
# Run tests/e2e.sh inside a Linux container that talks to the host docker daemon.
# Use this on macOS (colima, Docker Desktop): the scripts want Linux userland.
# The repo is copied into the container, so it works from any directory
# (a bind mount would only see paths the docker VM shares, usually $HOME).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

runner=$(docker run -d -v /var/run/docker.sock:/var/run/docker.sock docker:29.2.1-cli sleep 7200)
trap 'docker rm -f "$runner" >/dev/null' EXIT

docker exec "$runner" sh -c 'apk add --no-cache bash >/dev/null && mkdir -p /work'
tar --exclude=.git --exclude=NetName --exclude='*IP' --exclude='*_myid' --exclude=log.log -cf - . |
    docker exec -i "$runner" tar -xf - -C /work
docker exec -w /work \
    -e E2E_SUBNET -e E2E_NETWORK -e E2E_SKIP_BUILD -e E2E_KEEP \
    "$runner" bash tests/e2e.sh
