# TeleBox 一键安装脚本

## 项目简介

[TeleBox](https://github.com/TeleBoxOrg/TeleBox) 是一个基于 Node.js 与 TypeScript 的现代化 Telegram UserBot 框架，支持丰富插件与完整的首次登录流程。

本仓库脚本用于简化 TeleBox 部署，当前说明以官方安装指南为准，覆盖以下流程：

- ✅ 安装当前支持的 Node.js 24.x
- ✅ 安装基础依赖：`curl`、`git`、`build-essential`
- ✅ 拉取官方仓库 `TeleBoxOrg/TeleBox`
- ✅ 安装项目依赖并执行首次启动
- ✅ 首次填写 `api_id` / `api_hash`
- ✅ 根据提示选择二维码登录或手机号登录
- ✅ 可选使用 PM2 进行后台守护

## 系统要求

- **本地安装脚本 (`telebox.sh`)**: Debian / Ubuntu（基于 `apt` 的官方安装流程）
- **Docker 安装脚本 (`docker_telebox.sh`)**: 支持运行 Docker 的 Linux 主机
- **内存**: 至少 512MB RAM
- **存储**: 至少 1GB 可用空间
- **网络**: 需要可访问 GitHub、Telegram，以及 NodeSource Node.js 软件源

## 一键安装命令

### 安装到本地
```bash
wget https://raw.githubusercontent.com/TeleBoxOrg/InstallTeleBox/refs/heads/main/telebox.sh -O telebox.sh && chmod +x telebox.sh && bash telebox.sh
```

### 安装到 Docker 容器内
Docker 版本脚本作者: github.com/Seikolove
```bash
wget https://raw.githubusercontent.com/TeleBoxOrg/InstallTeleBox/refs/heads/main/docker_telebox.sh -O docker_telebox.sh && chmod +x docker_telebox.sh && bash docker_telebox.sh
```

## 当前安装流程说明

1. 安装脚本会先准备基础依赖：`curl`、`git`、`build-essential`
2. 按官方要求安装 Node.js 24.x
3. 从官方仓库 `https://github.com/TeleBoxOrg/TeleBox.git` 拉取项目
4. 执行 `npm install` 安装依赖
5. 首次运行 `npm start` 时，按提示填写 `api_id` 和 `api_hash`
6. 登录阶段可选择：
   - **二维码登录**：在 Telegram 客户端中扫描终端显示的二维码
   - **手机号登录**：依次输入手机号、验证码，以及两步验证密码（如已开启）
7. 首次登录完成后，可按需要继续以前台方式运行，或切换到 PM2 后台守护

## 可选：使用 PM2 持续运行

如果您希望 TeleBox 长期后台运行，可在安装完成后使用：

```bash
# 安装 PM2
npm install -g pm2

# 启动 TeleBox
pm2 start "npm start" --name telebox

# 查看服务状态
pm2 status

# 查看实时日志
pm2 logs telebox

# 重启服务
pm2 restart telebox

# 停止服务
pm2 stop telebox
```

## 注意事项

1. 安装前请确保服务器可以正常访问 GitHub、Telegram 和 NodeSource
2. 请提前准备好 Telegram `api_id` 与 `api_hash`，申请地址：<https://my.telegram.org/auth?to=apps>
3. 首次启动必须完成 Telegram 登录流程后，后续后台守护才有意义
4. Docker 脚本会保留当前两阶段流程：先交互登录，再切换到后台容器运行

## 故障排除

如果安装过程中遇到问题：

1. 优先查看终端输出或 PM2 日志定位错误
2. 确认 Node.js 版本为 24.x，且基础依赖已正确安装
3. 确认首次登录时已正确填写 `api_id` / `api_hash` 并完成二维码或手机号验证
4. 前往官方仓库与文档查看最新说明：
   - 项目仓库：<https://github.com/TeleBoxOrg/TeleBox>
   - 安装指南：<https://github.com/TeleBoxOrg/TeleBox/blob/main/INSTALL.md>

---

**项目地址**: [TeleBoxOrg/TeleBox](https://github.com/TeleBoxOrg/TeleBox)  
**脚本仓库**: [TeleBoxOrg/InstallTeleBox](https://github.com/TeleBoxOrg/InstallTeleBox)
