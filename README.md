# CBox Flutter 客户端

端到端加密数据同步客户端，集成在 server_box 应用中的云同步模块。

## 技术栈

| 组件 | 技术 |
|------|------|
| 框架 | Flutter 3.44.1 |
| 状态管理 | Riverpod (手写 Notifier) |
| 本地存储 | SecureProp (Hive CE) |
| 网络请求 | Dio |
| 加密 | AES-256-GCM (点对点) |
| 头像裁剪 | 自定义 Circular Crop |
| 双平台 | Android / Linux / Windows |

## 模块架构

```
lib/
├── main.dart                 # 应用入口
├── app.dart                  # 应用配置
├── core/                     # 核心工具
├── data/                     # 数据层
│   ├── model/                # 数据模型
│   ├── provider/             # Riverpod 状态管理
│   └── store/                # Hive 本地存储
├── sync/                     # 云同步模块（核心）
│   ├── sync_provider.dart    # 同步状态管理 (Riverpod Notifier)
│   ├── sync_ui.dart          # 同步页面 UI
│   ├── sync_client.dart      # 网络请求封装
│   ├── sync_config.dart      # 配置管理 (Token/URL存储)
│   ├── sync_engine.dart      # 同步引擎（上传/下载逻辑）
│   ├── sync_crypto.dart      # 加密/解密
│   ├── sync_error.dart       # 错误处理
│   └── avatar_crop_dialog.dart # 头像裁剪对话框
└── view/                     # 其他 UI 页面
```

## 同步状态管理

```dart
SyncState {
  loggedIn: bool,       // 是否已登录
  token: String?,       // JWT Token
  username: String?,    // 用户名
  nickname: String?,    // 昵称
  avatarUrl: String?,   // 头像 URL
  email: String?,       // 邮箱
  emailVerified: bool,  // 邮箱验证状态
  totpEnabled: bool,    // TOTP 状态
  serverVersion: int,   // 服务端数据版本
  localVersion: int,    // 本地数据版本
  syncing: bool,        // 同步中
  lastSyncAt: int,      // 最后同步时间
  lastSyncMessage: String?, // 最后同步消息
  error: String?,       // 错误信息
}
```

## 功能详解

### 认证流程

1. **登录**：用户名/邮箱 + 密码 → 获取 JWT Token → 保存到本地安全存储
2. **TOTP 检测**：登录时服务端返回 `totp_required` → 弹出 TOTP 输入框
3. **注册**：用户名 + 密码 + 邮箱 + 邀请码（动态检测是否需要）
4. **Recovery Key 登录**：用户名 + Recovery Key 替代 TOTP

### 数据同步流程

```
┌─────────────────────────────────────────────────────┐
│                     CBox 客户端                       │
│                                                      │
│  启动时:                                              │
│  ┌──────────┐   ┌──────────────┐   ┌────────────┐  │
│  │ 读取 Token│ → │ 尝试自动登录  │ → │ 显示同步状态│  │
│  │ (本地存储) │   │ (后台静默)   │   │            │  │
│  └──────────┘   └──────────────┘   └────────────┘  │
│                                                      │
│  同步操作:                                            │
│  ┌─────────────────────────────────────────────────┐ │
│  │ 一键同步: 智能判断上传/下载                        │ │
│  │ 1. 检查 localVersion vs serverVersion            │ │
│  │ 2. 本地新 → 上传 | 远程新 → 下载                  │ │
│  │ 3. AES-256-GCM 加密/解密                         │ │
│  └─────────────────────────────────────────────────┘ │
│                                                      │
│  头像系统:                                            │
│  ┌─────────────────────────────────────────────────┐ │
│  │ 1. 启动 → 读取本地缓存头像 → 显示                  │ │
│  │ 2. 后台静默获取最新头像 → 更新                    │ │
│  │ 3. 上传头像 → 裁剪 → API上传 → 立即刷新UI         │ │
│  │ 4. 两个头像位置同步更新（主卡片 + 资料弹窗）       │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### 头像系统

**本地缓存机制：**
1. 应用启动时，`_init()` 从 SecureProp 读取缓存的 `avatarUrl`
2. 立即显示缓存的头像（无需等待网络）
3. 后台 `_refreshProfile()` 异步获取最新头像 URL
4. 获取到新 URL 后更新 Riverpod 状态 → UI 自动刷新

**上传后即时刷新（修复后）：**
1. 选择图片 → 圆形裁剪 → 上传到服务端
2. 上传成功后：
   - 保存新 URL 到 Hive 本地缓存
   - **立即调用 `updateAvatarUrl()` 更新 Riverpod 状态**
   - 同步卡片头像即刻刷新
   - 资料弹窗头像即刻刷新
   - 后台 `refreshProfile()` 同步其他字段

### 邀请码

- 管理员创建的邀请码可在注册页面使用
- 用户可在个人资料中查看自己的邀请码（如果系统配置允许创建）
- 公开邀请码从服务端获取列表

### 邮箱验证

- 点击"去验证邮箱" → 发送验证码 → 输入 6 位验证码 → 验证成功
- 验证后 UUID 密钥发送到邮箱（用于数据恢复）

### 密码管理

- 修改密码：旧密码 + 新密码
- 忘记密码：用户名/邮箱 → 获取重置令牌 → 设置新密码

## 数据加密

### 密钥派生

```
UUID → SHA-256 → 32 字节 AES-256 密钥
```

### 加密流程

1. 提取本地数据（JSON）
2. 使用 UUID 派生密钥
3. AES-256-GCM 加密（随机 IV + 认证标签）
4. 上传密文到服务端

### 解密流程

1. 从服务端下载密文
2. 使用 UUID 派生密钥
3. AES-256-GCM 解密 + 认证
4. 恢复本地数据

## 安全存储

| 配置项 | 存储方式 | 说明 |
|--------|---------|------|
| JWT Token | SecureProp | 加密存储 |
| 用户名 | SecureProp | 明文存储 |
| UUID | SecureProp | 加密密钥派生源 |
| 头像 URL | SecureProp | 本地缓存 |
| 昵称 | SecureProp | 显示用 |
| 邮箱 | SecureProp | 显示用 |

## 与后端交互

所有 API 调用通过 `SyncClient` 类封装：

```dart
SyncClient.shared.login(username, password, totpCode)
SyncClient.shared.getProfile()
SyncClient.shared.uploadAvatar(filePath)
SyncClient.shared.upload(ciphertext, plaintextSize, clientVersion)
SyncClient.shared.download()
SyncClient.shared.checkDiff(localVersion)
SyncClient.shared.register(username, password, email, inviteCode, nickname)
// ... 等
```

所有请求自动携带 `Authorization: Bearer {token}` 头。

## 本地化

- 使用 `libL10n`（fl_lib 包）和 `l10n`（项目本地）
- 支持 12+ 种语言
- 新增字符串优先使用 `libL10n` 已有条目

## 构建

```bash
# Android
dart run fl_build -p android

# Linux
dart run fl_build -p linux

# Windows
dart run fl_build -p windows

# 代码生成（修改模型后）
dart run build_runner build --delete-conflicting-outputs
```

## 架构原则

- 状态管理：Riverpod Notifier（手写，免 build_runner）
- 依赖注入：GetIt（fl_lib 集成）
- UI 分离：Widget 构建 / Actions / Utils（extension on 模式）
- 组件复用：优先使用 fl_lib 包中的 `CustomAppBar`、`CardX`、`Btnx`、`Input` 等
- 本地存储：`hive_ce`（无需手动配置 HiveField/HiveType）