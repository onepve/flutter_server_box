import 'dart:math';

import 'package:fl_lib/fl_lib.dart';

/// 同步服务端配置 — 地址写死在客户端代码中
abstract final class SyncConfig {
  /// 同步服务端地址（硬编码，不允许用户修改）
  static const serverUrl = 'https://sync.onepve.com';

  /// Web 端个人资料页（用于 TOTP 绑定等复杂操作）
  static const webProfileUrl = '$serverUrl/profile';

  /// API 端点
  static const _base = '/api';
  static const register = '$_base/auth/register';
  static const login = '$_base/auth/login';
  static const profile = '$_base/auth/profile';
  static const changeUsername = '$_base/auth/profile/username';
  static const changeNickname = '$_base/auth/profile/nickname';
  static const changeEmail = '$_base/auth/profile/email';
  static const changePassword = '$_base/auth/profile/password';
  static const forgotPassword = '$_base/auth/forgot-password';
  static const resetPassword = '$_base/auth/reset-password';
  static const syncUpload = '$_base/sync/upload';
  static const syncDownload = '$_base/sync/download';
  static const syncDiff = '$_base/sync/diff';
  static const syncStatus = '$_base/sync/status';
  static const syncDelete = '$_base/sync';
  static const sendDeleteCode = '$_base/auth/send-delete-code';
  static const verifyDeleteCode = '$_base/auth/verify-delete-code';
  static const exportToEmail = '$_base/sync/export-to-email';
  static const deleteAccount = '$_base/auth/delete-account';
  static const totpStatus = '$_base/auth/totp/status';
  static const resendVerification = '$_base/auth/resend-verification';
  static const verifyEmail = '$_base/auth/verify-email';

  /// 同步相关安全存储
  static final token = SecureProp('sync_jwt_token');
  static final username = SecureProp('sync_username');
  static final nickname = SecureProp('sync_nickname');
  static final avatarUrl = SecureProp('sync_avatar_url');
  static final email = SecureProp('sync_email');
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
