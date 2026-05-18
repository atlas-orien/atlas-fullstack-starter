#!/usr/bin/env sh
set -eu

APP_DATABASE_URL="${APP_DATABASE_URL:-${DATABASE_URL:-postgres://postgres:123456@postgres:5432/app}}"
CONFIG_PATH="${CONFIG_PATH:-/app/config/services.toml}"
ROOT_IDENTIFIER="${ROOT_IDENTIFIER:-test}"
ROOT_PASSWORD="${ROOT_PASSWORD:-12345678}"
export APP_DATABASE_URL DATABASE_URL="$APP_DATABASE_URL" CONFIG_PATH ROOT_IDENTIFIER ROOT_PASSWORD

psql "$APP_DATABASE_URL" -v ON_ERROR_STOP=1 -c \
  'CREATE TABLE IF NOT EXISTS __app_init_state (name text PRIMARY KEY, created_at timestamptz NOT NULL DEFAULT now());'

if psql "$APP_DATABASE_URL" -tAc "SELECT 1 FROM __app_init_state WHERE name = 'db-init'" | grep -q 1; then
  echo "db-init already completed; skipping."
  exit 0
fi

migration up
xtask init-permissions
xtask init-app-permissions
xtask init-root

psql "$APP_DATABASE_URL" -v ON_ERROR_STOP=1 -c \
  "INSERT INTO __app_init_state (name) VALUES ('db-init') ON CONFLICT (name) DO NOTHING;"
