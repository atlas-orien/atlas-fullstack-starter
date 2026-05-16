#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

require_root_for_install() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "需要安装 Docker。请使用 root 运行，或使用 sudo 运行：sudo ./install.sh"
    exit 1
  fi
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    return 0
  fi

  require_root_for_install

  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    . /etc/os-release
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  elif command -v yum >/dev/null 2>&1; then
    yum install -y yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    echo "无法识别 Linux 包管理器，请先手动安装 Docker 和 Docker Compose plugin。"
    exit 1
  fi
}

start_docker() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now docker
  elif command -v service >/dev/null 2>&1; then
    service docker start || true
  fi
}

compose() {
  docker compose "$@"
}

install_docker
start_docker

IMAGE_TAR="${IMAGE_TAR:-atlas-fullstack-images.tar}"

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
