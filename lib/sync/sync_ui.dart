import 'dart:io' as io;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/sync/avatar_crop_dialog.dart';
import 'package:server_box/sync/sync_client.dart';
import 'package:server_box/sync/sync_config.dart';
import 'package:server_box/sync/sync_engine.dart';
import 'package:server_box/sync/sync_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// 服务端同步设置页面
class ServerSyncPage extends ConsumerStatefulWidget {
  const ServerSyncPage({super.key, this.showAppBar = true, this.showComparison = false});
  final bool showAppBar;
  final bool showComparison;
  @override
  ConsumerState<ServerSyncPage> createState() => _ServerSyncPageState();
  static const route = AppRouteNoArg(page: ServerSyncPage.new, path: '/server-sync');
}

final class _ServerSyncPageState extends ConsumerState<ServerSyncPage> {
  @override
  Widget build(BuildContext context) {
    SyncState? syncState;
    try {
      syncState = ref.watch(syncNotifierProvider);
    } catch (_) {
      // provider 没准备好时显示加载
    }

    final body = _buildBody(syncState ?? const SyncState());

    if (!widget.showAppBar) return body;
    return Scaffold(
      appBar: CustomAppBar(title: const Text('云同步')),
      body: body,
    );
  }

  Widget _buildBody(SyncState s) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section('同步账号'),
            _buildLoginStatus(s),
            if (s.loggedIn) ..._loggedInItems(s),

            if (s.loggedIn) ...[
              _section('同步操作'),
              _syncButtons(s),
            ],

