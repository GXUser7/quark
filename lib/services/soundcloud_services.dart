import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:quark/objects/track.dart';
import 'package:quark/services/database/settings_engine.dart';
import 'package:quark/services/soundcloud.dart';
import 'package:soundcloud_explode_dart/soundcloud_explode_dart.dart' as sc;

class SoundCloudService {
  static final SoundCloudService _instance = SoundCloudService._internal();
  factory SoundCloudService() => _instance;
  SoundCloudService._internal();

  final sc.SoundcloudClient _client = sc.SoundcloudClient();
  final Dio _dio = Dio();

  static const _clientId = 'KKzJxmw11tYpCs6T24P4uUYhqmjalG6M';

  static const _apiBase = 'https://api-v2.soundcloud.com';

  Future<String?> getStreamUrlWithOAuth(int trackId) async {
    final token = await Database.get("scOauthToken");
    if (token == null || token.isEmpty) {
      print('[SC] no OAuth token, fallback');
      return getStreamUrl(trackId);
    }

    final headers = {
      'Authorization': token,
      'Origin': 'https://soundcloud.com',
      'Referer': 'https://soundcloud.com/',
      'Accept': 'application/json',
    };

    try {
      final trackResp = await _dio.get(
        '$_apiBase/tracks/$trackId',
        queryParameters: {'client_id': _clientId},
        options: Options(headers: headers),
      );

      final transcodings =
          (trackResp.data['media']['transcodings'] as List)
              .cast<Map<String, dynamic>>();

      if (transcodings.isEmpty) return getStreamUrl(trackId);

      final chosen = _pickBestTranscoding(transcodings);
      print('[SC] chosen transcoding: preset=${chosen['preset']} '
          'protocol=${chosen['format']['protocol']}');

      final streamResp = await _dio.get(
        chosen['url'] as String,
        queryParameters: {'client_id': _clientId},
        options: Options(headers: headers),
      );

      final url = streamResp.data['url'] as String?;
      print('[SC] stream url: $url');
      return url;
    } on DioException catch (e) {
      print('[SC] getStreamUrlWithOAuth DioError: ${e.response?.statusCode} $e');
      return getStreamUrl(trackId); // fallback
    } catch (e) {
      print('[SC] getStreamUrlWithOAuth error: $e');
      return getStreamUrl(trackId); // fallback
    }
  }

  /// Приоритет: progressive+mp3 > progressive+aac > hls+mp3 > любой первый
  Map<String, dynamic> _pickBestTranscoding(
    List<Map<String, dynamic>> transcodings,
  ) {
    final priorities = [
      (protocol: 'progressive', presetHint: 'mp3'),
      (protocol: 'progressive', presetHint: 'aac'),
      (protocol: 'hls',         presetHint: 'mp3'),
    ];

    for (final p in priorities) {
      final match = transcodings.where((t) {
        final protocol = (t['format']?['protocol'] as String?) ?? '';
        final preset   = (t['preset']           as String?) ?? '';
        return protocol == p.protocol && preset.contains(p.presetHint);
      }).toList();
      if (match.isNotEmpty) return match.first;
    }

    return transcodings.first;
  }


  Future<LocalTrack?> resolveForPlayback(SoundCloudTrack track) async {
    final url = await getStreamUrlWithOAuth(track.id);
    if (url == null) return null;
    return LocalTrack(
      title: track.title,
      artists: track.artist != null ? [track.artist!] : ['Unknown'],
      albums: track.album != null ? [track.album!] : [],
      filepath: url,
      coverType:
          track.thumbnailUrl != null ? CoverType.url : CoverType.noCover,
      cover: track.thumbnailUrl ?? 'none',
    );
  }

  Future<List<SoundCloudTrack>> searchTracks(String query, {int limit = 20}) async {
    final results = <SoundCloudTrack>[];
    final stream = _client.search(query, searchFilter: sc.SearchFilter.tracks, limit: limit);
    final iterator = StreamIterator(stream);
    while (await iterator.moveNext()) {
      for (final result in iterator.current) {
        if (result case final sc.TrackSearchResult track) {
          results.add(SoundCloudTrack.fromSearchResult(track));
        }
      }
    }
    return results;
  }

  Future<List<SoundCloudPlaylist>> searchPlaylists(String query, {int limit = 20}) async {
    final results = <SoundCloudPlaylist>[];
    final stream = _client.search(query, searchFilter: sc.SearchFilter.playlists, limit: limit);
    final iterator = StreamIterator(stream);
    while (await iterator.moveNext()) {
      for (final result in iterator.current) {
        if (result case final sc.PlaylistSearchResult playlist) {
          results.add(SoundCloudPlaylist.fromSearchResult(playlist));
        }
      }
    }
    return results;
  }

