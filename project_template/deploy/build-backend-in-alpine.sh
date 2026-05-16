#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CARGO_CACHE_DIR="${CARGO_CACHE_DIR:-$HOME/.cargo}"
TARGET_DIR="${TARGET_DIR:-/workspace/backend/target}"

docker run --rm \
  -e CARGO_HOME=/cargo-cache \
  -e OPENSSL_STATIC=1 \
  -e PKG_CONFIG_ALLOW_CROSS=1 \
  -e TARGET_DIR="$TARGET_DIR" \
  -v "$PROJECT_DIR:/workspace" \
  -v "$CARGO_CACHE_DIR:/cargo-cache" \
  -w /workspace/backend \
  rust-builder:alpine \
  sh -c 'cargo build --release --locked -p web-server'
