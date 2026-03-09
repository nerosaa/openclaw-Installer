#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="OpenClaw 全平台傻瓜安装器 + 扩展中心"
INSTALL_DIR_DEFAULT="$HOME/.local/share/openclaw"
BIN_DIR_DEFAULT="$HOME/.local/bin"
LAUNCHER_NAME="openclaw"
REPO_URL_DEFAULT="https://github.com/pjasicek/OpenClaw.git"
REPO_DIR_NAME="OpenClaw"

INSTALL_DIR="$INSTALL_DIR_DEFAULT"
BIN_DIR="$BIN_DIR_DEFAULT"
REPO_URL="$REPO_URL_DEFAULT"

OS_TYPE=""
PACKAGE_MANAGER=""
SUDO_CMD=""

get_hub_dir() { printf '%s' "$INSTALL_DIR/hub"; }
get_models_file() { printf '%s' "$(get_hub_dir)/models.db"; }
get_connectors_file() { printf '%s' "$(get_hub_dir)/connectors.db"; }
get_pid_file() { printf '%s' "$(get_hub_dir)/openclaw.pid"; }
get_backup_dir() { printf '%s' "$(get_hub_dir)/backups"; }

print_line() { printf '%s\n' "============================================================"; }
info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
err() { printf '[ERROR] %s\n' "$*" >&2; }
pause() { read -r -p "按回车继续..." _ || true; }

ensure_hub_files() {
  mkdir -p "$(get_hub_dir)" "$(get_backup_dir)" "$INSTALL_DIR/integrations"
  touch "$(get_models_file)" "$(get_connectors_file)"
}

normalize_path() {
  local p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$p" 2>/dev/null || printf '%s' "$p"
  else
    printf '%s' "$p"
  fi
}

detect_os() {
  case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
    linux*) OS_TYPE="linux" ;;
    darwin*) OS_TYPE="macos" ;;
    mingw*|msys*|cygwin*) OS_TYPE="windows" ;;
    *) err "不支持的系统: $(uname -s)"; return 1 ;;
  esac
}

ensure_sudo() {
  if [[ "$OS_TYPE" == "windows" ]] || [[ "${EUID}" -eq 0 ]]; then
    SUDO_CMD=""
  else
    SUDO_CMD="sudo"
  fi
}

detect_package_manager() {
  if [[ "$OS_TYPE" == "linux" ]]; then
    local managers=(apt dnf yum pacman zypper)
    for pm in "${managers[@]}"; do
      command -v "$pm" >/dev/null 2>&1 && { PACKAGE_MANAGER="$pm"; return 0; }
    done
  elif [[ "$OS_TYPE" == "macos" ]]; then
    command -v brew >/dev/null 2>&1 && { PACKAGE_MANAGER="brew"; return 0; }
  else
    command -v winget >/dev/null 2>&1 && { PACKAGE_MANAGER="winget"; return 0; }
    command -v choco >/dev/null 2>&1 && { PACKAGE_MANAGER="choco"; return 0; }
    command -v pacman >/dev/null 2>&1 && { PACKAGE_MANAGER="msys2-pacman"; return 0; }
  fi
  return 1
}

install_system_deps() {
  detect_os
  ensure_sudo
  info "检测到系统: $OS_TYPE"
  info "检测包管理器..."
  detect_package_manager || { err "未找到可用包管理器。"; return 1; }

  info "使用包管理器: $PACKAGE_MANAGER"
  case "$PACKAGE_MANAGER" in
    apt)
      $SUDO_CMD apt update
      $SUDO_CMD apt install -y git cmake build-essential libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libtinyxml2-dev curl
      ;;
    dnf)
      $SUDO_CMD dnf install -y git cmake gcc-c++ make SDL2-devel SDL2_image-devel SDL2_mixer-devel tinyxml2-devel curl
      ;;
    yum)
      $SUDO_CMD yum install -y epel-release || true
      $SUDO_CMD yum install -y git cmake gcc-c++ make SDL2-devel SDL2_image-devel SDL2_mixer-devel tinyxml2-devel curl
      ;;
    pacman)
      $SUDO_CMD pacman -Sy --noconfirm git cmake base-devel sdl2 sdl2_image sdl2_mixer tinyxml2 curl
      ;;
    zypper)
      $SUDO_CMD zypper --non-interactive install git cmake gcc-c++ make libSDL2-devel libSDL2_image-devel libSDL2_mixer-devel tinyxml2-devel curl
      ;;
    brew)
      brew update
      brew install git cmake sdl2 sdl2_image sdl2_mixer tinyxml2 curl
      ;;
    winget)
      winget install -e --id Git.Git || true
      winget install -e --id Kitware.CMake || true
      winget install -e --id MSYS2.MSYS2 || true
      ;;
    choco)
      choco install -y git cmake msys2 || true
      ;;
    msys2-pacman)
      pacman -Sy --noconfirm --needed git cmake make mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-SDL2 mingw-w64-ucrt-x86_64-SDL2_image mingw-w64-ucrt-x86_64-SDL2_mixer mingw-w64-ucrt-x86_64-tinyxml2 curl
      ;;
    *) err "不支持的包管理器: $PACKAGE_MANAGER"; return 1 ;;
  esac
}

