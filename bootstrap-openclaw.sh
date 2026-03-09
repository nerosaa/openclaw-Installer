#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
err() { printf '[ERROR] %s\n' "$*" >&2; }

detect_os() {
  case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
    linux*) echo "linux" ;;
    darwin*) echo "macos" ;;
    mingw*|msys*|cygwin*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

ensure_sudo() {
  if [[ "${EUID}" -eq 0 ]]; then
    echo ""
  else
    echo "sudo"
  fi
}

install_node_linux() {
  local sudo_cmd="$1"
  if command -v apt >/dev/null 2>&1; then
    $sudo_cmd apt update
    $sudo_cmd apt install -y nodejs npm
  elif command -v dnf >/dev/null 2>&1; then
    $sudo_cmd dnf install -y nodejs npm
  elif command -v yum >/dev/null 2>&1; then
    $sudo_cmd yum install -y nodejs npm
  elif command -v pacman >/dev/null 2>&1; then
    $sudo_cmd pacman -Sy --noconfirm nodejs npm
  elif command -v zypper >/dev/null 2>&1; then
    $sudo_cmd zypper --non-interactive install nodejs npm
  else
    err "未找到受支持的 Linux 包管理器（apt/dnf/yum/pacman/zypper）。"
    return 1
  fi
}

install_node_macos() {
  if command -v brew >/dev/null 2>&1; then
    brew update
    brew install node
  else
    err "未检测到 Homebrew，无法自动安装 Node.js。请先安装 brew 后重试。"
    return 1
  fi
}

install_node_windows() {
  if command -v winget >/dev/null 2>&1; then
    winget install -e --id OpenJS.NodeJS.LTS
  elif command -v choco >/dev/null 2>&1; then
    choco install -y nodejs-lts
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm --needed nodejs npm
  else
    err "未检测到 winget/choco/msys2 pacman，无法自动安装 Node.js。"
    return 1
  fi
}

ensure_node() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    info "已检测到 Node.js: $(node -v), npm: $(npm -v)"
    return 0
  fi

  warn "未检测到 Node.js / npm，开始自动安装..."

  local os
  os="$(detect_os)"
  local sudo_cmd
  sudo_cmd="$(ensure_sudo)"

  info "开始自动安装 Node.js（系统: $os）..."
  case "$os" in
    linux) install_node_linux "$sudo_cmd" ;;
    macos) install_node_macos ;;
    windows) install_node_windows ;;
    *) err "不支持的系统，无法自动安装 Node.js。"; return 1 ;;
  esac

  command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 || {
    err "Node.js 安装后仍不可用，请重开终端后重试。"
    return 1
  }
  info "Node.js 安装成功: $(node -v), npm: $(npm -v)"
}

main() {
  ensure_node
  info "启动 OpenClaw 自动安装流程..."
  cd "$ROOT_DIR"
  if [[ "${1:-}" == "--menu" ]]; then
    npm start
  else
    npm start -- --auto-install
  fi
}

main "$@"
