import 'dart:io';

import 'package:dio/dio.dart';
import 'package:cross_file/cross_file.dart';
import 'package:quark/services/auth_services.dart';
import 'package:quark/services/vkmusic.dart';
import 'vkmusic.dart';

class VkMusicService {
  late String baseUrl;

  static final VkMusicService _instance = VkMusicService._internal();
  factory VkMusicService({String baseUrl = 'https://quarkaudio.ru/api/vk'}) =>
      _instance..baseUrl = baseUrl;

  VkMusicService._internal({this.baseUrl = 'https://quarkaudio.ru/api/vk'});

  void setAuthToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: 'https://quarkaudio.ru/api/vk',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ),
        )
        ..interceptors.add(
          LogInterceptor(
            request: true,
            requestHeader: true,
            responseHeader: false,
            responseBody: false,
            error: true,

            logPrint: (obj) => print('[VK_DIO] $obj'),
          ),
        );

  Future<void> disconnectAccount() async {
    try {
      final response = await _dio.delete('$baseUrl/token');
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to disconnect VK account');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<VkConnectionStatus> getConnectionStatus() async {
    try {
      final response = await _dio.get('$baseUrl/token/status');
      if (response.statusCode != 200) {
        return VkConnectionStatus(connected: false);
      }
      return VkConnectionStatus.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<List<VkSong>> getMySongs({int count = 50}) async {
    try {
      final response = await _dio.get(
        '$baseUrl/my/songs',
        queryParameters: {'count': count},
      );

      if (response.statusCode != 200) return [];

      final data = response.data as Map<String, dynamic>;
      final songsJson = data['songs'] as List? ?? [];
      return songsJson
          .whereType<Map<String, dynamic>>()
          .map((s) => VkSong.fromJson(s))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('VK audio is private or access denied');
      }
      _handleDioError(e);
      rethrow;
    }
  }

  Future<List<VkPlaylist>> getMyPlaylists({
    int count = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '$baseUrl/my/playlists',
        queryParameters: {'count': count, 'offset': offset},
      );

      if (response.statusCode != 200) return [];

      final data = response.data as Map<String, dynamic>;
      final playlistsJson = data['playlists'] as List? ?? [];
      return playlistsJson
          .whereType<Map<String, dynamic>>()
          .map((p) => VkPlaylist.fromJson(p))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('VK playlists are private or access denied');
      }
      _handleDioError(e);
      rethrow;
    }
  }

  Future<List<VkSong>> getPlaylistSongs({
    int count = 100,
    required String playlistId,
    required String accessKey,
  }) async {
    try {
      final pureId = playlistId.contains('_')
          ? playlistId.split('_').last
          : playlistId;
      final response = await _dio.get(
        '$baseUrl/my/playlist/$playlistId/songs', // передавай "561164135_3"
        queryParameters: {'count': count, 'access_key': accessKey},
      );

      if (response.statusCode != 200) return [];

      final data = response.data as Map<String, dynamic>;
      final songsJson = data['songs'] as List? ?? [];
      return songsJson
          .whereType<Map<String, dynamic>>()
          .map((s) => VkSong.fromJson(s))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<List<VkSong>> searchSongs(String query, {int count = 10}) async {
    try {
      final response = await _dio.get(
        '$baseUrl/search',
        queryParameters: {'query': query, 'count': count},
      );

      if (response.statusCode != 200) return [];

      final data = response.data as Map<String, dynamic>;
      final songsJson = data['songs'] as List? ?? [];
      return songsJson
          .whereType<Map<String, dynamic>>()
          .map((s) => VkSong.fromJson(s))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<List<VkSong>> getPopularTracks({
    int count = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '$baseUrl/popular',
        queryParameters: {'count': count, 'offset': offset},
      );

      if (response.statusCode != 200) return [];

      final data = response.data as Map<String, dynamic>;
      final songsJson = data['songs'] as List? ?? [];
      return songsJson
          .whereType<Map<String, dynamic>>()
          .map((s) => VkSong.fromJson(s))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  void _handleDioError(DioException e) {
    print('VK Music API Error:');
    print('  Status: ${e.response?.statusCode}');
    print('  Message: ${e.message}');
    if (e.response?.data != null) {
      print('  Response: ${e.response?.data}');
    }
  }

  Future<String?> refreshSongUrl(VkSong song) async {
    return song.isPlayable ? song.url : null;
  }
}
