import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/sync/sync_config.dart';
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
        trailing: syncState.syncing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
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
            trailing: syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
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
            onTap: syncing ? null : () => _doDownload(context),
          ),
        ),
      ],
    );
  }

  // ── 关于 ──

  Widget get _buildAboutItem {
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('服务端同步'),
        subtitle: Text(
          '数据端到端加密，服务端无法解密\n'
          '服务端地址: ${SyncConfig.serverUrl}',
          style: UIs.textGrey,
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
          Text('服务端地址: ${SyncConfig.serverUrl}', style: UIs.textGrey),
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
}
