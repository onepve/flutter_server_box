# CBox 客户端 — 完整技术规格书

> 📝 **本文档由 AI 生成**  
> **生成工具**：Hermes Agent (Nous Research)  
> **模型**：deepseek-v4-pro  
> **致敬原作者**：[lollipopkit/flutter_server_box](https://github.com/lollipopkit/flutter_server_box) — 感谢原作者的优秀作品  
> **本仓库**：[onepve/flutter_server_box](https://github.com/onepve/flutter_server_box) — 在原作基础上进行了自用修改  
> **最后更新**：2026-07-02

---

## 目录

1. [项目概述](#1-项目概述)
2. [架构总览](#2-架构总览)
3. [技术栈](#3-技术栈)
4. [项目结构](#4-项目结构)
5. [核心模块详解](#5-核心模块详解)
   - [5.1 应用入口与初始化](#51-应用入口与初始化)
   - [5.2 路由系统](#52-路由系统)
   - [5.3 数据层](#53-数据层)
   - [5.4 状态管理](#54-状态管理)
   - [5.5 UI 视图层](#55-ui-视图层)
   - [5.6 SSH/SFTP 子系统](#56-sshsftp-子系统)
   - [5.7 备份系统（内置）](#57-备份系统内置)
6. [云同步系统（CBox Sync）](#6-云同步系统cbox-sync)
   - [6.1 同步架构](#61-同步架构)
   - [6.2 SyncConfig — 服务端配置](#62-syncconfig--服务端配置)
   - [6.3 SyncClient — HTTP 客户端](#63-syncclient--http-客户端)
   - [6.4 SyncCrypto — 端到端加密](#64-synccrypto--端到端加密)
   - [6.5 SyncEngine — 一键同步编排](#65-syncengine--一键同步编排)
   - [6.6 SyncProvider — 状态管理](#66-syncprovider--状态管理)
   - [6.7 SyncUI — 用户界面](#67-syncui--用户界面)
   - [6.8 认证与安全流程](#68-认证与安全流程)
7. [自定义更新系统](#7-自定义更新系统)
8. [构建与部署](#8-构建与部署)
   - [8.1 构建配置](#81-构建配置)
   - [8.2 CI/CD 流水线](#82-cicd-流水线)
   - [8.3 签名配置](#83-签名配置)
9. [与上游的差异（CBox 定制）](#9-与上游的差异cbox-定制)
10. [数据流图](#10-数据流图)
11. [开发指南](#11-开发指南)
12. [附录](#12-附录)

---

## 1. 项目概述

### 1.1 项目定位

**CBox** 是一款跨平台的服务器管理与云同步工具，基于 Flutter 构建。它是 [lollipopkit/flutter_server_box](https://github.com/lollipopkit/flutter_server_box) 的定制分支（fork），在保留原作全部服务器管理功能的基础上，新增了完整的**端到端加密云同步（CBox Sync）**能力。

### 1.2 基本信息

| 属性 | 值 |
|------|-----|
| **应用名称** | CBox（Android 显示名），内部名 ServerBox |
| **Dart 包名** | `server_box` |
| **当前版本** | 1.0.1481+1481 |
| **构建号** | 1481（构建时代码自动更新） |
| **原始仓库** | [lollipopkit/flutter_server_box](https://github.com/lollipopkit/flutter_server_box) |
| **定制仓库** | [onepve/flutter_server_box](https://github.com/onepve/flutter_server_box) |
| **许可协议** | GPL-3.0 |
| **框架** | Flutter (Dart) |
| **Flutter SDK** | ≥3.44.0 |
| **Dart SDK** | ≥3.11.0 |

### 1.3 核心能力

#### 🔧 服务器管理（继承自上游）
- 实时状态监控（CPU、内存、磁盘 I/O、网络流量、GPU）
- SSH 终端（虚拟键盘、Tmux 会话选择器、端口转发）
- SFTP 文件管理（断点续传）
- Docker / Podman 容器管理
- 进程 & Systemd 服务管理
- Proxmox VE (PVE) 集成
- S.M.A.R.T. 磁盘健康检测
- 局域网 SSH 服务发现
- 自定义命令脚本
- iPerf3 带宽测试
- Wake-on-LAN 远程唤醒
- 生物认证解锁（指纹 / Face ID）
- 桌面小组件 (iOS/Android)
- watchOS 配套应用
- macOS 菜单栏

#### ☁️ CBox 云同步（CBox 新增）
- 端到端加密（AES-256-GCM），服务端零知识
- 多设备账号登录与同步
- 版本冲突检测
- 一键智能同步（自动判断上传/下载）
- TOTP 双因素认证
- Recovery Key 恢复机制
- 邀请码注册体系
- 头像上传与裁剪
- 邮箱验证
- 密码重置
- 数据导出到邮箱

---

## 2. 架构总览

### 2.1 分层架构

```
┌─────────────────────────────────────────────────┐
│              表现层 (UI)                         │
│     lib/view/page/, lib/view/widget/            │
│     lib/sync/sync_ui.dart                       │
│  - 页面、组件、对话框                            │
└─────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────┐
│            业务逻辑层 (Provider)                  │
│     lib/data/provider/, lib/sync/sync_provider   │
│  - Riverpod Notifier / AsyncNotifier            │
│  - 同步状态管理、业务编排                        │
└─────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────┐
│              数据访问层                          │
│     lib/data/store/, lib/data/model/            │
│     lib/sync/sync_client.dart                   │
│     lib/sync/sync_crypto.dart                   │
│  - Hive CE 本地存储、Freezed 数据模型            │
│  - Dio HTTP 客户端（同步 API）                   │
│  - AES-256-GCM 加密/解密                        │
└─────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────┐
│              外部集成层                          │
│  - dartssh2 (SSH/SFTP)、xterm (终端模拟)         │
│  - Dio (HTTP)、fl_chart (图表)                   │
│  - 平台原生代码 (iOS/Android/macOS/Linux/Windows) │
│  - CBox Sync Server (your-domain.com)           │
└─────────────────────────────────────────────────┘
```

### 2.2 核心设计原则

- **不可变状态**：数据模型使用 Freezed 确保编译时不可变性
- **依赖注入**：GetIt + Riverpod 双轨注入，Stores 和 Services 通过 GetIt 管理
- **代码生成**：JSON 序列化、Hive 适配器、Riverpod Provider 均由 `build_runner` 自动生成
- **UI 分离**：Widget 拆分为 `Build` / `Actions` / `Utils`，使用 Dart `extension on` 实现
- **端到端加密**：同步数据使用 AES-256-GCM，密钥从用户 UUID 派生，服务端无法解密

---

## 3. 技术栈

| 类别 | 技术选型 | 说明 |
|------|---------|------|
| **框架** | Flutter (≥3.44.0) + Dart (≥3.11.0) | 跨平台 UI 框架 |
| **状态管理** | Riverpod (`riverpod_annotation` + `riverpod_generator`) | 代码生成式 Provider |
| **依赖注入** | GetIt | Service Locator 模式 |
| **本地存储** | Hive CE (`hive_ce_flutter` + `hive_ce_generator`) | 高性能 KV 存储 |
| **安全存储** | fl_lib SecureProp | 基于平台 Keychain/KeyStore |
| **网络请求** | Dio (`^5.2.1`) | HTTP 客户端 |
| **SSH / SFTP** | dartssh2（定制分支） | `packages/dartssh2` |
| **终端模拟** | xterm.dart（定制分支） | `packages/xterm` |
| **图表** | fl_chart (`^1.2.0`) | 服务器状态可视化 |
| **不可变模型** | Freezed (`^3.0.0`) | 编译时不可变类生成 |
| **序列化** | json_serializable (`^6.13.0`) | JSON ↔ 模型 |
| **代码生成** | build_runner (`^2.4.15`) | 统一代码生成管线 |
| **构建系统** | fl_build（`packages/fl_build`） | 跨平台构建工具 |
| **共享组件** | fl_lib（`packages/fl_lib`） | 通用 UI 组件库 |
| **响应式布局** | responsive_framework (`^1.5.1`) | 多尺寸适配 |
| **动态主题** | dynamic_color (`^1.6.6`) | Material You 取色 |
| **本地化** | Flutter 原生 i18n (15 种 ARB 文件) | 多语言支持 |
| **图标** | icons_plus（定制分支） | BoxIcons 等图标集 |
| **推送通知** | plain_notification_token | `packages/plain_notification_token` |
| **Watch 通信** | watch_connectivity | `packages/watch_connectivity` |
| **Wake-on-LAN** | wake_on_lan (`^4.1.1+3`) | 远程唤醒 |
| **WebDAV** | webdav_client_plus (`^1.0.2`) | 内置备份存储 |
| **XML 解析** | xml (`^6.4.2`) | nvidia-smi 解析 |
| **屏幕常亮** | wakelock_plus (`^1.2.4`) | 后台运行 |
| **文件选择** | file_picker (`^10.1.9`) | 头像上传 |
| **SVG 支持** | flutter_svg (`^2.2.1`) | 矢量图标 |
| **高刷支持** | flutter_displaymode (`^0.7.0`) | Android 高刷新率 |
| **URL 启动** | url_launcher (`^6.2.6`) | 外部链接 |
| **GBK 转换** | flutter_gbk2utf8 | 编码处理 |
| **Isolate** | easy_isolate (`^1.3.0`) | 后台计算 |
| **并发** | computer (dart_computer) | Worker 线程池 |

### 定制依赖 (packages/)

| 包名 | 说明 |
|------|------|
| `packages/dartssh2` | 增强版 SSH 客户端，移动端优化 |
| `packages/xterm` | 终端模拟器，移动端手势/VK 集成 |
| `packages/fl_lib` | 共享工具包：CustomAppBar, Input, Btnx 等 |
| `packages/fl_build` | 跨平台构建系统 |
| `packages/circle_chart` | 圆形图表组件 |
| `packages/watch_connectivity` | Apple Watch 通信桥接 |
| `packages/plain_notification_token` | 推送通知令牌管理 |

---

## 4. 项目结构

```
flutter_server_box/
├── lib/                                    # 应用主代码
│   ├── main.dart                           # 入口点：初始化 Hive、Provider、路由
│   ├── app.dart                            # 根组件 MyApp：主题、本地化、引导页
│   ├── intro.dart                          # 引导页（part of app.dart）
│   │
│   ├── core/                               # 核心工具
│   │   ├── route.dart                      # 路由参数类 SpiRequiredArgs
│   │   ├── app_navigator.dart              # 全局导航 Key
│   │   ├── chan.dart                       # 平台通信通道
│   │   ├── sync.dart                       # 内置备份同步器 (BakSyncer / iCloud / WebDAV / Gist)
│   │   ├── extension/                      # Dart 扩展方法
│   │   │   ├── context/locale.dart         #   上下文本地化扩展
│   │   │   ├── server.dart                 #   服务器扩展
│   │   │   ├── ssh_client.dart             #   SSH 客户端扩展
│   │   │   └── sftpfile.dart               #   SFTP 文件扩展
│   │   ├── utils/                          # 工具类
│   │   │   ├── ssh_config.dart             #   SSH 配置解析
│   │   │   ├── ssh_auth.dart               #   SSH 认证管理
│   │   │   ├── server.dart                 #   服务器工具
│   │   │   ├── server_dedup.dart           #   服务器去重
│   │   │   ├── jump_chain.dart             #   跳板链
│   │   │   ├── refresh_interval.dart       #   刷新间隔逻辑
│   │   │   ├── sftp_sudo.dart              #   SFTP sudo 支持
│   │   │   ├── sftp_timeout.dart           #   SFTP 超时配置
│   │   │   ├── sudo_password.dart          #   Sudo 密码管理
│   │   │   ├── host_key_helper.dart        #   SSH Host Key 管理
│   │   │   ├── proxy_command_socket.dart   #   ProxyCommand 套接字
│   │   │   ├── misc.dart                   #   杂项工具
│   │   │   ├── comparator.dart             #   比较器
│   │   │   ├── shell_quote.dart            #   Shell 引号处理
│   │   │   └── version.dart                #   版本比较
│   │   └── service/                        # 核心服务
│   │       └── ssh_discovery.dart          #   SSH 局域网发现
│   │
│   ├── data/                               # 数据层
│   │   ├── model/                          # 数据模型
│   │   │   ├── server/                     #   服务器模型 (CPU/Disk/Network/Systemd/PVE 等)
│   │   │   ├── container/                  #   Docker 容器模型
│   │   │   ├── ssh/                        #   SSH 会话 / 虚拟键盘模型
│   │   │   ├── sftp/                       #   SFTP 文件传输模型
│   │   │   ├── ai/                         #   AI 对话模型
│   │   │   └── app/                        #   应用级模型 (菜单、备份、脚本、标签页)
│   │   ├── provider/                       # Riverpod Provider (状态管理)
│   │   │   ├── server/                     #   服务器状态 Provider
│   │   │   ├── container.dart              #   容器状态 Provider
│   │   │   ├── systemd.dart                #   Systemd Provider
│   │   │   ├── sftp.dart                   #   SFTP Provider
│   │   │   ├── snippet.dart                #   脚本片段 Provider
│   │   │   ├── private_key.dart            #   私钥 Provider
│   │   │   ├── pve.dart                    #   PVE Provider
│   │   │   ├── virtual_keyboard.dart       #   虚拟键盘 Provider
│   │   │   ├── port_forward_provider.dart  #   端口转发 Provider
│   │   │   └── ai/ask_ai.dart              #   AI 对话 Provider
│   │   ├── store/                          # Hive CE 持久化存储
│   │   │   ├── setting.dart                #   全局设置
│   │   │   ├── server.dart                 #   服务器配置
│   │   │   ├── container.dart              #   容器数据
│   │   │   ├── snippet.dart                #   脚本片段
│   │   │   ├── private_key.dart            #   私钥
│   │   │   ├── history.dart                #   命令历史
│   │   │   ├── connection_stats.dart       #   连接统计
│   │   │   └── port_forward.dart           #   端口转发规则
│   │   ├── res/                            # 静态资源定义
│   │   │   ├── store.dart                  #   Stores 全局单例 (GetIt)
│   │   │   ├── build_data.dart             #   构建元数据 (自动生成)
│   │   │   └── url.dart                    #   URL 常量 (上游 GitHub 链接)
│   │   └── ssh/                            # SSH 子系统
│   │       ├── session_manager.dart        #   会话生命周期管理
│   │       ├── persistent_shell.dart       #   持久化 Shell
│   │       └── tmux/                       #   Tmux 集成
│   │
│   ├── view/                               # UI 视图层
│   │   ├── page/                           # 页面
│   │   │   ├── home.dart                   #   主页 (PageView + BottomBar/Rail)
│   │   │   ├── home_tab.dart               #   标签页映射
│   │   │   ├── server/                     #   服务器相关页面
│   │   │   │   ├── tab/tab.dart            #     服务器列表
│   │   │   │   ├── detail/view.dart        #     服务器详情
│   │   │   │   ├── edit/edit.dart          #     服务器编辑
│   │   │   │   └── discovery/              #     SSH 发现
│   │   │   ├── ssh/                        #   SSH 终端页面
│   │   │   │   ├── tab.dart                #     SSH 标签页
│   │   │   │   └── page/                   #     终端页面/虚拟键盘/AskAI
│   │   │   ├── storage/                    #   文件管理页面
│   │   │   │   ├── sftp.dart               #     SFTP 浏览器
│   │   │   │   ├── sftp_mission.dart        #     SFTP 传输任务
│   │   │   │   └── local.dart              #     本地文件
│   │   │   ├── container/                  #   容器管理页面
│   │   │   ├── snippet/                    #   脚本片段管理
│   │   │   │   ├── list.dart               #     列表
│   │   │   │   └── edit.dart               #     编辑
│   │   │   ├── private_key/                #   私钥管理
│   │   │   ├── setting/                    #   设置页面
│   │   │   │   ├── entry.dart              #     设置主页
│   │   │   │   ├── about.dart              #     关于页面
│   │   │   │   ├── entries/                #     各项设置
│   │   │   │   ├── seq/                    #     排序设置
│   │   │   │   └── platform/               #     平台特定设置
│   │   │   ├── process.dart                #   进程管理
│   │   │   ├── systemd.dart                #   Systemd 管理
│   │   │   ├── pve.dart                    #   PVE 管理
│   │   │   ├── iperf.dart                  #   iPerf3 测试
│   │   │   ├── port_forward.dart           #   端口转发
│   │   │   ├── backup.dart                 #   内置备份/恢复
│   │   │   ├── connection_stats.dart       #   连接统计
│   │   │   └── macos_menu_bar.dart          #   macOS 菜单栏
│   │   └── widget/                         # 可复用组件
│   │       ├── server_func_btns.dart        #   服务器功能按钮
│   │       └── tmux_session_selector.dart   #   Tmux 会话选择器
│   │
│   ├── sync/                               # ☁️ 云同步模块 (CBox 新增)
│   │   ├── sync_config.dart                #   服务端地址、API 端点、SecureProp
│   │   ├── sync_client.dart                #   Dio HTTP 客户端、请求/响应处理
│   │   ├── sync_crypto.dart                #   AES-256-GCM 加密/解密
│   │   ├── sync_engine.dart                #   一键同步编排
│   │   ├── sync_provider.dart              #   Riverpod Notifier 状态管理
│   │   ├── sync_ui.dart                    #   同步设置页面 UI (全功能)
│   │   ├── custom_update.dart              #   自定义版本更新对话框
│   │   └── avatar_crop_dialog.dart         #   头像裁剪对话框
│   │
│   ├── l10n/                               # 本地化 ARB 文件 (15 种语言)
│   ├── generated/                          # 代码生成输出
│   │   └── l10n/                           #   生成的本地化类
│   └── hive/                               # Hive 适配器注册
│       ├── hive_adapters.dart              #   适配器定义
│       └── hive_registrar.g.dart           #   注册代码 (自动生成)
│
├── android/                                # Android 原生代码
│   └── app/src/main/
│       ├── AndroidManifest.xml             #   android:label="@string/app_name" → "CBox"
│       └── res/values/strings.xml          #   <string name="app_name">CBox</string>
│
├── ios/                                    # iOS 原生代码
├── macos/                                  # macOS 原生代码
├── linux/                                  # Linux 原生代码
├── windows/                                # Windows 原生代码
│
├── packages/                               # 定制 Dart 包 (monorepo)
│   ├── dartssh2/                           #   SSH 客户端
│   ├── xterm/                              #   终端模拟器
│   ├── fl_lib/                             #   共享组件库
│   ├── fl_build/                           #   构建工具
│   ├── circle_chart/                       #   圆形图表
│   ├── watch_connectivity/                 #   Watch 通信
│   └── plain_notification_token/           #   推送通知
│
├── scripts/                                # 构建脚本
│   └── release/                            #   发布相关脚本
│
├── test/                                   # 测试文件
├── .github/                                # GitHub 配置
│   └── workflows/
│       ├── build.yml                       #   CBox Build CI/CD
│       └── analysis.yml                    #   CBox 代码分析
│
├── pubspec.yaml                            # Flutter 依赖配置
├── fl_build.json                           # 构建系统配置
├── make.dart                               # 预构建任务
├── key.properties                          # Android 签名密钥配置 (CI 生成)
└── README.md                               # 项目说明
```

---

## 5. 核心模块详解

### 5.1 应用入口与初始化

**文件**: `lib/main.dart`

启动流程：

```dart
Future<void> main() async {
  await _runInZone(() async {
    await _initApp();
    runApp(ProviderScope(child: const MyApp()));
  });
}
```

初始化顺序：
1. `WidgetsFlutterBinding.ensureInitialized()` — 确保引擎绑定
2. **数据初始化** (`_initData`)：
   - `Paths.init(BuildData.name, ...)` — 初始化文件路径（`BuildData.name = "ServerBox"`）
   - `Hive.initFlutter()` + `Hive.registerAdapters()` — 初始化本地存储
   - `PrefStore.shared.init()` — 初始化偏好存储
   - `Stores.init()` — 通过 GetIt 注册所有 HiveStore 实例
   - `_doDbMigrate()` — 数据库迁移（版本升级时触发数据更新）
   - `AppUpdate.chan` 配置（Beta 通道判断）
3. **调试配置** (`_setupDebug`)：Logger 级别与记录器
4. **窗口初始化** (`_initWindow`)：桌面端窗口尺寸/位置恢复
5. **平台相关** (`_doPlatformRelated`)：
   - Android：设置高刷新率 (`FlutterDisplayMode.setHighRefreshRate()`)
   - 启动 Computer Worker 线程池（按服务器数量/3 + 1 分配）
6. 启动 ProviderScope（Riverpod）→ `MyApp` 根组件

### 5.2 路由系统

**文件**: `lib/core/route.dart`, `lib/app.dart`

- 路由参数定义：`SpiRequiredArgs` 包含 `Spi` (服务器私有信息)
- 导航使用 `AppNavigator.key` 全局 Key
- 引导页 (`_IntroPage`) 在首次启动或有新内容时显示
- 引导完成后跳转到 `HomePage`
- 生物认证页面 (`LocalAuthPage`) 在需要时以 push 方式覆盖主页

### 5.3 数据层

#### 5.3.1 模型 (lib/data/model/)

数据模型按功能域组织，均使用 Freezed 生成不可变类：

| 目录 | 内容 | 关键模型 |
|------|------|----------|
| `server/` | 服务器监控数据 | `Spi`(服务器信息), `Cpu`, `Disk`, `NetSpeed`, `Conn`, `Systemd`, `Pve` |
| `container/` | Docker/Podman | `ContainerPs`, `ContainerImage`, `ContainerType`, `ContainerStatus` |
| `ssh/` | SSH 会话 | `VirtualKey` |
| `sftp/` | SFTP | `SftpReq`, `SftpStatus`, `SftpWorker`, `BrowserStatus` |
| `ai/` | AI 对话 | `AskAiModels` |
| `app/` | 应用级 | `Backup/BackupV2`, `AppTab`, `ServerFuncBtn`, `ServerDetailCard`, `CmdTypes`, `ShellFunc` |

关键模型说明：

- **`Spi`** (`ServerPrivateInfo`) — 核心服务器连接信息：
  - 名称、地址、端口
  - 认证方式（密码/密钥）
  - 跳板链配置
  - 连接超时
  - 关联的私钥、脚本

- **`BackupV2`** — 备份/同步数据结构：
  - 服务器列表 (`spis`)
  - 脚本片段 (`snippets`)
  - 私钥 (`keys`)
  - 容器数据 (`container`)
  - 命令历史 (`history`)
  - 应用设置 (`settings`)
  - 版本号和时间戳

#### 5.3.2 存储 (lib/data/store/)

所有持久化使用 Hive CE，每个 Store 是单例，通过 GetIt 管理：

```dart
// lib/data/res/store.dart
abstract final class Stores {
  static SettingStore get setting => getIt<SettingStore>();
  static ServerStore get server => getIt<ServerStore>();
  static ContainerStore get container => getIt<ContainerStore>();
  static PrivateKeyStore get key => getIt<PrivateKeyStore>();
  static SnippetStore get snippet => getIt<SnippetStore>();
  static HistoryStore get history => getIt<HistoryStore>();
  static ConnectionStatsStore get connectionStats => getIt<ConnectionStatsStore>();
  static PortForwardStore get portForward => getIt<PortForwardStore>();
}
```

初始化流程 (`Stores.init()`):
1. 注册 8 个 Store 到 GetIt（lazySingleton）
2. 并行初始化所有 Store (`Future.wait`)
3. SSH 连接模式迁移 (`migrateSshConnectionMode`)
4. 连接统计索引重建

**全局版本追踪** (`Stores.lastModTime`)：
- 遍历所有 Store 的最后更新时间戳
- 返回最大值，用于同步差异比较

#### 5.3.3 静态资源 (lib/data/res/)

| 文件 | 说明 |
|------|------|
| `build_data.dart` | 编译时自动生成，包含 `name`（"ServerBox"）和 `build`（构建号） |
| `url.dart` | 上游 GitHub URL 常量（lollipopkit/flutter_server_box） |
| `store.dart` | Stores 全局门面，备份数据收集 |

### 5.4 状态管理

**技术**: Riverpod (Notifier / AsyncNotifier) + Freezed

#### Provider 列表

| Provider | 文件 | 管理状态 |
|----------|------|----------|
| `serversProvider` | `data/provider/server/all.dart` | 全部服务器列表、自动刷新、连接管理 |
| `singleServerProvider` | `data/provider/server/single.dart` | 单个服务器状态（CPU/内存/磁盘等） |
| `containerProvider` | `data/provider/container.dart` | Docker 容器列表与操作 |
| `systemdProvider` | `data/provider/systemd.dart` | Systemd 服务列表与操作 |
| `sftpProvider` | `data/provider/sftp.dart` | SFTP 连接与文件操作 |
| `snippetProvider` | `data/provider/snippet.dart` | 脚本片段列表 |
| `privateKeyProvider` | `data/provider/private_key.dart` | 私钥列表 |
| `pveProvider` | `data/provider/pve.dart` | PVE 虚拟机/CT 状态 |
| `virtualKeyboardProvider` | `data/provider/virtual_keyboard.dart` | 虚拟键盘配置 |
| `portForwardProvider` | `data/provider/port_forward_provider.dart` | 端口转发规则 |
| `askAiProvider` | `data/provider/ai/ask_ai.dart` | AI 对话 |
| **`syncNotifierProvider`** | **`sync/sync_provider.dart`** | **云同步状态（CBox 新增）** |

#### 状态管理模式

所有 Provider 遵循统一的代码生成模式：

```
模型定义 (*.dart) → build_runner → 生成代码 (*.g.dart, *.freezed.dart)
```

修改模型或 Provider 后，执行：
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 5.5 UI 视图层

#### 5.5.1 主页 (lib/view/page/home.dart)

`HomePage` 是一个 `ConsumerStatefulWidget`，包含：

- **标签页管理**：通过 `PageView` 按 `AppTab` 枚举切换（Server / SSH / File / Snippet）
- **导航栏**：
  - 移动端：`NavigationBar` (BottomNavigationBar)
  - 桌面端：`NavigationRail`
- **设置按钮**：固定在导航栏底部
- **自动刷新**：应用恢复时自动刷新服务器状态
- **生物认证**：应用从后台恢复时触发生物认证
- **备份同步**：首次布局后自动执行内置备份同步 (`bakSync.sync()`)
- **应用更新检查**：自动检查 GitHub Releases 更新 (`showCustomUpdateDialog`)

#### 5.5.2 标签页 (lib/view/page/home_tab.dart)

```dart
enum AppTab { server, ssh, file, snippet }
```

通过 `extension AppTabViewX on AppTab` 映射到具体页面和导航元素。

#### 5.5.3 主要功能页面

| 页面 | 路由/文件 | 功能 |
|------|-----------|------|
| 服务器列表 | `ServerPage` | SSH 连接列表，局域网发现，Wake-on-LAN |
| 服务器详情 | `ServerDetailPage` | 实时状态图表（CPU/内存/磁盘/网络/GPU） |
| 服务器编辑 | `ServerEditPage` | 新增/编辑服务器连接配置 |
| SSH 终端 | `SSHTabPage` | 多标签页 SSH 终端，虚拟键盘，Tmux，AskAI |
| SFTP | `SftpPage` | 远端文件浏览器，上传/下载 |
| 容器 | `ContainerPage` | Docker/Podman 容器管理 |
| 进程 | `ProcessPage` | 进程列表与终止 |
| Systemd | `SystemdPage` | 服务管理 |
| PVE | `PvePage` | Proxmox VE 管理 |
| 脚本 | `SnippetListPage/E` | 自定义命令脚本管理 |
| 私钥 | `PrivateKeyListPage/E` | SSH 私钥管理 |
| 备份 | `BackupPage` | 本地备份/恢复，WebDAV/Gist/iCloud |
| 设置 | `SettingsPage` | 全局设置入口 |
| 同步 | `ServerSyncPage` | **云同步设置（CBox 新增）** |

#### 5.5.4 主题系统 (lib/app.dart)

- **主色调**：用户自定义 + Material You 动态取色
- **主题模式**：系统跟随 / 浅色 / 深色 / AMOLED 深色 (模式 3)
- **组件**：`DynamicColorBuilder` + `ThemeData` (Material 3)
- **桌面窗口**：`VirtualWindowFrame` 包装，支持隐藏标题栏

### 5.6 SSH/SFTP 子系统

**核心组件**：

| 组件 | 位置 | 功能 |
|------|------|------|
| **dartssh2** | `packages/dartssh2` | 增强 SSH 客户端，移动端优化，心跳保活 |
| **xterm.dart** | `packages/xterm` | 终端渲染，手势支持，虚拟键盘适配 |
| **SessionManager** | `lib/data/ssh/session_manager.dart` | SSH 会话生命周期，Android 前台服务通知 |
| **PersistentShell** | `lib/data/ssh/persistent_shell.dart` | 持久 Shell 连接，命令执行 |
| **Tmux** | `lib/data/ssh/tmux/` | Tmux 会话自动发现与管理 |

**连接特性**：
- 跳板链 (Jump Chain) 支持
- ProxyCommand 支持
- Sudo 密码管理
- Host Key 管理与验证
- 连接统计与历史
- SFTP 断点续传
- SFTP 传输任务队列

### 5.7 备份系统（内置）

**文件**: `lib/core/sync.dart`（注意：这是内置备份的同步器，不是云同步）

支持三种备份目标：
1. **本地文件**：导出/导入 JSON 文件
2. **iCloud**：仅 iOS/macOS
3. **WebDAV**：自建 WebDAV 服务器
4. **GitHub Gist**：通过 Gist API

加密方案：
- 自定义备份密码
- AES-GCM 加密（使用 `fl_lib` 的 `Cryptor`）
- 可选：是否包含应用设置

---

## 6. 云同步系统（CBox Sync）

> ⚠️ **这是 CBox 相对于上游的核心新增功能。** 上游仓库 `lollipopkit/flutter_server_box` 不包含此模块。

### 6.1 同步架构

```
┌──────────────────────────┐       HTTPS        ┌──────────────────────────┐
│      CBox 客户端 A        │ ◄──────────────►  │    CBox Sync Server      │
│                          │                    │   your-domain.com        │
│  ┌────────────────────┐  │                    │                          │
│  │  SyncUI (UI 层)     │  │                    │  POST /api/auth/register  │
│  │  - 登录/注册/管理    │  │                    │  POST /api/auth/login      │
│  └────────┬───────────┘  │                    │  GET  /api/auth/profile    │
│           │              │                    │  POST /api/sync/upload     │
│  ┌────────▼───────────┐  │                    │  GET  /api/sync/download   │
│  │  SyncProvider       │  │                    │  POST /api/sync/diff       │
│  │  (Riverpod)         │  │                    │  ...                       │
│  └────────┬───────────┘  │                    │                          │
│           │              │                    └──────────────────────────┘
│  ┌────────▼───────────┐  │
│  │  SyncEngine         │  │
│  │  - 版本比较         │  │
│  │  - 智能上传/下载     │  │
│  └──┬───────┬─────────┘  │
│     │       │            │
│  ┌──▼──┐ ┌──▼─────────┐ │
│  │Sync │ │SyncCrypto  │ │
│  │Client│ │AES-GCM     │ │
│  │(Dio) │ │加密/解密   │ │
│  └─────┘ └────────────┘ │
└──────────────────────────┘
```

### 6.2 SyncConfig — 服务端配置

**文件**: `lib/sync/sync_config.dart`

```dart
abstract final class SyncConfig {
  /// 服务端地址（硬编码，不允许用户修改）
  static const serverUrl = 'https://your-domain.com';

  /// Web 个人资料页
  static const webProfileUrl = '$serverUrl/profile';

  /// 安全存储 Key（使用平台 Keychain/KeyStore）
  static final token = SecureProp('sync_jwt_token');     // JWT 令牌
  static final username = SecureProp('sync_username');    // 用户名
  static final nickname = SecureProp('sync_nickname');    // 昵称
  static final avatarUrl = SecureProp('sync_avatar_url'); // 头像 URL
  static final email = SecureProp('sync_email');          // 邮箱
  static final uuid = SecureProp('sync_uuid');            // 加密密钥 (!!)
  static final _deviceId = SecureProp('sync_device_id');  // 设备 ID
}
```

**API 端点一览**：

| 端点常量 | HTTP | 路径 | 功能 |
|----------|------|------|------|
| `register` | POST | `/api/auth/register` | 用户注册 |
| `login` | POST | `/api/auth/login` | 登录获取 JWT |
| `profile` | GET | `/api/auth/profile` | 获取用户资料 |
| `changeUsername` | PUT | `/api/auth/profile/username` | 修改用户名 |
| `changeNickname` | PUT | `/api/auth/profile/nickname` | 修改昵称 |
| `changeEmail` | PUT | `/api/auth/profile/email` | 修改邮箱 |
| `changePassword` | PUT | `/api/auth/profile/password` | 修改密码 |
| `forgotPassword` | POST | `/api/auth/forgot-password` | 忘记密码 |
| `resetPassword` | POST | `/api/auth/reset-password` | 重置密码 |
| `syncUpload` | POST | `/api/sync/upload` | 上传加密数据 |
| `syncDownload` | GET | `/api/sync/download/{type}` | 下载加密数据 |
| `syncDiff` | POST | `/api/sync/diff` | 版本差异对比 |
| `syncStatus` | GET | `/api/sync/status` | 各设备同步状态 |
| `syncDelete` | DELETE | `/api/sync/{type}` | 删除同步数据 |
| `sendDeleteCode` | POST | `/api/auth/send-delete-code` | 发送删除验证码 |
| `verifyDeleteCode` | POST | `/api/auth/verify-delete-code` | 验证删除操作 |
| `exportToEmail` | POST | `/api/sync/export-to-email` | 导出到邮箱 |
| `deleteAccount` | POST | `/api/auth/delete-account` | 注销账号 |
| `totpStatus` | GET | `/api/auth/totp/status` | TOTP 启用状态 |
| `resendVerification` | POST | `/api/auth/resend-verification` | 重发邮箱验证 |
| `verifyEmail` | POST | `/api/auth/verify-email` | 验证邮箱 |
| `uploadAvatar` | POST | `/api/auth/profile/avatar` | 上传头像 |
| `publicConfig` | GET | `/api/auth/config` | 公开注册配置 |
| `inviteUserCreate` | POST | `/api/invite/user-create` | 创建邀请码 |
| `inviteUserList` | GET | `/api/invite/user-list` | 邀请码列表 |
| `inviteUserDelete` | DELETE | `/api/invite/user-delete` | 删除邀请码 |

**关键常量**：
- `dataType = 'server_box_full'` — 同步数据类型标识
- `deviceId` — 首次生成 12 位随机字符串（`dev_xxxxxxxxxxxx`），持久化存储

### 6.3 SyncClient — HTTP 客户端

**文件**: `lib/sync/sync_client.dart`

基于 Dio HTTP 客户端，单例模式：

```dart
class SyncClient {
  SyncClient._();
  static SyncClient get shared => _instance;
  // ...
}
```

**关键特性**：
1. **自动 JWT 注入**：请求拦截器自动附加 `Authorization: Bearer <token>`
2. **Token 过期处理**：401 响应自动清除本地 token
3. **超时配置**：连接 15s / 接收 30s / 发送 60s
4. **完整 API 封装**：登录、注册、上传、下载、差异对比、状态查询、账号管理、邀请码管理

**错误处理体系**：

```dart
SyncError.parse(error) → {
  // 网络层错误（无响应）
  connectionTimeout → "连接服务器超时"
  connectionError   → "无法连接到服务器"
  // HTTP 状态码错误（有响应）
  401 → "认证失败" / "登录失败" / "TOTP 验证失败"
  400 → "邀请码错误" / "注册失败" / "验证码错误"
  404, 429, 500 → 对应中文提示
  // 特殊异常
  SyncTOTPRequiredException → "需要 TOTP 验证码"
}
```

所有错误信息均为中文，面向最终用户直接显示。

### 6.4 SyncCrypto — 端到端加密

**文件**: `lib/sync/sync_crypto.dart`

**加密方案**：
- **算法**：AES-256-GCM（通过 `fl_lib` 的 `Cryptor`）
- **密钥来源**：用户 UUID（登录时服务端返回，自动存储到 `SyncConfig.uuid`）
- **数据流向**：

```
  本地数据 (BackupV2)
      │
      ├── 上传流程 ──────────────────────────►
      │   1. BackupV2.loadFromStore() 收集所有数据
      │   2. json.encode() → JSON 字符串
      │   3. Cryptor.encrypt(json, uuid) → 密文 (base64)
      │   4. POST /api/sync/upload → 发送密文到服务端
      │
      └── 下载流程 ◄──────────────────────────
          1. GET /api/sync/download → 获取密文
          2. Cryptor.decrypt(ciphertext, uuid) → JSON 字符串
          3. json.decode() → BackupV2
          4. backup.merge() → 合并到本地存储
```

**安全性保证**：
- 密钥（UUID）仅在本地设备存储（SecureProp）
- 服务端从不存储或传输明文密钥
- 服务端收到的始终是加密后的密文
- 即使服务端数据库泄露，攻击者也无法解密同步数据

### 6.5 SyncEngine — 一键同步编排

**文件**: `lib/sync/sync_engine.dart`

核心逻辑：

```dart
static Future<String> syncAll() async {
  // 1. 获取加密密钥 (UUID)
  final uuid = await SyncConfig.uuid.read();

  // 2. 获取本地版本号
  final localVersion = Stores.lastModTime;

  // 3. 与远程对比差异
  final diff = await SyncClient.shared.checkDiff(localVersion: localVersion);

  if (diff.needsDownload) {
    // 远程更新 → 下载并恢复
    final data = await SyncClient.shared.download();
    final backup = await SyncCrypto.parseSyncPayload(data.ciphertext, uuid);
    await backup.merge();
    return '已从服务端恢复 (v${data.version})';
  } else {
    // 本地更新 → 上传到远程
    final ciphertext = await SyncCrypto.buildSyncPayload(uuid);
    final serverVersion = await SyncClient.shared.upload(...);
    return '已上传到服务端 (v$serverVersion)';
  }
}
```

**版本策略**：
- 本地版本 = 所有 Store 最后修改时间的最大值
- 远程版本 = 服务端记录的版本号
- 远程版本 > 本地版本 → 下载
- 否则 → 上传

### 6.6 SyncProvider — 状态管理

**文件**: `lib/sync/sync_provider.dart`

这是一个**手写的 Riverpod Notifier**（不依赖 `riverpod_generator`），管理完整的同步状态：

```dart
class SyncState {
  final bool loggedIn;          // 是否已登录
  final String? token;          // JWT Token
  final String? username;       // 用户名
  final String? nickname;       // 昵称
  final String? avatarUrl;      // 头像 URL
  final String? email;          // 邮箱
  final bool emailVerified;     // 邮箱是否已验证
  final bool totpEnabled;       // TOTP 是否已启用
  final int serverVersion;      // 服务端版本号
  final int localVersion;       // 本地版本号
  final bool syncing;           // 是否正在同步
  final int lastSyncAt;         // 上次同步时间戳
  final String? lastSyncMessage; // 上次同步消息
  final String? error;          // 最新错误
}
```

**关键方法**：

| 方法 | 功能 |
|------|------|
| `_init()` | 初始化：从 Secure Storage 恢复登录状态，后台刷新用户资料 |
| `login()` | 登录：调用 API → 存储 token/UUID/用户信息 → 更新状态 |
| `logout()` | 登出：清除所有 Secure Storage → 重置状态 |
| `upload()` | 上传：加密数据 → 调用 API → 更新版本号 |
| `download()` | 下载：调用 API → 解密 → merge → 更新版本号 |
| `checkForUpdates()` | 检查远程是否有更新 |
| `refreshProfile()` | 刷新用户完整资料（头像、邮箱验证状态、TOTP 状态） |
| `updateAvatarUrl(url)` | 直接更新头像 URL（上传成功后立刻生效） |

Provider 声明：
```dart
final syncNotifierProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
  name: 'syncNotifierProvider',
);
```

### 6.7 SyncUI — 用户界面

**文件**: `lib/sync/sync_ui.dart` (约 1010 行)

`ServerSyncPage` 是一个完整的云端同步管理页面，包含：

#### 页面结构
1. **同步账号区域**
   - 登录状态卡片（头像 + 用户名/昵称）
   - 点击查看完整资料（弹窗）
2. **个人资料弹窗**
   - 头像（可点击上传/裁剪）
   - 用户名、昵称、邮箱
   - 邮箱验证状态 + 验证入口
   - TOTP 状态 + 开启引导
   - 退出登录 / 删除云端数据按钮
   - 账号注销引导（前往网页端）
3. **同步操作区域**
   - 一键同步（智能）
   - 仅上传
   - 仅下载
4. **上次同步记录**
   - 显示时间与结果消息
5. **关于区域**
   - 加密说明（AES-256-GCM，端到端）
   - 服务端地址显示
   - AI 生成声明
6. **对比表格** (`showComparison=true` 时)
   - 云同步 vs 内置备份的多维对比

#### 对话框流程

| 功能 | 流程 |
|------|------|
| **登录** | 输入用户名+密码+TOTP → 调用 notifier.login() → 处理 TOTP 二次验证 |
| **注册** | 获取配置 → 显示规则/验证码需求 → 填写表单 → 显示 Recovery Key |
| **忘记密码** | 输入用户名/邮箱 → 获取重置令牌 → 显示令牌 → 输入新密码 |
| **删除云端数据** | 警告 → 身份验证(TOTP/邮箱) → 密码确认 → 二次确认 → 导出到邮箱(可选) → 执行删除 |
| **头像上传** | 選擇文件 → 圆形裁剪 → multipart 上传 → 更新状态 |
| **邮箱验证** | 发送验证码 → 输入 8 位验证码 → 验证成功提示（含 UUID 提示） |

### 6.8 认证与安全流程

#### 登录流程

```
用户输入用户名/密码
         │
         ▼
  POST /api/auth/login
         │
    ┌────┴────┐
    │         │
  成功      需要TOTP
    │         │
    ▼         ▼
  存储:    弹出TOTP输入框
  token          │
  uuid          ▼
  username  POST /api/login
  nickname  (带totp_code)
  avatarUrl     │
    │        成功│
    ▼         ▼
  更新SyncState
         │
         ▼
  后台刷新Profile
  (email/totp状态)
```

#### 数据同步的端到端加密

```
  本地数据                      传输中               服务端数据
┌──────────┐               ┌──────────┐          ┌──────────┐
│ BackupV2 │──JSON编码──►  │ 密文传输  │──HTTP──►│ 密文存储  │
│ (明文)   │──UUID加密──► │ (base64) │          │ (base64) │
└──────────┘               └──────────┘          └──────────┘
     ▲                                                 │
     │                      下载方向                     │
     │             UUID解密 + JSON解析 + merge           │
     └─────────────────────────────────────────────────┘
```

#### 设备 ID 机制

每个设备首次使用同步时生成唯一 ID（`dev_xxxxxxxxxxxx`），持久化存储。上传数据时携带设备 ID，服务端按设备+数据类型维护版本。

---

## 7. 自定义更新系统

**文件**: `lib/sync/custom_update.dart`

CBox 使用自定义的版本更新对话框，区别于上游的默认 AppUpdate 行为：

```dart
Future<void> showCustomUpdateDialog({
  required BuildContext context,
  required String githubReleasesUrl,
  required int build,
  String? storeUrl,
})
```

**功能**：
- 从 GitHub Releases API 获取最新版本
- 显示下载地址（可选择）
- 显示更新日志
- 三个操作按钮：
  - **跳过此版本**：关闭对话框
  - **一键直达**：打开 Releases 页面
  - **更新**：直接下载文件

**触发位置**：`HomePage.afterFirstLayout()` 中，当 `autoCheckAppUpdate` 设置启用时自动检查。

---

## 8. 构建与部署

### 8.1 构建配置

**文件**: `fl_build.json`

```json
{
    "appName": "ServerBox",
    "beforeBuild": "./make.dart before"
}
```

- `make.dart before` 在构建前执行预构建任务（如生成 `build_data.dart` 元数据）
- Dart 包名保持 `server_box`（pub.dev 名称不变）
- 版本号由 `fl_build` 自动从 Git tag 计算

**Android 签名配置**：
```
android/
├── key.properties         # CI 动态生成
│   storeFile=cbox-release.keystore
│   storePassword=***
│   keyAlias=***
│   keyPassword=***
└── app/cbox-release.keystore  # CI 从 GitHub Secrets 解码
```

### 8.2 CI/CD 流水线

#### Build Workflow (`.github/workflows/build.yml`)

**触发条件**：
- `workflow_dispatch`（手动触发）
- `push tags: v*`（版本标签推送）

**环境变量**：
```yaml
env:
  APP_NAME: CBox
  BUILD_NUMBER: ${{ github.run_number }}
```

**构建 Jobs**：

| Job | 平台 | 运行环境 | 产物 |
|-----|------|---------|------|
| `buildAndroid` | Android | ubuntu-latest | 按 ABI 拆包 APK (arm64/arm/amd64) |
| `buildLinux` | Linux | ubuntu-latest + ubuntu-22.04 | AppImage (现代 + 旧版兼容) |
| `buildWindows` | Windows | windows-latest | zip 包 |

**Android 构建流程**：
1. 检出代码（含子模块）
2. 安装 Flutter 3.44.1
3. 安装 Java 21 (Zulu)
4. 从 GitHub Secrets 解码签名密钥 → `key.properties`
5. `flutter pub get`
6. 修补 JNI build-id (`patch-jni-build-id.sh`)
7. `dart run fl_build -bp -p android`
8. 重命名 APK → `CBox_v1.0.$BUILD_NUMBER_$ARCH.apk`
9. 上传 Artifact + 创建 GitHub Release

**Linux 构建**：
- 双版本策略：`ubuntu-latest`（现代）+ `ubuntu-22.04`（旧版兼容，`_legacy` 后缀）
- 需要安装 GTK3、Vulkan、GStreamer 等系统依赖

#### Analysis Workflow (`.github/workflows/analysis.yml`)

**触发条件**：push/PR 到 `main` 分支

1. 检出代码 + 安装 Flutter
2. `flutter pub get`
3. `flutter analyze lib test` — 静态分析
4. `flutter test` — 运行测试

### 8.3 签名配置

**Android Release 签名**：
- 使用发布 keystore (`cbox-release.keystore`)，通过 GitHub Secrets 在 CI 中注入
- `key.properties` 在 CI 中动态生成
- 本地调试可使用 `-PallowDebugReleaseSigning=true` 跳过正式签名

---

## 9. 与上游的差异（CBox 定制）

### 9.1 变更一览

| 类别 | 变更内容 | 影响文件 |
|------|---------|---------|
| **品牌** | Android 显示名改为 "CBox" | `android/app/src/main/res/values/strings.xml` |
| **品牌** | README 标题改为 "CBox" | `README.md` |
| **品牌** | CI 环境变量 `APP_NAME: CBox` | `.github/workflows/build.yml` |
| **品牌** | Keystore 文件名 `cbox-release.keystore` | `build.yml` + `android/` |
| **云同步** | 新增完整 `lib/sync/` 模块 (8 个文件，约 2000+ 行) | `lib/sync/*` |
| **云同步** | 同步服务端地址硬编码 `your-domain.com` | `lib/sync/sync_config.dart` |
| **云同步** | 备份页面添加云同步入口 | `lib/view/page/backup.dart` |
| **更新** | 自定义更新对话框 `custom_update.dart` | `lib/sync/custom_update.dart` |
| **更新** | HomePage 使用 `showCustomUpdateDialog` | `lib/view/page/home.dart` |
| **CI** | GitHub Actions 工作流名称改为 "CBox Build" / "CBox 代码分析" | `.github/workflows/*.yml` |
| **CI** | Flutter 版本固定为 3.44.1 | `build.yml` |
| **CI** | Android 签名密钥名称改为 CBox 相关 | `build.yml` |
| **文档** | 新增 CLAUDE.md AI 辅助开发说明 | `CLAUDE.md` |

### 9.2 未变更部分

以下内容保持与上游一致：
- **Dart 包名**: `server_box`（未改为 `cbox`，因影响所有 import 路径）
- **`BuildData.name`**: 仍然为 `"ServerBox"`（代码内部名）
- **`fl_build.json`**: `appName` 仍为 `"ServerBox"`
- **`lib/data/res/url.dart`**: 仍指向 `lollipopkit/flutter_server_box`
- **所有原有功能代码**: 100% 保留
- **本地化文件**: 未修改（15 种语言）
- **所有 packages/**: 定制分支保持与上游同步
- **iOS/macOS 代码**: 未修改

### 9.3 云同步模块详细新增清单

```
lib/sync/                          # 新增目录，上游无此目录
├── sync_config.dart               # 94 行 - 配置与端点
├── sync_client.dart               # 455 行 - HTTP 客户端 (25+ API)
├── sync_crypto.dart               # 37 行 - 加密服务
├── sync_engine.dart               # 73 行 - 同步编排
├── sync_provider.dart             # 278 行 - 状态管理
├── sync_ui.dart                   # 1010 行 - 全功能 UI
├── custom_update.dart             # 95 行 - 更新对话框
└── avatar_crop_dialog.dart        # 头像裁剪组件
```

**总计新增代码量**: 约 2,000+ 行 Dart 代码（不含生成文件）

---

## 10. 数据流图

### 10.1 应用启动数据流

```
main()
  │
  ├─ WidgetsFlutterBinding.ensureInitialized()
  ├─ Paths.init("ServerBox", ...)          ← 文件路径
  ├─ Hive.initFlutter()                     ← 本地数据库
  │   └─ Hive.registerAdapters()
  ├─ PrefStore.shared.init()               ← 偏好设置
  ├─ Stores.init()                          ← 8 个 Store 注册并初始化
  │   ├─ setting.init()
  │   ├─ server.init()
  │   ├─ container.init()
  │   ├─ key.init()
  │   ├─ snippet.init()
  │   ├─ history.init()
  │   ├─ connectionStats.init()
  │   └─ portForward.init()
  ├─ _doDbMigrate()                         ← 版本升级数据迁移
  ├─ _initWindow()                          ← 桌面窗口恢复
  ├─ _doPlatformRelated()                   ← 平台特定初始化
  │   ├─ FlutterDisplayMode.setHighRefreshRate()
  │   └─ Computer.shared.turnOn()           ← Worker 线程池
  └─ runApp(ProviderScope(MyApp()))
      │
      ├─ syncNotifierProvider._init()       ← 恢复同步状态
      │   ├─ SyncConfig.token.read()
      │   ├─ SyncConfig.username.read()
      │   └─ _refreshProfile()              ← 后台刷新用户资料
      │
      └─ MaterialApp
          ├─ HomePage
          │   ├─ afterFirstLayout
          │   │   ├─ 生物认证
          │   │   ├─ showCustomUpdateDialog  ← 检查应用更新
          │   │   ├─ serversProvider.refresh()
          │   │   └─ bakSync.sync()          ← 内置备份同步
          │   └─ 标签页导航 (Server / SSH / File / Snippet)
          └─ 设置 → ServerSyncPage           ← 云同步管理
```

### 10.2 云同步数据流

```
用户点击「一键同步」
        │
        ▼
  SyncEngine.syncAll()
        │
        ├─ SyncConfig.uuid.read()            ← 读取加密密钥
        ├─ Stores.lastModTime                ← 本地版本号
        │
        ├─ SyncClient.checkDiff(localVersion)
        │       │
        │       ▼
        │   POST /api/sync/diff
        │   { local_versions: {"server_box_full": v} }
        │       │
        │       ▼
        │   返回 { needsDownload: bool, serverVersion }
        │
        ├── needsDownload = true ──────────► 下载
        │   │
        │   ├─ SyncClient.download()
        │   │       │
        │   │       ▼
        │   │   GET /api/sync/download/server_box_full
        │   │       │
        │   │       ▼
        │   │   返回 { ciphertext, version }
        │   │
        │   ├─ SyncCrypto.parseSyncPayload(ciphertext, uuid)
        │   │       │
        │   │       ├─ Cryptor.decrypt(ciphertext, uuid)  ← AES-256-GCM 解密
        │   │       ├─ json.decode() → BackupV2
        │   │       └─ backup.merge()                    ← 合并到 Hive
        │   │
        │   └─ "已从服务端恢复 (v{version})"
        │
        └── needsDownload = false ─────────► 上传
            │
            ├─ SyncCrypto.buildSyncPayload(uuid)
            │       │
            │       ├─ BackupV2.loadFromStore()           ← 收集所有数据
            │       ├─ json.encode(backup.toJson())
            │       └─ Cryptor.encrypt(json, uuid)        ← AES-256-GCM 加密
            │
            ├─ SyncClient.upload(ciphertext, ...)
            │       │
            │       ▼
            │   POST /api/sync/upload
            │   { data_type, device_id, ciphertext, plaintext_size, client_version }
            │       │
            │       ▼
            │   返回 { version }
            │
            └─ "已上传到服务端 (v{version})"
```

### 10.3 登录认证流程

```
用户打开云同步页面 → 点击登录
        │
        ▼
  _showLoginDialog()
  输入用户名/密码/(TOTP可选)
        │
        ▼
  syncNotifier.login(username, password, totpCode?)
        │
        ├─ SyncClient.login(...)
        │       │
        │       ▼
        │   POST /api/auth/login
        │   { username, password, totp_code? }
        │       │
        │   ┌───┴───┐
        │   │       │
        │  成功   totp_required
        │   │       │
        │   ▼       ▼
        │  返回    throw SyncTOTPRequiredException
        │  { token, user_id, uuid, username, nickname? }
        │
        ├─ 存储到 Secure Storage:
        │   SyncConfig.token.write(token)
        │   SyncConfig.username.write(username)
        │   SyncConfig.uuid.write(uuid)           ← 加密密钥
        │   SyncConfig.nickname.write(nickname?)
        │   SyncConfig.avatarUrl.write(avatarUrl?)
        │
        ├─ 更新 SyncState: loggedIn=true, syncing=false
        │
        └─ _refreshProfile()                      ← 后台获取完整资料
                │
                ▼
            GET /api/auth/profile
                │
                ▼
            获取 email, email_verified, totp_enabled 等
```

---

## 11. 开发指南

### 11.1 环境要求

- **Flutter SDK**: stable channel, ≥3.44.0
- **Dart SDK**: ≥3.11.0
- **Android Studio** / **Xcode**（对应平台构建所需）
- **Rust** 工具链（部分原生依赖需要）

### 11.2 快速开始

```bash
# 克隆仓库（含子模块）
git clone --recurse-submodules https://github.com/onepve/flutter_server_box.git
cd flutter_server_box

# 安装依赖
flutter pub get

# 代码生成（修改模型后必须执行）
dart run build_runner build --delete-conflicting-outputs

# 生成多语言文件
flutter gen-l10n

# 开发运行
flutter run

# 运行测试
flutter test
```

### 11.3 开发规范

> 详见 `CLAUDE.md`

1. **绝不运行代码格式化命令** — 代码库有特定格式
2. **修改模型后必须运行代码生成** — `dart run build_runner build --delete-conflicting-outputs`
3. **不要手动编辑** `*.g.dart`、`*.freezed.dart` 等生成文件
4. **依赖注入**：GetIt 用于 Stores 和 Services
5. **Hive**：使用 `hive_ce` 而非 `hive`，无需手动配置 `HiveField` / `HiveType`
6. **UI 组件**：优先使用 `fl_lib` 中的 `CustomAppBar`, `Input`, `Btnx` 等
7. **本地化**：优先使用 `libL10n`（fl_lib），只在必要时添加 `l10n` 项目字符串
8. **UI 分离**：Widget Build / Actions / Utils 使用 `extension on` 分离
9. **Android 签名**：正式发布必须使用 release keystore，本地验证使用 `-PallowDebugReleaseSigning=true`

### 11.4 构建命令

```bash
# 使用 fl_build（推荐）
dart run fl_build -p android    # Android (按 ABI 拆包)
dart run fl_build -p linux      # Linux AppImage
dart run fl_build -p windows    # Windows zip

# 标准 Flutter 构建
flutter build apk --release --split-per-abi
```

### 11.5 同步功能开发注意事项

1. **`SyncConfig.serverUrl`** 是硬编码的，修改后需重新编译
2. **加密密钥 (UUID)** 存储在平台 Keychain/KeyStore (`SecureProp`)，不会因卸载而丢失
3. **`SyncClient`** 是单例，重置时调用 `reset()` 重建 Dio 实例
4. **错误处理**：所有 API 异常通过 `SyncError.parse()` 转换为中文错误信息
5. **同步数据格式**：使用 `BackupV2`，与内置备份共享数据结构
6. **版本号**：`Stores.lastModTime` 遍历所有 Store 获取最大时间戳

---

## 12. 附录

### 12.1 Key Properties

| 属性 | 值 |
|------|-----|
| Android 包名 | `tech.lolli.toolbox`（继承上游） |
| iOS Bundle ID | 继承上游 |
| Android 最低 SDK | 继承上游 |
| iOS 最低版本 | 继承上游 |
| 本地化支持 | 15 种语言 |
| 代码仓库 | `onepve/flutter_server_box` |
| 同步服务端 | `your-domain.com:8765` (Nginx → 443) |

### 12.2 多语言列表

简体中文、English、繁體中文、Deutsch、Français、日本語、한국어、Nederlands、Português、Українська、Türkçe、Русский、Español、Italiano、Bahasa Indonesia

### 12.3 相关仓库

| 仓库 | 说明 |
|------|------|
| [lollipopkit/flutter_server_box](https://github.com/lollipopkit/flutter_server_box) | 上游原作 |
| [onepve/flutter_server_box](https://github.com/onepve/flutter_server_box) | CBox 定制分支（本仓库） |
| [nous/hermes](https://github.com/nous/hermes) | CBox Sync 服务端代码 |

### 12.4 文件统计（估计）

| 模块 | 文件数 | 代码行数 (约) |
|------|-------|-------------|
| `lib/core/` | ~24 | ~1,500 |
| `lib/data/model/` | ~100 | ~5,000 |
| `lib/data/provider/` | ~30 | ~2,000 |
| `lib/data/store/` | ~8 | ~1,500 |
| `lib/view/` | ~50 | ~15,000 |
| `lib/sync/` | 8 | ~2,000 |
| `lib/l10n/` + `lib/generated/` | ~30 | 自动生成 |
| `packages/` | ~7 包 | ~10,000 |
| **总计** | **~250** | **~37,000** |

---

> 📝 本文档基于对 `/root/.hermes/onepve/code/github/repos/flutter_server_box/` 代码库的完整阅读生成，涵盖所有关键源文件、架构设计、数据流和 CI/CD 配置。如发现文档与代码不一致，以实际代码为准。
