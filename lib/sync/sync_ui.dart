import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/sync/sync_client.dart';
import 'package:server_box/sync/sync_config.dart';
import 'package:server_box/sync/sync_engine.dart';
import 'package:server_box/sync/sync_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// 服务端同步设置页面
///
/// 支持：
/// - 账号密码登录
/// - 一键同步（上传/下载）
/// - 同步状态查看
/// - 个人资料查看（含 TOTP 引导）
class ServerSyncPage extends ConsumerStatefulWidget {
  const ServerSyncPage({super.key});

  @override
  ConsumerState<ServerSyncPage> createState() => _ServerSyncPageState();

  static const route = AppRouteNoArg(page: ServerSyncPage.new, path: '/server-sync');
}

final class _ServerSyncPageState extends ConsumerState<ServerSyncPage> {
  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncNotifierProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('服务端同步'),
      ),
      body: SafeArea(
        child: MultiList(
          widthDivider: 2,
          children: [
            [
              CenterGreyTitle('同步账号'),
              _buildLoginStatus(syncState),
              if (!syncState.loggedIn) _buildLoginButton(syncState),
              if (syncState.loggedIn) ..._buildLoggedInItems(syncState),
            ],
            [
              CenterGreyTitle('同步操作'),
              if (syncState.loggedIn) _buildSyncButtons(syncState),
            ],
            [
              CenterGreyTitle('关于'),
              _buildAboutItem,
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  登录状态（头像 + 昵称，可点击查看详细资料）
  // ═══════════════════════════════════════════════════════════

  String _displayName(SyncState s) {
    if (s.nickname != null && s.nickname!.isNotEmpty) return s.nickname!;
    if (s.username != null && s.username!.isNotEmpty) return s.username!;
    return '未知';
  }

  String _displaySubtitle(SyncState s) {
    final parts = <String>[];
    if (s.nickname != null && s.nickname!.isNotEmpty) {
      parts.add('用户名: ${s.username ?? "—"}');
    }
    if (s.email != null && s.email!.isNotEmpty) {
      parts.add(s.email!);
    }
    if (parts.isEmpty) return '已登录';
    return parts.join('  |  ');
  }

  Widget _buildLoginStatus(SyncState syncState) {
    final avatarUrl = syncState.avatarUrl;
    final bool hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final fullAvatarUrl = hasAvatar
        ? (avatarUrl.startsWith('http')
            ? avatarUrl
            : '${SyncConfig.serverUrl}$avatarUrl')
        : null;

    return CardX(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: syncState.loggedIn
            ? () => _showProfileDialog(context, syncState)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 头像（居中） ──
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        fullAvatarUrl != null ? NetworkImage(fullAvatarUrl) : null,
                    child: fullAvatarUrl == null
                        ? Icon(
                            syncState.loggedIn
                                ? Icons.person
                                : Icons.cloud_off,
                            size: 28,
                            color: syncState.loggedIn
                                ? Colors.grey.shade500
                                : Colors.grey,
                          )
                        : null,
                  ),
                  if (syncState.loggedIn)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              UIs.height10,
              // ── 昵称/用户名 ──
              Text(
                _displayName(syncState),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              UIs.height4,
              // ── 详细信息 ──
              Text(
                _displaySubtitle(syncState),
                style: UIs.textGrey?.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (syncState.loggedIn) ...[
                UIs.height4,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      syncState.totpEnabled
                          ? Icons.lock
                          : Icons.lock_open,
                      size: 12,
                      color: syncState.totpEnabled
                          ? Colors.green
                          : Colors.orange.shade400,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      syncState.totpEnabled ? 'TOTP 已开启' : 'TOTP 未开启',
                      style: TextStyle(
                        fontSize: 11,
                        color: syncState.totpEnabled
                            ? Colors.green
                            : Colors.orange.shade400,
                      ),
                    ),
                  ],
                ),
                UIs.height6,
                Text(
                  '点击查看详细资料',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  个人资料详情弹窗
  // ═══════════════════════════════════════════════════════════

  Future<void> _showProfileDialog(BuildContext context, SyncState s) async {
    // 先刷新资料
    final notifier = ref.read(syncNotifierProvider.notifier);
    unawaited(notifier.refreshProfile());

    await context.showRoundDialog(
      title: '个人资料',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: (s.avatarUrl != null && s.avatarUrl!.isNotEmpty)
                  ? NetworkImage(
                      s.avatarUrl!.startsWith('http')
                          ? s.avatarUrl!
                          : '${SyncConfig.serverUrl}${s.avatarUrl}',
                    )
                  : null,
              child: (s.avatarUrl == null || s.avatarUrl!.isEmpty)
                  ? Icon(Icons.person, size: 32, color: Colors.grey.shade500)
                  : null,
            ),
          ),
          UIs.height13,
          _profileRow('用户名', s.username ?? '—'),
          _profileRow('昵称', (s.nickname != null && s.nickname!.isNotEmpty) ? s.nickname : '未设置'),
          _profileRow('邮箱', s.email ?? '—'),
          _profileRow(
            '邮箱验证',
            s.emailVerified ? '已验证 ✓' : '未验证',
            valueColor: s.emailVerified ? Colors.green : Colors.orange,
          ),
          _profileRow(
            'TOTP 双因素认证',
            s.totpEnabled ? '已开启 ✓' : '未开启',
            valueColor: s.totpEnabled ? Colors.green : Colors.orange.shade400,
          ),
          UIs.height13,
          if (!s.totpEnabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text(
                        '建议开启 TOTP 保护账号安全',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '由于手机端扫码不便，建议在电脑浏览器中开启 TOTP。'
                    '登录网页端后进入个人资料页即可绑定 Authenticator。',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      label: const Text('在网页端开启 TOTP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () {
                        _openWebProfile(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (s.totpEnabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'TOTP 已开启，账号受保护。如需管理 TOTP 设置，请在网页端操作。',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _profileRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWebProfile(BuildContext context) async {
    final url = Uri.parse(SyncConfig.webProfileUrl);
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(url, mode: LaunchMode.inAppWebView);
      }
    } catch (e) {
      context.showSnackBar('无法打开浏览器: $e');
      // 降级：复制链接
      await Clipboard.setData(ClipboardData(text: url.toString()));
      context.showSnackBar('链接已复制到剪贴板，请在浏览器中打开');
    }
  }

  // ── 登录按钮 ──

  Widget _buildLoginButton(SyncState syncState) {
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.login),
        title: const Text('登录同步账户'),
        subtitle: Text(
          '服务端地址已固定，无需手动配置',
          style: UIs.textGrey,
        ),
        trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _helpBtn(
                '登录',
                '使用在同步管理平台注册的账号登录。\n\n'
                '首次使用需要先通过邀请码注册账号。\n\n'
                '如果开启了 TOTP 双因素认证，登录时需要额外输入 6 位动态验证码。',
              ),
              if (syncState.syncing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        onTap: syncState.syncing ? null : () => _showLoginDialog(context),
      ),
    );
  }

  List<Widget> _buildLoggedInItems(SyncState syncState) {
    return [
      CardX(
        child: ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('退出登录'),
          trailing: _helpBtn(
            '退出登录',
            '清除本地保存的登录令牌（JWT Token），退出后需要重新登录才能同步。\n\n本机数据不会丢失。',
          ),
          onTap: () async {
            await ref.read(syncNotifierProvider.notifier).logout();
            setState(() {});
          },
        ),
      ),
      if (syncState.lastSyncAt > 0)
        CardX(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: const Text('上次同步'),
            subtitle: Text(
              syncState.lastSyncMessage ?? '未知',
              style: UIs.textGrey,
            ),
          ),
        ),
      if (syncState.error != null)
        CardX(
          child: ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.red),
            title: Text(syncState.error!, style: const TextStyle(color: Colors.red)),
          ),
        ),
      CardX(
        child: ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: Text('删除同步数据', style: const TextStyle(color: Colors.red)),
          subtitle: Text(
            '清空服务端加密数据',
            style: UIs.textGrey,
          ),
          trailing: _helpBtn(
            '删除同步数据',
            '永久删除服务端存储的所有加密同步数据。\n\n'
            '• 本机数据不受影响\n'
            '• 删除后其他设备将无法下载数据\n'
            '• 如需再次同步，需重新上传\n'
            '• 此操作不可撤销！',
          ),
          onTap: () => _doDeleteData(context),
        ),
      ),
    ];
  }

  // ── 同步按钮 ──

  Widget _buildSyncButtons(SyncState syncState) {
    final syncing = syncState.syncing;
    return Column(
      children: [
        CardX(
          child: ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('一键同步'),
            subtitle: Text(
              '智能判断上传或下载，保持多设备一致',
              style: UIs.textGrey,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _helpBtn(
                  '一键同步',
                  '自动检测服务端与本机的数据版本差异：\n\n'
                  '• 如果服务端有更新的数据 → 下载到本机恢复\n'
                  '• 如果本机数据更新或相同 → 将本机数据加密上传到服务端\n\n'
                  '适合日常快速同步，无需手动选择方向。',
                ),
                if (syncing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.sync),
              ],
            ),
            onTap: syncing ? null : () => _doSync(context),
          ),
        ),
        CardX(
          child: ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('仅上传'),
            subtitle: Text(
              '将本机数据加密上传到服务端',
              style: UIs.textGrey,
            ),
            trailing: _helpBtn(
              '仅上传',
              '将本机的服务器列表、SSH 密钥、容器配置等数据加密后上传到服务端，覆盖云端数据。\n\n'
              '适用场景：\n'
              '• 刚配置好新设备，把数据备份到云端\n'
              '• 做了大量修改后主动推送最新数据',
            ),
            onTap: syncing ? null : () => _doUpload(context),
          ),
        ),
        CardX(
          child: ListTile(
            leading: const Icon(Icons.download),
            title: const Text('仅下载'),
            subtitle: Text(
              '从服务端下载数据并恢复到本机',
              style: UIs.textGrey,
            ),
            trailing: _helpBtn(
              '仅下载',
              '从服务端下载加密数据并恢复到本机，覆盖本地数据。\n\n'
              '适用场景：\n'
              '• 换了新手机或新电脑，需要恢复之前的配置\n'
              '• 误删了数据需要从云端恢复\n'
              '• 想同步其他设备的服务器列表',
            ),
            onTap: syncing ? null : () => _doDownload(context),
          ),
        ),
      ],
    );
  }

  // ── 关于 ──

  Widget _helpBtn(String title, String detail) {
    return IconButton(
      icon: const Icon(Icons.help_outline, size: 18, color: Colors.grey),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: '查看说明',
      onPressed: () => _showHelp(context, title, detail),
    );
  }

  Future<void> _showHelp(BuildContext context, String title, String detail) async {
    await context.showRoundDialog(
      title: title,
      child: Text(detail, style: UIs.textGrey),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('知道了')),
      ],
    );
  }

  Widget get _buildAboutItem {
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('服务端同步'),
        subtitle: Text(
          '数据端到端加密，服务端无法解密\n'
          '服务端地址: ${SyncConfig.serverUrl}',
          style: UIs.textGrey.copyWith(fontSize: 12),
        ),
      ),
    );
  }

  // ── 登录 ──

  Future<void> _showLoginDialog(BuildContext context) async {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final totpCtrl = TextEditingController();
    final usernameNode = FocusNode();
    final passwordNode = FocusNode();

    final result = await context.showRoundDialog<bool>(
      title: '登录同步账户',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Input(
            label: '用户名',
            controller: usernameCtrl,
            node: usernameNode,
            onSubmitted: (_) => passwordNode.requestFocus(),
          ),
          UIs.height13,
          Input(
            label: '密码',
            controller: passwordCtrl,
            node: passwordNode,
            obscureText: true,
            onSubmitted: (_) => context.pop(true),
          ),
          UIs.height13,
          Input(
            label: 'TOTP 验证码（可选）',
            controller: totpCtrl,
          ),
          UIs.height7,
          Row(
            children: [
              TextButton(
                onPressed: () {
                  context.pop();
                  _showRegisterDialog(context);
                },
                child: const Text('没有账号？注册', style: TextStyle(fontSize: 13)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  context.pop();
                  _showForgotPasswordDialog(context);
                },
                child: const Text('忘记密码？', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
      actions: Btnx.oks,
    );

    if (result == true) {
      final username = usernameCtrl.text.trim();
      final password = passwordCtrl.text.trim();
      final totpCode = totpCtrl.text.trim();

      if (username.isEmpty || password.isEmpty) {
        context.showSnackBar('用户名和密码不能为空');
        usernameCtrl.dispose();
        passwordCtrl.dispose();
        totpCtrl.dispose();
        usernameNode.dispose();
        passwordNode.dispose();
        return;
      }

      final notifier = ref.read(syncNotifierProvider.notifier);
      final err = await notifier.login(
        username: username,
        password: password,
        totpCode: totpCode.isNotEmpty ? totpCode : null,
      );

      if (err == null) {
        context.showSnackBar('登录成功');
        setState(() {});
      } else if (err == 'totp_required') {
        // 重新弹窗，让用户输入 TOTP
        context.showSnackBar('需要 TOTP 验证码');
        _showLoginWithTotp(context, username, password);
      } else {
        context.showSnackBar('登录失败: $err');
      }
    }

    usernameCtrl.dispose();
    passwordCtrl.dispose();
    totpCtrl.dispose();
    usernameNode.dispose();
    passwordNode.dispose();
  }

  Future<void> _showLoginWithTotp(
    BuildContext context,
    String username,
    String password,
  ) async {
    final totpCtrl = TextEditingController();

    final result = await context.showRoundDialog<bool>(
      title: 'TOTP 验证',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('请输入 Authenticator 中的 6 位验证码', style: UIs.textGrey),
          UIs.height13,
          Input(
            label: 'TOTP 验证码',
            controller: totpCtrl,
            onSubmitted: (_) => context.pop(true),
          ),
        ],
      ),
      actions: Btnx.oks,
    );

    if (result == true) {
      final totpCode = totpCtrl.text.trim();
      if (totpCode.isEmpty) {
        context.showSnackBar('验证码不能为空');
        totpCtrl.dispose();
        return;
      }

      final notifier = ref.read(syncNotifierProvider.notifier);
      final err = await notifier.login(
        username: username,
        password: password,
        totpCode: totpCode,
      );

      if (err == null) {
        context.showSnackBar('登录成功');
        setState(() {});
      } else {
        context.showSnackBar('登录失败: $err');
      }
    }
    totpCtrl.dispose();
  }

  Future<void> _doSync(BuildContext context) async {
    final pwd = await _requirePassword(context);
    if (pwd == null) return;

    final notifier = ref.read(syncNotifierProvider.notifier);
    final result = await context.showLoadingDialog(
      fn: () => SyncEngine.syncAll(pwd),
    );

    if (result.$1 != null) {
      context.showSnackBar(result.$1!);
      notifier.checkForUpdates();
      setState(() {});
    } else if (result.$2 != null) {
      notifier.logout();
      context.showSnackBar('同步失败: ${result.$2}');
    }
  }

  Future<void> _doUpload(BuildContext context) async {
    final pwd = await _requirePassword(context);
    if (pwd == null) return;

    final notifier = ref.read(syncNotifierProvider.notifier);
    final err = await context.showLoadingDialog(
      fn: () => notifier.upload(password: pwd),
    );

    if (err.$1 == null) {
      context.showSnackBar('上传成功');
    } else {
      context.showSnackBar('上传失败: ${err.$1}');
    }
    setState(() {});
  }

  Future<void> _doDownload(BuildContext context) async {
    final pwd = await _requirePassword(context);
    if (pwd == null) return;

    final notifier = ref.read(syncNotifierProvider.notifier);

    final confirmed = await context.showRoundDialog<bool>(
      title: '确认下载恢复',
      child: const Text('将从服务端下载数据并覆盖本地内容，确定继续？'),
      actions: Btnx.cancelOk,
    );
    if (confirmed != true) return;

    final err = await context.showLoadingDialog(
      fn: () => notifier.download(password: pwd),
    );

    if (err.$1 == null) {
      context.showSnackBar('下载恢复成功');
    } else {
      context.showSnackBar('下载失败: ${err.$1}');
    }
    setState(() {});
  }

  /// 获取同步密码
  Future<String?> _requirePassword(BuildContext context) async {
    final savedPwd = await SecureStoreProps.bakPwd.read();
    if (savedPwd != null && savedPwd.isNotEmpty) {
      return savedPwd;
    }

    final controller = TextEditingController();
    final result = await context.showRoundDialog<bool>(
      title: '同步加密密码',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '数据会用此密码加密后上传\n'
            '建议与登录密码相同',
            style: UIs.textGrey,
          ),
          UIs.height13,
          Input(
            label: '加密密码',
            controller: controller,
            obscureText: true,
            onSubmitted: (_) => context.pop(true),
          ),
        ],
      ),
      actions: Btnx.oks,
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      final pwd = controller.text.trim();
      await SecureStoreProps.bakPwd.write(pwd);
      controller.dispose();
      return pwd;
    }
    controller.dispose();
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  //  注册（含昵称字段）
  // ═══════════════════════════════════════════════════════════

  Future<void> _showRegisterDialog(BuildContext context) async {
    final usernameCtrl = TextEditingController();
    final nicknameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final inviteCodeCtrl = TextEditingController();
    final usernameNode = FocusNode();
    final nicknameNode = FocusNode();
    final emailNode = FocusNode();
    final passwordNode = FocusNode();
    final inviteCodeNode = FocusNode();

    final result = await context.showRoundDialog<bool>(
      title: '注册同步账号',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '需要邀请码才能注册，请联系管理员获取',
            style: UIs.textGrey,
          ),
          UIs.height13,
          Input(
            label: '用户名 *',
            controller: usernameCtrl,
            node: usernameNode,
            onSubmitted: (_) => nicknameNode.requestFocus(),
          ),
          UIs.height7,
          Input(
            label: '昵称（选填）',
            controller: nicknameCtrl,
            node: nicknameNode,
            onSubmitted: (_) => emailNode.requestFocus(),
          ),
          UIs.height7,
          Input(
            label: '邮箱地址 *',
            controller: emailCtrl,
            node: emailNode,
            onSubmitted: (_) => passwordNode.requestFocus(),
          ),
          UIs.height7,
          Input(
            label: '密码 *',
            controller: passwordCtrl,
            node: passwordNode,
            obscureText: true,
            onSubmitted: (_) => inviteCodeNode.requestFocus(),
          ),
          UIs.height7,
          Input(
            label: '邀请码 *',
            controller: inviteCodeCtrl,
            node: inviteCodeNode,
            onSubmitted: (_) => context.pop(true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => context.pop(true),
          child: const Text('注册'),
        ),
      ],
    );

    if (result == true) {
      final username = usernameCtrl.text.trim();
      final nickname = nicknameCtrl.text.trim();
      final email = emailCtrl.text.trim();
      final password = passwordCtrl.text.trim();
      final inviteCode = inviteCodeCtrl.text.trim();

      if (username.isEmpty || email.isEmpty || password.isEmpty || inviteCode.isEmpty) {
        context.showSnackBar('请填写所有必填字段（带 * 号）');
        _disposeRegCtrls(
          usernameCtrl, nicknameCtrl, emailCtrl, passwordCtrl, inviteCodeCtrl,
          usernameNode, nicknameNode, emailNode, passwordNode, inviteCodeNode,
        );
        return;
      }

      try {
        final resp = await context.showLoadingDialog(
          fn: () => SyncClient.shared.register(
            username: username,
            nickname: nickname.isNotEmpty ? nickname : null,
            email: email,
            password: password,
            inviteCode: inviteCode,
          ),
        );

        if (resp.$1 != null) {
          if (resp.$1!.recoveryKey != null) {
            final key = resp.$1!.recoveryKey!;

            await context.showRoundDialog(
              title: '注册成功',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('账号注册成功！'),
                  UIs.height13,
                  const Text('请保存好以下 Recovery Key，用于：'),
                  const Text('• 忘记 TOTP 设备时恢复账号'),
                  const Text('• 在验证码失效时登录'),
                  UIs.height7,
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      key,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                    ),
                  ),
                  UIs.height7,
                  const Text('此密钥仅显示一次，请立即记录！',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('知道了'),
                ),
              ],
            );
          } else {
            context.showSnackBar(resp.$1!.message);
          }
        } else {
          context.showSnackBar('注册失败: ${resp.$2}');
        }
      } catch (e) {
        context.showSnackBar('网络错误: $e');
      }
    }

    _disposeRegCtrls(
      usernameCtrl, nicknameCtrl, emailCtrl, passwordCtrl, inviteCodeCtrl,
      usernameNode, nicknameNode, emailNode, passwordNode, inviteCodeNode,
    );
  }

  void _disposeRegCtrls(
    TextEditingController u, TextEditingController n,
    TextEditingController e, TextEditingController p,
    TextEditingController i,
    FocusNode un, FocusNode nn, FocusNode en,
    FocusNode pn, FocusNode ino,
  ) {
    u.dispose(); n.dispose(); e.dispose(); p.dispose(); i.dispose();
    un.dispose(); nn.dispose(); en.dispose(); pn.dispose(); ino.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  //  忘记密码（支持用户名或邮箱）
  // ═══════════════════════════════════════════════════════════

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final identifierCtrl = TextEditingController();
    final node = FocusNode();

    final result = await context.showRoundDialog<bool>(
      title: '忘记密码',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '输入用户名或注册邮箱，获取重置令牌',
            style: UIs.textGrey,
          ),
          UIs.height13,
          Input(
            label: '用户名 / 邮箱地址',
            controller: identifierCtrl,
            node: node,
            onSubmitted: (_) => context.pop(true),
          ),
        ],
      ),
      actions: Btnx.oks,
    );

    if (result == true) {
      final identifier = identifierCtrl.text.trim();
      if (identifier.isEmpty) {
        context.showSnackBar('请输入用户名或邮箱');
        identifierCtrl.dispose();
        node.dispose();
        return;
      }

      try {
        final resp = await context.showLoadingDialog(
          fn: () => SyncClient.shared.forgotPassword(usernameOrEmail: identifier),
        );

        if (resp.$1 != null) {
          final message = resp.$1!.message;

          if (resp.$1!.token != null) {
            // 自托管模式：直接拿到令牌，进入重置密码
            final ok = await context.showRoundDialog<bool>(
              title: '重置令牌已获取',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: UIs.textGrey),
                  UIs.height13,
                  const Text('请立即使用此令牌重置密码，一小时内有效：'),
                  UIs.height7,
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      resp.$1!.token!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => context.pop(false),
                  child: const Text('稍后重置'),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.pop(true);
                  },
                  child: const Text('下一步：重置密码'),
                ),
              ],
            );

            if (ok == true) {
              _showResetPasswordDialog(context, initialToken: resp.$1!.token);
            }
          } else {
            // SMTP 模式：邮件已发送
            context.showSnackBar(message);
          }
        } else {
          context.showSnackBar('请求失败: ${resp.$2}');
        }
      } catch (e) {
        context.showSnackBar('网络错误: $e');
      }
    }

    identifierCtrl.dispose();
    node.dispose();
  }

  // ── 重置密码 ──

  Future<void> _showResetPasswordDialog(
    BuildContext context, {
    String? initialToken,
  }) async {
    final tokenCtrl = TextEditingController(text: initialToken ?? '');
    final pwdCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final tokenNode = FocusNode();
    final pwdNode = FocusNode();
    final confirmNode = FocusNode();

    final result = await context.showRoundDialog<bool>(
      title: '重置密码',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '输入重置令牌和新密码',
            style: UIs.textGrey,
          ),
          UIs.height13,
          Input(
            label: '重置令牌',
            controller: tokenCtrl,
            node: tokenNode,
            onSubmitted: (_) => pwdNode.requestFocus(),
          ),
          UIs.height7,
          Input(
            label: '新密码',
            controller: pwdCtrl,
            node: pwdNode,
            obscureText: true,
            onSubmitted: (_) => confirmNode.requestFocus(),
          ),
          UIs.height7,
          Input(
            label: '确认新密码',
            controller: confirmCtrl,
            node: confirmNode,
            obscureText: true,
            onSubmitted: (_) => context.pop(true),
          ),
        ],
      ),
      actions: Btnx.oks,
    );

    if (result == true) {
      final token = tokenCtrl.text.trim();
      final pwd = pwdCtrl.text.trim();
      final confirm = confirmCtrl.text.trim();

      if (token.isEmpty || pwd.isEmpty || confirm.isEmpty) {
        context.showSnackBar('请填写所有字段');
      } else if (pwd != confirm) {
        context.showSnackBar('两次输入的密码不一致');
      } else if (pwd.length < 8) {
        context.showSnackBar('密码至少 8 位');
      } else {
        try {
          await context.showLoadingDialog(
            fn: () => SyncClient.shared.resetPassword(
              token: token,
              newPassword: pwd,
            ),
          );
          context.showSnackBar('密码已重置成功，请使用新密码登录');
        } catch (e) {
          context.showSnackBar('重置失败: $e');
        }
      }
    }

    tokenCtrl.dispose();
    pwdCtrl.dispose();
    confirmCtrl.dispose();
    tokenNode.dispose();
    pwdNode.dispose();
    confirmNode.dispose();
  }

  // ── 删除同步数据 ──

  Future<void> _doDeleteData(BuildContext context) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: '确认删除同步数据',
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⚠ 此操作不可撤销！',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('将永久删除服务端存储的所有加密同步数据：'),
          SizedBox(height: 4),
          Text('• 本机数据不受影响'),
          Text('• 其他设备将无法下载数据'),
          Text('• 如需再次同步需重新上传'),
        ],
      ),
      actions: Btnx.cancelOk,
    );
    if (confirmed != true) return;

    try {
      await context.showLoadingDialog(
        fn: () => SyncClient.shared.deleteData(
          dataType: SyncConfig.dataType,
        ),
      );
      context.showSnackBar('服务端同步数据已删除');
      setState(() {});
    } catch (e) {
      context.showSnackBar('删除失败: $e');
    }
  }
}
