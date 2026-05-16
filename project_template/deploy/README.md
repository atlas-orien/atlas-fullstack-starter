# Docker Compose 源码构建部署

这个目录用于本机或服务器持有源码时的 Docker Compose 部署测试。

## 服务

- `postgres`: 基于官方 PostgreSQL latest 的项目数据库镜像，数据保存在 `postgres_data` volume。PostgreSQL 18+ 使用 `/var/lib/postgresql` 作为 volume 挂载点。
- `backend`: Rust `web-server` 服务，监听 `19878`。
- `web`: Vite `apps/web` 构建产物，由 nginx 托管，宿主端口 `8080`。
- `admin`: Vite `apps/admin` 构建产物，由 nginx 托管，宿主端口 `8081`。

## 启动

## 系统支持

- `build-release.sh`：支持 macOS/Linux Bash 环境，用于打包人员生成离线交付包。
- `runtime/install.sh`：支持 Linux 服务器，用于实施人员现场安装 Docker、加载镜像并启动服务。
- Windows 不提供部署打包脚本；Windows 开发者不需要执行本目录脚本。

生成最终离线交付包：

```bash
./deploy/build-release.sh
```

脚本会依次完成：

```text
1. 检查并准备 rust-builder:alpine
2. 编译前端 web/admin dist
3. 编译后端 web-server/migration/xtask 静态 bin
4. 构建最终 Docker 镜像
5. 生成 output/atlas-fullstack-offline.tar.gz
```

本机测试启动：

```bash
docker compose up -d
```

前端镜像只使用 nginx，不在 Docker 里安装 Node 或 pnpm。`deploy/frontend/Dockerfile` 只会把本机已经生成的 `frontend/apps/web/dist` 或 `frontend/apps/admin/dist` 复制进 nginx 镜像。

后端发布使用 stable Rust，不依赖本机 nightly。当前后端 builder 采用 Alpine/musl 路线，builder 镜像只安装系统构建依赖，不预下载项目依赖：

```text
rust-builder:alpine
  stable Rust + Alpine 构建工具 + musl + OpenSSL static libs + zlib static libs
```

先执行：

```bash
./deploy/build-backend-base-images.sh
```

这个步骤只在本地不存在 `rust-builder:alpine` 时构建 builder 基础镜像。它会安装 Alpine 系统依赖，但不会 `cargo fetch`，也不会把当前项目源码 COPY 进镜像。

用 builder 容器编译后端：

```bash
./deploy/build-backend-in-alpine.sh
```

这个脚本运行时挂载：

```text
当前项目源码 -> /workspace
本机 ~/.cargo -> /cargo-cache
```

注意不要把本机 `~/.cargo` 直接挂载到容器的 `/usr/local/cargo`。Rust 官方镜像自己的 `cargo`、`rustc`、`rustup` 入口就在 `/usr/local/cargo/bin`，整目录覆盖会导致容器里找不到工具链。脚本会使用 `CARGO_HOME=/cargo-cache` 复用本机 Cargo registry/git 缓存，同时保留镜像内的 Rust 工具链。

如果希望使用其它 Cargo 缓存目录：

```bash
CARGO_CACHE_DIR=/path/to/cargo-cache ./deploy/build-backend-in-alpine.sh
```

访问：

- Web: http://localhost:8080
- Admin: http://localhost:8081

`backend` 和 `postgres` 默认不映射到宿主机端口，只在 Docker Compose 内部网络中访问。

## 配置

容器内后端使用 `deploy/backend/services.docker.toml`，其中数据库地址是：

```text
postgres://postgres:123456@postgres:5432/app
```

注意容器内不能使用本机开发环境的 `localhost:15432`，必须用 Compose 服务名 `postgres`。

数据库结构不会在 `docker build` 阶段初始化。镜像构建时没有最终运行中的 PostgreSQL，也没有最终数据 volume；初始化应该发生在 `docker compose up` 的运行阶段。

当前 Compose 启动顺序是：

```text
postgres -> backend -> web/admin
```

数据库第一次创建数据目录时，PostgreSQL 会自动执行 `deploy/postgres/init-database.sh`。初始化包含：

```text
1. migration up
2. xtask init-permissions
3. xtask init-app-permissions
4. xtask init-root
```

默认 root 账号初始化参数：

```text
ROOT_IDENTIFIER=test
ROOT_PASSWORD=12345678
```

`xtask init-root` 会登录外部 auth 服务，并把该 auth 用户绑定到本地 root 后台角色。

`auth` 和 `file` 不由本项目 Compose 托管。正式构建后的前端仍然请求同源路径：

```text
/api
/auth
/file
```

nginx 容器在运行时把这些路径转发到不同 upstream。默认配置是：

```bash
API_UPSTREAM=http://backend:19878
AUTH_UPSTREAM=http://1.85.61.130:29001
FILE_UPSTREAM=http://1.85.61.130:29002
```

需要替换外部服务地址时，启动前设置环境变量即可，不需要重新编译前端：

```bash
AUTH_UPSTREAM=http://auth-server-host:port \
FILE_UPSTREAM=http://file-server-host:port \
docker compose up --build
```

浏览器只访问当前前端站点的 `/api`、`/auth`、`/file`，因此生产运行不依赖浏览器 CORS。

## 后续正式化方向

第一版采用“前端本机 build，后端 Alpine builder 编译静态 bin”的混合方案。最终运行镜像里不包含 Rust toolchain，也不依赖额外 Linux 动态库 runtime。

离线交付时至少需要保存这些镜像：

```bash
./deploy/package-offline.sh
```

脚本会生成：

```text
output/atlas-fullstack-offline.tar.gz
output/atlas-fullstack-offline/
```

`output/` 已被 `.gitignore` 忽略，不需要提交到 Git。把 `atlas-fullstack-offline.tar.gz` 交给实施人员即可。

后端当前使用 Alpine builder 编译静态 `web-server`。最终交付镜像只需要复制 `web-server` 和运行配置；`migration` 与开发/初始化流程相关，不放入最终后端运行镜像。
