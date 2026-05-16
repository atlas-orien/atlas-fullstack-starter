#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  . "$PROJECT_DIR/.env"
  set +a
fi

IMAGE_PREFIX="${IMAGE_PREFIX:-atlas-fullstack}"

echo "==> Preparing Rust builder"
"$PROJECT_DIR/deploy/build-backend-base-images.sh"

echo "==> Building frontend dist"
pnpm --dir frontend install --frozen-lockfile
pnpm --dir frontend --filter web build
pnpm --dir frontend --filter admin build

echo "==> Building Rust static binaries"
docker run --rm \
  -e CARGO_HOME=/cargo-cache \
  -e CARGO_TARGET_DIR=/tmp/cargo-target \
  -e OPENSSL_STATIC=1 \
  -e PKG_CONFIG_ALLOW_CROSS=1 \
  -v "$PROJECT_DIR:/workspace" \
  -v "$HOME/.cargo:/cargo-cache" \
  -w /workspace/backend \
  rust-builder:alpine \
  sh -c 'rm -rf "$CARGO_TARGET_DIR" && if [ ! -f Cargo.lock ]; then cargo generate-lockfile; fi && cargo build --release --locked -p web-server -p migration -p xtask && mkdir -p target/release && cp "$CARGO_TARGET_DIR/release/web-server" "$CARGO_TARGET_DIR/release/migration" "$CARGO_TARGET_DIR/release/xtask" target/release/'

echo "==> Building runtime images"
docker compose build postgres backend
docker compose build --no-cache web admin

echo "==> Verifying runtime images"
for image in \
  "$IMAGE_PREFIX-postgres:local" \
  "$IMAGE_PREFIX-backend:local" \
  "$IMAGE_PREFIX-web:local" \
  "$IMAGE_PREFIX-admin:local"
do
  docker image inspect "$image" >/dev/null
  echo "found $image"
done

echo "==> Packaging offline installer"
"$PROJECT_DIR/deploy/package-offline.sh"