  Future<SoundCloudTrack?> getTrackByUrl(String url) async {
    try {
      final t = await _client.tracks.getByUrl(url);
      return SoundCloudTrack(
        id: t.id, title: t.title ?? 'Unknown', artist: t.user?.username,
        thumbnailUrl: t.artworkUrl?.toString(), durationMs: t.duration,
        fullDurationMs: t.fullDuration, genre: t.genre,
        permalinkUrl: t.permalinkUrl?.toString(),
      );
    } catch (_) { return null; }
  }

  Future<SoundCloudTrack?> getTrackById(int id) async {
    try {
      final t = await _client.tracks.get(id);
      return SoundCloudTrack(
        id: t.id, title: t.title ?? 'Unknown', artist: t.user?.username,
        thumbnailUrl: t.artworkUrl?.toString(), durationMs: t.duration,
        fullDurationMs: t.fullDuration, genre: t.genre,
        permalinkUrl: t.permalinkUrl?.toString(),
      );
    } catch (_) { return null; }
  }

  Future<String?> getStreamUrl(int trackId) async {
    try {
      final streams = await _client.tracks.getStreams(trackId);
      if (streams.isEmpty) return null;
      final mp3 = streams.where((s) {
        final url = s.url?.toLowerCase() ?? '';
        return url.contains('.mp3') || url.contains('mp3');
      }).toList();
      return mp3.isNotEmpty ? mp3.first.url : streams.first.url;
    } catch (_) { return null; }
  }

  Future<List<SoundCloudTrack>> getPlaylistTracks(int playlistId) async {
    final results = <SoundCloudTrack>[];
    try {
      final stream = _client.playlists.getTracks(playlistId);
      final iterator = StreamIterator(stream);
      while (await iterator.moveNext()) {
        for (final t in iterator.current) {
          results.add(SoundCloudTrack(
            id: t.id, title: t.title ?? 'Unknown', artist: t.user?.username,
            thumbnailUrl: t.artworkUrl?.toString(), durationMs: t.duration,
            fullDurationMs: t.fullDuration, permalinkUrl: t.permalinkUrl?.toString(),
          ));
        }
      }
    } catch (_) {}
    return results;
  }

  Future<List<SoundCloudTrack>> getUserTracks(String userUrl) async {
    final results = <SoundCloudTrack>[];
    try {
      final user = await _client.users.getByUrl(userUrl);
      final stream = _client.users.getTracks(user.id);
      final iterator = StreamIterator(stream);
      while (await iterator.moveNext()) {
        for (final t in iterator.current) {
          if (t.id == null) continue;
          results.add(SoundCloudTrack(
            id: t.id, title: t.title ?? 'Unknown', artist: t.user?.username,
            thumbnailUrl: t.artworkUrl?.toString(), durationMs: t.duration,
            fullDurationMs: t.fullDuration, permalinkUrl: t.permalinkUrl?.toString(),
          ));
        }
      }
    } catch (_) {}
    return results;
  }

  Future<List<SoundCloudPlaylist>> getUserPlaylists(String userUrl) async {
    final results = <SoundCloudPlaylist>[];
    final cleanUrl = userUrl.trim().replaceAll(RegExp(r'/$'), '');
    final userId = await _resolveUserId(cleanUrl);
    if (userId == null) throw Exception('Не удалось найти пользователя по ссылке');

    final stream = _client.users.getPlaylists(userId);
    final iterator = StreamIterator(stream);
    while (await iterator.moveNext()) {
      for (final p in iterator.current) {
        if (p.id == null) continue;
        String? thumb = p.artworkUrl?.toString();
        if (thumb == null) {
          try {
            final trackStream = _client.playlists.getTracks(p.id!);
            final trackIterator = StreamIterator(trackStream);
            if (await trackIterator.moveNext() && trackIterator.current.isNotEmpty) {
              thumb = trackIterator.current.first.artworkUrl?.toString();
            }
            await trackIterator.cancel();
          } catch (_) {}
        }
        if (thumb != null) thumb = thumb.replaceAll('-large.', '-t300x300.');
        results.add(SoundCloudPlaylist(
          id: p.id!, title: p.title ?? 'Unknown', thumbnailUrl: thumb,
          permalinkUrl: p.permalinkUrl?.toString(),
          trackCount: p.trackCount ?? 0, isAlbum: p.isAlbum ?? false,
        ));
      }
    }
    return results;
  }

  Future<int?> _resolveUserId(String profileUrl) async {
    try {
      final response = await _dio.get<String>(
        profileUrl,
        options: Options(headers: {'User-Agent': 'Mozilla/5.0'}, responseType: ResponseType.plain),
      );
      final html = response.data ?? '';
      final match = RegExp(r'"id":(\d+)').firstMatch(html);
      if (match != null) return int.tryParse(match.group(1)!);
    } catch (e) { print('[SC] _resolveUserId error: $e'); }
    return null;
  }
}