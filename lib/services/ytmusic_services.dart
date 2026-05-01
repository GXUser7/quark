import 'package:dio/dio.dart';
import 'ytmusic.dart';

class YTMusicAPI {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  final String baseUrl;
  final String localUrl = 'https://localhost:8000/api/yt';

  static final YTMusicAPI _instance = YTMusicAPI._internal();
  factory YTMusicAPI() => _instance;
  YTMusicAPI._internal({this.baseUrl = 'https://quarkaudio.ru/api/yt'});


  // /api/search
  Future<List<SearchResult>> search(String query, {int limit = 20}) async {
    final response = await dio.get(
      '$baseUrl/search',
      queryParameters: {
        'query': 'ytsearch$limit:$query', // формат для yt-dlp
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

  // /api/song
  Future<Track> getTrack(
    String videoId, {
    String format = 'ba[ext=m4a]/ba[ext=mp3]/ba',
  }) async {
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
  }

  // /api/playlist
  Future<PlaylistResponse> getPlaylist(
    String playlistId, {
    String? cookies,
  }) async {
    final response = await dio.post(
      '$baseUrl/playlist',
      data: {
        'playlist_id': playlistId,
        'format': 'ba[ext=m4a]/ba[ext=mp3]/ba',
        if (cookies != null) 'cookies': cookies,
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch playlist: ${response.statusCode}');
    }

    return PlaylistResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
