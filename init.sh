#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_OUTPUT_DIR="$(pwd)"

STARTER_REPO_DEFAULT="https://github.com/atlas-orien/atlas-fullstack-starter.git"
STARTER_REF_DEFAULT="main"
BACKEND_SOURCE_DEFAULT="https://github.com/atlas-orien/db-center-template.git"
BACKEND_REF_DEFAULT="main"
FRONTEND_SOURCE_DEFAULT="https://github.com/atlas-orien/react-mono-template.git"
FRONTEND_REF_DEFAULT="main"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "错误：缺少命令 '$1'"
    exit 1
  fi
}

usage() {
  cat <<'EOF'
用法：
  ./init.sh <project-name> [output-dir]

示例：
  ./init.sh my-app
  ./init.sh my-app /Users/ancient/workspace

远程执行示例：
  curl -fsSL https://raw.githubusercontent.com/atlas-orien/atlas-fullstack-starter/main/init.sh | bash -s -- my-app
  curl -fsSL https://raw.githubusercontent.com/atlas-orien/atlas-fullstack-starter/main/init.sh | bash -s -- my-app /Users/ancient/src

可选环境变量：
  STARTER_REPO     脚手架仓库地址，用于远程执行时拉取文档模板
  STARTER_REF      脚手架仓库分支
  BACKEND_SOURCE   后端模板来源，可以是 git 地址或本地目录
  BACKEND_REF      后端分支、标签或提交，仅对 git 地址有效
  FRONTEND_SOURCE  前端模板来源，可以是 git 地址或本地目录
  FRONTEND_REF     前端分支、标签或提交，仅对 git 地址有效
EOF
}

