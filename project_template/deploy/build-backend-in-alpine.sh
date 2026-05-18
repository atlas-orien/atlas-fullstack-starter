#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CARGO_CACHE_DIR="${CARGO_CACHE_DIR:-$HOME/.cargo}"
BACKEND_ARTIFACT_DIR="/workspace/deploy/artifacts/backend"

docker run --rm \
  -e CARGO_HOME=/cargo-cache \
  -e CARGO_TARGET_DIR=/tmp/cargo-target \
  -e BACKEND_ARTIFACT_DIR="$BACKEND_ARTIFACT_DIR" \
  -e OPENSSL_STATIC=1 \
  -e PKG_CONFIG_ALLOW_CROSS=1 \
  -v "$PROJECT_DIR:/workspace" \
  -v "$CARGO_CACHE_DIR:/cargo-cache" \
  -w /workspace/backend \
  rust-builder:alpine \
  sh -c 'rm -rf "$CARGO_TARGET_DIR" "$BACKEND_ARTIFACT_DIR" && if [ ! -f Cargo.lock ]; then cargo generate-lockfile; fi && cargo build --release --locked -p web-server && mkdir -p "$BACKEND_ARTIFACT_DIR" && cp "$CARGO_TARGET_DIR/release/web-server" "$BACKEND_ARTIFACT_DIR"/'
