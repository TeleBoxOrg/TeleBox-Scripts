#!/usr/bin/env bash
# TeleBox 本机一键安装 / 管理脚本
# 仓库: https://github.com/TeleBoxOrg/TeleBox-Scripts
# Coding by Telegram @awaEmpty

set -o pipefail

# ── 颜色 ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[信息]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[完成]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[注意]${NC} $1"; }
log_error()   { echo -e "${RED}[错误]${NC} $1"; }
log_step()    { echo -e "\n${CYAN}${BOLD}▶ $1${NC}"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# 读入：优先 /dev/tty，避免管道/wget 时无交互
ask() {
  local prompt="$1"
  local reply
  if [ -r /dev/tty ]; then
    read -r -p "$prompt" reply </dev/tty || true
  else
    read -r -p "$prompt" reply || true
  fi
  printf '%s' "$reply"
}

ask_yn() {
  # 默认 Yes；传入第二参数 default=n 则默认 No
  local prompt="$1"
  local def="${2:-y}"
  local hint="[Y/n]"
  [[ "$def" == "n" ]] && hint="[y/N]"
  local reply
  reply="$(ask "$prompt $hint ")"
  reply="${reply:-$def}"
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ── 全局：版本选择结果 ────────────────────────────────
EDITION=""          # classic | next
BRAND=""            # TeleBox | TeleBox-Next
REPO_URL=""
DEFAULT_DIR=""
PM2_NAME=""
SHORT_LABEL=""

# ── root / sudo ───────────────────────────────────────
need_root_cmd() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command_exists sudo; then
    sudo "$@"
  else
    log_error "需要 root 权限执行: $*"
    log_error "请用 root 运行本脚本，或先安装 sudo。"
    return 1
  fi
}

# ── 版本选择 ──────────────────────────────────────────
show_edition_help() {
  echo ""
  echo -e "${BOLD}请选择要安装的版本：${NC}"
  echo ""
  echo -e "  ${GREEN}1) Classic（推荐新手）${NC}  — 仓库 TeleBox"
  echo "     · 更成熟、资料多、社区插件最全"
  echo "     · Telegram 库：Teleproto"
  echo "     · 默认目录：~/telebox    进程名：telebox"
  echo ""
  echo -e "  ${CYAN}2) Next${NC}                 — 仓库 TeleBox-Next"
  echo "     · 下一代实现，原生异步架构"
  echo "     · Telegram API：mtcute"
  echo "     · 默认目录：~/telebox-next  进程名：telebox-next"
  echo ""
  echo "  两个版本功能大体一致（插件管理、热重载、权限等）。"
  echo "  装好后可用 .switch go 在 Classic ↔ Next 之间切换（会转换会话）。"
  echo "  拿不准就选 1。"
  echo ""
}

apply_edition() {
  case "$1" in
    classic|1)
      EDITION="classic"
      BRAND="TeleBox"
      REPO_URL="https://github.com/TeleBoxOrg/TeleBox.git"
      DEFAULT_DIR="${HOME}/telebox"
      PM2_NAME="telebox"
      SHORT_LABEL="Classic"
      ;;
    next|2)
      EDITION="next"
      BRAND="TeleBox-Next"
      REPO_URL="https://github.com/TeleBoxOrg/TeleBox-Next.git"
      DEFAULT_DIR="${HOME}/telebox-next"
      PM2_NAME="telebox-next"
      SHORT_LABEL="Next"
      ;;
    *)
      return 1
      ;;
  esac
}

choose_edition() {
  # 环境变量 TELEBOX_EDITION=classic|next 可跳过交互
  if [ -n "${TELEBOX_EDITION:-}" ]; then
    if apply_edition "$TELEBOX_EDITION"; then
      log_ok "已按环境变量选择：${BRAND}（${SHORT_LABEL}）"
      return 0
    fi
    log_warn "TELEBOX_EDITION=$TELEBOX_EDITION 无效，改为手动选择"
  fi

  show_edition_help
  while true; do
    local choice
    choice="$(ask "请输入 1 或 2 [默认 1]: ")"
    choice="${choice:-1}"
    if apply_edition "$choice"; then
      log_ok "已选择：${BRAND}（${SHORT_LABEL}）"
      return 0
    fi
    log_error "无效输入，请输入 1（Classic）或 2（Next）"
  done
}

