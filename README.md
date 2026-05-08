# Atlas Fullstack Starter

这是一个给普通用户使用的前后端一体项目脚手架。

它的作用很简单：

帮你快速创建一个新的项目，并把前端、后端和后续和 AI 协作需要用到的文档目录一起准备好。

## 使用方式

先进入一个你准备存放项目的目录。

## 运行前准备

请先确保系统里已经安装这些工具：

1. `git`
2. Rust 工具链，也就是 `rustc` 和 `cargo`
3. `cargo-generate`
4. Node.js
5. `pnpm`

如果已经安装 Rust，可以用下面的命令安装 `cargo-generate`：

```bash
cargo install cargo-generate
```

如果已经安装 Node.js，可以用下面的命令启用或安装 `pnpm`：

```bash
corepack enable
corepack prepare pnpm@latest --activate
```

macOS / Linux 还需要系统里有 `curl`、`bash`、`tar`。Windows 请使用 PowerShell 执行下面的 Windows 命令。

这个脚手架只推荐用户使用远程执行方式，不介绍本地执行方式。

按你的系统选择下面这一条命令直接执行。

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/atlas-form/atlas-fullstack-starter/main/init.sh | bash -s -- my-app
```

### Windows PowerShell

请先打开 PowerShell，并进入你准备存放项目的目录，例如：

```powershell
cd D:\tmp
```

然后复制下面这一整行命令执行：

```powershell
$script = Join-Path $env:TEMP "atlas-fullstack-init.ps1"; irm https://raw.githubusercontent.com/atlas-form/atlas-fullstack-starter/main/init.ps1 -OutFile $script; & $script -ProjectName my-app
```

如果要换项目名，把最后的 `my-app` 改成自己的项目名即可。

如果提示 `Target directory already exists`，说明当前目录下已经存在同名项目目录。请换一个项目名，或者删除已有目录后再执行。

如果提示缺少 `git`、`cargo-generate`、`pnpm` 这类命令，说明对应工具没有安装，或者安装后还没有重新打开 PowerShell。

Windows 用户可以先执行下面这些命令检查环境：

```powershell
git --version
rustc --version
cargo --version
cargo generate --version
node --version
pnpm --version
```

这些命令都能正常输出版本号后，再执行初始化命令。

执行完成后，会生成：

```text
./my-app
```

## 初始化后先看哪里

生成完成后，先看新项目根目录里的这些内容：

1. `README.md`
2. `AGENTS.md`
3. `temp/REQUIREMENTS/`

生成后的项目使用 Rust manager 管理前后端服务：

```bash
cargo manage --help
cargo manage init-env
cargo manage backend start
cargo manage frontend admin start
```

`cargo manage` 会通过 Cargo 自动编译生成项目里的 `manager/` 工具，不需要使用
`manage.sh` 或 `manage.ps1`。

## 给用户的原则

1. 先让 AI 检查环境
2. 再通过 `temp/REQUIREMENTS/` 或聊天描述业务需求
3. 先确认开发文档，再让 AI 正式开发
