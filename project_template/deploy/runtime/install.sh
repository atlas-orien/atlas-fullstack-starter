#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

compose() {
  docker compose "$@"
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "错误：未检测到 Docker。请先执行环境准备脚本或手动安装 Docker。"
    exit 1
  fi

  if ! docker info >/dev/null 2>&1; then
    echo "错误：Docker daemon 不可用。请先启动 Docker，并确认当前用户有权限访问 Docker。"
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo "错误：未检测到 Docker Compose plugin。请先安装 docker compose。"
    exit 1
  fi
}

require_docker

IMAGE_TAR="${IMAGE_TAR:-__PROJECT_NAME__-images.tar}"

if [ ! -f "$IMAGE_TAR" ]; then
  echo "找不到 $IMAGE_TAR"
  exit 1
fi

if [ ! -f .env ]; then
  cp .env.example .env
fi

docker load -i "$IMAGE_TAR"
compose up -d

echo "安装完成"
echo "Web:   http://localhost:${WEB_PORT:-8080}"
echo "Admin: http://localhost:${ADMIN_PORT:-8081}"