is_git_url() {
  case "$1" in
    http://*|https://*|git@*|ssh://*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

copy_local_dir() {
  local source_dir="$1"
  local target_dir="$2"

  if [ ! -d "$source_dir" ]; then
    echo "错误：本地模板目录不存在：$source_dir"
    exit 1
  fi

  mkdir -p "$target_dir"
  (
    cd "$source_dir" && tar \
      --exclude='.git' \
      --exclude='node_modules' \
      --exclude='target' \
      --exclude='dist' \
      --exclude='.turbo' \
      --exclude='logs' \
      --exclude='tmp' \
      --exclude='.DS_Store' \
      -cf - .
  ) | (
    cd "$target_dir" && tar -xf -
  )
}

copy_git_repo() {
  local repo_url="$1"
  local repo_ref="$2"
  local tmp_dir="$3"
  local target_dir="$4"

  git clone --depth 1 --branch "$repo_ref" "$repo_url" "$tmp_dir" >/dev/null
  mkdir -p "$target_dir"
  (cd "$tmp_dir" && tar --exclude='.git' -cf - .) | (cd "$target_dir" && tar -xf -)
}

generate_backend_with_cargo_generate() {
  local source="$1"
  local ref="$2"
  local destination_dir="$3"

  require_command cargo-generate
  mkdir -p "$(dirname "$destination_dir")"

  if is_git_url "$source"; then
    cargo generate \
      --git "$source" \
      --branch "$ref" \
      --destination "$(dirname "$destination_dir")" \
      --name "$(basename "$destination_dir")" \
      --silent \
      --vcs none
  else
    cargo generate \
      --path "$source" \
      --destination "$(dirname "$destination_dir")" \
      --name "$(basename "$destination_dir")" \
      --silent \
      --vcs none
  fi
}

copy_frontend_template() {
  local source="$1"
  local ref="$2"
  local tmp_dir="$3"
  local target_dir="$4"

  echo "==> 准备前端模板"
  echo "    来源：$source"

  if is_git_url "$source"; then
    echo "    版本：$ref"
    copy_git_repo "$source" "$ref" "$tmp_dir" "$target_dir"
  else
    copy_local_dir "$source" "$target_dir"
  fi
}

resolve_template_source() {
  local starter_repo="$1"
  local starter_ref="$2"
  local starter_tmp_dir="$3"

  if [ -d "$SCRIPT_DIR/project_template" ] && [ -f "$SCRIPT_DIR/project_template/ROOT_README.md.tpl" ]; then
    echo "$SCRIPT_DIR/project_template"
    return 0
  fi

  git clone --depth 1 --branch "$starter_ref" "$starter_repo" "$starter_tmp_dir" >/dev/null
  echo "$starter_tmp_dir/project_template"
}

copy_project_template() {
  local template_source_dir="$1"
  local project_dir="$2"

  if [ ! -d "$template_source_dir" ]; then
    echo "错误：文档模板目录不存在：$template_source_dir"
    exit 1
  fi

  (cd "$template_source_dir" && tar -cf - .) | (cd "$project_dir" && tar -xf -)
}

unify_api_docs() {
  local project_dir="$1"
  local backend_dir="$2"
  local backend_api_dir="$backend_dir/API_CONTRACTS"
  local root_api_dir="$project_dir/API_DOCS"

  if [ ! -d "$backend_api_dir" ]; then
    return 0
  fi

  mkdir -p "$root_api_dir"
  (cd "$backend_api_dir" && tar -cf - .) | (cd "$root_api_dir" && tar -xf -)
  rm -rf "$backend_api_dir"

  find "$backend_dir" -type f -name '*.md' -print0 |
    while IFS= read -r -d '' file; do
      tmp_file="$file.tmp"
      sed \
        -e 's#`API_CONTRACTS/#`../API_DOCS/#g' \
        -e 's#API_CONTRACTS/#../API_DOCS/#g' \
        -e 's#`API_CONTRACTS`#`../API_DOCS`#g' \
        -e 's#API_CONTRACTS#../API_DOCS#g' \
        "$file" > "$tmp_file"
      mv "$tmp_file" "$file"
    done

  find "$root_api_dir" -type f -name '*.md' -print0 |
    while IFS= read -r -d '' file; do
      tmp_file="$file.tmp"
      sed \
        -e 's#`API_CONTRACTS/#`API_DOCS/#g' \
        -e 's#API_CONTRACTS/#API_DOCS/#g' \
        -e 's#`API_CONTRACTS`#`API_DOCS`#g' \
        -e 's#API_CONTRACTS#API_DOCS#g' \
        "$file" > "$tmp_file"
      mv "$tmp_file" "$file"
    done
}

render_root_readme() {
  local project_dir="$1"
  local project_name="$2"

  if [ ! -f "$project_dir/ROOT_README.md.tpl" ]; then
    echo "错误：缺少 ROOT_README.md.tpl 模板"
    exit 1
  fi

  sed \
    -e "s#__PROJECT_NAME__#$project_name#g" \
    -e 's#__MANAGE_ENTRY__#cargo manage#g' \
    -e 's#__MANAGE_DESC__#跨平台管理前后端服务的 Rust CLI#g' \
    -e 's#__MANAGE_CMD__#cargo manage#g' \
    -e 's#__MANAGE_CODE_LANG__#bash#g' \
    "$project_dir/ROOT_README.md.tpl" > "$project_dir/README.md"
  rm -f "$project_dir/ROOT_README.md.tpl"
}

get_file_mode() {
  local file="$1"

  stat -c '%a' "$file" 2>/dev/null || stat -f '%OLp' "$file"
}

render_project_placeholders() {
  local project_dir="$1"
  local project_name="$2"

  find "$project_dir" -type f \
    ! -path "$project_dir/.git/*" \
    ! -path "$project_dir/frontend/node_modules/*" \
    ! -path "$project_dir/backend/target/*" \
    -print0 |
    while IFS= read -r -d '' file; do
      if LC_ALL=C grep -Iq . "$file" && grep -q '__PROJECT_NAME__' "$file"; then
        tmp_file="$file.tmp"
        file_mode="$(get_file_mode "$file")"
        sed -e "s#__PROJECT_NAME__#$project_name#g" "$file" > "$tmp_file"
        mv "$tmp_file" "$file"
        chmod "$file_mode" "$file"
      fi
    done
}

remove_legacy_manage_scripts() {
  local project_dir="$1"

  rm -f "$project_dir/manage.sh"
  rm -f "$project_dir/manage.ps1"
}

write_root_gitignore() {
  local project_dir="$1"

  cat > "$project_dir/.gitignore" <<'EOF'
.DS_Store
.idea/
.vscode/
.claude/
.serena/

output/
temp/
deploy/artifacts/
target/
EOF
}

clean_generated_files() {
  local project_dir="$1"

  find "$project_dir" -name .git -type d -prune -exec rm -rf {} +
  find "$project_dir" -name node_modules -type d -prune -exec rm -rf {} +
  find "$project_dir" -name target -type d -prune -exec rm -rf {} +
  find "$project_dir" -name logs -type d -prune -exec rm -rf {} +
  find "$project_dir" -name dist -type d -prune -exec rm -rf {} +
  find "$project_dir" -name .turbo -type d -prune -exec rm -rf {} +
  find "$project_dir" -name tmp -type d -prune -exec rm -rf {} +
  find "$project_dir" -name .DS_Store -type f -delete
}

PROJECT_NAME="${1:-}"
OUTPUT_DIR="${2:-$DEFAULT_OUTPUT_DIR}"

if [ -z "$PROJECT_NAME" ]; then
  usage
  exit 1
fi

if [[ ! "$PROJECT_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "错误：项目名 '$PROJECT_NAME' 非法。只允许字母、数字、点、下划线和中划线。"
  exit 1
fi

require_command git
require_command tar

STARTER_REPO="${STARTER_REPO:-$STARTER_REPO_DEFAULT}"
STARTER_REF="${STARTER_REF:-$STARTER_REF_DEFAULT}"
BACKEND_SOURCE="${BACKEND_SOURCE:-$BACKEND_SOURCE_DEFAULT}"
BACKEND_REF="${BACKEND_REF:-$BACKEND_REF_DEFAULT}"
FRONTEND_SOURCE="${FRONTEND_SOURCE:-$FRONTEND_SOURCE_DEFAULT}"
FRONTEND_REF="${FRONTEND_REF:-$FRONTEND_REF_DEFAULT}"

TARGET_DIR="$OUTPUT_DIR/$PROJECT_NAME"
BACKEND_DIR="$TARGET_DIR/backend"
FRONTEND_DIR="$TARGET_DIR/frontend"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/atlas-fullstack-starter.XXXXXX")"
TMP_BACKEND_DIR="$TMP_DIR/backend"
TMP_FRONTEND_DIR="$TMP_DIR/frontend"
TMP_STARTER_DIR="$TMP_DIR/starter"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ -e "$TARGET_DIR" ]; then
  echo "错误：目标目录已存在：$TARGET_DIR"
  exit 1
fi

mkdir -p "$OUTPUT_DIR" "$TARGET_DIR"

echo "==> 生成后端模板"
echo "    来源：$BACKEND_SOURCE"
if is_git_url "$BACKEND_SOURCE"; then
  echo "    版本：$BACKEND_REF"
fi
generate_backend_with_cargo_generate "$BACKEND_SOURCE" "$BACKEND_REF" "$BACKEND_DIR"

copy_frontend_template "$FRONTEND_SOURCE" "$FRONTEND_REF" "$TMP_FRONTEND_DIR" "$FRONTEND_DIR"

echo "==> 拉取脚手架文档模板"
TEMPLATE_SOURCE_DIR="$(resolve_template_source "$STARTER_REPO" "$STARTER_REF" "$TMP_STARTER_DIR")"
copy_project_template "$TEMPLATE_SOURCE_DIR" "$TARGET_DIR"

echo "==> 统一 API 文档到根目录"
unify_api_docs "$TARGET_DIR" "$BACKEND_DIR"

echo "==> 渲染根目录 README 和 .gitignore"
render_root_readme "$TARGET_DIR" "$PROJECT_NAME"
render_project_placeholders "$TARGET_DIR" "$PROJECT_NAME"
write_root_gitignore "$TARGET_DIR"
remove_legacy_manage_scripts "$TARGET_DIR"

echo "==> 清理模板残留文件"
clean_generated_files "$TARGET_DIR"

echo "==> 初始化新的 git 仓库"
git -C "$TARGET_DIR" init -b main >/dev/null 2>&1 || {
  git -C "$TARGET_DIR" init >/dev/null
  git -C "$TARGET_DIR" branch -M main >/dev/null 2>&1 || true
}

echo
echo "初始化完成：$TARGET_DIR"
echo "当前项目已经是一个全新的 git 仓库"
echo "模板仓库原本的 .git 目录不会保留到用户项目中"
echo
echo "目录结构："
echo "  $TARGET_DIR/"
echo "  ├── temp/"
echo "  ├── API_DOCS/"
echo "  ├── frontend/"
echo "  ├── backend/"
echo "  ├── deploy/"
echo "  ├── manager/"
echo "  ├── AGENTS.md"
echo "  ├── README.md"
echo "  ├── docker-compose.yml"
echo "  ├── .dockerignore"
echo "  ├── .cargo/"
echo "  ├── AI_PROTOCOLS/"
echo "  └── .gitignore"
