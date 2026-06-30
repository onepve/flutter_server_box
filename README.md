<h2 align="center">Flutter Server Box</h2>

<h3 align="center">onepve 自用分支 — 含自建云同步</h3>

<div align="center">
  <img alt="语言" src="https://img.shields.io/badge/语言-dart-cyan">
  <img alt="license" src="https://img.shields.io/badge/证书-AGPLv3-yellow">
</div>

<p align="center">
使用 Flutter 开发的 Linux / Unix / Windows 服务器工具箱，提供服务器状态图表和管理工具。
<br>
本分支 fork 自 <a href="https://github.com/lollipopkit/flutter_server_box">lollipopkit/flutter_server_box</a>，主要面向<b>自用 + 好友共享</b>部署场景，附加了完整的自建同步后端支持。
</p>

---

## ✨ 分支特性（基于上游 + 新增）

### ☁️ 自建云同步 — 核心功能

- **跨设备同步** — 手机、平板、电脑间同步服务器配置和状态数据
- **端到端加密** — AES-256-GCM + PBKDF2 派生密钥，服务端零信任
- **智能一键同步** — 自动检测远程是否有更新，智能决定上传或下载
- **多设备共存** — 同一账号多设备同时使用，互不影响
- **数据安全** — 支持数据导出到邮箱、多步验证删除

### 🔐 用户账户系统

| 功能 | 说明 |
|------|------|
| 邀请码注册 | 管理员可控，防止无关人员注册 |
| 登录/登出 | JWT Token 持久化 |
| TOTP 双因素认证 | 兼容 Google Authenticator |
| 邮箱验证 | 可选，配置 SMTP 后可用 |
| 头像和昵称 | 个人资料自定义 |
| 忘记密码 | 邮箱验证重置 |
| 注销账号 | 多步验证 + 数据清理 |
| 退出登录/删除数据 | 客户端一键操作 |

### 🛠️ 服务器管理（上游原有）

- `状态图表` CPU、内存、磁盘、网络、传感器、GPU、S.M.A.R.T…
- `SSH 终端` 全功能终端，支持 xterm
- `SFTP 文件管理` 文件浏览器
- `Docker 管理` 容器、镜像、日志
- `进程管理` / `Systemd 服务管理`
- `桌面小部件` / `推送通知` / `生物认证`
- 多语言支持（中文、英文、德文、法文、日文等）

---

## 📥 安装

| 平台 | 下载 | 编译 |
|------|------|------|
| Android | [GitHub Releases](https://github.com/onepve/flutter_server_box/releases) | ✅ 自动（arm64-v8a / armeabi-v7a / x86_64） |
| Windows | [GitHub Releases](https://github.com/onepve/flutter_server_box/releases) | ✅ 自动 |
| Linux | [GitHub Releases](https://github.com/onepve/flutter_server_box/releases) | ✅ 自动（AppImage + .deb） |
| iOS | 暂不提供 | ❌ 未编译（需 Apple 开发者证书） |
| macOS | 暂不提供 | ❌ 未编译 |

> CI 自动编译 Android / Windows / Linux 三个平台。iOS/macOS 需自行从源码构建。

---

## 🚀 快速开始（云同步）

1. 下载并安装最新 Release 的 APK
2. 打开 App → 备份页面 → **自建云同步**
3. 使用管理员提供的邀请码注册账号
4. 登录后设置同步密码（AES-256-GCM 加密用）
5. 点击「一键同步」完成首次上传
6. 其他设备登录同账号即可自动同步

> 同步服务端地址已固定为 `sync.onepve.com`，客户端无需额外配置。

---

## 🧱 自行构建

```bash
# 1. 安装 Flutter 3.44.1+
# 2. 克隆仓库
git clone https://github.com/onepve/flutter_server_box.git
cd flutter_server_box

# 3. 安装依赖
flutter pub get

# 4. 运行
flutter run

# 5. 构建
dart run fl_build -p android   # Android
dart run fl_build -p linux     # Linux
dart run fl_build -p windows   # Windows
```

### 同步服务端搭建

自建同步后端请参考 [flutter-sync-server](https://github.com/onepve/flutter-sync-server) 项目。

---

## 🔧 复刻自定义指南

如果你复刻本项目自用，请修改以下文件：

| 文件 | 修改内容 |
|------|----------|
| `lib/sync/sync_config.dart` | `serverUrl` → 你的同步服务器地址 |
| `pubspec.yaml` | `name`、`description`、`homepage` |
| `android/app/build.gradle.kts` | `applicationId` → 你的包名 |
| `.github/workflows/build.yml` | 签名密钥配置 |

---

## 📝 协议

`AGPL v3 — lollipopkit & 所有贡献者`