#!/usr/bin/env bash
# TeleBox Docker 一键安装 / 管理脚本
# 仓库: https://github.com/TeleBoxOrg/TeleBox-Scripts
# Coding by Telegram @awaEmpty

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[信息]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[完成]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[注意]${NC} $1"; }
log_error() { echo -e "${RED}[错误]${NC} $1"; }
log_step()  { echo -e "\n${CYAN}${BOLD}▶ $1${NC}"; }

# 交互读入：兼容管道 / 无 tty
ask() {
  local prompt="$1" reply
  if [ -r /dev/tty ]; then
    read -r -p "$prompt" reply </dev/tty || true
  else
    read -r -p "$prompt" reply || true
  fi
  printf '%s' "$reply"
}

ask_yn() {
  local prompt="$1" def="${2:-y}" hint="[Y/n]" reply
  [[ "$def" == "n" ]] && hint="[y/N]"
  reply="$(ask "$prompt $hint ")"
  reply="${reply:-$def}"
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ── 版本 ──────────────────────────────────────────────
EDITION=""
BRAND=""
REPO_URL=""
REPO_DIR=""          # 容器内项目目录名 telebox | telebox-next
PM2_NAME=""
SHORT_LABEL=""
DEFAULT_CONTAINER=""

apply_edition() {
  case "$1" in
    classic|1)
      EDITION="classic"
      BRAND="TeleBox"
      REPO_URL="https://github.com/TeleBoxOrg/TeleBox.git"
      REPO_DIR="telebox"
      PM2_NAME="telebox"
      SHORT_LABEL="Classic"
      DEFAULT_CONTAINER="telebox"
      ;;
    next|2)
      EDITION="next"
      BRAND="TeleBox-Next"
      REPO_URL="https://github.com/TeleBoxOrg/TeleBox-Next.git"
      REPO_DIR="telebox-next"
      PM2_NAME="telebox-next"
      SHORT_LABEL="Next"
      DEFAULT_CONTAINER="teleboxnext"
      ;;
    *) return 1 ;;
  esac
}

show_edition_help() {
  echo ""
  echo -e "${BOLD}请选择要安装的版本：${NC}"
  echo ""
  echo -e "  ${GREEN}1) Classic（推荐新手）${NC}  — TeleBox"
  echo "     · 更成熟、插件生态最全"
  echo "     · Telegram 库：Teleproto"
  echo "     · 容器内目录：/root/telebox    进程名：telebox"
  echo ""
  echo -e "  ${CYAN}2) Next${NC}                 — TeleBox-Next"
  echo "     · 下一代实现，原生异步架构"
  echo "     · Telegram API：mtcute"
  echo "     · 容器内目录：/root/telebox-next  进程名：telebox-next"
  echo ""
  echo "  功能大体一致。装好后可用 .switch go 在两版间切换。"
  echo "  拿不准就选 1。"
  echo ""
}

choose_edition() {
  if [ -n "${TELEBOX_EDITION:-}" ] && apply_edition "$TELEBOX_EDITION"; then
    log_ok "环境变量已选择：${BRAND}（${SHORT_LABEL}）"
    return 0
  fi
  show_edition_help
  while true; do
    local c
    c="$(ask "请输入 1 或 2 [默认 1]: ")"
    c="${c:-1}"
    if apply_edition "$c"; then
      log_ok "已选择：${BRAND}（${SHORT_LABEL}）"
      return 0
    fi
    log_error "请输入 1 或 2"
  done
}

# ── root ──────────────────────────────────────────────
require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log_error "Docker 安装脚本需要 root（或 sudo su 后执行）。"
    log_error "原因：要装 Docker、写 /root/Docker_Telebox、管理容器。"
    exit 1
  fi
}

# ── 容器名 ────────────────────────────────────────────
validate_container_name() {
  [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]
}

ask_container_name() {
  local def="${1:-$DEFAULT_CONTAINER}"
  while true; do
    local name
    name="$(ask "容器名称（字母数字._-）[默认: $def]: ")"
    name="${name:-$def}"
    if validate_container_name "$name"; then
      printf '%s' "$name"
      return 0
    fi
    log_error "名称不合法，请重试"
  done
}

host_data_dir() {
  # 统一数据根；可被 TELEBOX_DOCKER_ROOT 覆盖
  local root="${TELEBOX_DOCKER_ROOT:-/root/Docker_Telebox}"
  printf '%s/%s' "$root" "$1"
}

