import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';

/// 同步数据加密
///
/// 使用与本地备份相同的加密机制（AES-GCM），密钥从用户密码派生。
/// 加密在客户端完成，服务端零信任。
class SyncCrypto {
  /// 加密明文 JSON → base64 密文字符串
  static String encrypt(String plaintext, String password) {
    return Cryptor.encrypt(plaintext, password);
  }

  /// 解密密文 → 明文 JSON
  static String decrypt(String ciphertext, String password) {
    return Cryptor.decrypt(ciphertext, password);
  }

  /// 构造同步数据包：收集所有数据 → JSON → 加密
  static Future<String> buildSyncPayload(String password) async {
    final backup = await BackupV2.loadFromStore();
    final jsonStr = json.encode(backup.toJson());
    return encrypt(jsonStr, password);
  }

  /// 解析同步数据包：解密 → 解析 JSON → 返回 BackupV2
  static Future<BackupV2> parseSyncPayload(
    String ciphertext,
    String password,
  ) async {
    final jsonStr = decrypt(ciphertext, password);
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    return BackupV2.fromJson(map);
  }
}