            if (widget.showComparison) ...[
              _section('与内置备份方式对比'),
              _comparisonCard(),
              _section('使用建议'),
              _usageCard(),
            ] else ...[
              _section('关于'),
              _aboutCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(title, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600,
      )),
    );
  }

  // ════════════════════════════════════════════
  //  错误弹窗
  // ════════════════════════════════════════════

  /// 弹出详细错误对话框
  Future<void> _showError(SyncError err) async {
    await context.showRoundDialog(
      title: err.title,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
        const SizedBox(height: 14),
        Text(err.message, style: const TextStyle(fontSize: 14), textAlign: TextAlign.center),
      ]),
      actions: [TextButton(onPressed: () => context.pop(), child: const Text('知道了'))],
    );
  }

  /// 弹出成功对话框
  Future<void> _showSuccess(String title, String message) async {
    await context.showRoundDialog(
      title: title,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade400),
        const SizedBox(height: 14),
        Text(message, style: const TextStyle(fontSize: 14), textAlign: TextAlign.center),
      ]),
      actions: [TextButton(onPressed: () => context.pop(), child: const Text('知道了'))],
    );
  }

  // ════════════════════════════════════════════
  //  登录状态卡片
  // ════════════════════════════════════════════

  String _displayName(SyncState s) {
    if (s.nickname != null && s.nickname!.isNotEmpty) return s.nickname!;
    if (s.username != null && s.username!.isNotEmpty) return s.username!;
    return '未登录';
  }

  String _fullAvatarUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return url.startsWith('http') ? url : '${SyncConfig.serverUrl}$url';
  }

  Widget _buildLoginStatus(SyncState s) {
    final avatarUrl = _fullAvatarUrl(s.avatarUrl);
    return CardX(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => s.loggedIn ? _showProfileDialog(s) : _showLoginDialog(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            Center(
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Icon(Icons.person, size: 26, color: Colors.grey.shade500)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(_displayName(s), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (s.loggedIn) ...[
              const SizedBox(height: 4),
              Text('点击查看完整资料',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
          ]),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  //  资料弹窗
  // ════════════════════════════════════════════

  Future<void> _showProfileDialog(SyncState s) async {
    ref.read(syncNotifierProvider.notifier).refreshProfile();
    await context.showRoundDialog(
      title: '个人资料',
      child: Consumer(builder: (context, ref, _) {
        final live = ref.watch(syncNotifierProvider);
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 32, backgroundColor: Colors.grey.shade200,
                  backgroundImage: _fullAvatarUrl(live.avatarUrl).isNotEmpty
                      ? NetworkImage(_fullAvatarUrl(live.avatarUrl)) : null,
                  child: _fullAvatarUrl(live.avatarUrl).isEmpty
                      ? Icon(Icons.person, size: 28, color: Colors.grey.shade500) : null,
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: GestureDetector(
                    onTap: () => _pickAndUploadAvatar(live),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          UIs.height13,
          _pRow('用户名', live.username ?? '—'),
          _pRow('昵称', (live.nickname != null && live.nickname!.isNotEmpty) ? live.nickname! : '未设置'),
          _pRow('邮箱', live.email ?? '—'),
          _pRow('邮箱验证', live.emailVerified ? '已验证 ✓' : '未验证',
              vc: live.emailVerified ? Colors.green : Colors.orange),
          if (!live.emailVerified && live.email != null && live.email!.isNotEmpty)
            Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.mail_outline, size: 15),
                label: const Text('去验证邮箱', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  context.pop(); // 关闭资料弹窗
                  _showVerifyEmailDialog(live);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
          ),
        _pRow('TOTP 双因素', live.totpEnabled ? '已开启 ✓' : '未开启',
            vc: live.totpEnabled ? Colors.green : Colors.orange.shade400),
        const SizedBox(height: 10),
        if (!live.totpEnabled) _totpPrompt(),
        if (live.totpEnabled) _totpEnabled(),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Center(child: Text('账号操作', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('退出登录'),
            onPressed: () {
              context.pop();
              ref.read(syncNotifierProvider.notifier).logout();
              setState(() {});
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 16, color: Colors.red),
            label: const Text('删除云端数据', style: TextStyle(color: Colors.red)),
            onPressed: () {
              context.pop();
              _startDeleteFlow();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red.shade200),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ]);
    },
  ),
  actions: [TextButton(onPressed: () => context.pop(), child: const Text('关闭'))],
);
  }

  Widget _totpPrompt() => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
        const SizedBox(width: 6),
        Text('建议开启 TOTP 保护账号', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.orange.shade800)),
      ]),
      const SizedBox(height: 6),
      Text('手机端扫码不便，建议在电脑浏览器中绑定。', style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.open_in_browser, size: 15),
          label: const Text('在网页端开启 TOTP'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8)),
          onPressed: () async {
            final url = Uri.parse(SyncConfig.webProfileUrl);
            try {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            } catch (_) {
              await Clipboard.setData(ClipboardData(text: url.toString()));
              context.showSnackBar('链接已复制到剪贴板');
            }
          },
        ),
      ),
    ]),
  );

  Widget _totpEnabled() => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200)),
    child: Row(children: [
      Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
      const SizedBox(width: 6),
      Expanded(child: Text('TOTP 已开启，账号受保护。', style: TextStyle(fontSize: 12, color: Colors.green.shade700))),
    ]),
  );

  Widget _pRow(String label, String value, {Color? vc}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: vc))),
    ]),
  );

  // ════════════════════════════════════════════
  //  邮箱验证
  // ════════════════════════════════════════════

  Future<void> _showVerifyEmailDialog(SyncState s) async {
    final ctrl = TextEditingController();
    // 发送验证码
    try {
      final sendMsg = await context.showLoadingDialog(
        fn: () => SyncClient.shared.resendVerification(),
      );
      context.showSnackBar(sendMsg.$1 ?? '验证码已发送');
    } catch (e) {
      await _showError(SyncError.parse(e));
      return;
    }

    final r = await context.showRoundDialog<bool>(
      title: '验证邮箱',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('验证码已发送到 ${s.email ?? '您的邮箱'}', style: UIs.textGrey, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('请在 10 分钟内输入', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        const SizedBox(height: 10),
        Input(label: '6 位验证码', controller: ctrl, maxLength: 6, onSubmitted: (_) => context.pop(true)),
      ]),
      actions: Btnx.oks,
    );
    if (r != true) { ctrl.dispose(); return; }
    final code = ctrl.text.trim();
    ctrl.dispose();
    if (code.isEmpty) { context.showSnackBar('请输入验证码'); return; }

    try {
      await context.showLoadingDialog(
        fn: () => SyncClient.shared.verifyEmail(code: code),
      );
      await _showSuccess('邮箱验证成功', '邮箱验证成功 ✓\n解密密钥（UUID）已发送到您的邮箱');
      ref.read(syncNotifierProvider.notifier).refreshProfile();
      setState(() {});
    } catch (e) {
      await _showError(SyncError.parse(e));
    }
  }

  // ════════════════════════════════════════════
  //  登录/退出/危险按钮
  // ════════════════════════════════════════════

  Widget _buildLoginButton(SyncState s) => CardX(child: ListTile(
    leading: const Icon(Icons.login), title: const Text('登录同步账户'),
    subtitle: Text('服务端地址已固定，无需手动配置', style: UIs.textGrey),
    trailing: s.syncing
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.chevron_right),
    onTap: s.syncing ? null : () => _showLoginDialog(),
  ));

  List<Widget> _loggedInItems(SyncState s) => [
    if (s.lastSyncAt > 0)
      CardX(child: ListTile(leading: const Icon(Icons.history), title: const Text('上次同步'),
        subtitle: Text(s.lastSyncMessage ?? '未知', style: UIs.textGrey))),
    if (s.error != null)
      CardX(child: ListTile(leading: const Icon(Icons.error_outline, color: Colors.red),
        title: Text(s.error!, style: const TextStyle(color: Colors.red)))),
    // ── 注销账号说明 ──
    CardX(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: '注销账号请 ',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  children: [
                    TextSpan(
                      text: '前往网站自助操作',
                      style: TextStyle(color: Colors.blue.shade600, decoration: TextDecoration.underline),
                    ),
                    const TextSpan(text: '（设置 → 个人信息 → 底部危险区域）'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ];

  Widget _syncButtons(SyncState s) {
    final syncing = s.syncing;
    return Column(children: [
      CardX(child: ListTile(leading: const Icon(Icons.sync), title: const Text('一键同步'),
        subtitle: Text('智能判断上传或下载', style: UIs.textGrey),
        trailing: syncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
        onTap: syncing ? null : () => _doSync())),
      CardX(child: ListTile(leading: const Icon(Icons.upload), title: const Text('仅上传'),
        subtitle: Text('本机加密上传到服务端', style: UIs.textGrey),
        onTap: syncing ? null : () => _doUpload())),
      CardX(child: ListTile(leading: const Icon(Icons.download), title: const Text('仅下载'),
        subtitle: Text('从服务端下载恢复', style: UIs.textGrey),
        onTap: syncing ? null : () => _doDownload())),
    ]);
  }

  Widget _aboutCard() => CardX(child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text('云同步服务', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
      const SizedBox(height: 8),
      Text('此功能由 Hermes + deepseek-v4-flash AI 辅助开发。',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
      const SizedBox(height: 4),
      Text('同步数据使用 AES-256-GCM 端到端加密，',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      Text('加密密钥派生自注册 UUID，仅存于本地设备，',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      Text('服务端无法解密任何数据。',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      const SizedBox(height: 6),
      Text('服务端地址: ${SyncConfig.serverUrl}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
    ]),
  ));

  // ════════════════════════════════════════════
  //  对比表格
  // ════════════════════════════════════════════

  Widget _comparisonCard() => CardX(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _compRow(isHeader: true, children: [
          const Expanded(flex: 3, child: Text('', style: TextStyle(fontWeight: FontWeight.w600))),
          const Expanded(flex: 4, child: Text('☁️ 云同步', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
          const Expanded(flex: 5, child: Text('📦 内置备份', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
        ]),
        const Divider(height: 1),
        _compRow(children: [
          const Expanded(flex: 3, child: Text('触发方式', style: TextStyle(fontSize: 12))),
          const Expanded(flex: 4, child: Text('一键同步', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
          const Expanded(flex: 5, child: Text('手动导出/导入', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
        ]),
        _compRow(children: [
          const Expanded(flex: 3, child: Text('加密方式', style: TextStyle(fontSize: 12))),
          Expanded(flex: 4, child: Text('UUID 派生密钥\nAES-256-GCM', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
          Expanded(flex: 5, child: Text('自定义备份密码\nAES-GCM', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
        ]),
        _compRow(children: [
          const Expanded(flex: 3, child: Text('多设备', style: TextStyle(fontSize: 12))),
          const Expanded(flex: 4, child: Text('登录即自动同步', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
          const Expanded(flex: 5, child: Text('需手动传输文件', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
        ]),
        _compRow(children: [
          const Expanded(flex: 3, child: Text('存储位置', style: TextStyle(fontSize: 12))),
          const Expanded(flex: 4, child: Text('云端服务器', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
          const Expanded(flex: 5, child: Text('WebDAV / Gist / 本地', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
        ]),
        _compRow(children: [
          const Expanded(flex: 3, child: Text('账号系统', style: TextStyle(fontSize: 12))),
          const Expanded(flex: 4, child: Text('有，可多设备登录', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
          const Expanded(flex: 5, child: Text('无账号，本地使用', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
        ]),
        _compRow(children: [
          const Expanded(flex: 3, child: Text('数据恢复', style: TextStyle(fontSize: 12))),
          const Expanded(flex: 4, child: Text('支持导出到邮箱', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
          const Expanded(flex: 5, child: Text('本地文件直接恢复', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
        ]),
        _compRow(children: [
          const Expanded(flex: 3, child: Text('是否可解密', style: TextStyle(fontSize: 12))),
          Expanded(flex: 4, child: Text('仅本地可解密\n服务端无法解密', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
          Expanded(flex: 5, child: Text('仅本地可解密\n存储端无法解密', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
        ]),
      ]),
    ),
  );

  Widget _compRow({required List<Widget> children, bool isHeader = false}) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
      color: isHeader ? Colors.grey.shade100 : null,
    ),
    child: Row(children: children),
  );

  Widget _usageCard() => CardX(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber.shade700),
          const SizedBox(width: 6),
          Text('推荐用法', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.amber.shade800)),
        ]),
        const SizedBox(height: 8),
        _tip('多设备间同步服务器数据 → 推荐使用云同步'),
        _tip('换手机迁移 → 云同步一键下载恢复'),
        _tip('需要本地存档 → 可用内置备份导出到 WebDAV/Gist/本地'),
        _tip('也可以两者同时使用，互不影响'),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Expanded(child: Text('云同步和内置备份使用不同的加密方式，数据格式独立。云同步通过 UUID 派生密钥加密传输，内置备份通过自定义密码本地加密。两者可根据需要选用。',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
        ]),
      ]),
    ),
  );

  Widget _tip(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('• ', style: TextStyle(fontSize: 12)),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
    ]),
  );

  // ════════════════════════════════════════════
  //  多步删除 / 注销流程
  // ════════════════════════════════════════════

  Future<void> _startDeleteFlow() async {
    final s = ref.read(syncNotifierProvider);
    final warn = await context.showRoundDialog<bool>(
      title: '⚠ 删除同步数据',
      child: const Text('将永久删除服务端存储的所有加密同步数据。\n\n删除前需要身份验证。'),
      actions: Btnx.cancelOk,
    );
    if (warn != true) return;

    final verified = await _verifyIdentity(s);
    if (!verified) return;

    final pwdOk = await _verifyPassword();
    if (!pwdOk) return;

    final confirmed = await context.showRoundDialog<bool>(
      title: '确认删除',
      child: const Text('确定要删除所有同步数据吗？\n此操作不可撤销。'),
      actions: Btnx.cancelOk,
    );
    if (confirmed != true) return;

    final wantExport = await context.showRoundDialog<bool>(
      title: '导出备份',
      child: const Text('是否将加密数据导出并发送到您的邮箱？\n\n万一后悔时可以找回并解密恢复。'),
      actions: [
        TextButton(onPressed: () => context.pop(false), child: const Text('不导出')),
        ElevatedButton(onPressed: () => context.pop(true), child: const Text('导出到邮箱')),
      ],
    );

    String? exportMsg;
    if (wantExport == true) {
      try {
        final exportRes = await context.showLoadingDialog(fn: () => SyncClient.shared.exportToEmail());
        exportMsg = exportRes.$1;
      } catch (e) {
        await _showError(SyncError.parse(e));
        final cont = await context.showRoundDialog<bool>(
          title: '导出失败',
          child: Text('导出失败，是否仍然删除数据？\n错误: ${SyncError.parse(e).message}'),
          actions: Btnx.cancelOk,
        );
        if (cont != true) return;
      }
    }

    try {
      await context.showLoadingDialog(
        fn: () => SyncClient.shared.deleteData(dataType: SyncConfig.dataType),
      );
      final msg = exportMsg != null ? '数据已删除，备份已发送到邮箱' : '数据已删除';
      context.showSnackBar(msg);
      setState(() {});
    } catch (e) {
      await _showError(SyncError.parse(e));
    }
  }

  Future<bool> _verifyIdentity(SyncState s, {String purpose = 'sync_data'}) async {
    if (s.totpEnabled) {
      return _verifyTotp();
    } else {
      return _verifyEmailCode(purpose: purpose);
    }
  }

  Future<bool> _verifyTotp() async {
    final ctrl = TextEditingController();
    final result = await context.showRoundDialog<bool>(
      title: 'TOTP 验证',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('请输入 6 位 TOTP 验证码', style: UIs.textGrey),
        const SizedBox(height: 10),
        Input(label: '验证码', controller: ctrl, onSubmitted: (_) => context.pop(true)),
      ]),
      actions: Btnx.oks,
    );
    if (result != true) { ctrl.dispose(); return false; }
    final code = ctrl.text.trim();
    ctrl.dispose();
    if (code.isEmpty) { context.showSnackBar('请输入验证码'); return false; }
    try {
      await context.showLoadingDialog(fn: () => SyncClient.shared.verifyDeleteCode(code: code));
      return true;
    } catch (e) {
      await _showError(SyncError.parse(e));
      return false;
    }
  }

  Future<bool> _verifyEmailCode({String purpose = 'sync_data'}) async {
    try {
      final sendRes = await context.showLoadingDialog(
        fn: () => SyncClient.shared.sendDeleteCode(purpose: purpose),
      );
      context.showSnackBar(sendRes.$1 ?? '验证码已发送');
    } catch (e) {
      await _showError(SyncError.parse(e));
      return false;
    }

    final ctrl = TextEditingController();
    final result = await context.showRoundDialog<bool>(
      title: '邮箱验证',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('验证码已发送到您的邮箱，请查收', style: UIs.textGrey),
        const SizedBox(height: 10),
        Input(label: '6 位验证码', controller: ctrl, onSubmitted: (_) => context.pop(true)),
      ]),
      actions: Btnx.oks,
    );
    if (result != true) { ctrl.dispose(); return false; }
    final code = ctrl.text.trim();
    ctrl.dispose();
    if (code.isEmpty) { context.showSnackBar('请输入验证码'); return false; }
    try {
      await context.showLoadingDialog(fn: () => SyncClient.shared.verifyDeleteCode(code: code));
      return true;
    } catch (e) {
      await _showError(SyncError.parse(e));
      return false;
    }
  }

  Future<bool> _verifyPassword() async {
    final ctrl = TextEditingController();
    final result = await context.showRoundDialog<bool>(
      title: '密码验证',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('请输入登录密码以确认删除', style: UIs.textGrey),
        const SizedBox(height: 10),
        Input(label: '登录密码', controller: ctrl, obscureText: true, onSubmitted: (_) => context.pop(true)),
      ]),
      actions: Btnx.oks,
    );
    if (result != true) { ctrl.dispose(); return false; }
    final pwd = ctrl.text.trim();
    ctrl.dispose();
    if (pwd.isEmpty) { context.showSnackBar('请输入密码'); return false; }

    final username = ref.read(syncNotifierProvider).username;
    if (username == null) { context.showSnackBar('内部错误'); return false; }

    try {
      await SyncClient.shared.login(username: username, password: pwd);
      return true;
    } on SyncTOTPRequiredException {
      return true;
    } catch (e) {
      await _showError(SyncError.parse(e));
      return false;
    }
  }

  // ════════════════════════════════════════════
  //  登录 / 注册 / 忘记密码
  // ════════════════════════════════════════════

  Future<void> _showLoginDialog() async {
    final uCtrl = TextEditingController(), pCtrl = TextEditingController(), tCtrl = TextEditingController();
    final uNode = FocusNode(), pNode = FocusNode();
    final result = await context.showRoundDialog<bool>(
      title: '登录同步账户',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Input(label: '用户名', controller: uCtrl, node: uNode, onSubmitted: (_) => pNode.requestFocus()),
        UIs.height13,
        Input(label: '密码', controller: pCtrl, node: pNode, obscureText: true, onSubmitted: (_) => context.pop(true)),
        UIs.height13,
        Input(label: 'TOTP 验证码（可选）', controller: tCtrl),
        UIs.height7,
        Row(children: [
          TextButton(onPressed: () { context.pop(); _showRegisterDialog(); }, child: const Text('没有账号？注册', style: TextStyle(fontSize: 13))),
          const Spacer(),
          TextButton(onPressed: () { context.pop(); _showForgotPasswordDialog(); }, child: const Text('忘记密码？', style: TextStyle(fontSize: 13))),
        ]),
      ]),
      actions: Btnx.oks,
    );
    if (result != true) { uCtrl.dispose(); pCtrl.dispose(); tCtrl.dispose(); uNode.dispose(); pNode.dispose(); return; }
    final u = uCtrl.text.trim(), p = pCtrl.text.trim(), t = tCtrl.text.trim();
    uCtrl.dispose(); pCtrl.dispose(); tCtrl.dispose(); uNode.dispose(); pNode.dispose();
    if (u.isEmpty || p.isEmpty) { context.showSnackBar('用户名和密码不能为空'); return; }
    try {
      final err = await ref.read(syncNotifierProvider.notifier).login(username: u, password: p, totpCode: t.isNotEmpty ? t : null);
      if (err == null) {
        context.showSnackBar('登录成功');
        setState(() {});
      } else if (err == 'totp_required') {
        context.showSnackBar('需要 TOTP 验证码');
        _showLoginWithTotp(u, p);
      }
    } catch (e) {
      await _showError(SyncError.parse(e));
    }
  }

  Future<void> _showLoginWithTotp(String u, String p) async {
    final ctrl = TextEditingController();
    final r = await context.showRoundDialog<bool>(title: 'TOTP 验证', child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('请输入 6 位验证码', style: UIs.textGrey), UIs.height13,
      Input(label: 'TOTP 验证码', controller: ctrl, onSubmitted: (_) => context.pop(true)),
    ]), actions: Btnx.oks);
    if (r != true) { ctrl.dispose(); return; }
    final code = ctrl.text.trim(); ctrl.dispose();
    if (code.isEmpty) { context.showSnackBar('验证码不能为空'); return; }
    try {
      final err = await ref.read(syncNotifierProvider.notifier).login(username: u, password: p, totpCode: code);
      if (err == null) { context.showSnackBar('登录成功'); setState(() {}); }
    } catch (e) {
      await _showError(SyncError.parse(e));
    }
  }

  Future<void> _showRegisterDialog() async {
    final uCtrl = TextEditingController(), nCtrl = TextEditingController(), eCtrl = TextEditingController();
    final pCtrl = TextEditingController(), iCtrl = TextEditingController();
    final uN = FocusNode(), nN = FocusNode(), eN = FocusNode(), pN = FocusNode(), iN = FocusNode();
    final r = await context.showRoundDialog<bool>(title: '注册同步账号', child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('需要邀请码才能注册', style: UIs.textGrey), UIs.height13,
      Input(label: '用户名 *（英文数字下划线，3-64位）', controller: uCtrl, node: uN, onSubmitted: (_) => nN.requestFocus()), UIs.height7,
      Input(label: '昵称（选填，中英文64位内）', controller: nCtrl, node: nN, onSubmitted: (_) => eN.requestFocus()), UIs.height7,
      Input(label: '邮箱地址 *', controller: eCtrl, node: eN, onSubmitted: (_) => pN.requestFocus()), UIs.height7,
      Input(label: '密码 *（8-128位）', controller: pCtrl, node: pN, obscureText: true, onSubmitted: (_) => iN.requestFocus()), UIs.height7,
      Input(label: '邀请码 *', controller: iCtrl, node: iN, onSubmitted: (_) => context.pop(true)),
    ]), actions: [TextButton(onPressed: () => context.pop(false), child: const Text('取消')), ElevatedButton(onPressed: () => context.pop(true), child: const Text('注册'))]);
    if (r != true) { _dispose([uCtrl,nCtrl,eCtrl,pCtrl,iCtrl],[uN,nN,eN,pN,iN]); return; }
    final u = uCtrl.text.trim(), n = nCtrl.text.trim(), e = eCtrl.text.trim(), p = pCtrl.text.trim(), inv = iCtrl.text.trim();
    _dispose([uCtrl,nCtrl,eCtrl,pCtrl,iCtrl],[uN,nN,eN,pN,iN]);
    if (u.isEmpty||e.isEmpty||p.isEmpty||inv.isEmpty) { context.showSnackBar('请填写所有必填字段（带 * 号）'); return; }
    try {
      final resp = await context.showLoadingDialog(fn: () => SyncClient.shared.register(username: u, nickname: n.isNotEmpty?n:null, email: e, password: p, inviteCode: inv));
      if (resp.$1 != null) {
        if (resp.$1!.recoveryKey != null) {
          await context.showRoundDialog(title: '注册成功', child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('账号注册成功！'), const SizedBox(height: 10), const Text('请保存 Recovery Key：'),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: SelectableText(resp.$1!.recoveryKey!, style: const TextStyle(fontFamily: 'monospace', fontSize: 14))),
            const Text('此密钥仅显示一次！', style: TextStyle(color: Colors.red, fontSize: 12)),
          ]), actions: [TextButton(onPressed: () => context.pop(), child: const Text('知道了'))]);
        } else { context.showSnackBar(resp.$1!.message); }
      } else { await _showError(SyncError.parse(Exception(resp.$2 ?? '注册失败'))); }
    } catch (e) { await _showError(SyncError.parse(e)); }
  }

  /// 选择图片并上传头像
  Future<void> _pickAndUploadAvatar(SyncState s) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;

      // 弹出圆形裁剪对话框
      final croppedBytes = await AvatarCropDialog.show(context, io.File(filePath));
      if (croppedBytes == null) return; // 用户取消

      // 将裁剪后的字节写为临时文件
      final tempDir = await io.Directory.systemTemp.createTemp('avatar_');
      final cropFile = io.File('${tempDir.path}/avatar_cropped.png');
      await cropFile.writeAsBytes(croppedBytes);

      final newUrl = await context.showLoadingDialog(
        fn: () => SyncClient.shared.uploadAvatar(cropFile.path),
      );

      // 清理临时文件
      try { await cropFile.delete(); await tempDir.delete(); } catch (_) {}

      if (newUrl.$1 != null) {
        await SyncConfig.avatarUrl.write(newUrl.$1);
        ref.read(syncNotifierProvider.notifier).refreshProfile();
        if (context.mounted) {
          context.showSnackBar('头像上传成功');
          setState(() {});
        }
      }
    } catch (e) {
      if (context.mounted) await _showError(SyncError.parse(e));
    }
  }

  void _dispose(List<TextEditingController> cs, List<FocusNode> ns) {
    for (var c in cs) { c.dispose(); }
    for (var n in ns) { n.dispose(); }
  }

  Future<void> _showForgotPasswordDialog() async {
    final ctrl = TextEditingController(), node = FocusNode();
    final r = await context.showRoundDialog<bool>(title: '忘记密码', child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('输入用户名或注册邮箱', style: UIs.textGrey), UIs.height13,
      Input(label: '用户名 / 邮箱地址', controller: ctrl, node: node, onSubmitted: (_) => context.pop(true)),
    ]), actions: Btnx.oks);
    if (r != true) { ctrl.dispose(); node.dispose(); return; }
    final id = ctrl.text.trim(); ctrl.dispose(); node.dispose();
    if (id.isEmpty) { context.showSnackBar('请输入用户名或邮箱'); return; }
    try {
      final resp = await context.showLoadingDialog(fn: () => SyncClient.shared.forgotPassword(usernameOrEmail: id));
      if (resp.$1 != null && resp.$1!.token != null) {
        final ok = await context.showRoundDialog<bool>(title: '重置令牌', child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(resp.$1!.message, style: UIs.textGrey), const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: SelectableText(resp.$1!.token!, style: const TextStyle(fontFamily: 'monospace', fontSize: 16))),
        ]), actions: [TextButton(onPressed: ()=>context.pop(false), child: const Text('稍后')), ElevatedButton(onPressed: ()=>context.pop(true), child: const Text('重置密码'))]);
        if (ok == true) _showResetPasswordDialog(resp.$1!.token);
      } else if (resp.$1 != null) { context.showSnackBar(resp.$1!.message); }
      else { await _showError(SyncError.parse(Exception(resp.$2 ?? '请求失败'))); }
    } catch (e) { await _showError(SyncError.parse(e)); }
  }

  Future<void> _showResetPasswordDialog(String? initialToken) async {
    final tCtrl = TextEditingController(text: initialToken??''), pCtrl = TextEditingController(), cCtrl = TextEditingController();
    final tN = FocusNode(), pN = FocusNode(), cN = FocusNode();
    final r = await context.showRoundDialog<bool>(title: '重置密码', child: Column(mainAxisSize: MainAxisSize.min, children: [
      Input(label: '重置令牌', controller: tCtrl, node: tN, onSubmitted: (_)=>pN.requestFocus()), UIs.height7,
      Input(label: '新密码', controller: pCtrl, node: pN, obscureText: true, onSubmitted: (_)=>cN.requestFocus()), UIs.height7,
      Input(label: '确认新密码', controller: cCtrl, node: cN, obscureText: true, onSubmitted: (_)=>context.pop(true)),
    ]), actions: Btnx.oks);
    if (r != true) { tCtrl.dispose(); pCtrl.dispose(); cCtrl.dispose(); tN.dispose(); pN.dispose(); cN.dispose(); return; }
    final t = tCtrl.text.trim(), p = pCtrl.text.trim(), c = cCtrl.text.trim();
    tCtrl.dispose(); pCtrl.dispose(); cCtrl.dispose(); tN.dispose(); pN.dispose(); cN.dispose();
    if (t.isEmpty||p.isEmpty||c.isEmpty) { context.showSnackBar('请填写所有字段'); return; }
    if (p!=c) { context.showSnackBar('两次密码不一致'); return; }
    if (p.length<8) { context.showSnackBar('密码至少 8 位'); return; }
    try {
      await context.showLoadingDialog(fn: ()=>SyncClient.shared.resetPassword(token:t, newPassword:p));
      await _showSuccess('密码已重置', '密码已重置成功，请使用新密码登录');
    } catch (e) { await _showError(SyncError.parse(e)); }
  }

  // ════════════════════════════════════════════
  //  同步操作
  // ════════════════════════════════════════════

  Future<void> _doSync() async {
    final notifier = ref.read(syncNotifierProvider.notifier);
    final r = await context.showLoadingDialog(fn: () => SyncEngine.syncAll());
    if (r.$1 != null) {
      context.showSnackBar(r.$1!);
      notifier.checkForUpdates();
      setState(() {});
    } else if (r.$2 != null) {
      await _showError(SyncError.parse(Exception(r.$2!)));
    }
  }

  Future<void> _doUpload() async {
    final notifier = ref.read(syncNotifierProvider.notifier);
    final e = await context.showLoadingDialog(fn: () => notifier.upload());
    if (e.$1 == null) {
      context.showSnackBar('上传成功');
    } else {
      await _showError(SyncError.parse(Exception(e.$1!)));
    }
    setState(() {});
  }

  Future<void> _doDownload() async {
    final c = await context.showRoundDialog<bool>(
      title: '确认下载恢复',
      child: const Text('将从服务端下载数据并覆盖本地内容'),
      actions: Btnx.cancelOk,
    );
    if (c != true) return;
    final e = await context.showLoadingDialog(
      fn: () => ref.read(syncNotifierProvider.notifier).download(),
    );
    if (e.$1 == null) {
      context.showSnackBar('下载恢复成功');
    } else {
      await _showError(SyncError.parse(Exception(e.$1!)));
    }
    setState(() {});
  }
}