# ── Docker 安装 ───────────────────────────────────────
docker_check() {
  log_step "检查 Docker"
  if command -v docker >/dev/null 2>&1; then
    log_ok "Docker 已安装: $(docker --version 2>/dev/null | head -1)"
    return 0
  fi
  log_warn "未检测到 Docker"
  if ! ask_yn "是否现在自动安装 Docker？" "y"; then
    log_error "请先安装 Docker 后重试：https://docs.docker.com/engine/install/"
    exit 1
  fi
  install_docker_package
}

install_docker_package() {
  local os_id="unknown"
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    os_id="${ID:-unknown}"
  fi

  case "$os_id" in
    ubuntu|debian)
      log_info "使用官方仓库安装 Docker（$os_id）…"
      apt-get update -y
      apt-get install -y ca-certificates curl gnupg lsb-release
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL "https://download.docker.com/linux/${os_id}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${os_id} $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list
      apt-get update -y
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;
    centos|rhel|rocky|almalinux|fedora)
      log_info "使用 yum/dnf 安装 Docker（$os_id）…"
      if command -v dnf >/dev/null 2>&1; then
        dnf -y install dnf-plugins-core
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null \
          || dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      else
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      fi
      systemctl enable --now docker 2>/dev/null || true
      ;;
    alpine)
      log_info "Alpine: apk 安装 docker…"
      apk add --no-cache docker docker-cli-compose
      service docker start 2>/dev/null || true
      ;;
    *)
      log_error "暂不支持自动安装 Docker 的系统: $os_id"
      log_error "请手动安装 Docker 后重新运行本脚本"
      exit 1
      ;;
  esac

  if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker 安装后仍不可用"
    exit 1
  fi
  systemctl enable --now docker 2>/dev/null || service docker start 2>/dev/null || true
  log_ok "Docker 安装完成"
}

access_check() {
  log_step "检查 Docker 是否可用"
  if docker info >/dev/null 2>&1; then
    log_ok "Docker 守护进程正常"
    return 0
  fi
  log_warn "无法连接 Docker，尝试启动服务…"
  systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
  sleep 2
  if docker info >/dev/null 2>&1; then
    log_ok "Docker 已启动"
    return 0
  fi
  log_error "Docker 仍不可用。请检查: systemctl status docker"
  exit 1
}

list_containers() {
  echo ""
  echo "========== 当前 Docker 容器 =========="
  if ! docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' 2>/dev/null; then
    echo "（无法列出容器）"
  fi
  echo "======================================"
  echo ""
}

# 在容器内执行的安装引导脚本（通过 stdin 传入，避免引号地狱）
# 环境变量: TB_REPO_URL TB_REPO_DIR TB_PM2_NAME TB_MODE=login|daemon
container_bootstrap_script() {
  cat <<'INNER'
set -e
export DEBIAN_FRONTEND=noninteractive
echo "[容器] 更新软件源…"
apt-get update -y
apt-get install -y curl git ca-certificates gnupg build-essential python3
update-ca-certificates || true

if ! command -v node >/dev/null 2>&1 || [ "$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)" -lt 24 ]; then
  echo "[容器] 安装 Node.js 24.x…"
  curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
  apt-get install -y nodejs
fi
echo "[容器] Node $(node -v)  npm $(npm -v)"

if [ "$TB_MODE" = "daemon" ] || [ "$TB_MODE" = "login" ]; then
  npm install -g pm2 >/dev/null 2>&1 || npm install -g pm2
fi

if [ ! -d "/root/${TB_REPO_DIR}/.git" ]; then
  echo "[容器] 克隆 ${TB_REPO_URL} → /root/${TB_REPO_DIR}"
  rm -rf "/root/${TB_REPO_DIR}"
  git clone --depth 1 "${TB_REPO_URL}" "/root/${TB_REPO_DIR}"
else
  echo "[容器] 已存在 /root/${TB_REPO_DIR}，跳过克隆"
fi

cd "/root/${TB_REPO_DIR}"
echo "[容器] npm install…"
npm install

if [ "$TB_MODE" = "login" ]; then
  echo ""
  echo "=========================================="
  echo " 首次登录：按提示填写 api_id / api_hash"
  echo " 可申请: https://my.telegram.org/auth?to=apps"
  echo " 备用频道: https://t.me/TeleBox_API"
  echo " 登录成功后按 Ctrl+C 结束前台进程"
  echo "=========================================="
  echo ""
  npm start || true
  echo ""
  echo "[容器] 登录阶段结束（会话数据已写在挂载卷中）"
elif [ "$TB_MODE" = "daemon" ]; then
  pm2 delete "${TB_PM2_NAME}" >/dev/null 2>&1 || true
  pm2 start "npm start" --name "${TB_PM2_NAME}" --cwd "/root/${TB_REPO_DIR}" \
    || (cd "/root/${TB_REPO_DIR}" && pm2 start "npm start" --name "${TB_PM2_NAME}")
  pm2 save
  echo "[容器] 已用 PM2 启动 ${TB_PM2_NAME}，进入 pm2-runtime…"
  exec pm2-runtime resurrect
fi
INNER
}

