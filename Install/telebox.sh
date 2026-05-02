#!/bin/bash

# TeleBox 安装脚本
# 版本: 1.0.0
# 项目: https://github.com/TeleBoxOrg/TeleBox
# Coding by Telegram @Tiara_Basori

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查 root 权限
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "不建议使用 root 权限运行本脚本"
        read -p "是否继续? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 系统检测
check_system() {
    log_info "正在检测系统信息..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif command_exists lsb_release; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [[ -f /etc/redhat-release ]]; then
        OS=$(awk '{print $1}' /etc/redhat-release)
        VER=$(awk '{print $3}' /etc/redhat-release)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    # 检测包管理器
    if command_exists apt-get; then
        PKG_MANAGER="apt"
        UPDATE_CMD="sudo apt update"
        INSTALL_CMD="sudo apt install -y"
    else
        log_error "当前脚本仅支持 Debian / Ubuntu 的 apt 安装流程"
        exit 1
    fi
}

# 欢迎信息
welcome() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                   TeleBox 安装脚本                          ║"
    echo "║                现代化 Telegram Bot 框架                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "安装步骤："
    echo "  1. 安装系统依赖"
    echo "  2. 安装 Node.js"
    echo "  3. 下载 TeleBox"
    echo "  4. 安装项目依赖"
    echo "  5. 登录配置"
    echo "  6. 启动服务"
    echo ""
    sleep 2
}

# 安装系统依赖
install_system_deps() {
    log_info "安装系统依赖..."
    
    if ! $UPDATE_CMD; then
        log_error "系统更新失败"
        exit 1
    fi
    
    case $PKG_MANAGER in
        "apt")
            $INSTALL_CMD curl git build-essential screen || {
                log_error "系统依赖安装失败"
                exit 1
            }
            ;;
    esac
    
    log_success "系统依赖安装完成"
}

# 安装 Node.js
install_nodejs() {
    log_info "检查 Node.js..."
    
    if command_exists node; then
        NODE_VERSION=$(node --version 2>/dev/null | cut -d'v' -f2)
        if [ -n "$NODE_VERSION" ]; then
            MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d'.' -f1)
            if [ "$MAJOR_VERSION" -ge 24 ] 2>/dev/null; then
                log_success "Node.js 版本符合要求"
                return 0
            fi
        fi
    fi
    
    log_info "安装 Node.js 24.x..."
    
    case $PKG_MANAGER in
        "apt")
            curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - && sudo apt-get install -y nodejs || {
                log_error "Node.js 安装失败"
                exit 1
            }
            ;;
        *)
            log_error "当前脚本仅支持基于 Linux 包管理器的 apt 安装流程"
            exit 1
            ;;
    esac
    
    log_success "Node.js 安装完成"
}

# 克隆项目
clone_project() {
    local install_dir="$1"
    
    log_info "下载 TeleBox..."
    
    if [ -d "$install_dir" ]; then
        read -p "目录已存在，是否重新安装? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$install_dir" || {
                log_error "无法删除现有目录"
                exit 1
            }
        else
            cd "$install_dir" || {
                log_error "无法进入目录"
                exit 1
            }
            return 0
        fi
    fi
    
    git clone https://github.com/TeleBoxOrg/TeleBox.git "$install_dir" && cd "$install_dir" || {
        log_error "项目下载失败"
        exit 1
    }
    
    log_success "TeleBox 下载完成"
}

# 安装项目依赖
install_project_deps() {
    log_info "安装项目依赖..."
    
    if [ ! -f "package.json" ]; then
        log_error "未在项目目录中"
        exit 1
    fi
    
    npm install || {
        log_error "依赖安装失败"
        exit 1
    }
    
    log_success "依赖安装完成"
}

# 使用 screen 安全运行登录流程
safe_login_screen() {
    local install_dir="$1"
    
    cd "$install_dir" || {
        log_error "无法进入安装目录"
        return 1
    }
    
    log_info "启动登录界面..."
    
    # 关闭可能存在的旧会话
    screen -S telebox-login -X quit >/dev/null 2>&1 || true
    
    # 创建新的 screen 会话
    screen -dmS telebox-login bash -c "cd '$install_dir' && npm start"
    
    sleep 2
    
    if ! screen -list | grep -q "telebox-login"; then
        log_error "无法启动登录会话"
        return 1
    fi
    
    echo ""
    echo "请按以下步骤操作："
    echo "  1. 输入 API ID 和 API Hash"
    echo "  2. 按提示选择二维码登录或手机号登录"
    echo "  3. 如果使用手机号登录，依次输入手机号、验证码和 2FA 密码（如有）"
    echo "  4. 登录成功后按 Ctrl+A 然后按 D 返回"
    echo ""
    
    read -p "按 Enter 开始登录 " </dev/tty
    
    screen -r telebox-login
    
    echo ""
    read -p "登录是否完成？(y/n): " login_done </dev/tty
    if [[ "$login_done" =~ ^[Yy]$ ]]; then
        log_success "登录完成"
    else
        log_warning "登录可能未完成"
    fi
    
    # 清理 screen 会话
    screen -S telebox-login -X quit >/dev/null 2>&1 || true
}

# 首次配置
first_time_setup() {
    log_info "开始登录配置..."
    echo ""
    echo "需要从 https://my.telegram.org 获取 API ID 和 Hash"
    echo ""
    
    read -p "按 Enter 开始 " </dev/tty
    
    safe_login_screen "$install_dir"
}

# 安装 PM2
install_pm2() {
    log_info "安装 PM2..."
    
    if command_exists pm2; then
        log_info "PM2 已安装"
    else
        sudo npm install -g pm2 || {
            log_error "PM2 安装失败"
            exit 1
        }
    fi
    
    pm2 install pm2-logrotate >/dev/null 2>&1 || true
}

