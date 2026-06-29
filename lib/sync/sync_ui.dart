import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/sync/sync_config.dart';
import 'package:server_box/sync/sync_client.dart';
import 'package:server_box/sync/sync_engine.dart';
import 'package:server_box/sync/sync_provider.dart';

/// 服务端同步设置页面
///
/// 支持：
/// - 账号密码登录
/// - 一键同步（上传/下载）
/// - 同步状态查看
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

  // ── 登录状态 ──

  Widget _buildLoginStatus(SyncState syncState) {
    return CardX(
      child: ListTile(
        leading: Icon(
          syncState.loggedIn ? Icons.cloud_done : Icons.cloud_off,
          color: syncState.loggedIn ? Colors.green : Colors.grey,
        ),
        title: Text(syncState.loggedIn ? '已登录' : '未登录'),
        subtitle: Text(
          syncState.loggedIn
              ? '账号: ${syncState.username ?? "未知"}'
              : '请使用同步账号登录',
          style: UIs.textGrey,
        ),
      ),
    );
  }

  Widget _buildLoginButton(SyncState syncState) {
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.login),
        title: Text('登录到 ${SyncConfig.serverUrl}'),
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

  // ── 操作 ──

  Future<void> _showLoginDialog(BuildContext context) async {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final totpCtrl = TextEditingController();
    final usernameNode = FocusNode();
    final passwordNode = FocusNode();

    final result = await context.showRoundDialog<bool>(
      title: '登录同步服务',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('服务端地址: ${SyncConfig.serverUrl}', style: UIs.textGrey.copyWith(fontSize: 12)),
          UIs.height13,
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                context.pop();
                _showForgotPasswordDialog(context);
              },
              child: const Text('忘记密码？', style: TextStyle(fontSize: 13)),
            ),
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
  ///
  /// 优先使用登录时的密码（从 SecureProp 读取），如果不存在则弹窗让用户输入。
  Future<String?> _requirePassword(BuildContext context) async {
    // 使用登录密码作为加密密码（密钥从密码派生）
    final savedPwd = await SecureStoreProps.bakPwd.read();
    if (savedPwd != null && savedPwd.isNotEmpty) {
      return savedPwd;
    }

    // 弹窗让用户输入加密密码
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

  // ── 忘记密码 ──

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final emailCtrl = TextEditingController();
    final node = FocusNode();

    final result = await context.showRoundDialog<bool>(
      title: '忘记密码',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '输入注册邮箱，获取重置令牌',
            style: UIs.textGrey,
          ),
          UIs.height13,
          Input(
            label: '邮箱地址',
            controller: emailCtrl,
            node: node,
            onSubmitted: (_) => context.pop(true),
          ),
        ],
      ),
      actions: Btnx.oks,
    );

    if (result == true) {
      final email = emailCtrl.text.trim();
      if (email.isEmpty) {
        context.showSnackBar('请输入邮箱');
        emailCtrl.dispose();
        node.dispose();
        return;
      }

      try {
        final resp = await context.showLoadingDialog(
          fn: () => SyncClient.shared.forgotPassword(email: email),
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

    emailCtrl.dispose();
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
