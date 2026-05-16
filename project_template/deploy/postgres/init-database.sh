#!/usr/bin/env bash
set -euo pipefail

export DATABASE_URL="${DATABASE_URL:-postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@%2Fvar%2Frun%2Fpostgresql/${POSTGRES_DB}}"
export APP_DATABASE_URL="${APP_DATABASE_URL:-$DATABASE_URL}"
export CONFIG_PATH="${CONFIG_PATH:-/app/config/services.toml}"
export ROOT_IDENTIFIER="${ROOT_IDENTIFIER:-test}"
export ROOT_PASSWORD="${ROOT_PASSWORD:-12345678}"

echo "Running __PROJECT_NAME__ database migrations..."
migration up

echo "Initializing __PROJECT_NAME__ permissions..."
xtask init-permissions
xtask init-app-permissions

echo "Initializing __PROJECT_NAME__ root account..."
xtask init-root

echo "__PROJECT_NAME__ database initialization complete."
