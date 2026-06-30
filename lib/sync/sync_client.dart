import 'package:dio/dio.dart';
import 'package:server_box/sync/sync_config.dart';

/// 同步 API HTTP 客户端
///
/// 处理所有与服务端的通信：登录、上传、下载、差异对比。
class SyncClient {
  SyncClient._();
  static final _instance = SyncClient._();
  static SyncClient get shared => _instance;

  late Dio _dio = _createDio();

  Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: SyncConfig.serverUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    // 自动附加 JWT Token
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SyncConfig.token.read();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token 过期，清除本地 token
          SyncConfig.token.write(null);
        }
        handler.next(error);
      },
    ));

    return dio;
  }

  /// 登录，获取 JWT Token
  Future<({String token, int userId, String username, String? nickname, String? avatarUrl})> login({
    required String username,
    required String password,
    String? totpCode,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'password': password,
    };
    if (totpCode != null) {
      body['totp_code'] = totpCode;
    }

    final resp = await _dio.post(SyncConfig.login, data: body);
    final data = resp.data as Map<String, dynamic>;

    if (data['totp_required'] == true) {
      throw SyncTOTPRequiredException();
    }

    final token = data['access_token'] as String;
    return (
      token: token,
      userId: data['user_id'] as int,
      username: data['username'] as String,
      nickname: data['nickname'] as String?,
      avatarUrl: data['avatar_url'] as String?,
    );
  }

  /// 获取用户完整资料（用户名、昵称、邮箱、TOTP 状态等）
  Future<({
    int id,
    String uuid,
    String username,
    String? nickname,
    String email,
    bool emailVerified,
    bool totpEnabled,
    bool isActive,
    String? avatarUrl,
  })> getProfile() async {
    final resp = await _dio.get(SyncConfig.profile);
    final data = resp.data as Map<String, dynamic>;
    return (
      id: data['id'] as int,
      uuid: data['uuid'] as String,
      username: data['username'] as String,
      nickname: data['nickname'] as String?,
      email: data['email'] as String,
      emailVerified: data['email_verified'] as bool,
      totpEnabled: data['totp_enabled'] as bool,
      isActive: data['is_active'] as bool,
      avatarUrl: data['avatar_url'] as String?,
    );
  }

  /// 上传加密数据
  Future<int> upload({
    required String ciphertext,
    required int plaintextSize,
    required int clientVersion,
  }) async {
    final resp = await _dio.post(SyncConfig.syncUpload, data: {
      'data_type': SyncConfig.dataType,
      'device_id': await SyncConfig.deviceId,
      'ciphertext': ciphertext,
      'plaintext_size': plaintextSize,
      'client_version': clientVersion,
    });
    return (resp.data as Map<String, dynamic>)['version'] as int;
  }

  /// 下载加密数据
  Future<({String ciphertext, int version, int plaintextSize})> download() async {
    final resp = await _dio.get('${SyncConfig.syncDownload}/${SyncConfig.dataType}');
    final data = resp.data as Map<String, dynamic>;
    return (
      ciphertext: data['ciphertext'] as String,
      version: data['version'] as int,
      plaintextSize: data['plaintext_size'] as int,
    );
  }

  /// 对比本地版本，返回需要下载的数据类型
  Future<({String dataType, int serverVersion, bool needsDownload})> checkDiff({
    required int localVersion,
  }) async {
    final resp = await _dio.post(SyncConfig.syncDiff, data: {
      'local_versions': {SyncConfig.dataType: localVersion},
    });
    final items = (resp.data as Map<String, dynamic>)['items'] as List;
    final item = items.firstWhere(
      (e) => e['data_type'] == SyncConfig.dataType,
      orElse: () => <String, dynamic>{
        'data_type': SyncConfig.dataType,
        'server_version': 0,
        'client_version': localVersion,
        'needs_download': false,
      },
    );
    return (
      dataType: item['data_type'] as String,
      serverVersion: item['server_version'] as int,
      needsDownload: item['needs_download'] as bool,
    );
  }

  /// 获取同步状态
  Future<List<({String deviceId, String dataType, int version})>> getStatus() async {
    final resp = await _dio.get(SyncConfig.syncStatus);
    final devices = (resp.data as Map<String, dynamic>)['devices'] as List;
    return devices.map((d) => (
      deviceId: d['device_id'] as String,
      dataType: d['data_type'] as String,
      version: d['version'] as int,
    )).toList();
  }

  void reset() {
    _dio.close();
    _dio = _createDio();
  }

  /// 注册新账号
  Future<({String message, String? recoveryKey})> register({
    required String username,
    String? nickname,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'email': email,
      'password': password,
      'invite_code': inviteCode,
    };
    if (nickname != null && nickname.trim().isNotEmpty) {
      body['nickname'] = nickname.trim();
    }
    final resp = await _dio.post(SyncConfig.register, data: body);
    final data = resp.data as Map<String, dynamic>;
    return (
      message: data['message'] as String? ?? '注册成功',
      recoveryKey: data['recovery_key'] as String?,
    );
  }

  /// 忘记密码，获取重置令牌（支持用户名或邮箱）
  Future<({String message, String? token})> forgotPassword({
    required String usernameOrEmail,
  }) async {
    final resp = await _dio.post(SyncConfig.forgotPassword, data: {
      'username_or_email': usernameOrEmail,
    });
    final data = resp.data as Map<String, dynamic>;
    return (
      message: data['message'] as String,
      token: data['token'] as String?,
    );
  }

  /// 使用重置令牌设置新密码
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _dio.post(SyncConfig.resetPassword, data: {
      'token': token,
      'new_password': newPassword,
    });
  }

  /// 删除指定类型的同步数据
  Future<void> deleteData({required String dataType}) async {
    await _dio.delete('${SyncConfig.syncDelete}/$dataType');
  }

  /// 发送删除验证码到邮箱
  Future<String> sendDeleteCode({String purpose = 'sync_data'}) async {
    final resp = await _dio.post('${SyncConfig.sendDeleteCode}?purpose=$purpose');
    return (resp.data as Map<String, dynamic>)['message'] as String;
  }

  /// 验证删除操作（TOTP 码或邮件验证码）
  Future<String> verifyDeleteCode({required String code}) async {
    final resp = await _dio.post(SyncConfig.verifyDeleteCode, data: {
      'code': code,
    });
    return (resp.data as Map<String, dynamic>)['message'] as String;
  }

  /// 导出加密同步数据到邮箱
  Future<String> exportToEmail() async {
    final resp = await _dio.post(SyncConfig.exportToEmail);
    return (resp.data as Map<String, dynamic>)['message'] as String;
  }

  /// 注销账号（需先通过身份验证流程）
  Future<String> deleteAccount({
    required String password,
    bool exportToEmail = false,
  }) async {
    final resp = await _dio.post(SyncConfig.deleteAccount, data: {
      'password': password,
      'export_to_email': exportToEmail,
    });
    return (resp.data as Map<String, dynamic>)['message'] as String;
  }

  /// 获取 TOTP 启用状态
  Future<bool> getTotpStatus() async {
    final resp = await _dio.get(SyncConfig.totpStatus);
    return (resp.data as Map<String, dynamic>)['enabled'] as bool;
  }

  /// 重新发送邮箱验证码
  Future<String> resendVerification() async {
    final resp = await _dio.post(SyncConfig.resendVerification);
    return (resp.data as Map<String, dynamic>)['message'] as String;
  }

  /// 验证邮箱
  Future<String> verifyEmail({required String code}) async {
    final profile = await getProfile();
    final resp = await _dio.post(SyncConfig.verifyEmail, data: {
      'user_uuid': profile.uuid,
      'code': code,
    });
    return (resp.data as Map<String, dynamic>)['message'] as String;
  }
}

/// 服务器要求 TOTP 验证
class SyncTOTPRequiredException implements Exception {
  @override
  String toString() => '需要 TOTP 验证码';
}
