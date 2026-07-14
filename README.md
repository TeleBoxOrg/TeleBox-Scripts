<div align="center">

# 🚀 TeleBox Scripts

**TeleBox 官方一键脚本**

_本机或 Docker 安装 Classic / Next · 面向新手 · 少踩坑_

[⚡ 快速开始](#-快速开始) · [📦 脚本说明](#-脚本说明) · [🔀 版本区别](#-classic-还是-next) · [❓ 常见问题](#-常见问题)

</div>

---

## 👋 这是什么？

帮你自动完成：

1. 准备系统依赖与 Node.js 24  
2. **自选 Classic 或 Next** 并下载对应仓库  
3. `npm install`  
4. 引导完成 Telegram 首次登录  
5. 可选开启 **PM2 后台运行**

不想手敲一长串命令时，直接用这里的脚本即可。

## 🔀 Classic 还是 Next？

| | **Classic（推荐新手）** | **Next** |
|--|-------------------------|----------|
| 仓库 | [TeleBox](https://github.com/TeleBoxOrg/TeleBox) | [TeleBox-Next](https://github.com/TeleBoxOrg/TeleBox-Next) |
| 定位 | 更成熟、资料与社区插件最多 | 下一代实现、原生异步架构 |
| Telegram API | Teleproto | mtcute |
| 默认目录 | `~/telebox` | `~/telebox-next` |
| PM2 进程名 | `telebox` | `telebox-next` |

- 功能大体一致（插件商店、热重载、权限、`.switch` 等）。  
- 装好后可用 **`.switch go`** 在两版间切换（会转换会话与迁移配置）。  
- **拿不准就选 Classic（脚本里选 1）**。

脚本支持环境变量跳过菜单：`TELEBOX_EDITION=classic` 或 `next`。

## ✅ 使用前准备

1. 一台 **Linux** 主机（本机脚本：Debian/Ubuntu 最省心；也尝试支持 dnf/yum/apk）  
2. 网络能访问 **GitHub**、**Telegram**、**NodeSource**（装 Node 时）  
3. 准备好 Telegram **`api_id` / `api_hash`**  
   - 申请：<https://my.telegram.org/auth?to=apps>  
   - 备用：<https://t.me/TeleBox_API>  
4. 建议 ≥ **512MB RAM**、**1GB** 磁盘  

Docker 脚本需要 **root**，并会检测/可选安装 Docker。

## 🚀 快速开始

### 方式一：安装到本机（大多数用户）

```bash
wget https://raw.githubusercontent.com/TeleBoxOrg/TeleBox-Scripts/refs/heads/main/Install/telebox.sh -O telebox.sh && chmod +x telebox.sh && bash telebox.sh
```

按提示选择 **1 Classic** 或 **2 Next**，再完成登录与（可选）PM2。

非交互示例：

```bash
TELEBOX_EDITION=classic bash telebox.sh install
TELEBOX_EDITION=next bash telebox.sh install
# 或: bash telebox.sh install next
```

### 方式二：Docker 容器

适合会用 Docker、想和环境隔离的用户：

```bash
wget https://raw.githubusercontent.com/TeleBoxOrg/TeleBox-Scripts/refs/heads/main/Install/docker_telebox.sh -O docker_telebox.sh && chmod +x docker_telebox.sh && sudo bash docker_telebox.sh
```

数据默认在宿主机：`/root/Docker_Telebox/<容器名>/`（可用 `TELEBOX_DOCKER_ROOT` 改根目录）。

## 📦 脚本说明

### `Install/telebox.sh`（本机）

- 版本选择 + 简明对比说明  
- 包管理器：`apt` / `dnf` / `yum` / `apk`  
- Node.js 24.x（NodeSource；Alpine 走仓库并提示版本）  
- 克隆官方仓库 → `npm install` → 登录（支持 **screen** 防 SSH 断线）  
- 可选 PM2；进程名按版本区分  
- 菜单：安装 / 卸载 / 重装 / 重新登录 / 启停与日志  

### `Install/docker_telebox.sh`（Docker）

- 同样可选 Classic / Next  
- 自动检测 Docker，可选安装（Debian/Ubuntu/RHEL 系/Alpine）  
- 阶段一：交互容器完成登录（数据落在挂载卷）  
- 阶段二：可选 PM2 + `pm2-runtime` 后台容器  
- 管理：启停、日志、进容器、备份/恢复；版本元数据写在数据目录  

## 🧭 安装后你会做什么？

1. 在 Telegram 里给自己发 **`.help`**  
2. 装插件：**`.tpm search`** / **`.tpm i <名字>`**  
3. 后台：`pm2 logs telebox` 或 `pm2 logs telebox-next`  
4. 换版本：**`.switch go`**（在已运行的 TeleBox 里）  

## ❓ 常见问题

**安装失败？**  
检查能否访问 GitHub / NodeSource；Node 是否为 24.x；磁盘与编译依赖（`build-essential` 等）是否齐全。

**一直停在登录？**  
多半在等你输入 api_id、扫码或验证码，按终端提示操作即可。

**本机 vs Docker？**  
- 本机：直接装在系统里，好改文件，适合大多数人。  
- Docker：隔离环境，数据在 `Docker_Telebox` 目录，适合熟悉容器的人。

**Classic / Next 装错了？**  
可再跑脚本装另一版到不同目录，或在已运行实例里用 `.switch go` 切换。

## 📚 相关链接

<div align="center">

[![TeleBox](https://img.shields.io/badge/📦_TeleBox-Classic-blue?style=for-the-badge&logo=github)](https://github.com/TeleBoxOrg/TeleBox)
[![TeleBox-Next](https://img.shields.io/badge/📦_TeleBox--Next-blue?style=for-the-badge&logo=github)](https://github.com/TeleBoxOrg/TeleBox-Next)
[![Issues](https://img.shields.io/badge/🆘_问题反馈-Issues-red?style=for-the-badge&logo=github)](https://github.com/TeleBoxOrg/TeleBox/issues)

</div>