clone_or_update_repo() {
  mkdir -p "$INSTALL_DIR"
  local repo_path="$INSTALL_DIR/$REPO_DIR_NAME"
  if [[ -d "$repo_path/.git" ]]; then
    info "检测到已有源码，更新中..."
    git -C "$repo_path" fetch --all --prune
    git -C "$repo_path" reset --hard origin/master || git -C "$repo_path" reset --hard origin/main
  else
    info "下载 OpenClaw 源码..."
    git clone "$REPO_URL" "$repo_path"
  fi
}

find_built_executable() {
  local build_dir="$1"
  local c
  for c in "$build_dir/OpenClaw" "$build_dir/OpenClaw.exe" "$build_dir/src/OpenClaw" "$build_dir/src/OpenClaw.exe"; do
    [[ -f "$c" ]] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

build_openclaw() {
  local repo_path="$INSTALL_DIR/$REPO_DIR_NAME"
  local build_dir="$repo_path/build"
  local exe_path=""

  [[ -d "$repo_path" ]] || { err "源码目录不存在: $repo_path"; return 1; }
  mkdir -p "$build_dir"

  info "配置 CMake..."
  cmake -S "$repo_path" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release
  info "开始编译（请稍候）..."
  cmake --build "$build_dir" -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 2)"

  exe_path="$(find_built_executable "$build_dir" || true)"
  [[ -n "$exe_path" ]] || { err "未找到编译产物（OpenClaw/OpenClaw.exe）。"; return 1; }

  mkdir -p "$BIN_DIR"
  cat > "$BIN_DIR/$LAUNCHER_NAME" <<LAUNCHER
#!/usr/bin/env bash
exec "$(normalize_path "$exe_path")" "\$@"
LAUNCHER
  chmod +x "$BIN_DIR/$LAUNCHER_NAME"
  info "启动器已创建: $BIN_DIR/$LAUNCHER_NAME"
}

one_click_install() {
  print_line
  info "开始一键安装 OpenClaw"
  install_system_deps
  clone_or_update_repo
  build_openclaw
  ensure_hub_files
  info "安装完成，可运行: $LAUNCHER_NAME"
  print_line
}

check_item() {
  local name="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then printf '  [OK] %s\n' "$name"; else printf '  [FAIL] %s\n' "$name"; return 1; fi
}

auto_repair() {
  print_line
  info "启动自动修复..."
  local repo_path="$INSTALL_DIR/$REPO_DIR_NAME"
  local build_dir="$repo_path/build"
  local need_rebuild=0

  check_item "git 可用" "command -v git" || install_system_deps
  check_item "cmake 可用" "command -v cmake" || install_system_deps

  if [[ ! -d "$repo_path/.git" ]]; then
    warn "源码缺失，重新拉取..."
    clone_or_update_repo
    need_rebuild=1
  elif ! git -C "$repo_path" fsck --full >/dev/null 2>&1; then
    warn "仓库异常，重新同步..."
    clone_or_update_repo
    need_rebuild=1
  fi

  if ! find_built_executable "$build_dir" >/dev/null 2>&1; then
    need_rebuild=1
  fi
  [[ "$need_rebuild" -eq 1 ]] && build_openclaw || build_openclaw

  ensure_hub_files
  info "自动修复完成。"
  print_line
}

update_openclaw() { print_line; info "更新 OpenClaw..."; clone_or_update_repo; build_openclaw; print_line; }

