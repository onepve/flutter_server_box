import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/sync/sync_client.dart';
import 'package:server_box/sync/sync_config.dart';
import 'package:server_box/sync/sync_engine.dart';
import 'package:server_box/sync/sync_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// 服务端同步设置页面
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
      appBar: CustomAppBar(title: const Text('服务端同步')),
      body: SafeArea(
        child: MultiList(widthDivider: 2, children: [
          [CenterGreyTitle('同步账号'), _buildLoginStatus(syncState),
           if (!syncState.loggedIn) _buildLoginButton(syncState),
           if (syncState.loggedIn) ..._buildLoggedInItems(syncState)],
          [CenterGreyTitle('同步操作'),
           if (syncState.loggedIn) _buildSyncButtons(syncState)],
          [CenterGreyTitle('关于'), _buildAboutItem],
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  登录状态 — 只有头像 + 昵称，点击展开完整资料
  // ═══════════════════════════════════════════════════

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
        onTap: s.loggedIn ? () => _showProfileDialog(s) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // 头像
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? Icon(Icons.person, size: 26, color: Colors.grey.shade500)
                  : null,
            ),
            UIs.height10,
            // 昵称
            Text(_displayName(s),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (s.loggedIn) ...[
              UIs.height4,
              Text('点击查看完整资料',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  完整资料弹窗
  // ═══════════════════════════════════════════════════

  Future<void> _showProfileDialog(SyncState s) async {
    ref.read(syncNotifierProvider.notifier).refreshProfile();
    await context.showRoundDialog(
      title: '个人资料',
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: CircleAvatar(
            radius: 32, backgroundColor: Colors.grey.shade200,
            backgroundImage: _fullAvatarUrl(s.avatarUrl).isNotEmpty
                ? NetworkImage(_fullAvatarUrl(s.avatarUrl)) : null,
            child: _fullAvatarUrl(s.avatarUrl).isEmpty
                ? Icon(Icons.person, size: 28, color: Colors.grey.shade500) : null,
          ),
        ),
        UIs.height13,
        _pRow('用户名', s.username ?? '—'),
        _pRow('昵称', (s.nickname != null && s.nickname!.isNotEmpty) ? s.nickname! : '未设置'),
        _pRow('邮箱', s.email ?? '—'),
        _pRow('邮箱验证', s.emailVerified ? '已验证 ✓' : '未验证',
            vc: s.emailVerified ? Colors.green : Colors.orange),
        _pRow('TOTP 双因素', s.totpEnabled ? '已开启 ✓' : '未开启',
            vc: s.totpEnabled ? Colors.green : Colors.orange.shade400),
        UIs.height10,
        if (!s.totpEnabled)
          _totpPrompt(),
        if (s.totpEnabled)
          _totpEnabled(),
      ]),
      actions: [TextButton(onPressed: () => context.pop(), child: const Text('关闭'))],
    );
  }

  Widget _totpPrompt() {
    return Container(
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
  }

  Widget _totpEnabled() {
    return Container(
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
  }

  Widget _pRow(String label, String value, {Color? vc}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: vc))),
    ]),
  );

  // ═══════════════════════════════════════════════════
  //  登录 / 退出 / 同步按钮（不变）
  // ═══════════════════════════════════════════════════

  Widget _buildLoginButton(SyncState s) => CardX(child: ListTile(
    leading: const Icon(Icons.login), title: const Text('登录同步账户'),
    subtitle: Text('服务端地址已固定，无需手动配置', style: UIs.textGrey),
    trailing: s.syncing
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.chevron_right),
    onTap: s.syncing ? null : () => _showLoginDialog(),
  ));

  List<Widget> _buildLoggedInItems(SyncState s) => [
    CardX(child: ListTile(
      leading: const Icon(Icons.logout), title: const Text('退出登录'),
      onTap: () async { await ref.read(syncNotifierProvider.notifier).logout(); setState(() {}); },
    )),
    if (s.lastSyncAt > 0)
      CardX(child: ListTile(leading: const Icon(Icons.history), title: const Text('上次同步'),
        subtitle: Text(s.lastSyncMessage ?? '未知', style: UIs.textGrey))),
    if (s.error != null)
      CardX(child: ListTile(leading: const Icon(Icons.error_outline, color: Colors.red),
        title: Text(s.error!, style: const TextStyle(color: Colors.red)))),
    // ── 删除同步数据 ──
    CardX(child: ListTile(
      leading: const Icon(Icons.delete_forever, color: Colors.red),
      title: const Text('删除同步数据', style: TextStyle(color: Colors.red)),
      subtitle: Text('清空服务端加密数据（需身份验证）', style: UIs.textGrey),
      onTap: () => _startDeleteFlow(),
    )),
  ];

  Widget _buildSyncButtons(SyncState s) {
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

  Widget get _buildAboutItem => CardX(child: ListTile(
    leading: const Icon(Icons.info_outline), title: const Text('服务端同步'),
    subtitle: Text('数据端到端加密，服务端无法解密\n服务端地址: ${SyncConfig.serverUrl}',
        style: UIs.textGrey.copyWith(fontSize: 12)),
  ));

  // ═══════════════════════════════════════════════════
  //  多步删除流程
  // ═══════════════════════════════════════════════════

  Future<void> _startDeleteFlow() async {
    final s = ref.read(syncNotifierProvider);
    // ── ⚠ 初始警告 ──
    final warn = await context.showRoundDialog<bool>(
      title: '⚠ 删除同步数据',
      child: const Text('将永久删除服务端存储的所有加密同步数据。\n\n删除前需要身份验证。'),
      actions: Btnx.cancelOk,
    );
    if (warn != true) return;

    // ── 第 1 步：身份验证 ──
    final verified = await _verifyIdentity(s);
    if (!verified) return;

    // ── 第 2 步：输入密码 ──
    final pwdOk = await _verifyPassword();
    if (!pwdOk) return;

    // ── 第 3 步：二次确认 ──
    final confirmed = await context.showRoundDialog<bool>(
      title: '确认删除',
      child: const Text('确定要删除所有同步数据吗？\n此操作不可撤销。'),
      actions: Btnx.cancelOk,
    );
    if (confirmed != true) return;

    // ── 第 4 步：导出备份？ ──
    final wantExport = await context.showRoundDialog<bool>(
      title: '导出备份',
      child: const Text('是否将加密数据导出并发送到您的邮箱？\n\n万一后悔时可以找回并解密恢复。'),
      actions: [
        TextButton(onPressed: () => context.pop(false), child: const Text('不导出')),
        ElevatedButton(onPressed: () => context.pop(true), child: const Text('导出到邮箱')),
      ],
    );

    // ── 第 5 步：执行删除 + 导出 ──
    String? exportMsg;
    if (wantExport == true) {
      try {
        exportMsg = await context.showLoadingDialog(fn: () => SyncClient.shared.exportToEmail());
      } catch (e) {
        context.showSnackBar('导出失败: $e');
        // 询问是否继续删除
        final cont = await context.showRoundDialog<bool>(
          title: '导出失败',
          child: Text('导出失败，是否仍然删除数据？\n错误: $e'),
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
      context.showSnackBar('删除失败: $e');
    }
  }

  /// 第 1 步：身份验证（TOTP 码或邮件验证码）
  Future<bool> _verifyIdentity(SyncState s) async {
    if (s.totpEnabled) {
      return _verifyTotp();
    } else {
      return _verifyEmailCode();
    }
  }

  Future<bool> _verifyTotp() async {
    final ctrl = TextEditingController();
    final result = await context.showRoundDialog<bool>(
      title: 'TOTP 验证',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('请输入 6 位 TOTP 验证码', style: UIs.textGrey),
        UIs.height10,
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
      context.showSnackBar('验证失败: $e');
      return false;
    }
  }

  Future<bool> _verifyEmailCode() async {
    // 发送验证码
    try {
      final msg = await context.showLoadingDialog(fn: () => SyncClient.shared.sendDeleteCode());
      context.showSnackBar(msg);
    } catch (e) {
      context.showSnackBar('发送失败: $e');
      return false;
    }

    final ctrl = TextEditingController();
    final result = await context.showRoundDialog<bool>(
      title: '邮箱验证',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('验证码已发送到您的邮箱，请查收', style: UIs.textGrey),
        UIs.height10,
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
      context.showSnackBar('验证失败: $e');
      return false;
    }
  }

  /// 第 2 步：输入密码验证
  Future<bool> _verifyPassword() async {
    final ctrl = TextEditingController();
    final result = await context.showRoundDialog<bool>(
      title: '密码验证',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('请输入登录密码以确认删除', style: UIs.textGrey),
        UIs.height10,
        Input(label: '登录密码', controller: ctrl, obscureText: true, onSubmitted: (_) => context.pop(true)),
      ]),
      actions: Btnx.oks,
    );
    if (result != true) { ctrl.dispose(); return false; }
    final pwd = ctrl.text.trim();
    ctrl.dispose();
    if (pwd.isEmpty) { context.showSnackBar('请输入密码'); return false; }

    // 用当前用户名 + 密码尝试登录验证
    final username = ref.read(syncNotifierProvider).username;
    if (username == null) { context.showSnackBar('内部错误'); return false; }

    try {
      await SyncClient.shared.login(username: username, password: pwd);
      return true;
    } on SyncTOTPRequiredException {
      // TOTP 开了但这里不需要完整登录——密码正确就够了
      return true;
    } catch (e) {
      context.showSnackBar('密码错误');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════
  //  登录 / 注册 / 忘记密码 / 同步操作
  // ═══════════════════════════════════════════════════

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
    final err = await ref.read(syncNotifierProvider.notifier).login(username: u, password: p, totpCode: t.isNotEmpty ? t : null);
    if (err == null) { context.showSnackBar('登录成功'); setState(() {}); }
    else if (err == 'totp_required') { context.showSnackBar('需要 TOTP 验证码'); _showLoginWithTotp(u, p); }
    else { context.showSnackBar('登录失败: $err'); }
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
    final err = await ref.read(syncNotifierProvider.notifier).login(username: u, password: p, totpCode: code);
    if (err == null) { context.showSnackBar('登录成功'); setState(() {}); }
    else { context.showSnackBar('登录失败: $err'); }
  }

  Future<void> _showRegisterDialog() async {
    final uCtrl = TextEditingController(), nCtrl = TextEditingController(), eCtrl = TextEditingController();
    final pCtrl = TextEditingController(), iCtrl = TextEditingController();
    final uN = FocusNode(), nN = FocusNode(), eN = FocusNode(), pN = FocusNode(), iN = FocusNode();
    final r = await context.showRoundDialog<bool>(title: '注册同步账号', child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('需要邀请码才能注册', style: UIs.textGrey), UIs.height13,
      Input(label: '用户名 *', controller: uCtrl, node: uN, onSubmitted: (_) => nN.requestFocus()), UIs.height7,
      Input(label: '昵称（选填）', controller: nCtrl, node: nN, onSubmitted: (_) => eN.requestFocus()), UIs.height7,
      Input(label: '邮箱地址 *', controller: eCtrl, node: eN, onSubmitted: (_) => pN.requestFocus()), UIs.height7,
      Input(label: '密码 *', controller: pCtrl, node: pN, obscureText: true, onSubmitted: (_) => iN.requestFocus()), UIs.height7,
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
            const Text('账号注册成功！'), UIs.height10, const Text('请保存 Recovery Key：'),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: SelectableText(resp.$1!.recoveryKey!, style: const TextStyle(fontFamily: 'monospace', fontSize: 14))),
            const Text('此密钥仅显示一次！', style: TextStyle(color: Colors.red, fontSize: 12)),
          ]), actions: [TextButton(onPressed: () => context.pop(), child: const Text('知道了'))]);
        } else { context.showSnackBar(resp.$1!.message); }
      } else { context.showSnackBar('注册失败: ${resp.$2}'); }
    } catch (e) { context.showSnackBar('网络错误: $e'); }
  }

  void _dispose(List<TextEditingController> cs, List<FocusNode> ns) { for (var c in cs) c.dispose(); for (var n in ns) n.dispose(); }

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
          Text(resp.$1!.message, style: UIs.textGrey), UIs.height10,
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: SelectableText(resp.$1!.token!, style: const TextStyle(fontFamily: 'monospace', fontSize: 16))),
        ]), actions: [TextButton(onPressed: ()=>context.pop(false), child: const Text('稍后')), ElevatedButton(onPressed: ()=>context.pop(true), child: const Text('重置密码'))]);
        if (ok == true) _showResetPasswordDialog(resp.$1!.token);
      } else if (resp.$1 != null) { context.showSnackBar(resp.$1!.message); }
      else { context.showSnackBar('请求失败: ${resp.$2}'); }
    } catch (e) { context.showSnackBar('网络错误: $e'); }
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
      context.showSnackBar('密码已重置成功');
    } catch (e) { context.showSnackBar('重置失败: $e'); }
  }

  Future<void> _doSync() async { final p = await _requirePwd(); if (p==null) return; final notifier = ref.read(syncNotifierProvider.notifier); final r = await context.showLoadingDialog(fn: ()=>SyncEngine.syncAll(p)); if (r.$1!=null) { context.showSnackBar(r.$1!); notifier.checkForUpdates(); setState((){}); } else if (r.$2!=null) { notifier.logout(); context.showSnackBar('同步失败: ${r.$2}'); } }
  Future<void> _doUpload() async { final p = await _requirePwd(); if (p==null) return; final notifier = ref.read(syncNotifierProvider.notifier); final e = await context.showLoadingDialog(fn: ()=>notifier.upload(password:p)); if (e.$1==null) context.showSnackBar('上传成功'); else context.showSnackBar('上传失败: ${e.$1}'); setState((){}); }
  Future<void> _doDownload() async { final p = await _requirePwd(); if (p==null) return; final c = await context.showRoundDialog<bool>(title:'确认下载恢复', child: const Text('将从服务端下载数据并覆盖本地内容'), actions:Btx.cancelOk); if (c!=true) return; final e = await context.showLoadingDialog(fn: ()=>ref.read(syncNotifierProvider.notifier).download(password:p)); if (e.$1==null) context.showSnackBar('下载恢复成功'); else context.showSnackBar('下载失败: ${e.$1}'); setState((){}); }

  Future<String?> _requirePwd() async {
    final saved = await SecureStoreProps.bakPwd.read(); if (saved!=null && saved.isNotEmpty) return saved;
    final ctrl = TextEditingController();
    final r = await context.showRoundDialog<bool>(title:'同步加密密码', child:Column(mainAxisSize:MainAxisSize.min,children:[
      Text('数据会用此密码加密后上传\n建议与登录密码相同',style:UIs.textGrey),UIs.height13,
      Input(label:'加密密码',controller:ctrl,obscureText:true,onSubmitted:(_)=>context.pop(true)),
    ]),actions:Btx.oks);
    if (r==true && ctrl.text.trim().isNotEmpty) { final p=ctrl.text.trim(); await SecureStoreProps.bakPwd.write(p); ctrl.dispose(); return p; }
    ctrl.dispose(); return null;
  }
}
