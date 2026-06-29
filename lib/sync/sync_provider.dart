import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/sync/sync_client.dart';
import 'package:server_box/sync/sync_config.dart';
import 'package:server_box/sync/sync_crypto.dart';

final _logger = Logger('SyncProvider');

// ═══════════════════════════════════════════════════════════════════
//  同步状态模型（手写 Riverpod Notifier，不依赖代码生成）
// ═══════════════════════════════════════════════════════════════════

/// 同步模块状态
class SyncState {
  final bool loggedIn;
  final String? username;
  final int serverVersion;
  final int localVersion;
  final bool syncing;
  final int lastSyncAt;
  final String? lastSyncMessage;
  final String? error;

  const SyncState({
    this.loggedIn = false,
    this.username,
    this.serverVersion = 0,
    this.localVersion = 0,
    this.syncing = false,
    this.lastSyncAt = 0,
    this.lastSyncMessage,
    this.error,
  });

  SyncState copyWith({
    bool? loggedIn,
    String? username,
    int? serverVersion,
    int? localVersion,
    bool? syncing,
    int? lastSyncAt,
    String? lastSyncMessage,
    String? error,
    bool clearError = false,
  }) {
    return SyncState(
      loggedIn: loggedIn ?? this.loggedIn,
      username: username ?? this.username,
      serverVersion: serverVersion ?? this.serverVersion,
      localVersion: localVersion ?? this.localVersion,
      syncing: syncing ?? this.syncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncMessage: lastSyncMessage ?? this.lastSyncMessage,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 同步状态管理（手动实现，免 build_runner）
final syncNotifierProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
  name: 'syncNotifierProvider',
);

class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    _init();
    return const SyncState();
  }

  Future<void> _init() async {
    final token = await SyncConfig.token.read();
    final name = await SyncConfig.username.read();
    if (token != null && token.isNotEmpty && name != null) {
      state = state.copyWith(loggedIn: true, username: name);
    }
  }

  /// 登录
  Future<String?> login({
    required String username,
    required String password,
    String? totpCode,
  }) async {
    state = state.copyWith(syncing: true, clearError: true);
    try {
      final result = await SyncClient.shared.login(
        username: username,
        password: password,
        totpCode: totpCode,
      );
      await SyncConfig.token.write(result.token);
      await SyncConfig.username.write(result.username);
      state = state.copyWith(
        loggedIn: true,
        username: result.username,
        syncing: false,
      );
      return null;
    } on SyncTOTPRequiredException {
      state = state.copyWith(syncing: false);
      return 'totp_required';
    } catch (e) {
      _logger.warning('Login failed', e);
      state = state.copyWith(syncing: false, error: e.toString());
      return e.toString();
    }
  }

  /// 登出
  Future<void> logout() async {
    await SyncConfig.token.write(null);
    await SyncConfig.username.write(null);
    state = const SyncState();
  }

  /// 上传同步数据到服务端
  Future<String?> upload({required String password}) async {
    state = state.copyWith(syncing: true, clearError: true);
    try {
      final ciphertext = await SyncCrypto.buildSyncPayload(password);
      final plaintextSize = ciphertext.length;

      final serverVersion = await SyncClient.shared.upload(
        ciphertext: ciphertext,
        plaintextSize: plaintextSize,
        clientVersion: state.localVersion,
      );

      state = state.copyWith(
        serverVersion: serverVersion,
        localVersion: serverVersion,
        syncing: false,
        lastSyncAt: DateTime.now().millisecondsSinceEpoch,
        lastSyncMessage: '上传成功 (v$serverVersion)',
      );
      return null;
    } catch (e) {
      _logger.warning('Upload failed', e);
      state = state.copyWith(syncing: false, error: e.toString());
      return e.toString();
    }
  }

  /// 从服务端下载并恢复数据
  Future<String?> download({required String password}) async {
    state = state.copyWith(syncing: true, clearError: true);
    try {
      final data = await SyncClient.shared.download();
      final backup = await SyncCrypto.parseSyncPayload(data.ciphertext, password);
      await backup.merge();

      state = state.copyWith(
        serverVersion: data.version,
        localVersion: data.version,
        syncing: false,
        lastSyncAt: DateTime.now().millisecondsSinceEpoch,
        lastSyncMessage: '下载恢复成功 (v${data.version})',
      );
      return null;
    } catch (e) {
      _logger.warning('Download failed', e);
      state = state.copyWith(syncing: false, error: e.toString());
      return e.toString();
    }
  }

  /// 检查远程是否有更新
  Future<bool> checkForUpdates() async {
    try {
      final localVersion = Stores.lastModTime;
      final result = await SyncClient.shared.checkDiff(
        localVersion: localVersion,
      );
      state = state.copyWith(
        localVersion: localVersion,
        serverVersion: result.serverVersion,
      );
      return result.needsDownload;
    } catch (e) {
      _logger.warning('Diff check failed', e);
      return false;
    }
  }
}
