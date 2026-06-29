import 'dart:math';

import 'package:fl_lib/fl_lib.dart';

/// 同步服务端配置 — 地址写死在客户端代码中
abstract final class SyncConfig {
  /// 同步服务端地址（硬编码，不允许用户修改）
  static const serverUrl = 'https://sync.onepve.com';

  /// API 端点
  static const _base = '/api';
  static const login = '$_base/auth/login';
  static const profile = '$_base/auth/profile';
  static const forgotPassword = '$_base/auth/forgot-password';
  static const resetPassword = '$_base/auth/reset-password';
  static const syncUpload = '$_base/sync/upload';
  static const syncDownload = '$_base/sync/download';
  static const syncDiff = '$_base/sync/diff';
  static const syncStatus = '$_base/sync/status';
  static const syncDelete = '$_base/sync';

  /// 同步相关安全存储
  static final token = SecureProp('sync_jwt_token');
  static final username = SecureProp('sync_username');
  static final _deviceId = SecureProp('sync_device_id');

  /// 当前设备唯一标识（首次生成后持久化）
  static Future<String> get deviceId async {
    final existing = await _deviceId.read();
    if (existing != null && existing.isNotEmpty) return existing;
    final newId = _generateDeviceId();
    await _deviceId.write(newId);
    return newId;
  }

  static String _generateDeviceId() {
    final rand = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final id = List.generate(12, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'dev_$id';
  }

  /// 同步的数据类型标识
  static const dataType = 'server_box_full';
}
