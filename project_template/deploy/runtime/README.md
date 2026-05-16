# Atlas Fullstack 离线安装包

## 安装

本安装脚本只面向 Linux 服务器。Windows 和 macOS 不使用 `install.sh`。

```bash
sudo ./install.sh
```

安装脚本会：

```text
1. 检查并安装 Docker
2. 启动 Docker
3. 加载 __PROJECT_NAME__-images.tar
4. 创建 .env
5. 启动 docker compose
```

## 访问

```text
Web:   http://服务器IP:8080
Admin: http://服务器IP:8081
```

## 配置

需要调整端口、auth/file 服务地址或 root 账号时，修改 `.env` 后执行：

```bash
docker compose up -d
```

数据库数据保存在 Docker volume 中。不要执行 `docker compose down -v`，除非明确要删除数据库数据。
