import 'dart:io';

import 'package:dio/dio.dart';
import 'ytmusic.dart';
import 'package:cross_file/cross_file.dart';

class YTMusicAPI {
  final String baseUrl;
  final String localUrl = 'https://localhost:8000/api/yt';

  static final YTMusicAPI _instance = YTMusicAPI._internal();
  factory YTMusicAPI() => _instance;
  YTMusicAPI._internal({this.baseUrl = 'https://quarkaudio.ru/api/yt'});

  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // /api/yt/search
  Future<List<SearchResult>> search(String query, {int limit = 20}) async {
    final response = await dio.get(
      '$baseUrl/search',
      data: {
        'query': query,
        'max_results': limit,
      },
    );

    if (response.statusCode != 200) return [];

    final List results = response.data;
    return results
        .whereType<Map<String, dynamic>>()
        .map((json) => SearchResult(json))
        .toList();
  }

  Future<String?> getLocalYtdlpStream(String videoId) async {
    try {
      print('[YTMusicAPI] yt-dlp: Attempting local resolution fallback for videoId: $videoId...');
      
      // Try with safe prioritized audio format first, falling back to 'best' format
      var result = await Process.run('yt-dlp', [
        '-g',
        '-f', 'bestaudio[ext=m4a]/bestaudio[acodec!=opus]/bestaudio/best',
        '--',
        videoId
      ]);
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty && output.startsWith('http')) {
          print('[YTMusicAPI] yt-dlp: Successfully resolved stream URL locally!');
          return output;
        }
      }
      
      // Secondary fallback: Run without any format constraints
      print('[YTMusicAPI] yt-dlp: Primary format extraction failed. Retrying without format constraints...');
      result = await Process.run('yt-dlp', [
        '-g',
        '--',
        videoId
      ]);
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty && output.startsWith('http')) {
          print('[YTMusicAPI] yt-dlp: Successfully resolved stream URL locally on secondary fallback!');
          return output;
        }
      } else {
        print('[YTMusicAPI] yt-dlp: Local process returned exit code: ${result.exitCode}');
        print('[YTMusicAPI] yt-dlp: stderr: ${result.stderr}');
      }
    } catch (e) {
      print('[YTMusicAPI] yt-dlp: Failed to execute local yt-dlp: $e');
    }
    return null;
  }

  // /api/song
  Future<Track> getTrack(
    String videoId, {
    String format = 'bestaudio[ext=m4a]/bestaudio[acodec!=opus]/bestaudio',
  }) async {
    try {
      final response = await dio.get(
        '$baseUrl/song',
        data: {
          'video_id': videoId,
          'format': format, // 'ba' = best audio only
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch track: ${response.statusCode}');
      }

      return Track(response.data as Map<String, dynamic>);
    } catch (e) {
      print('[YTMusicAPI] Remote stream resolution failed: $e. Trying local yt-dlp fallback...');
      final localStream = await getLocalYtdlpStream(videoId);
      if (localStream != null) {
        return Track({
          'id': videoId,
          'title': 'YouTube Stream (Resolved Locally)',
          'url': localStream,
        });
      }
      rethrow;
    }
  }

  // /api/yt/playlist
  Future<PlaylistResponse> getPlaylist(
    XFile cookieFile,
    String playlistId,
    String format
  ) async {
    final fileName = cookieFile.path.split('/').last;
    final file = File(cookieFile.path);

    final fileContent = await file.readAsString();

    final formData = FormData.fromMap({
      'playlist_id': playlistId,
      'format': format,
      'cookies': MultipartFile.fromString(fileContent, filename: fileName)
    });

    final response = await dio.post(
      '$baseUrl/playlistAuth',
      data: formData,
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch playlist: ${response.statusCode}');
    }

    return PlaylistResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // api/yt/playlists
  Future<YTMusicPlaylistsResponse> getAuthPlaylists(XFile cookiePath) async {
    final fileName = cookiePath.path.split('/').last;
    final file = File(cookiePath.path);

    final fileContent = await file.readAsString();

    final formData = FormData.fromMap({
      'cookies': MultipartFile.fromString(fileContent, filename: fileName),
    });

    try {
      final response = await dio.post(
        '$baseUrl/playlists',
        data: formData,
        options: Options(contentType: 'multipart/form-data', headers: {}),
        onSendProgress: (sent, total) {
          if (total != -1) {
            print(
              'Upload progress: ${(sent / total * 100).toStringAsFixed(1)}%',
            );
          }
        },
      );

      return YTMusicPlaylistsResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      print('STATUS: ${e.response?.statusCode}');
      print('BODY: ${e.response?.data}');
      print('HEADERS: ${e.response?.headers.map}');

      if (e.response?.data is String) {
        print('Raw response: ${e.response?.data}');
      }

      rethrow;
    }
  }
}
