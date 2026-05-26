import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quark/services/playlist_sync_services.dart';
import 'database//database.dart';
import 'database/settings_engine.dart';

const String baseUrl = 'https://quarkaudio.ru/api/auth';
const String baseUrlYandex = 'https://quarkaudio.ru/api/yandex';
const String baseUrlVk = 'https://quarkaudio.ru/api/vk';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Future<void> init() async {
    await loadTokens();
  }

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  final db = DatabaseStreamerService();

  String? accessToken;
  String? refreshToken;

  Future<void> loadTokens() async {
    final at = await Database.get('accessToken');
    final rt = await Database.get('refreshToken');
    print('DB accessToken: $at');
    print('DB refreshToken: $rt');

    accessToken = (at == null || at == '') ? null : at;
    refreshToken = (rt == null || rt == '') ? null : rt;

    print('accessToken after load: $accessToken');

    if (accessToken != null) {
      db.accessToken.value = accessToken!;
      db.isLoggedIn.value = true;
    }
  }

  Future<void> _saveTokens(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    try {
      db.accessToken.value = access;
      db.refreshToken.value = refresh;
      db.isLoggedIn.value = true;
      await Database.put(
        DatabaseKeys.accessToken.value,
        access,
      ); // 'accessToken'
      await Database.put(
        DatabaseKeys.refreshToken.value,
        refresh,
      ); // 'refreshToken'
      await Database.put(DatabaseKeys.isLoggedIn.value, true); // 'isLoggedIn'
      print('Saved: access=$access');
      print('Saved: refresh=$refresh');
    } catch (e) {
      print('storage write failed: $e');
    }
  }

  Future<void> _clearTokens() async {
    accessToken = null;
    refreshToken = null;
    db.accessToken.value = '';
    db.refreshToken.value = '';
    db.isLoggedIn.value = false;
    await Database.put('accessToken', '');
    await Database.put('refreshToken', '');
    await Database.put('isLoggedIn', false);
  }

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  Future<void> register(String email, String password, String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await _saveTokens(data['access_token'], data['refresh_token']);
    } else {
      throw Exception('Register failed: ${response.body}');
    }
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveTokens(data['access_token'], data['refresh_token']);

      // TODO: finish secret storage parasha
      // await _saveTokens(data['access_token'], data['refresh_token']);

      if (AuthService().isLoggedIn) {
        unawaited(_syncPlaylists());
      }
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  Future<void> _syncPlaylists() async {
  try {
    print('AUTH SYNC: starting download');
    await PlaylistSyncService().downloadAndSave();
    print('AUTH SYNC: download done');
    await PlaylistSyncService().uploadAll();
    print('AUTH SYNC: upload done');
  } catch (e, st) {
    print('AUTH SYNC ERROR: $e');
    print(st);
  }
}

  Future<void> refresh() async {
    print('refreshToken field: $refreshToken');
    print('refreshToken db: ${db.refreshToken.value}');

    final rt = db.refreshToken.value.isEmpty
        ? refreshToken
        : db.refreshToken.value;
    if (rt == null || rt.isEmpty) throw Exception('No refresh token');

    print('rt to use: $rt');

    final response = await http.post(
      Uri.parse('$baseUrl/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': rt}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveTokens(data['access_token'], data['refresh_token']);
    } else {
      await _clearTokens();
      throw Exception('Session expired, please login again');
    }
  }

  Future<http.Response> authorizedRequest(
    Future<http.Response> Function(String token) request,
  ) async {
    // accessToken ??= await _storage.read(key: _keyAccess);
    // if (accessToken == null) throw Exception('not authenticated');

    if (accessToken == null || accessToken!.isEmpty) {
      try {
        await refresh();
      } catch (e) {
        throw Exception("not authenticated");
      }
    }

    if (accessToken == null || accessToken!.isEmpty) {
      throw Exception('not authenticated');
    }

    if (DatabaseStreamerService().isLoggedIn.value == false) {}
    var response = await request(accessToken!);

    if (response.statusCode == 401) {
      await refresh();

      if (accessToken == null || accessToken!.isEmpty) {
        throw Exception('Session expired, please login again');
      }
      response = await request(accessToken!);
    }

    return response;
  }

  Future<Map<String, dynamic>> getMe() async {
    if (isLoggedIn) {
      final response = await authorizedRequest(
        (token) => http.get(
          Uri.parse('$baseUrl/me'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to get profile: ${response.body}');
    }
    return {"detail": "not authentificated in qdb services"};
  }

  Future<void> logout() async {
    try {
      if (accessToken != null && refreshToken != null) {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'refresh_token': refreshToken}),
        );
      }
    } catch (_) {
    } finally {
      await _clearTokens();
    }
  }

  Future<void> loginVk(String login, String password) async {
    final response = await authorizedRequest(
      (token) => http.post(
        Uri.parse('$baseUrlVk/login'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'login': login, 'password': password}),
      ),
    );

    print('VK login status: ${response.statusCode}');
    print('VK login body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('VK login failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    db.vkMusicToken.value = data['vk_user_id'].toString();
  }

  Future<void> saveVkToken(String vkToken) async {
    if (isLoggedIn) {
      // to db
      Database.put('vkMusicToken', vkToken);
      // to user acc
      final response = await authorizedRequest(
        (token) => http.post(
          Uri.parse('$baseUrlVk/token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'token': vkToken, 'client': 'Kate'}),
        ),
      );
      print("succ write to qdb");
      if (response.statusCode != 200) {
        throw Exception('Failed to save VK token');
      }
    }
    db.vkMusicToken.value = vkToken;
  }

  // YANDEX
  Future<void> saveYandexToken(String yandexToken) async {
    if (isLoggedIn) {
      final response = await authorizedRequest(
        (token) => http.post(
          Uri.parse('$baseUrlYandex/token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'token': yandexToken}),
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to save Yandex token: ${response.body}');
      }
    }

    db.yandexMusicToken.value = yandexToken;
  }

  Future<String?> getYandexToken() async {
    if (isLoggedIn) {
      try {
        final response = await authorizedRequest(
          (token) => http.get(
            Uri.parse('$baseUrlYandex/token'),
            headers: {'Authorization': 'Bearer $token'},
          ),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final token = data['token'] as String?;
          if (token != null) db.yandexMusicToken.value = token;
          return token;
        }
        return null;
      } catch (e) {
        print('getYandexToken error: $e');
        return null;
      }
    }
  }

  Future<void> deleteYandexToken() async {
    await authorizedRequest(
      (token) => http.delete(
        Uri.parse('$baseUrlYandex/token'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    db.yandexMusicToken.value = '';
  }
}

extension AccountMethods on AuthService {
  Future<void> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode != 202) {
      throw Exception('forgot_password failed: ${response.body}');
    }
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
        'new_password': newPassword,
      }),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'reset_password failed');
    }
  }

  /// Отправить код подтверждения на текущий email.
  Future<void> sendEmailVerification() async {
    final response = await authorizedRequest(
      (token) => http.post(
        Uri.parse('$baseUrl/send-email-verification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({}),
      ),
    );
    if (response.statusCode != 202) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'send_verification failed');
    }
  }

  Future<void> verifyEmail(String code) async {
    final response = await authorizedRequest(
      (token) => http.post(
        Uri.parse('$baseUrl/verify-email'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'code': code}),
      ),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'verify_email failed');
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? username,
    String? email,
  }) async {
    final payload = <String, String>{};
    if (username != null) payload['username'] = username;
    if (email != null) payload['email'] = email;
    if (payload.isEmpty) throw Exception('nothing_to_update');

    final response = await authorizedRequest(
      (token) => http.patch(
        Uri.parse('$baseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'update_profile failed');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await authorizedRequest(
      (token) => http.patch(
        Uri.parse('$baseUrl/me/password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      ),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'change_password failed');
    }
  }
}
