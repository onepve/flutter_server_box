import 'package:dio/dio.dart';
import 'package:server_box/sync/sync_config.dart';

/// 解析 API 错误，返回用户友好的中文错误信息
class SyncError {
  final String title;
  final String message;

  const SyncError({required this.title, required this.message});

  @override
  String toString() => '$title: $message';

  /// 从 DioException 或任意异常解析出 SyncError
  static SyncError parse(dynamic error) {
    if (error is SyncTOTPRequiredException) {
      return const SyncError(title: '需要 TOTP 验证', message: '请输入 TOTP 验证码');
    }
    if (error is SyncException) {
      return SyncError(title: error.title, message: error.message);
    }
    if (error is DioException) {
      return _fromDio(error);
    }
    return SyncError(title: '未知错误', message: error.toString());
  }

  static SyncError _fromDio(DioException e) {
    // 尝试提取服务端返回的 detail
    String? serverMsg;
    final data = e.response?.data;
    if (data is Map && data.containsKey('detail')) {
      serverMsg = data['detail'] as String?;
    }

    // 网络层错误（无响应）
    if (e.response == null) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const SyncError(title: '网络超时', message: '连接服务器超时，请检查网络或稍后重试');
        case DioExceptionType.connectionError:
          return const SyncError(title: '网络错误', message: '无法连接到服务器\n请检查网络连接或服务端地址是否正确');
        case DioExceptionType.cancel:
          return const SyncError(title: '请求已取消', message: '');
        default:
          return const SyncError(title: '网络错误', message: '发生网络异常，请稍后重试');
      }
    }

    // 有响应的错误 — 根据状态码 + 服务端消息分类
    final code = e.response!.statusCode ?? 0;
    final msg = serverMsg ?? '';

    if (code == 401) {
      if (msg.contains('TOTP')) {
        return const SyncError(title: 'TOTP 验证失败', message: 'TOTP 验证码错误，请重新输入');
      }
      if (msg.contains('密码') || msg.contains('credential')) {
        return const SyncError(title: '登录失败', message: '用户名或密码错误，请检查后重试');
      }
      return SyncError(title: '认证失败', message: msg.isNotEmpty ? msg : '登录凭据无效，请重新登录');
    }

    if (code == 400) {
      if (msg.contains('邀请码') || msg.contains('invite')) {
        return SyncError(title: '邀请码错误', message: msg);
      }
      if (msg.contains('用户名') && (msg.contains('占用') || msg.contains('存在'))) {
        return SyncError(title: '注册失败', message: msg);
      }
      if (msg.contains('邮箱') && (msg.contains('注册') || msg.contains('存在'))) {
        return SyncError(title: '注册失败', message: msg);
      }
      if (msg.contains('验证码') || msg.contains('code')) {
        return SyncError(title: '验证码错误', message: msg);
      }
      if (msg.contains('密码') && msg.contains('重置')) {
        return SyncError(title: '密码重置失败', message: msg);
      }
      return SyncError(title: '请求失败', message: msg.isNotEmpty ? msg : '参数有误');
    }

    if (code == 404) {
      return SyncError(title: '未找到', message: msg.isNotEmpty ? msg : '请求的资源不存在');
    }

    if (code == 429) {
      return SyncError(title: '操作太频繁', message: msg.isNotEmpty ? msg : '请稍后重试');
    }

    if (code >= 500) {
      return SyncError(title: '服务器错误', message: msg.isNotEmpty ? msg : '服务器内部错误，请联系管理员');
    }

    return SyncError(
      title: '请求失败',
      message: msg.isNotEmpty ? msg : '未知错误 (HTTP $code)',
    );
  }
}

/// 服务器要求 TOTP 验证
class SyncTOTPRequiredException implements Exception {
  @override
  String toString() => '需要 TOTP 验证码';
}

/// 带标题的同步异常
class SyncException implements Exception {
  final String title;
  final String message;
  const SyncException({required this.title, required this.message});
  @override
  String toString() => '$title: $message';
}

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
  Future<({String token, int userId, String uuid, String username, String? nickname, String? avatarUrl})> login({
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
      uuid: (data['uuid'] ?? data['user_uuid']) as String,
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
    String? inviteCode,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'email': email,
      'password': password,
    };
    if (inviteCode != null && inviteCode.trim().isNotEmpty) {
      body['invite_code'] = inviteCode.trim();
    }
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

  /// 上传头像（multipart）
  Future<String> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final resp = await _dio.post(SyncConfig.uploadAvatar, data: formData);
    final data = resp.data as Map<String, dynamic>?;
    if (data == null) throw SyncException(title: '上传失败', message: '服务器返回为空');
    final url = data['avatar_url'] as String?;
    if (url == null || url.isEmpty) throw SyncException(
      title: '上传失败',
      message: data['detail'] as String? ?? '服务器返回异常，请重试',
    );
    return url;
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

  /// 获取系统公开配置（是否需要邀请码注册等）
  Future<({bool requireInvite, bool allowUserCreate, int maxPerUser})> getConfig() async {
    final resp = await _dio.get(SyncConfig.publicConfig);
    final data = resp.data as Map<String, dynamic>;
    return (
      requireInvite: data['require_invite_for_registration'] as bool,
      allowUserCreate: data['allow_user_create_invite'] as bool,
      maxPerUser: data['max_invites_per_user'] as int,
    );
  }

  /// 普通用户创建自己的邀请码
  Future<({String code, int maxUses, int usedCount, bool isActive, String? expiresAt})> createUserInvite({
    required int maxUses,
    required int expiresInDays,
  }) async {
    final resp = await _dio.post(SyncConfig.inviteUserCreate, data: {
      'max_uses': maxUses,
      'expires_in_days': expiresInDays,
    });
    final data = resp.data as Map<String, dynamic>;
    return (
      code: data['code'] as String,
      maxUses: data['max_uses'] as int,
      usedCount: data['used_count'] as int,
      isActive: data['is_active'] as bool,
      expiresAt: data['expires_at'] as String?,
    );
  }

  /// 获取自己创建的邀请码列表
  Future<List<Map<String, dynamic>>> listUserInvites() async {
    final resp = await _dio.get(SyncConfig.inviteUserList);
    final data = resp.data as Map<String, dynamic>;
    return (data['codes'] as List).cast<Map<String, dynamic>>();
  }

  /// 删除自己创建的邀请码
  Future<void> deleteUserInvite(int inviteId) async {
    await _dio.delete(SyncConfig.inviteUserDelete, queryParameters: {'invite_id': inviteId});
  }
}