# ── 系统检测 ──────────────────────────────────────────
PKG_MANAGER=""

detect_system() {
  log_step "检测系统环境"

  local os_name="unknown" os_ver=""
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    os_name="${NAME:-$ID}"
    os_ver="${VERSION_ID:-}"
  fi
  log_info "系统: ${os_name} ${os_ver}"
  log_info "架构: $(uname -m)"

  if command_exists apt-get; then
    PKG_MANAGER="apt"
  elif command_exists dnf; then
    PKG_MANAGER="dnf"
  elif command_exists yum; then
    PKG_MANAGER="yum"
  elif command_exists apk; then
    PKG_MANAGER="apk"
  else
    log_error "未识别到 apt / dnf / yum / apk。"
    log_error "请先手动安装：curl git 编译工具链 Node.js 24.x，再运行本脚本。"
    exit 1
  fi
  log_ok "包管理器: $PKG_MANAGER"
}

# ── 系统依赖 ──────────────────────────────────────────
install_system_deps() {
  log_step "安装系统依赖（git / curl / 编译工具）"

  # 更新索引（失败不致命）
  if [ "$PKG_MANAGER" = "apt" ]; then
    need_root_cmd apt-get update -y || log_warn "apt update 失败，继续尝试安装…"
  elif [ "$PKG_MANAGER" = "apk" ]; then
    need_root_cmd apk update || true
  fi

  case "$PKG_MANAGER" in
    apt)
      need_root_cmd apt-get install -y curl git ca-certificates build-essential python3 make g++ \
        || { log_error "系统依赖安装失败"; exit 1; }
      # screen 可选：用于 SSH 断线时保住登录界面
      need_root_cmd apt-get install -y screen 2>/dev/null || true
      ;;
    dnf|yum)
      need_root_cmd "$PKG_MANAGER" install -y curl git ca-certificates gcc-c++ make python3 \
        || { log_error "系统依赖安装失败"; exit 1; }
      need_root_cmd "$PKG_MANAGER" install -y screen 2>/dev/null || true
      ;;
    apk)
      need_root_cmd apk add --no-cache curl git ca-certificates build-base python3 \
        || { log_error "系统依赖安装失败"; exit 1; }
      need_root_cmd apk add --no-cache screen 2>/dev/null || true
      ;;
  esac
  log_ok "系统依赖就绪"
}

# ── Node.js 24 ────────────────────────────────────────
node_major() {
  node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0
}

install_nodejs() {
  log_step "检查 / 安装 Node.js 24.x"

  if command_exists node; then
    local major
    major="$(node_major)"
    if [ "$major" -ge 24 ] 2>/dev/null; then
      log_ok "已有 Node.js $(node -v)（符合要求）"
      return 0
    fi
    log_warn "当前 Node.js $(node -v)，需要 24.x，将尝试升级"
  fi

  case "$PKG_MANAGER" in
    apt)
      if curl -fsSL https://deb.nodesource.com/setup_24.x | need_root_cmd bash - \
        && need_root_cmd apt-get install -y nodejs; then
        :
      else
        log_error "NodeSource 安装失败"
        log_error "请手动安装 Node.js 24：https://nodejs.org/ 或 https://github.com/nodesource/distributions"
        exit 1
      fi
      ;;
    dnf|yum)
      if curl -fsSL https://rpm.nodesource.com/setup_24.x | need_root_cmd bash - \
        && need_root_cmd "$PKG_MANAGER" install -y nodejs; then
        :
      else
        log_error "NodeSource(RPM) 安装失败，请手动安装 Node.js 24"
        exit 1
      fi
      ;;
    apk)
      # Alpine 官方仓库版本可能落后，尽量装最新
      need_root_cmd apk add --no-cache nodejs npm \
        || { log_error "Alpine 安装 nodejs 失败"; exit 1; }
      local major
      major="$(node_major)"
      if [ "$major" -lt 24 ] 2>/dev/null; then
        log_warn "Alpine 仓库 Node $(node -v) 可能 < 24，若启动失败请换 Debian/Ubuntu 或自行升级 Node"
      fi
      ;;
  esac

  if ! command_exists node; then
    log_error "Node.js 仍不可用"
    exit 1
  fi
  log_ok "Node.js $(node -v) · npm $(npm -v 2>/dev/null || echo '?')"
}