run_interactive_login() {
  local container_name="$1"
  local data_dir
  data_dir="$(host_data_dir "$container_name")"
  mkdir -p "$data_dir"

  log_step "第一阶段：交互式登录（${BRAND}）"
  echo "  容器: $container_name"
  echo "  数据: $data_dir  →  容器内 /root"
  echo "  项目: /root/${REPO_DIR}"
  echo ""
  echo "说明：会拉取 debian:12，在容器内装 Node 并克隆仓库，然后 npm start 登录。"
  echo "登录成功后按 Ctrl+C；数据会留在宿主机目录里。"
  echo ""

  if docker inspect "$container_name" &>/dev/null; then
    log_warn "同名容器已存在，将删除后重建"
    docker rm -f "$container_name" >/dev/null 2>&1 || true
  fi

  # 把 bootstrap 写到数据目录，挂载后执行（兼容性更好）
  container_bootstrap_script > "$data_dir/.telebox-bootstrap.sh"
  chmod +x "$data_dir/.telebox-bootstrap.sh"

  docker run -it --name "$container_name" \
    -e TB_REPO_URL="$REPO_URL" \
    -e TB_REPO_DIR="$REPO_DIR" \
    -e TB_PM2_NAME="$PM2_NAME" \
    -e TB_MODE=login \
    -v "$data_dir:/root" \
    --pull always \
    debian:12 \
    bash /root/.telebox-bootstrap.sh || true

  echo ""
  log_ok "交互式登录阶段结束"
}

