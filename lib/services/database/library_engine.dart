import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quark/objects/track.dart';

part 'library_engine.g.dart';

class PlaylistWithTracks {
  final Playlist playlist;
  final List<KnownTrack> tracks;

  PlaylistWithTracks(this.playlist, this.tracks);
}

@TableIndex(name: 'idx_known_tracks_title', columns: {#title})
@TableIndex(name: 'idx_known_tracks_artists', columns: {#artists})
@DataClassName("KnownTrack")
class KnownTracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  // UI info without relation
  TextColumn get title => text()();
  // UI info without relation
  TextColumn get artists => text()();
  // UI info without relation
  TextColumn get album => text()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  TextColumn get blurCoverPath => text().nullable()();
  TextColumn get md5 => text().nullable()();
  TextColumn get source => text().withDefault(const Constant("local"))();
  TextColumn get sourceid => text().nullable()();
  BoolColumn get downloaded => boolean()();
}

@DataClassName("Playlist")
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get blurCoverPath => text().nullable()();
  // Album / Playlist
  TextColumn get type => text().withDefault(const Constant("Playlist"))();
}

@TableIndex(
  name: 'idx_playlist_tracks_playlist_pos',
  columns: {#playlist, #position},
)
@DataClassName("PlaylistTrack")
class PlaylistTracks extends Table {
  @override
  Set<Column> get primaryKey => {playlist, track};
  IntColumn get track => integer().references(KnownTracks, #id)();
  IntColumn get playlist => integer().references(Playlists, #id)();
  IntColumn get position => integer()();
}

@TableIndex(name: 'idx_cover_colors_md5', columns: {#md5})
@DataClassName("CoverColor")
class CoverColors extends Table {
  TextColumn get md5 => text()();

  /// JSON FORMAT => ```List<int>```
  TextColumn get colors => text()();

  @override
  Set<Column> get primaryKey => {md5};
}

@TableIndex(name: 'idx_listen_stats_track', columns: {#track})
@TableIndex(name: 'idx_listen_stats_time', columns: {#time})
@DataClassName("ListenStat")
class ListenStats extends Table {
  IntColumn get track => integer().references(KnownTracks, #id)();

  /// ISO8601
  DateTimeColumn get time => dateTime()();
  IntColumn get playedSeconds => integer()();
  IntColumn get totalTrackDuration => integer()();
  IntColumn get progressPercent => integer()();
  BoolColumn get isSkipped => boolean()();
}

@TableIndex(name: 'idx_listen_stats_track', columns: {#track})
@DataClassName("StarredTrack")
class StarredTrack extends Table {
  IntColumn get track => integer().references(KnownTracks, #id)();
  IntColumn get rating => integer()();
}

@DriftDatabase(
  tables: [Playlists, PlaylistTracks, KnownTracks, CoverColors, ListenStats],
)
// class LogSaver {
//   LogSaver._internal() : super(_openConnection());
//   factory LogSaver() => _instance;
//   static final LogSaver _instance = LogSaver._internal();
//   @override
//   int get schemaVersion => 1;
// }
// class Tracksdb {
//   Tracksdb._internal() : super(_openConnection());
//   factory Tracksdb() => _instance;
//   static final Tracksdb _instance = Tracksdb._internal();
//   @override
//   int get schemaVersion => 1;
// }
// class PlaylistsDb extends _$AppDatabase {
//   PlaylistsDb._internal() : super(_openConnection());
//   factory PlaylistsDb() => _instance;
//   static final PlaylistsDb _instance = PlaylistsDb._internal();
//   @override
//   int get schemaVersion => 1;
// }
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(_openConnection());
  factory AppDatabase() => _instance;
  static final AppDatabase _instance = AppDatabase._internal();

  @override
  int get schemaVersion => 1;

  final Set<String> _knownPaths = {};

  Future<void> saveTracks(List<PlayerTrack> tracks, {bool? downloaded}) async {
    final newTracks = tracks
        .where((t) => !_knownPaths.contains(t.filepath))
        .toList();

    if (newTracks.isEmpty) return;

    await batch((b) {
      b.insertAll(
        knownTracks,
        newTracks
            .map(
              (track) => KnownTracksCompanion.insert(
                path: track.filepath,
                title: track.title,
                artists: track.artists.join(","),
                album: track.albums.join(','),
                downloaded: downloaded ?? true,
                coverUrl: Value(track.cover),
              ),
            )
            .toList(),
        mode: InsertMode.insertOrIgnore,
      );
    });

    _knownPaths.addAll(newTracks.map((t) => t.filepath));
  }

  Future<int> saveSingleTrack(PlayerTrack track, {bool? downloaded}) async {
    final row = await into(knownTracks).insertReturning(
      KnownTracksCompanion.insert(
        path: track.filepath,
        title: track.title,
        artists: track.artists.join(","),
        album: track.albums.join(','),
        downloaded: downloaded ?? true,
        coverUrl: Value(track.cover),
      ),
      mode: InsertMode.insertOrReplace,
    );
    return row.id;
  }

  Future<void> saveStats(
    PlayerTrack track,
    int playedSeconds,
    int totalTrackDuration,
    int progressPercent,
    bool skipped,
  ) async {
    final existingTrack = await (select(
      knownTracks,
    )..where((e) => e.path.equals(track.filepath))).getSingleOrNull();

    int trackId;

    if (existingTrack == null) {
      trackId = await saveSingleTrack(track);
    } else {
      trackId = existingTrack.id;
    }

    await into(listenStats).insert(
      ListenStatsCompanion.insert(
        track: trackId,
        time: DateTime.now(),
        playedSeconds: playedSeconds,
        totalTrackDuration: totalTrackDuration,
        progressPercent: progressPercent,
        isSkipped: skipped,
      ),
    );
  }

  Future<List<ListenStat>> getStats() async {
    return await select(listenStats).get();
  }

  Future<List<KnownTrack>> getKnownTracks() async {
    return await select(knownTracks).get();
  }

  Future<void> deletePlaylist(int playlistId) async {
    await transaction(() async {
      await (delete(
        playlistTracks,
      )..where((pt) => pt.playlist.equals(playlistId))).go();

      await (delete(playlists)..where((p) => p.id.equals(playlistId))).go();
    });
  }

  Future<void> renamePlaylist(int playlistId, String newTitle) async {
    await (update(playlists)..where((p) => p.id.equals(playlistId))).write(
      PlaylistsCompanion(title: Value(newTitle)),
    );
  }

  Future<void> changeCover(int playlistId, String path) async {
    await (update(playlists)..where((p) => p.id.equals(playlistId))).write(
      PlaylistsCompanion(coverPath: Value(path)),
    );
  }

  /// Returns ID of playlist
  Future<int> createPlaylist(String title) async {
    final result = await into(
      playlists,
    ).insert(PlaylistsCompanion.insert(title: title));
    return result;
  }

  Future<Playlist?> getPlaylist(int id) async {
    return await (select(
      playlists,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertTrackIntoPlaylist(int playlistID, int trackID) async {
    await customInsert(
      'INSERT INTO playlist_tracks (playlist, track, position) '
      'VALUES (?, ?, (SELECT COALESCE(MAX(position), 0) + 1 FROM playlist_tracks WHERE playlist = ?))',
      variables: [
        Variable.withInt(playlistID),
        Variable.withInt(trackID),
        Variable.withInt(playlistID),
      ],
      updates: {playlistTracks},
    );
  }

  Future<void> removeTrackPosition(int playlistID, int position) async {
    await (delete(playlistTracks)..where(
          (t) => t.playlist.equals(playlistID) & t.position.equals(position),
        ))
        .go();
  }

  Future<PlaylistWithTracks?> watchPlaylist(int playlistId) async {
    final playlist = await (select(
      playlists,
    )..where((p) => p.id.equals(playlistId))).getSingleOrNull();

    if (playlist == null) return null;

    final rows =
        await (select(knownTracks).join([
                innerJoin(
                  playlistTracks,
                  playlistTracks.track.equalsExp(knownTracks.id),
                ),
              ])
              ..where(playlistTracks.playlist.equals(playlistId))
              ..orderBy([OrderingTerm.asc(playlistTracks.position)]))
            .get();

    final tracks = rows.map((row) => row.readTable(knownTracks)).toList();

    return PlaylistWithTracks(playlist, tracks);
  }

  Future<List<PlaylistWithTracks>> getAllPlaylistsWithTracks() async {
    final rows = await select(playlists).join([
      leftOuterJoin(
        playlistTracks,
        playlistTracks.playlist.equalsExp(playlists.id),
      ),
      leftOuterJoin(
        knownTracks,
        knownTracks.id.equalsExp(playlistTracks.track),
      ),
    ]).get();

    final Map<Playlist, List<KnownTrack>> data = {};

    for (final row in rows) {
      final playlist = row.readTable(playlists);
      final track = row.readTableOrNull(knownTracks);

      final list = data.putIfAbsent(playlist, () => []);
      if (track != null) list.add(track);
    }

    return data.entries.map((e) => PlaylistWithTracks(e.key, e.value)).toList();
  }

  Future<void> init() async {
    final paths = await select(knownTracks).map((row) => row.path).get();
    _knownPaths.addAll(paths);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationCacheDirectory();
    final file = File(p.join(dbFolder.path, 'quark.db'));
    return NativeDatabase.createInBackground(file);
  });
}