uninstall_openclaw() {
  print_line
  read -r -p "确认卸载 OpenClaw 吗？(y/N): " ans
  [[ "${ans,,}" == "y" ]] || { info "已取消卸载。"; return 0; }
  rm -rf "$INSTALL_DIR/$REPO_DIR_NAME" "$INSTALL_DIR/integrations" "$(get_hub_dir)"
  rm -f "$BIN_DIR/$LAUNCHER_NAME"
  info "已卸载。"
}

health_check() {
  print_line
  info "系统健康检查..."
  check_item "系统识别" "detect_os"
  check_item "git" "command -v git"
  check_item "cmake" "command -v cmake"
  check_item "curl" "command -v curl"
  check_item "安装目录可写" "mkdir -p '$INSTALL_DIR'"
  check_item "启动目录可写" "mkdir -p '$BIN_DIR'"
  check_item "网络连通 github" "curl -I --max-time 8 https://github.com >/dev/null"
  print_line
}

write_connector_template() {
  local name="$1"
  local cfg="$INSTALL_DIR/integrations/${name}.env"
  cat > "$cfg" <<CFG
# ${name} 接入模板（填写后按你的桥接程序读取）
ENABLED=1
NAME=${name}
WEBHOOK_URL=
BOT_TOKEN=
APP_ID=
APP_SECRET=
EXTRA=
CFG
  info "已生成模板: $cfg"
}

connector_add() {
  ensure_hub_files
  echo "可选聊天软件: telegram discord slack feishu wecom dingtalk qq wechat"
  read -r -p "输入接入名称: " name
  [[ -n "$name" ]] || { warn "名称不能为空"; return 1; }
  write_connector_template "$name"
  printf '%s|enabled|%s\n' "$name" "$(date +%F_%T)" >> "$(get_connectors_file)"
  info "已登记聊天软件接入: $name"
}

connector_list() {
  ensure_hub_files
  print_line
  if [[ ! -s "$(get_connectors_file)" ]]; then
    echo "暂无聊天软件接入记录"
  else
    awk -F'|' '{printf "- %s (%s, %s)\n",$1,$2,$3}' "$(get_connectors_file)"
  fi
  print_line
}

model_add() {
  ensure_hub_files
  echo "1) 第三方API模型  2) 自定义本地模型"
  read -r -p "请选择 [1-2]: " t
  read -r -p "模型别名: " alias
  [[ -n "$alias" ]] || { warn "别名不能为空"; return 1; }

  if [[ "$t" == "1" ]]; then
    read -r -p "提供商(如 openai/anthropic/gemini/openrouter): " provider
    read -r -p "API Base URL: " base_url
    read -r -p "模型ID: " model_id
    read -r -p "API Key(可留空后续再填): " api_key
    printf '%s|third_party|%s|%s|%s|%s|active|%s\n' "$alias" "$provider" "$base_url" "$model_id" "$api_key" "$(date +%F_%T)" >> "$(get_models_file)"
  else
    read -r -p "运行时(ollama/vllm/lmstudio/other): " runtime
    read -r -p "本地端点(如 http://127.0.0.1:11434): " endpoint
    read -r -p "模型名: " model_id
    printf '%s|custom|%s|%s|%s|-|active|%s\n' "$alias" "$runtime" "$endpoint" "$model_id" "$(date +%F_%T)" >> "$(get_models_file)"
  fi

  info "模型已添加: $alias"
}

model_list() {
  ensure_hub_files
  print_line
  if [[ ! -s "$(get_models_file)" ]]; then
    echo "暂无模型"
  else
    awk -F'|' '{printf "- %s [%s] provider/runtime=%s endpoint=%s model=%s status=%s\n",$1,$2,$3,$4,$5,$7}' "$(get_models_file)"
  fi
  print_line
}

model_mark_old() {
  ensure_hub_files
  read -r -p "输入要标记为旧模型的别名: " alias
  [[ -n "$alias" ]] || return 1
  awk -F'|' -v a="$alias" 'BEGIN{OFS="|"} {if($1==a){$7="old"} print $0}' "$(get_models_file)" > "$(get_models_file).tmp"
  mv "$(get_models_file).tmp" "$(get_models_file)"
  info "已标记旧模型: $alias"
}

model_clear_old() {
  ensure_hub_files
  read -r -p "确认清除所有旧模型(status=old)吗？(y/N): " ans
  [[ "${ans,,}" == "y" ]] || { info "已取消。"; return 0; }
  awk -F'|' '$7!="old"' "$(get_models_file)" > "$(get_models_file).tmp"
  mv "$(get_models_file).tmp" "$(get_models_file)"
  info "已清除旧模型。"
}