run_daemon() {
  local container_name="$1"
  local data_dir
  data_dir="$(host_data_dir "$container_name")"
  mkdir -p "$data_dir"

  log_step "第二阶段：PM2 后台常驻"
  docker rm -f "$container_name" >/dev/null 2>&1 || true

  container_bootstrap_script > "$data_dir/.telebox-bootstrap.sh"
  chmod +x "$data_dir/.telebox-bootstrap.sh"

  docker run -d --name "$container_name" --restart unless-stopped \
    -e TB_REPO_URL="$REPO_URL" \
    -e TB_REPO_DIR="$REPO_DIR" \
    -e TB_PM2_NAME="$PM2_NAME" \
    -e TB_MODE=daemon \
    -v "$data_dir:/root" \
    --pull always \
    debian:12 \
    bash /root/.telebox-bootstrap.sh

  sleep 2
  if docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null | grep -q true; then
    log_ok "容器已在后台运行"
  else
    log_warn "容器可能未成功启动，请查看: docker logs $container_name"
  fi

  echo ""
  echo -e "${GREEN}${BOLD}🎉 ${BRAND} Docker 安装完成${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  版本:     ${SHORT_LABEL}"
  echo "  容器名:   $container_name"
  echo "  数据目录: $data_dir"
  echo "  项目路径: $data_dir/${REPO_DIR}  (容器内 /root/${REPO_DIR})"
  echo "  PM2 名:   $PM2_NAME"
  echo ""
  echo "  常用命令:"
  echo "    docker logs -f $container_name"
  echo "    docker restart $container_name"
  echo "    docker stop $container_name"
  echo "    docker exec -it $container_name bash"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

finish_without_pm2() {
  local container_name="$1"
  local data_dir
  data_dir="$(host_data_dir "$container_name")"
  echo ""
  echo -e "${GREEN}${BOLD}🎉 登录数据已保留${NC}"
  echo "  未启用后台容器。数据在: $data_dir"
  echo "  之后若要后台运行，请重新执行本脚本选「安装」并启用 PM2。"
  echo "  或手动以 daemon 模式启动（数据目录需已含 ${REPO_DIR}）。"
  echo ""
  # 交互容器若还在，可删掉避免占名
  if docker inspect "$container_name" &>/dev/null; then
    local st
    st="$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null || true)"
    if [ "$st" != "running" ]; then
      docker rm -f "$container_name" >/dev/null 2>&1 || true
    fi
  fi
}

# 把 edition 元数据写入数据目录，方便重装/信息展示
save_edition_meta() {
  local data_dir="$1"
  mkdir -p "$data_dir"
  cat > "$data_dir/.telebox-edition" <<EOF
EDITION=$EDITION
BRAND=$BRAND
REPO_URL=$REPO_URL
REPO_DIR=$REPO_DIR
PM2_NAME=$PM2_NAME
SHORT_LABEL=$SHORT_LABEL
EOF
}

load_edition_meta() {
  local data_dir="$1"
  if [ -f "$data_dir/.telebox-edition" ]; then
    # shellcheck disable=SC1090
    . "$data_dir/.telebox-edition"
    return 0
  fi
  return 1
}

start_installation() {
  clear 2>/dev/null || true
  echo -e "${BLUE}"
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║         TeleBox Docker 一键安装                          ║"
  echo "║     Classic / Next 可选 · 数据落在宿主机卷               ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo "5 秒内 Ctrl+C 可取消…"
  sleep 5

  require_root
  choose_edition
  docker_check
  access_check

  local container_name data_dir
  container_name="$(ask_container_name "$DEFAULT_CONTAINER")"
  data_dir="$(host_data_dir "$container_name")"
  mkdir -p "$data_dir"
  save_edition_meta "$data_dir"

  log_info "版本 ${BRAND} · 容器 $container_name · 数据 $data_dir"
  if ! ask_yn "确认开始安装？" "y"; then
    log_info "已取消"
    return 0
  fi

  run_interactive_login "$container_name"

  echo ""
  echo "推荐启用 PM2 后台运行：关掉终端后容器内 TeleBox 仍持续运行。"
  if ask_yn "现在启用 PM2 后台容器？" "y"; then
    run_daemon "$container_name"
  else
    finish_without_pm2 "$container_name"
  fi
}

# ── 管理操作 ──────────────────────────────────────────
pick_container() {
  list_containers
  local def="${1:-telebox}"
  ask_container_name "$def"
}

cleanup() {
  require_root
  local container_name data_dir
  container_name="$(pick_container telebox)"
  data_dir="$(host_data_dir "$container_name")"

  if ! docker inspect "$container_name" &>/dev/null && [ ! -d "$data_dir" ]; then
    log_error "找不到容器或数据目录: $container_name"
    return 1
  fi

  if ! ask_yn "确定卸载容器 $container_name？" "n"; then
    return 0
  fi
  docker rm -f "$container_name" >/dev/null 2>&1 || true
  log_ok "容器已删除（若存在）"

  if [ -d "$data_dir" ]; then
    if ask_yn "是否同时删除数据目录 $data_dir？" "n"; then
      rm -rf "$data_dir"
      log_ok "数据已删除"
    else
      log_info "数据保留: $data_dir"
    fi
  fi
}

stop_telebox() {
  require_root
  local c
  c="$(pick_container telebox)"
  docker stop "$c" && log_ok "已停止 $c" || log_error "停止失败"
}

start_telebox() {
  require_root
  local c
  c="$(pick_container telebox)"
  docker start "$c" && log_ok "已启动 $c" || log_error "启动失败"
}

restart_telebox() {
  require_root
  local c
  c="$(pick_container telebox)"
  docker restart "$c" && log_ok "已重启 $c" || log_error "重启失败"
}

reinstall_telebox() {
  require_root
  local container_name data_dir
  container_name="$(pick_container telebox)"
  data_dir="$(host_data_dir "$container_name")"

  if [ -d "$data_dir" ] && load_edition_meta "$data_dir"; then
    log_info "检测到上次版本: ${BRAND:-?}（${SHORT_LABEL:-?}）"
    if ! ask_yn "仍使用该版本？" "y"; then
      choose_edition
      save_edition_meta "$data_dir"
    fi
  else
    choose_edition
    mkdir -p "$data_dir"
    save_edition_meta "$data_dir"
  fi

  if ask_yn "是否清空数据目录后全新安装？" "n"; then
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    rm -rf "$data_dir"
    mkdir -p "$data_dir"
    save_edition_meta "$data_dir"
    log_ok "数据已清空"
  else
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    log_info "保留数据: $data_dir"
  fi

  run_interactive_login "$container_name"
  if ask_yn "启用 PM2 后台？" "y"; then
    run_daemon "$container_name"
  else
    finish_without_pm2 "$container_name"
  fi
}

view_logs() {
  require_root
  local c
  c="$(pick_container telebox)"
  docker logs -f "$c"
}

enter_container() {
  require_root
  local c data_dir repo
  c="$(pick_container telebox)"
  data_dir="$(host_data_dir "$c")"
  repo="telebox"
  if load_edition_meta "$data_dir" 2>/dev/null; then
    repo="${REPO_DIR:-telebox}"
  fi
  echo "进入容器后项目目录: /root/$repo  （exit 退出）"
  docker exec -it "$c" bash || docker exec -it "$c" sh
}

show_container_info() {
  require_root
  local c data_dir
  c="$(pick_container telebox)"
  data_dir="$(host_data_dir "$c")"
  echo ""
  echo "========== 容器信息 =========="
  if docker inspect "$c" &>/dev/null; then
    docker inspect -f '状态: {{.State.Status}}  ID: {{.Id}}' "$c"
  else
    echo "容器不存在"
  fi
  echo "数据目录: $data_dir"
  if load_edition_meta "$data_dir" 2>/dev/null; then
    echo "版本: $BRAND ($SHORT_LABEL)"
    echo "仓库: $REPO_URL"
    echo "项目: $data_dir/$REPO_DIR"
  fi
  if [ -d "$data_dir" ]; then
    echo "目录大小: $(du -sh "$data_dir" 2>/dev/null | cut -f1)"
    ls -la "$data_dir" 2>/dev/null | head -20
  fi
  echo "=============================="
}

backup_telebox() {
  require_root
  local c data_dir backup_file
  c="$(pick_container telebox)"
  data_dir="$(host_data_dir "$c")"
  if [ ! -d "$data_dir" ]; then
    log_error "数据目录不存在: $data_dir"
    return 1
  fi
  backup_file="telebox-backup-${c}-$(date +%Y%m%d-%H%M%S).tar.gz"
  log_info "打包 $data_dir → $backup_file"
  tar czf "$backup_file" -C "$(dirname "$data_dir")" "$(basename "$data_dir")"
  log_ok "备份完成: $(pwd)/$backup_file"
  echo "恢复: tar xzf $backup_file -C $(dirname "$data_dir")/"
}

restore_telebox() {
  require_root
  local c backup_file data_root
  c="$(pick_container telebox)"
  backup_file="$(ask "备份文件路径: ")"
  if [ ! -f "$backup_file" ]; then
    log_error "文件不存在: $backup_file"
    return 1
  fi
  data_root="${TELEBOX_DOCKER_ROOT:-/root/Docker_Telebox}"
  mkdir -p "$data_root"
  docker stop "$c" 2>/dev/null || true
  tar xzf "$backup_file" -C "$data_root"
  log_ok "已解压到 $data_root"
  if docker inspect "$c" &>/dev/null; then
    docker start "$c" && log_ok "容器已启动" || true
  else
    log_info "容器不存在，请用菜单「安装/重装」基于该数据目录重建"
  fi
}

show_menu() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║         TeleBox Docker 管理菜单                          ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
  echo "  1) 安装（可选 Classic / Next）"
  echo "  2) 卸载"
  echo "  3) 停止容器"
  echo "  4) 启动容器"
  echo "  5) 重启容器"
  echo "  6) 重装"
  echo "  7) 查看日志"
  echo "  8) 进入容器"
  echo "  9) 容器 / 数据信息"
  echo " 10) 备份数据"
  echo " 11) 恢复数据"
  echo "  0) 退出"
  echo ""
  echo "  脚本仓库: https://github.com/TeleBoxOrg/TeleBox-Scripts"
  echo ""
}

