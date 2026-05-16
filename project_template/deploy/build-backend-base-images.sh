#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if docker image inspect rust-builder:alpine >/dev/null 2>&1; then
  echo "rust-builder:alpine 已存在，跳过构建。"
  exit 0
fi

docker build \
  -f "$PROJECT_DIR/deploy/backend/builder-base.Dockerfile" \
  -t rust-builder:alpine \
  "$PROJECT_DIR"