# 创建 PM2 配置文件
create_pm2_config() {
    local install_dir="$1"
    
    local official_pm2_config="$install_dir/ecosystem.config.cjs"

    mkdir -p "$install_dir/logs"

    if [ ! -f "$official_pm2_config" ]; then
        log_error "未找到官方 PM2 配置: $official_pm2_config"
        exit 1
    fi
}

# 配置系统服务
setup_service() {
    local install_dir="$1"
    
    log_info "配置系统服务..."
    
    create_pm2_config "$install_dir"
    
    cd "$install_dir" && pm2 start ecosystem.config.cjs && pm2 save || {
        log_error "服务启动失败"
        exit 1
    }
    
    # 尝试设置开机自启
    if pm2 startup >/dev/null 2>&1; then
        startup_cmd=$(pm2 startup | tail -n 1)
        [ -n "$startup_cmd" ] && eval "$startup_cmd" >/dev/null 2>&1 || true
    fi
    
    log_success "服务配置完成"
}

# 显示使用说明
show_usage() {
    local install_dir="$1"
    
    echo ""
    echo "🎉 TeleBox 安装完成！"
    echo ""
    echo "📋 使用命令:"
    echo "   pm2 status                   # 查看状态"
    echo "   pm2 logs telebox             # 查看日志"
    echo "   pm2 restart telebox          # 重启服务"
    echo ""
    echo "📁 项目目录: $install_dir"
    echo ""
}

# 重置 PM2 配置
reset_pm2_config() {
    local install_dir="$1"
    
    log_info "重置 PM2 配置..."
    
    pm2 delete telebox 2>/dev/null || true
    create_pm2_config "$install_dir"
    cd "$install_dir" && pm2 start ecosystem.config.cjs && pm2 save || {
        log_error "重置失败"
        return 1
    }
    
    log_success "PM2 配置重置完成"
}

# 重新登录
relogin() {
    local install_dir="$1"
    
    log_info "准备重新登录..."
    
    if [ ! -d "$install_dir" ]; then
        log_error "安装目录不存在"
        return 1
    fi
    
    pm2 stop telebox 2>/dev/null || true
    
    # 删除会话文件
    session_locations=(
        "$install_dir/my_session"
        "$install_dir/session"
        "$install_dir"/*.session
        "$install_dir/session.json"
    )
    
    for location in "${session_locations[@]}"; do
        for item in $location; do
            [ -e "$item" ] && rm -rf "$item"
        done
    done
    
    safe_login_screen "$install_dir"
    
    log_info "重新启动服务..."
    pm2 start telebox && log_success "重新登录完成" || log_error "启动失败"
}

# 显示服务状态
show_status() {
    if command_exists pm2; then
        pm2 status telebox
    else
        log_error "PM2 未安装"
    fi
}

# 查看日志
show_logs() {
    if command_exists pm2; then
        pm2 logs telebox
    else
        log_error "PM2 未安装"
    fi
}

# 主安装函数
main_installation() {
    local install_dir="${1:-$HOME/telebox}"
    
    welcome
    check_root
    check_system
    install_system_deps
    install_nodejs
    clone_project "$install_dir"
    install_project_deps
    
    read -p "现在进行登录配置? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        first_time_setup
    fi
    
    install_pm2
    setup_service "$install_dir"
    show_usage "$install_dir"
}

# 卸载函数
uninstall_telebox() {
    local install_dir="${1:-$HOME/telebox}"
    
    log_warning "即将卸载 TeleBox..."
    
    read -p "确定继续? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 0
    fi
    
    if [ -d "$install_dir" ]; then
        command_exists pm2 && pm2 delete telebox 2>/dev/null
        rm -rf "$install_dir" && log_success "卸载完成" || log_error "删除失败"
    else
        log_info "目录不存在"
    fi
}

# 显示菜单
show_menu() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                   TeleBox 管理菜单                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "  1) 安装 TeleBox"
    echo "  2) 卸载 TeleBox"
    echo "  3) 重新安装"
    echo "  4) 重新登录"
    echo "  5) 启动服务"
    echo "  6) 停止服务"
    echo "  7) 查看状态"
    echo "  8) 查看日志"
    echo "  9) 退出"
    echo ""
    echo -n "请选择 [1-9]: "
}

# 信号处理函数
handle_interrupt() {
    echo ""
    log_warning "操作已取消"
    exit 1
}

# 主函数
main() {
    local install_dir="$HOME/telebox"
    
    trap handle_interrupt INT
    
    case "${1:-}" in
        "install")
            main_installation "$2"
            ;;
        "uninstall")
            uninstall_telebox "$2"
            ;;
        "reset")
            reset_pm2_config "$install_dir"
            ;;
        "relogin")
            relogin "$install_dir"
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        *)
            while true; do
                show_menu
                read -r choice
                case $choice in
                    1)
                        main_installation "$install_dir"
                        ;;
                    2)
                        uninstall_telebox "$install_dir"
                        ;;
                    3)
                        uninstall_telebox "$install_dir"
                        main_installation "$install_dir"
                        ;;
                    4)
                        relogin "$install_dir"
                        ;;
                    5)
                        command_exists pm2 && pm2 start telebox && show_status || log_error "PM2 未安装"
                        ;;
                    6)
                        command_exists pm2 && pm2 stop telebox && show_status || log_error "PM2 未安装"
                        ;;
                    7)
                        show_status
                        ;;
                    8)
                        show_logs
                        ;;
                    9)
                        exit 0
                        ;;
                    *)
                        log_error "无效选择"
                        ;;
                esac
                echo ""
                read -p "按 Enter 继续..." </dev/tty
            done
            ;;
    esac
}

# 运行主函数
main "$@"