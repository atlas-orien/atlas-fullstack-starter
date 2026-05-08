# Atlas Fullstack Starter Agent Instructions

本仓库是前后端一体脚手架，不是生成后的业务项目。

维护本仓库时，必须同时关注三类文件：

1. 根目录初始化脚本：`init.sh`、`init.ps1`
2. 生成项目模板：`project_template/`
3. 生成后会放入用户项目的两个子项目：
   - `frontend/` 来自 `react-mono-template`
   - `backend/` 来自 `db-center-template`

## AI 入口文件规则

生成后的用户项目根目录必须包含 `AGENTS.md`。

这个根目录 `AGENTS.md` 只负责统一入口和路由：

- 先说明全栈项目的根流程
- 再指向 `frontend/AGENTS.md`
- 再指向 `backend/AGENTS.md`

不要把前端或后端模板里的完整协议复制到根目录入口里。前端和后端各自的细节规则继续由它们自己的 `AGENTS.md` 维护。

## 修改脚手架时的检查项

如果新增或改动生成项目根目录里的固定文件，必须检查：

1. `project_template/` 是否包含该文件
2. `init.sh` 的输出目录结构提示是否需要更新
3. `init.ps1` 的输出目录结构提示是否需要更新
4. `README.md` 和 `project_template/ROOT_README.md.tpl` 是否需要提醒用户阅读该文件
5. 如果改动生成后项目管理命令，必须同步更新 `project_template/manager/`

## 初始化流程约束

`init.sh` 和 `init.ps1` 必须保持行为一致。

生成顺序保持为：

1. 生成 `backend/`
2. 复制 `frontend/`
3. 复制 `project_template/` 到项目根目录
4. 把后端模板自带的 `backend/API_CONTRACTS/` 迁移到根目录 `API_DOCS/`，并删除后端里的原目录
5. 渲染根目录 `README.md`
6. 写入根目录 `.gitignore`
7. 清理模板残留
8. 初始化新的 git 仓库

不要把模板仓库的 `.git`、`node_modules`、`target`、`dist`、`.turbo` 等生成产物带入用户项目。
