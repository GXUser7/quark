import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:quark/services/auth_services.dart';
import 'package:quark/services/database/library_engine.dart' as db;
import 'package:quark/objects/track.dart';

const _kBaseUrl = 'https://quarkaudio.ru';

class CloudTrack {
  final String path;
  final String title;
  final String artists;
  final String album;
  final String? coverUrl;
  final String source;
  final String? sourceId;
  final int position;

  CloudTrack({
    required this.path,
    required this.title,
    required this.artists,
    required this.album,
    this.coverUrl,
    required this.source,
    this.sourceId,
    required this.position,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'title': title,
    'artists': artists,
    'album': album,
    'cover_url': coverUrl,
    'source': source,
    'source_id': sourceId,
    'position': position,
  };

  static CloudTrack fromJson(Map<String, dynamic> j) => CloudTrack(
    path: j['path'] ?? '',
    title: j['title'] ?? '',
    artists: j['artists'] ?? '',
    album: j['album'] ?? '',
    coverUrl: j['cover_url'],
    source: j['source'] ?? 'local',
    sourceId: j['source_id'],
    position: j['position'] ?? 0,
  );

  db.KnownTracksCompanion toCompanion() {
    return db.KnownTracksCompanion.insert(
      path: path,
      title: title,
      artists: artists,
      album: album,
      coverUrl: Value(coverUrl),
      source: Value(source),
      sourceid: Value(sourceId),
      downloaded: false,
    );
  }
}

class CloudPlaylist {
  final String? cloudId; // ID в облаке (null если ещё не синхронизирован)
  final String title;
  final String? coverUrl;
  final String? description;
  final String type;
  final List<CloudTrack> tracks;

  CloudPlaylist({
    this.cloudId,
    required this.title,
    this.coverUrl,
    this.description,
    this.type = 'Playlist',
    required this.tracks,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'cover_url': coverUrl,
    'description': description,
    'type': type,
    'tracks': tracks.map((t) => t.toJson()).toList(),
  };

  static CloudPlaylist fromJson(Map<String, dynamic> j) => CloudPlaylist(
    cloudId: j['id']?.toString(),
    title: j['title'] ?? '',
    coverUrl: j['cover_url'],
    description: j['description'],
    type: j['type'] ?? 'Playlist',
    tracks: (j['tracks'] as List<dynamic>? ?? [])
        .map((t) => CloudTrack.fromJson(t as Map<String, dynamic>))
        .toList(),
  );

  static CloudPlaylist fromLocal(db.PlaylistWithTracks p) {
    return CloudPlaylist(
      title: p.playlist.title,
      coverUrl: p.playlist.coverUrl,
      description: p.playlist.description,
      type: p.playlist.type,
      tracks: p.tracks.asMap().entries.map((e) {
        final t = e.value;
        return CloudTrack(
          path: t.path,
          title: t.title,
          artists: t.artists,
          album: t.album,
          coverUrl: t.coverUrl,
          source: t.source ?? 'local',
          sourceId: t.sourceid,
          position: e.key,
        );
      }).toList(),
    );
  }
}

class PlaylistSyncService {
  static final PlaylistSyncService _instance = PlaylistSyncService._internal();
  factory PlaylistSyncService() => _instance;

  final _dio = Dio(
    BaseOptions(
      baseUrl: _kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  PlaylistSyncService._internal() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = AuthService().accessToken ?? '';
          options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              await AuthService().refresh();

              final opts = error.requestOptions;
              opts.headers['Authorization'] =
                  'Bearer ${AuthService().accessToken}';

              final resp = await _dio.fetch(opts);
              handler.resolve(resp);
              return;
            } catch (e) {
              print('PlaylistSyncService: session expired, $e');
              handler.next(error);
              return;
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Options get _authHeaders {
    final token = AuthService().accessToken ?? '';
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// return cloud id
  Future<String?> uploadPlaylist(db.PlaylistWithTracks playlist) async {
    try {
      final cloud = CloudPlaylist.fromLocal(playlist);
      final resp = await _dio.post(
        '/api/sync',
        data: cloud.toJson(),
        options: _authHeaders,
      );
      return resp.data['id']?.toString();
    } catch (e) {
      print('PlaylistSyncService: upload error $e');
      return null;
    }
  }

  Future<void> uploadAll() async {
    final cloudPlaylists = await fetchAll();
    final cloudTitles = cloudPlaylists.map((e) => e.title).toSet();

    final local = await db.AppDatabase().getAllPlaylistsWithTracks();
    for (final p in local) {
      if (cloudTitles.contains(p.playlist.title)) continue;
      await uploadPlaylist(p);
    }
  }

  Future<List<CloudPlaylist>> fetchAll() async {
    try {
      final resp = await _dio.get('/api/sync', options: _authHeaders);
      final list = resp.data as List<dynamic>;
      return list
          .map((e) => CloudPlaylist.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('PlaylistSyncService: fetch error $e');
      return [];
    }
  }

  Future<void> downloadAndSave() async {
    final cloud = await fetchAll();
    final dbInstance = db.AppDatabase();

    // Получаем уже существующие плейлисты
    final existing = await dbInstance.getAllPlaylistsWithTracks();
    final existingTitles = existing.map((e) => e.playlist.title).toSet();

    for (final cp in cloud) {
      if (existingTitles.contains(cp.title)) continue;

      final playlistId = await dbInstance.createPlaylist(cp.title);

      if (cp.tracks.isNotEmpty) {
        await dbInstance.batch((batch) {
          batch.insertAll(
            dbInstance.knownTracks,
            cp.tracks.map((t) => t.toCompanion()).toList(),
            mode: InsertMode.insertOrReplace,
          );
        });

        for (final t in cp.tracks) {
          final known = await (dbInstance.select(
            dbInstance.knownTracks,
          )..where((k) => k.path.equals(t.path))).getSingleOrNull();
          if (known != null) {
            await dbInstance.insertTrackIntoPlaylist(playlistId, known.id);
          }
        }
      }
    }
  }

  Future<bool> deletePlaylist(String cloudId) async {
    try {
      await _dio.delete('/api/sync/$cloudId', options: _authHeaders);
      return true;
    } catch (e) {
      return false;
    }
  }
}