# ── 克隆 ──────────────────────────────────────────────
clone_project() {
  local install_dir="$1"
  log_step "下载 ${BRAND}"

  if [ -d "$install_dir/.git" ]; then
    log_warn "目录已存在: $install_dir"
    if ask_yn "是否删除后重新下载？" "n"; then
      rm -rf "$install_dir" || { log_error "无法删除 $install_dir"; exit 1; }
    else
      log_info "保留现有目录，跳过克隆"
      cd "$install_dir" || exit 1
      return 0
    fi
  elif [ -d "$install_dir" ]; then
    log_warn "目录存在但不是 git 仓库: $install_dir"
    if ask_yn "是否删除后重新下载？" "n"; then
      rm -rf "$install_dir" || exit 1
    else
      cd "$install_dir" || exit 1
      return 0
    fi
  fi

  log_info "克隆 $REPO_URL"
  if ! git clone --depth 1 "$REPO_URL" "$install_dir"; then
    log_error "下载失败。请检查网络是否能访问 GitHub。"
    log_error "可尝试代理，或手动: git clone $REPO_URL $install_dir"
    exit 1
  fi
  cd "$install_dir" || exit 1
  log_ok "${BRAND} 已下载到 $install_dir"
}

# ── npm install ───────────────────────────────────────
install_project_deps() {
  log_step "安装项目依赖（可能需要几分钟）"
  if [ ! -f package.json ]; then
    log_error "当前目录没有 package.json，路径不对？"
    exit 1
  fi
  # 原生模块编译失败时给提示
  if ! npm install; then
    log_error "npm install 失败"
    log_error "常见原因：缺编译工具、Node 版本不对、磁盘满、网络超时"
    log_error "可重试: cd 项目目录 && npm install"
    exit 1
  fi
  log_ok "依赖安装完成"
}

# ── 登录 ──────────────────────────────────────────────
print_login_tips() {
  echo ""
  echo -e "${BOLD}即将进入 ${BRAND} 官方登录流程${NC}"
  echo "  1. 准备好 api_id / api_hash"
  echo "     · 申请: https://my.telegram.org/auth?to=apps"
  echo "     · 或备用: https://t.me/TeleBox_API"
  echo "  2. 选择 二维码登录 或 手机号登录"
  echo "  3. 手机号登录时按提示输入验证码；若开了两步验证再输密码"
  echo "  4. 登录成功看到运行日志后，按 ${BOLD}Ctrl+C${NC} 结束前台进程即可"
  echo "     （会话会保存，之后用 PM2 后台跑）"
  echo ""
}

run_login_foreground() {
  local install_dir="$1"
  cd "$install_dir" || return 1
  print_login_tips
  ask "准备好后按 Enter 开始登录… " >/dev/null
  echo ""
  # 不 set -e：用户 Ctrl+C 属正常
  npm start || true
  echo ""
  if ask_yn "登录是否已完成？" "y"; then
    log_ok "登录流程结束"
  else
    log_warn "若未完成，可稍后: cd $install_dir && npm start"
  fi
}

run_login_screen() {
  local install_dir="$1"
  local session="telebox-login-$$"

  if ! command_exists screen; then
    log_warn "未安装 screen，改用前台登录"
    run_login_foreground "$install_dir"
    return
  fi

  cd "$install_dir" || return 1
  print_login_tips
  echo "将使用 screen 会话（SSH 断开也不容易丢登录界面）"
  echo "  离开会话：Ctrl+A 再按 D"
  echo "  回到会话：screen -r $session"
  echo ""
  ask "准备好后按 Enter 开始… " >/dev/null

  screen -S "$session" -X quit >/dev/null 2>&1 || true
  screen -dmS "$session" bash -lc "cd $(printf %q "$install_dir") && npm start; echo; echo '进程已结束，按 Enter 关闭…'; read"
  sleep 1
  if ! screen -list 2>/dev/null | grep -q "$session"; then
    log_warn "screen 启动失败，改用前台"
    run_login_foreground "$install_dir"
    return
  fi
  screen -r "$session" || true
  screen -S "$session" -X quit >/dev/null 2>&1 || true

  if ask_yn "登录是否已完成？" "y"; then
    log_ok "登录流程结束"
  else
    log_warn "若未完成，可稍后: cd $install_dir && npm start"
  fi
}

