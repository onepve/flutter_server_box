import 'package:logging/logging.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/sync/sync_client.dart';
import 'package:server_box/sync/sync_crypto.dart';

final _logger = Logger('SyncEngine');

/// 同步引擎 — 一键同步流程编排
///
/// 提供「一键同步」功能：先检查差异，再决定上传还是下载。
abstract final class SyncEngine {
  /// 一键同步：智能判断上传或下载
  ///
  /// 策略：
  /// 1. 检查远程是否有更新（diff）
  /// 2. 如果远程有新数据且本地修改时间更旧 → 下载
  /// 3. 否则 → 上传本地数据
  ///
  /// 返回描述本次操作结果的字符串。
  static Future<String> syncAll(String password) async {
    try {
      final localVersion = Stores.lastModTime;

      // 1. 检查远程版本
      final diff = await SyncClient.shared.checkDiff(
        localVersion: localVersion,
      );

      if (diff.needsDownload) {
        // 远程有更新 → 下载
        _logger.info('Remote is newer, downloading...');
        final data = await SyncClient.shared.download();
        final backup = await SyncCrypto.parseSyncPayload(data.ciphertext, password);
        await backup.merge();
        _logger.info('Download & restore completed (v${data.version})');
        return '已从服务端恢复 (v${data.version})';
      }

      // 2. 远程没更新 → 上传本地数据
      _logger.info('Local is same or newer, uploading...');
      final ciphertext = await SyncCrypto.buildSyncPayload(password);
      final serverVersion = await SyncClient.shared.upload(
        ciphertext: ciphertext,
        plaintextSize: ciphertext.length,
        clientVersion: localVersion,
      );
      _logger.info('Upload completed (v$serverVersion)');
      return '已上传到服务端 (v$serverVersion)';
    } catch (e) {
      _logger.warning('Sync failed', e);
      rethrow;
    }
  }

  /// 检查是否有可用更新
  static Future<bool> hasUpdate() async {
    try {
      final localVersion = Stores.lastModTime;
      final diff = await SyncClient.shared.checkDiff(
        localVersion: localVersion,
      );
      return diff.needsDownload;
    } catch (e) {
      _logger.warning('Check update failed', e);
      return false;
    }
  }
}
