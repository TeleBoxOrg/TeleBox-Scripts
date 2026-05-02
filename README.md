<div align="center">

# 🚀 TeleBox Scripts

[![License](https://img.shields.io/badge/License-LGPL%202.1-blue.svg?style=for-the-badge)](LICENSE)
[![TeleBox](https://img.shields.io/badge/TeleBox-Main%20Repo-2b6cb0?style=for-the-badge&logo=github)](https://github.com/TeleBoxOrg/TeleBox)
[![Node.js](https://img.shields.io/badge/Node.js-24.x-green.svg?style=for-the-badge&logo=node.js)](https://nodejs.org/)
[![Platform](https://img.shields.io/badge/Linux-Debian%20%2F%20Ubuntu-orange.svg?style=for-the-badge&logo=linux)](https://www.debian.org/)

**TeleBox 官方一键安装脚本仓库**

_帮你更快完成 TeleBox 安装、首次登录和后台运行，新手也能按步骤直接上手。_

[⚡ 立即开始](#-快速开始) • [📦 脚本说明](#-脚本说明) • [❓ 常见问题](#-常见问题) • [📚 相关链接](#-相关链接)

</div>

---

## ✨ 核心特性

<table>
<tr>
<td width="33%">

### ⚡ **一键安装**

- 自动安装基础依赖
- 自动安装 Node.js 24.x
- 自动拉取官方 TeleBox 仓库
- 自动执行 `npm install`

</td>
<td width="33%">

### 🔐 **新手友好登录**

- 首次启动会进入官方登录流程
- 支持 **二维码登录**
- 支持 **手机号登录**
- 按提示填写 `api_id` / `api_hash` 即可

</td>
<td width="33%">

### 🛠️ **持续运行**

- 本地脚本可配合 PM2 守护运行
- Docker 脚本支持两阶段安装
- 安装完成后可长期后台运行
- 适合服务器部署

</td>
</tr>
</table>

## 👋 这是什么？

这个仓库提供了 TeleBox 的**一键安装脚本**，适合想快速部署 TeleBox 的用户使用。

如果你不想手动执行一长串命令，而是希望：

- 自动准备依赖环境
- 自动下载 TeleBox
- 自动安装项目依赖
- 按提示完成 Telegram 登录
- 后续继续后台运行

那你直接使用这里的脚本即可。

## ✅ 使用前准备

开始前请先确认：

1. 你有一台 **Linux 主机**
2. 网络可以访问 **GitHub**、**Telegram** 和 **NodeSource**
3. 你已经准备好 Telegram 的 **`api_id`** 和 **`api_hash`**
4. 至少有 **512MB RAM** 和 **1GB 可用空间**

Telegram API 申请地址：<https://my.telegram.org/auth?to=apps>

## 🚀 快速开始

### 方式一：安装到本机（推荐大多数用户）

适合：
- Debian / Ubuntu 服务器
- 想直接把 TeleBox 安装到当前系统中
- 想自己查看目录、手动管理文件

```bash
wget https://raw.githubusercontent.com/TeleBoxOrg/TeleBox_Scripts/refs/heads/main/Install/telebox.sh -O telebox.sh && chmod +x telebox.sh && bash telebox.sh
```

### 方式二：安装到 Docker 容器

适合：
- 你已经在使用 Docker
- 想把 TeleBox 和系统环境隔离开
- 想用容器方式部署和迁移

Docker 版本脚本作者：github.com/Seikolove

```bash
wget https://raw.githubusercontent.com/TeleBoxOrg/TeleBox_Scripts/refs/heads/main/Install/docker_telebox.sh -O docker_telebox.sh && chmod +x docker_telebox.sh && bash docker_telebox.sh
```

## 📦 脚本说明

### `Install/telebox.sh`

本地安装脚本，当前基于 **Debian / Ubuntu 的 apt 流程**。

它会自动完成：

1. 安装基础依赖：`curl`、`git`、`build-essential`、`screen`
2. 安装 Node.js 24.x
3. 克隆官方仓库 `https://github.com/TeleBoxOrg/TeleBox.git`
4. 执行 `npm install`
5. 启动 `npm start`，进入首次登录流程

### `Install/docker_telebox.sh`

Docker 安装脚本，适合想用容器部署的用户。

它会分两阶段完成：

1. 启动交互式容器，完成首次登录
2. 登录完成后切换到后台容器运行模式

## 🧭 安装后会发生什么？

无论你使用哪种方式，首次安装的核心流程基本一致：

1. 准备系统依赖
2. 安装 Node.js 24.x
3. 下载 TeleBox 主仓库
4. 安装项目依赖
5. 首次运行 `npm start`
6. 填写 `api_id` 和 `api_hash`
7. 选择以下任意一种登录方式：
   - **二维码登录**：在 Telegram 客户端中扫码登录
   - **手机号登录**：依次输入手机号、验证码，以及两步验证密码（如果开启了 2FA）

## 🔐 首次登录说明

首次启动时，脚本不会跳过官方登录流程。

你需要按提示完成：

- 输入 Telegram `api_id`
- 输入 Telegram `api_hash`
- 选择 **二维码登录** 或 **手机号登录**
- 如使用手机号登录，继续输入验证码与 2FA 密码（如已开启）

> 首次登录完成后，后续后台运行才有意义。

## 💡 安装完成后的常用命令

### PM2 后台运行

如果你是本机安装，并希望 TeleBox 长期后台运行，可以使用：

```bash
# 安装 PM2
npm install -g pm2

# 启动 TeleBox
pm2 start "npm start" --name telebox

# 查看状态
pm2 status

# 查看日志
pm2 logs telebox

# 重启服务
pm2 restart telebox

# 停止服务
pm2 stop telebox
```

### Docker 常用操作

Docker 版本安装完成后，常见操作包括：

```bash
# 查看日志
docker logs -f telebox

# 重启容器
docker restart telebox

# 停止容器
docker stop telebox
```

> 如果你在安装时自定义了容器名，请把上面的 `telebox` 替换成你自己的容器名。

## ❓ 常见问题

### 1. 为什么安装失败？

优先检查这几项：

- 是否能正常访问 GitHub、Telegram、NodeSource
- 是否为 Debian / Ubuntu（本机脚本）
- 是否已经安装并可使用 Docker（Docker 脚本）
- Node.js 是否成功安装为 **24.x**

### 2. 为什么启动后卡在登录？

这通常不是卡住，而是在等待你完成官方登录流程。请根据终端提示：

- 输入 `api_id` / `api_hash`
- 选择二维码登录或手机号登录
- 按要求完成验证

### 3. root 可以直接运行吗？

- `telebox.sh` 会提示你**不建议使用 root** 继续执行
- `docker_telebox.sh` 需要 **root 权限** 执行

### 4. Docker 版本和本机版本有什么区别？

- **本机版本**：直接安装到当前 Linux 系统，适合大多数普通用户
- **Docker 版本**：运行在容器内，适合已经熟悉 Docker 或想隔离环境的用户

<details>
<summary><b>📁 点击展开仓库结构</b></summary>

```text
TeleBox_Scripts/
├── Install/
│   ├── telebox.sh           # 本机一键安装脚本
│   └── docker_telebox.sh    # Docker 一键安装脚本
├── LICENSE
└── README.md
```

</details>

## 📚 相关链接

<div align="center">

[![主仓库](https://img.shields.io/badge/📦_主仓库-TeleBox-blue?style=for-the-badge&logo=github)](https://github.com/TeleBoxOrg/TeleBox)
[![安装指南](https://img.shields.io/badge/📋_官方安装指南-INSTALL.md-green?style=for-the-badge&logo=github)](https://github.com/TeleBoxOrg/TeleBox/blob/main/INSTALL.md)
[![问题反馈](https://img.shields.io/badge/🆘_问题反馈-Issues-red?style=for-the-badge&logo=github)](https://github.com/TeleBoxOrg/TeleBox/issues)
[![脚本仓库](https://img.shields.io/badge/⚙️_脚本仓库-TeleBox__Scripts-orange?style=for-the-badge&logo=github)](https://github.com/TeleBoxOrg/TeleBox_Scripts)

</div>

## 📄 许可证

本项目采用 [LGPL-2.1](LICENSE) 许可证开源。

---

<div align="center">

### 🎯 **TeleBox Scripts**

_让 TeleBox 安装更简单，上手更直接。_

</div>