first_time_setup() {
  local install_dir="$1"
  log_step "首次登录配置"
  if command_exists screen; then
    if ask_yn "是否用 screen 保护登录界面？（推荐 SSH 用户）" "y"; then
      run_login_screen "$install_dir"
      return
    fi
  fi
  run_login_foreground "$install_dir"
}

# ── PM2 ───────────────────────────────────────────────
install_pm2() {
  log_step "安装 PM2"
  if command_exists pm2; then
    log_ok "PM2 已存在: $(pm2 -v 2>/dev/null || true)"
  else
    if ! need_root_cmd npm install -g pm2; then
      # 无 root 时尝试用户级
      log_warn "全局安装失败，尝试用户目录 npm prefix…"
      mkdir -p "$HOME/.local"
      npm config set prefix "$HOME/.local"
      export PATH="$HOME/.local/bin:$PATH"
      npm install -g pm2 || { log_error "PM2 安装失败"; return 1; }
    fi
  fi
  pm2 install pm2-logrotate >/dev/null 2>&1 || true
  return 0
}

setup_pm2_service() {
  local install_dir="$1"
  log_step "用 PM2 后台启动 ${BRAND}"
  cd "$install_dir" || return 1
  pm2 delete "$PM2_NAME" >/dev/null 2>&1 || true
  if ! pm2 start "npm start" --name "$PM2_NAME" --cwd "$install_dir"; then
    # 兼容旧 pm2：无 --cwd 时 cd 后启动
    cd "$install_dir" && pm2 start "npm start" --name "$PM2_NAME" || {
      log_error "PM2 启动失败"
      return 1
    }
  fi
  pm2 save || true

  # 开机自启（尽力而为）
  if [ "$(id -u)" -eq 0 ]; then
    pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || pm2 startup >/dev/null 2>&1 || true
  else
    log_info "若需开机自启，请用 root 执行: pm2 startup"
    local line
    line="$(pm2 startup 2>/dev/null | tail -n 1 || true)"
    if [[ "$line" == sudo* ]] || [[ "$line" == env* ]]; then
      log_info "建议执行: $line"
    fi
  fi
  log_ok "PM2 进程名: $PM2_NAME"
}

prompt_pm2_setup() {
  local install_dir="$1"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${BOLD}建议开启 PM2 后台运行${NC}"
  echo "  · 关掉终端 / 断开 SSH 后，${BRAND} 仍会继续跑"
  echo "  · 方便查看日志、重启"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if ! ask_yn "现在启用 PM2？" "y"; then
    log_info "已跳过。之后可手动："
    echo "  npm install -g pm2"
    echo "  cd $install_dir && pm2 start \"npm start\" --name $PM2_NAME && pm2 save"
    return 1
  fi
  install_pm2 || return 1
  setup_pm2_service "$install_dir" || return 1
  return 0
}

