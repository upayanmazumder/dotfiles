#!/usr/bin/env bash
# docker-prune-all.sh -- reclaim disk space from stopped containers, dangling
# images, unused networks and (with --volumes) unused volumes. Prints what
# would be freed before touching anything destructive that isn't already
# `docker ... prune`'s own built-in confirmation-free scope.
#
# Usage:
#   docker-prune-all.sh            # containers, images, networks, build cache
#   docker-prune-all.sh --volumes  # also prune unused volumes (data loss risk)
set -euo pipefail

command -v docker >/dev/null 2>&1 || { echo "docker not found" >&2; exit 1; }

echo "==> disk usage before"
docker system df

echo "==> pruning stopped containers, dangling images, unused networks, build cache"
docker system prune -f

if [ "${1:-}" = "--volumes" ]; then
  echo "==> pruning unused volumes (irreversible data loss for unattached volumes)"
  docker volume prune -f
fi

echo "==> disk usage after"
docker system df
