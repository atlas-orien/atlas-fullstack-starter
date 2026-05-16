# __PROJECT_NAME__

这是一个由 Atlas Fullstack Starter 生成的前后端一体项目。

## 目录结构

- `temp/REQUIREMENTS/`：用户放需求文档
- `temp/DEVELOPMENT_DOCS/backend/`：AI 编写后端开发文档
- `temp/DEVELOPMENT_DOCS/frontend/`：AI 在后端 API 确认后编写前端开发文档
- `API_DOCS/`：项目唯一 API 文档入口
- `frontend/`：前端项目
- `backend/`：后端项目
- `deploy/`：Docker 构建、离线打包和实施安装脚本
- `__MANAGE_ENTRY__`：__MANAGE_DESC__
- `AGENTS.md`：AI 统一入口，负责指向前端和后端子项目规则

## 快速开始

1. 先让 AI 从根目录 `AGENTS.md` 开始读取规则
2. 再让 AI 检查本机环境是否能启动前端和后端
3. 可以把业务需求文档放进 `temp/REQUIREMENTS/`，也可以直接在聊天里描述需求
4. 让 AI 先整理需求摘要，再生成 `temp/DEVELOPMENT_DOCS/backend/` 下的后端开发文档和数据库表结构
5. 用户确认后端设计
6. 让 AI 再生成 `API_DOCS/` 和 `temp/DEVELOPMENT_DOCS/frontend/`
7. 用户确认后，再开始正式开发
8. 如果后端接口有新增或修改，让 AI 同步更新根目录 `API_DOCS/`

## 你和 AI 的分工

你负责：

1. 提业务需求
2. 确认开发文档是否符合你的想法
3. 在 AI 无法继续时提供必要信息

AI 负责：

1. 安装和修复环境
2. 读取需求文档，或整理你在聊天中描述的需求
3. 先写后端开发文档
4. 再写 API 文档和前端开发文档
5. 开发、联调、修复错误

## 重要规则

1. AI 的入口是根目录 `AGENTS.md`
2. 不要一开始就让 AI 直接写代码
3. 一定先确认后端开发文档
4. 前端开发应以根目录 `API_DOCS/` 里的接口文档为准

## 常用命令

本项目使用 `__MANAGE_ENTRY__` 管理本地前后端服务。

初始化前后端 env：

```__MANAGE_CODE_LANG__
__MANAGE_CMD__ init-env
```

这个命令会同时初始化后端 env，并先执行前端 `pnpm install`，再生成前端 env 文件。
它不会启动 Docker，也不会执行数据库迁移。

也可以只初始化其中一端：

```__MANAGE_CODE_LANG__
__MANAGE_CMD__ init-env backend
__MANAGE_CMD__ init-env frontend
```

启动后端 Docker PostgreSQL 并确认数据库：

```__MANAGE_CODE_LANG__
__MANAGE_CMD__ backend db-up
```

执行后端数据库迁移：

```__MANAGE_CODE_LANG__
__MANAGE_CMD__ backend migrate
```

如果想一次完成数据库启动和迁移：

```__MANAGE_CODE_LANG__
__MANAGE_CMD__ backend setup-db
```

启动后端：

```__MANAGE_CODE_LANG__
__MANAGE_CMD__ backend start
```

停止后端：

```__MANAGE_CODE_LANG__
__MANAGE_CMD__ backend stop
```

安装前端依赖：

```__MANAGE_CODE_LANG__
__MANAGE_CMD__ frontend install
```

启动前端 app：

```__MANAGE_CODE_LANG__
__MANAGE_CMD__ frontend admin start
```

启动成功后会输出访问地址，例如 `http://localhost:5173/`。如果端口被占用，Vite 会自动顺延到下一个可用端口，实际地址以脚本输出为准。

停止前端 app：

```__MANAGE_CODE_LANG__
__MANAGE_CMD__ frontend admin stop
```

查看状态：

```__MANAGE_CODE_LANG__
__MANAGE_CMD__ backend status
__MANAGE_CMD__ frontend admin status
```

日志放在：

```text
temp/logs/
```

生成 Docker 离线交付包：

```bash
./deploy/build-release.sh
```

生成结果在：

```text
output/atlas-fullstack-offline.tar.gz
```

部署脚本的系统边界：

- `deploy/build-release.sh` 只支持 macOS/Linux 的 Bash 环境。
- `deploy/runtime/install.sh` 面向 Linux 服务器，用于实施人员现场安装。
- Windows 开发者不需要执行部署打包脚本。

## 新对话提示词

你可以在每次开启新对话时，把下面这段发给 AI：

```text
请先阅读当前项目根目录 AGENTS.md，再按 AGENTS.md 的要求阅读相关协议和项目文档，然后再开始工作。

在你确认自己已经读完这些协议之前，不要直接回答我的业务问题，也不要直接开始写代码。

你现在的工作目录就是这个前后端一体项目的根目录。

请按下面规则工作：
1. 先检查前端和后端环境是否完整，缺什么你自己安装或修复
2. 如果数据库初始化失败，你先自己排查；实在不行再告诉我需要一个可用数据库链接
3. 不要直接开始写业务代码，先让我描述需求
4. 我可能会把需求文档放到 temp/REQUIREMENTS/ 目录，也可能直接在聊天里描述需求
5. 你要先整理我的需求摘要和待确认问题，再从服务端设计开始
6. 先写 temp/DEVELOPMENT_DOCS/backend/ 下的后端开发文档和数据库表结构给我确认
7. 后端 API 设计确认后，再写 temp/DEVELOPMENT_DOCS/frontend/ 和 API_DOCS/ 给前端使用
8. 我确认文档后，你再正式开发
9. 如果后端接口有新增或修改，必须同步更新根目录 API_DOCS/
10. 如果过程中报错，优先自己处理，不要把原始报错直接甩给我
```

## 你最常接触的目录

1. `temp/REQUIREMENTS/`：放需求文档，也可以不用，直接在聊天里描述需求
2. `temp/DEVELOPMENT_DOCS/`：AI 写前后端开发文档
3. `API_DOCS/`：AI 写 API 文档，框架已有 API 和新业务 API 都放这里
4. `__MANAGE_ENTRY__`：启动、停止、查看服务状态
5. `frontend/`：前端代码
6. `backend/`：后端代码

## 如果报错怎么办

默认先让 AI 自己处理。

如果数据库一直初始化失败，你可以找技术人员要一个可用数据库链接，再发给 AI 处理。