show_usage() {
  local install_dir="$1"
  local pm2_enabled="${2:-false}"

  echo ""
  echo -e "${GREEN}${BOLD}🎉 ${BRAND} 安装完成${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  版本:   ${SHORT_LABEL}（$EDITION）"
  echo "  目录:   $install_dir"
  echo "  仓库:   $REPO_URL"
  echo ""
  if [[ "$pm2_enabled" == "true" ]]; then
    echo "  状态:   PM2 后台运行中（$PM2_NAME）"
    echo ""
    echo "  常用命令:"
    echo "    pm2 status"
    echo "    pm2 logs $PM2_NAME"
    echo "    pm2 restart $PM2_NAME"
    echo "    pm2 stop $PM2_NAME"
  else
    echo "  状态:   未启用 PM2（不会后台常驻）"
    echo ""
    echo "  前台启动:"
    echo "    cd $install_dir && npm start"
  fi
  echo ""
  echo "  装好后在 Telegram 给自己发: .help"
  echo "  插件: .tpm search  /  .tpm i <名字>"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# ── 会话清理（重新登录） ──────────────────────────────
clear_session_files() {
  local install_dir="$1"
  # Classic: config.json 内 session；Next: assets 下 sqlite 等
  local paths=(
    "$install_dir/config.json"
    "$install_dir/assets/session.db"
    "$install_dir/assets/session.db-wal"
    "$install_dir/assets/session.db-shm"
    "$install_dir/my_session"
    "$install_dir/session"
    "$install_dir/session.json"
  )
  local p
  for p in "${paths[@]}"; do
    if [ -e "$p" ]; then
      # config.json 只清 session 字段太复杂，整文件备份后删由用户重登重建
      if [[ "$(basename "$p")" == "config.json" ]]; then
        cp -a "$p" "${p}.bak.$(date +%s)" 2>/dev/null || true
        rm -f "$p"
        log_info "已备份并移除 config.json（将重新填写 API）"
      else
        rm -rf "$p"
        log_info "已删除: $p"
      fi
    fi
  done
  # 残留 *.session
  find "$install_dir" -maxdepth 1 -name '*.session' -exec rm -f {} \; 2>/dev/null || true
}

relogin() {
  local install_dir="${1:-$DEFAULT_DIR}"
  if [ ! -d "$install_dir" ]; then
    log_error "目录不存在: $install_dir"
    return 1
  fi
  # 尝试从目录/remote 推断 edition
  detect_edition_from_dir "$install_dir" || choose_edition

  log_warn "重新登录会清除本机会话，需要重新扫码/收验证码"
  if ! ask_yn "确定继续？" "n"; then
    return 0
  fi

  if command_exists pm2; then
    pm2 stop "$PM2_NAME" >/dev/null 2>&1 || true
  fi
  clear_session_files "$install_dir"
  first_time_setup "$install_dir"
  if command_exists pm2 && pm2 describe "$PM2_NAME" >/dev/null 2>&1; then
    pm2 start "$PM2_NAME" >/dev/null 2>&1 || pm2 restart "$PM2_NAME" || true
  fi
  log_ok "重新登录流程结束"
}

detect_edition_from_dir() {
  local install_dir="$1"
  [ -d "$install_dir" ] || return 1
  local url=""
  if [ -d "$install_dir/.git" ]; then
    url="$(git -C "$install_dir" remote get-url origin 2>/dev/null || true)"
  fi
  if echo "$url" | grep -qi 'TeleBox-Next'; then
    apply_edition next
    return 0
  fi
  if echo "$url" | grep -qi 'TeleBox'; then
    apply_edition classic
    return 0
  fi
  # 目录名启发
  case "$(basename "$install_dir")" in
    *next*|*Next*) apply_edition next; return 0 ;;
    telebox) apply_edition classic; return 0 ;;
  esac
  return 1
}

# ── 卸载 ──────────────────────────────────────────────
uninstall_telebox() {
  local install_dir="${1:-}"
  if [ -z "$install_dir" ]; then
    choose_edition
    install_dir="$DEFAULT_DIR"
  else
    detect_edition_from_dir "$install_dir" || true
    [ -n "$PM2_NAME" ] || apply_edition classic
  fi

  log_warn "将卸载: $install_dir （进程: ${PM2_NAME:-telebox}）"
  if ! ask_yn "确定删除？" "n"; then
    return 0
  fi
  if command_exists pm2 && [ -n "$PM2_NAME" ]; then
    pm2 delete "$PM2_NAME" >/dev/null 2>&1 || true
    pm2 save >/dev/null 2>&1 || true
  fi
  if [ -d "$install_dir" ]; then
    rm -rf "$install_dir" && log_ok "已删除 $install_dir" || log_error "删除失败"
  else
    log_info "目录不存在，无需删除"
  fi
}

# ── 主安装 ────────────────────────────────────────────
welcome() {
  clear 2>/dev/null || true
  echo -e "${BLUE}"
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║           TeleBox 本机一键安装脚本                       ║"
  echo "║     Classic / Next 可选 · 面向新手 · 少踩坑              ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo "流程：选版本 → 装依赖 → 下载 → npm install → 登录 →（可选）PM2"
  echo ""
}