main_menu() {
  while true; do
    show_menu
    local choice
    choice="$(ask "请输入编号: ")"
    case "$choice" in
      1) start_installation ;;
      2) cleanup ;;
      3) stop_telebox ;;
      4) start_telebox ;;
      5) restart_telebox ;;
      6) reinstall_telebox ;;
      7) view_logs ;;
      8) enter_container ;;
      9) show_container_info ;;
      10) backup_telebox ;;
      11) restore_telebox ;;
      0|q|Q) echo "再见"; exit 0 ;;
      *) log_error "无效编号" ; sleep 1 ;;
    esac
  done
}

# 非交互子命令
case "${1:-}" in
  install)
    require_root
    if [ -n "${2:-}" ] && apply_edition "$2"; then
      :
    else
      choose_edition
    fi
    docker_check
    access_check
    container_name="$(ask_container_name "${3:-$DEFAULT_CONTAINER}")"
    data_dir="$(host_data_dir "$container_name")"
    mkdir -p "$data_dir"
    save_edition_meta "$data_dir"
    run_interactive_login "$container_name"
    if ask_yn "启用 PM2 后台？" "y"; then
      run_daemon "$container_name"
    else
      finish_without_pm2 "$container_name"
    fi
    ;;
  *)
    main_menu
    ;;
esac
