简体中文 | [English](README_en.md)

> 🔧 **复刻自定义指南**（fork 必读）\
> 如果你复刻了这个项目，请修改以下文件来适配你自己的服务端：
> 
> | 文件 | 修改内容 |
> |------|----------|
> | `lib/sync/sync_config.dart` | `serverUrl` → 你的同步服务器地址 |
> | `lib/sync/sync_config.dart` | `dataType` → 自定义数据类型标识（可选） |
> | `lib/app.dart` + `lib/data/res/` | 修改默认语言为 `zh`（简体中文）已默认设置 |
> | `pubspec.yaml` | 修改 `name`、`description`、`homepage` |
> | `lib/data/res/default.dart` | 修改 GitHub 链接、关于页等默认值 |
> | `android/app/build.gradle.kts` | `applicationId` → 你的包名 |
> | `ios/Runner.xcodeproj` | Bundle Identifier → 你的标识符 |
> | `android/key.properties` | 签名密钥（Release） |
> 
> **快速改服务器地址**：打开 `lib/sync/sync_config.dart`，修改第 8 行：
> ```dart
> static const serverUrl = 'https://your-server.com';  // ← 改成你自己的
> ```
> 然后运行 `dart run fl_build -p android` 或 `dart run fl_build -p ios` 构建即可。

---

<h2 align="center">Flutter Server Box</h2>

<div align="center">
  <img alt="语言" src="https://img.shields.io/badge/语言-dart-cyan">
  <img alt="license" src="https://img.shields.io/badge/证书-AGPLv3-yellow">
</div>

<p align="center">
使用 Flutter 开发的 Linux, Unix, Windows 服务器工具箱，提供服务器状态图表和管理工具。
<br>
本项目 fork 自 <a href="https://github.com/lollipopkit/flutter_server_box">lollipopkit/flutter_server_box</a>，已添加同步服务支持和多项优化。
特别感谢 <a href="https://github.com/TerminalStudio/dartssh2">dartssh2</a> & <a href="https://github.com/TerminalStudio/xterm.dart">xterm.dart</a>。
</p>

## ✨ 新增功能（Fork 版）

- **☁️ 服务端同步** — 多设备数据同步，端到端加密（服务端零信任）
- **🔐 TOTP 双因素认证** — 兼容 Google Authenticator
- **👥 邀请码注册** — 管理员可控的用户注册
- **🖼️ 头像 & 昵称** — 登录后显示用户头像和昵称
- **📊 管理后台** — Web 管理面板（用户管理、邀请码、审计日志）
- **🌐 公开邀请码页** — 无需登录即可获取邀请码

## 🏙️ 截屏

<table>
  <tr>
    <td><img width="200px" src="https://cdn.lpkt.cn/serverbox/screenshot/1.jpg"></td>
    <td><img width="200px" src="https://cdn.lpkt.cn/serverbox/screenshot/2.jpg"></td>
    <td><img width="200px" src="https://cdn.lpkt.cn/serverbox/screenshot/3.jpg"></td>
    <td><img width="200px" src="https://cdn.lpkt.cn/serverbox/screenshot/4.jpg"></td>
  </tr>
</table>

## 📥 安装

| 平台 | 下载 | 编译 |
|------|------|------|
| Android | [GitHub Releases](https://github.com/onepve/flutter_server_box/releases) | ✅ 自动编译 |
| Windows | [GitHub Releases](https://github.com/onepve/flutter_server_box/releases) | ✅ 自动编译 |
| Linux | [GitHub Releases](https://github.com/onepve/flutter_server_box/releases) | ✅ 自动编译 |
| iOS | 暂不提供 | ❌ 未编译 |
| macOS | 暂不提供 | ❌ 未编译 |

> ⚠️ 当前 CI 仅自动编译 **Android / Windows / Linux** 三个平台。iOS 和 macOS 需要 Apple 开发者证书，如需使用请自行从源码构建。

请从 **信任** 的来源下载！

## 🔖 特点

- `状态图表`（CPU、传感器、GPU 等）, `SSH` 终端, `SFTP`, `Docker & 进程 & Systemd` 管理，`S.M.A.R.T`...
- 特殊支持：`生物认证`、`推送`、`桌面小部件`、`watchOS App`、`跟随系统颜色`...
- 多语言支持
  - English, 简体中文
  - Deutsch [@its-tom](https://github.com/its-tom), 繁體中文 [@kalashnikov](https://github.com/kalashnikov), Indonesian [@azkadev](https://github.com/azkadev), Français [@FrancXPT](https://github.com/FrancXPT), Dutch [@QazCetelic](https://github.com/QazCetelic), Türkçe [@mikropsoft](https://github.com/mikropsoft), Українська мова [@CakesTwix](https://github.com/CakesTwix)
  - Español, Русский язык, Português, 日本語 (GPT 生成)

## 🆘 帮助

- **常见问题** 可以在 [upstream wiki](https://github.com/lollipopkit/flutter_server_box/wiki/主页) 查看。
- 需要在服务器上安装 [ServerBoxMonitor](https://github.com/lollipopkit/server_box_monitor) 来实现推送和桌面小部件功能。

反馈前须知：

1. 反馈问题请附带 log（点击首页右上角），并以 bug 模版提交。
2. 欢迎所有有效、正面的反馈。

## 🧱 贡献

任何正面的贡献都欢迎。

### 开发

1. 安装 [Flutter](https://flutter.dev/docs/get-started/install)
2. 克隆仓库，运行 `flutter run` 启动应用
3. 运行 `dart run fl_build -p PLATFORM` 构建应用

### 翻译

[指南](https://blog.lpkt.cn/faq/) 可在原作者的博客中找到。

## 📦 同步服务端

配套的同步服务端仓库：[flutter-sync-server](https://github.com/onepve/flutter-sync-server)（FastAPI + MySQL + Docker）

## 📝 协议

`AGPL v3` — 基于 [lollipopkit/flutter_server_box](https://github.com/lollipopkit/flutter_server_box)