main_installation() {
  local install_dir="${1:-}"
  local pm2_enabled="false"

  welcome
  choose_edition
  install_dir="${install_dir:-$DEFAULT_DIR}"

  log_info "将安装 ${BRAND} 到: $install_dir"
  if ! ask_yn "确认开始？" "y"; then
    log_info "已取消"
    return 0
  fi

  detect_system
  install_system_deps
  install_nodejs
  clone_project "$install_dir"
  install_project_deps

  if ask_yn "现在进行 Telegram 登录配置？" "y"; then
    first_time_setup "$install_dir"
  else
    log_info "跳过登录。稍后: cd $install_dir && npm start"
  fi

  if prompt_pm2_setup "$install_dir"; then
    pm2_enabled="true"
  fi
  show_usage "$install_dir" "$pm2_enabled"
}

# ── 菜单 ──────────────────────────────────────────────
show_menu() {
  echo -e "${BLUE}"
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║              TeleBox 本机管理菜单                        ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo "  1) 安装（可选 Classic / Next）"
  echo "  2) 卸载"
  echo "  3) 重新安装"
  echo "  4) 重新登录"
  echo "  5) 启动（PM2）"
  echo "  6) 停止（PM2）"
  echo "  7) 状态（PM2）"
  echo "  8) 日志（PM2）"
  echo "  9) 退出"
  echo ""
}

resolve_pm2_target() {
  # 已选 edition 用对应名；否则看哪个在跑
  if [ -n "$PM2_NAME" ]; then
    echo "$PM2_NAME"
    return
  fi
  if command_exists pm2; then
    if pm2 describe telebox-next >/dev/null 2>&1; then
      echo "telebox-next"; return
    fi
    if pm2 describe telebox >/dev/null 2>&1; then
      echo "telebox"; return
    fi
  fi
  echo "telebox"
}

main() {
  trap 'echo; log_warn "已中断"; exit 130' INT

  case "${1:-}" in
    install)
      # install [classic|next] [dir]
      if [ -n "${2:-}" ] && apply_edition "$2" 2>/dev/null; then
        main_installation "${3:-$DEFAULT_DIR}"
      else
        main_installation "${2:-}"
      fi
      ;;
    uninstall)
      if [ -n "${2:-}" ] && apply_edition "$2" 2>/dev/null; then
        uninstall_telebox "${3:-$DEFAULT_DIR}"
      else
        uninstall_telebox "${2:-}"
      fi
      ;;
    relogin)
      if [ -n "${2:-}" ] && [ -d "${2:-}" ]; then
        detect_edition_from_dir "$2" || choose_edition
        relogin "$2"
      else
        choose_edition
        relogin "${2:-$DEFAULT_DIR}"
      fi
      ;;
    status)
      command_exists pm2 && pm2 status || log_error "PM2 未安装"
      ;;
    logs)
      local name
      name="$(resolve_pm2_target)"
      command_exists pm2 && pm2 logs "$name" || log_error "PM2 未安装"
      ;;
    *)
      while true; do
        show_menu
        local choice
        choice="$(ask "请选择 [1-9]: ")"
        case "$choice" in
          1) main_installation ;;
          2) uninstall_telebox ;;
          3)
            choose_edition
            uninstall_telebox "$DEFAULT_DIR"
            main_installation "$DEFAULT_DIR"
            ;;
          4)
            choose_edition
            relogin "$DEFAULT_DIR"
            ;;
          5)
            local n; n="$(resolve_pm2_target)"
            command_exists pm2 && pm2 start "$n" && pm2 status || log_error "PM2 未安装或进程不存在"
            ;;
          6)
            local n; n="$(resolve_pm2_target)"
            command_exists pm2 && pm2 stop "$n" && pm2 status || log_error "PM2 未安装或进程不存在"
            ;;
          7) command_exists pm2 && pm2 status || log_error "PM2 未安装" ;;
          8)
            local n; n="$(resolve_pm2_target)"
            command_exists pm2 && pm2 logs "$n" || log_error "PM2 未安装"
            ;;
          9|q|Q) exit 0 ;;
          *) log_error "无效选择" ;;
        esac
        echo ""
        ask "按 Enter 返回菜单… " >/dev/null
      done
      ;;
  esac
}

main "$@"