one_click_restart() {
  ensure_hub_files
  local launcher="$BIN_DIR/$LAUNCHER_NAME"
  [[ -x "$launcher" ]] || { err "未找到启动器: $launcher"; return 1; }

  if [[ -f "$(get_pid_file)" ]]; then
    local old_pid
    old_pid="$(cat "$(get_pid_file)")"
    if kill -0 "$old_pid" >/dev/null 2>&1; then
      info "停止旧进程 PID=$old_pid"
      kill "$old_pid" || true
      sleep 1
    fi
  fi

  info "后台启动 OpenClaw..."
  nohup "$launcher" >/dev/null 2>&1 &
  echo "$!" > "$(get_pid_file)"
  info "重启完成，新 PID=$(cat "$(get_pid_file)")"
}

backup_hub() {
  ensure_hub_files
  local target="$(get_backup_dir)/hub-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
  tar -czf "$target" -C "$INSTALL_DIR" hub integrations 2>/dev/null || tar -czf "$target" -C "$INSTALL_DIR" hub
  info "备份完成: $target"
}

restore_hub() {
  ensure_hub_files
  local latest
  latest="$(ls -1t "$(get_backup_dir)"/*.tar.gz 2>/dev/null | head -n 1 || true)"
  [[ -n "$latest" ]] || { warn "没有可恢复备份。"; return 1; }
  tar -xzf "$latest" -C "$INSTALL_DIR"
  info "已恢复最新备份: $latest"
}

show_config() {
  print_line
  echo "当前配置："
  echo "  安装目录 : $INSTALL_DIR"
  echo "  启动目录 : $BIN_DIR"
  echo "  仓库地址 : $REPO_URL"
  print_line
}

configure_paths() {
  show_config
  read -r -p "新的安装目录(留空保持): " new_install
  read -r -p "新的启动目录(留空保持): " new_bin
  read -r -p "新的仓库地址(留空保持): " new_repo
  [[ -n "$new_install" ]] && INSTALL_DIR="$new_install"
  [[ -n "$new_bin" ]] && BIN_DIR="$new_bin"
  [[ -n "$new_repo" ]] && REPO_URL="$new_repo"
  ensure_hub_files
}

run_auto_install() {
  info "自动模式：开始下载 + 安装 OpenClaw（无人值守）..."
  one_click_install
  info "自动模式安装完成。"
}

show_menu() {
  clear || true
  print_line
  echo " $SCRIPT_NAME"
  print_line
  echo " 1) 一键安装 OpenClaw"
  echo " 2) 自动修复"
  echo " 3) 更新 OpenClaw"
  echo " 4) 卸载"
  echo " 5) 高级设置（路径/仓库）"
  echo " 6) 仅安装系统依赖"
  echo " 7) 聊天软件接入（新增模板）"
  echo " 8) 查看聊天软件接入列表"
  echo " 9) 新增模型（第三方API/自定义）"
  echo "10) 查看模型列表"
  echo "11) 标记旧模型"
  echo "12) 清除旧模型"
  echo "13) 一键重启 OpenClaw"
  echo "14) 系统健康检查"
  echo "15) 备份扩展配置"
  echo "16) 恢复扩展配置"
  echo " 0) 退出"
  print_line
}

main() {
  detect_os
  ensure_hub_files
  info "检测到系统: $OS_TYPE"

  if [[ "${1:-}" == "--auto-install" ]]; then
    run_auto_install
    exit 0
  fi

  while true; do
    show_menu
    read -r -p "请选择 [0-16]: " choice
    case "$choice" in
      1) one_click_install; pause ;;
      2) auto_repair; pause ;;
      3) update_openclaw; pause ;;
      4) uninstall_openclaw; pause ;;
      5) configure_paths; pause ;;
      6) install_system_deps; pause ;;
      7) connector_add; pause ;;
      8) connector_list; pause ;;
      9) model_add; pause ;;
      10) model_list; pause ;;
      11) model_mark_old; pause ;;
      12) model_clear_old; pause ;;
      13) one_click_restart; pause ;;
      14) health_check; pause ;;
      15) backup_hub; pause ;;
      16) restore_hub; pause ;;
      0) info "已退出。"; exit 0 ;;
      *) warn "无效选项，请重试。"; pause ;;
    esac
  done
}

main "$@"
