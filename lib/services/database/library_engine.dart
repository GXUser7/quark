import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quark/objects/track.dart';
import 'package:quark/services/cached_images.dart';

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
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(_openConnection());
  factory AppDatabase() => _instance;
  static final AppDatabase _instance = AppDatabase._internal();

  @override
  int get schemaVersion => 1;

  Future<void> saveTracks(List<PlayerTrack> tracks, {bool? downloaded}) async {
    await batch((b) {
      b.insertAll(
        knownTracks,
        tracks
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
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<List<KnownTrack>> getKnownTracks() async {
    return await select(knownTracks).get();
  }

  Future<void> deletePlaylist(int playlistId) async {
    print('[AppDatabase] Deleting playlist with ID: $playlistId...');
    await transaction(() async {
      await (delete(
        playlistTracks,
      )..where((pt) => pt.playlist.equals(playlistId))).go();

      await (delete(playlists)..where((p) => p.id.equals(playlistId))).go();
    });
    print('[AppDatabase] Successfully deleted playlist with ID: $playlistId.');
  }

  Future<void> renamePlaylist(int playlistId, String newTitle) async {
    print('[AppDatabase] Renaming playlist ID: $playlistId to "$newTitle"...');
    await (update(playlists)..where((p) => p.id.equals(playlistId))).write(
      PlaylistsCompanion(title: Value(newTitle)),
    );
    print('[AppDatabase] Successfully renamed playlist ID: $playlistId to "$newTitle".');
  }

  Future<void> changeCover(int playlistId, String path) async {
    print('[AppDatabase] Changing cover of playlist ID: $playlistId to path: "$path"...');
    await (update(playlists)..where((p) => p.id.equals(playlistId))).write(
      PlaylistsCompanion(coverPath: Value(path)),
    );
    print('[AppDatabase] Successfully changed cover of playlist ID: $playlistId.');
  }

  /// Returns ID of playlist
  Future<int> createPlaylist(String title) async {
    print('[AppDatabase] Creating new playlist: "$title"...');
    final result = await into(
      playlists,
    ).insert(PlaylistsCompanion.insert(title: title));
    print('[AppDatabase] Successfully created playlist: "$title" (Assigned ID: $result).');
    return result;
  }

  Future<Playlist?> getPlaylist(int id) async {
    return await (select(
      playlists,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertTrackIntoPlaylist(int playlistID, int trackID) async {
    print('[AppDatabase] Inserting track ID: $trackID into playlist ID: $playlistID...');
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
    print('[AppDatabase] Successfully inserted track ID: $trackID into playlist ID: $playlistID.');
  }

  Future<void> removeTrackPosition(int playlistID, int position) async {
    print('[AppDatabase] Removing track at position: $position from playlist ID: $playlistID...');
    await (delete(playlistTracks)..where(
          (t) => t.playlist.equals(playlistID) & t.position.equals(position),
        ))
        .go();
    print('[AppDatabase] Successfully removed track at position: $position from playlist ID: $playlistID.');
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
  

  Future<List<ListenStat>> getStats() async {
    return await select(listenStats).get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationCacheDirectory();
    final file = File(p.join(dbFolder.path, 'quark.db'));
    return NativeDatabase.createInBackground(file);
  });
}
