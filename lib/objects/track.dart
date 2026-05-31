import 'dart:io';
import 'dart:typed_data';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:quark/services/files.dart';
import 'package:yandex_music/src/objects/track.dart';
import '../services/database/library_engine.dart' as db;

enum CoverType {
  url("url"),
  builtIn("builtIn"),
  externalFile("external"),
  noCover("noCover");

  final String value;

  const CoverType(this.value);

  static CoverType parseString(String string) {
    switch (string) {
      case "url":
        return CoverType.url;
      case "buildIn":
        return CoverType.builtIn;
      case "external":
        return CoverType.externalFile;
      case "noCover":
        return CoverType.noCover;
      default:
        return CoverType.builtIn;
    }
  }
}

abstract class PlayerTrack {
  final String title;
  final List<String> artists;
  final List<String> albums;
  final String filepath;
  String cover;
  Uint8List coverByted = Uint8List(0);
  CoverType coverType;

  PlayerTrack({
    required this.title,
    required this.artists,
    required this.albums,
    required this.filepath,
    required this.coverType,
    this.cover = 'none',
    Uint8List? coverByted,
  }) : coverByted = coverByted ?? Uint8List(0);

  static PlayerTrack getDummy() {
    return LocalTrack(
      albums: ['Unknown album'],
      artists: ['Unknown artist'],
      filepath: '',
      title: 'Unknown',
      coverType: CoverType.noCover,
    );
  }

  static PlayerTrack fromKnownTrack(db.KnownTrack t) {
    final artists = (t.artists?.isNotEmpty == true)
        ? t.artists!.split(',').map((e) => e.trim()).toList()
        : ['Unknown artist'];

    final albums = (t.album?.isNotEmpty == true)
        ? t.album!.split(',').map((e) => e.trim()).toList()
        : ['Unknown album'];

    var cover = t.coverUrl ?? 'none';
    if (t.source == 'yandex' && cover != 'none') {
      cover = cover.replaceFirst('https://', '').replaceFirst('http://', '');
      cover = cover.replaceAll(RegExp(r'\d+x\d+'), '%%');
    }
    final coverType = (cover != 'none' && cover.isNotEmpty)
        ? CoverType.url
        : CoverType.noCover;

    switch (t.source) {
      case 'yandex':
        final cachedPath = getTrackPath(t.sourceid ?? '');
        final ymTrack = YandexMusicTrack.createMinimalTrack(
          id: t.sourceid ?? '',
          title: t.title ?? '',
          artists: artists,
          albums: albums,
          coverUri: cover != 'none' ? cover : null,
        );
        return YandexMusicTrack(
          track: ymTrack,
          title: t.title ?? '',
          artists: artists,
          albums: albums,
          filepath: File(cachedPath).existsSync() ? cachedPath : t.path,
          coverType: coverType,
          cover: cover,
        );

      case 'youtube':
        return YTMusicTrack(
          videoId: t.sourceid ?? '',
          title: t.title ?? '',
          artists: artists,
          albums: albums,
          filepath: t.path.startsWith('http')
              ? t.path
              : getYTMusicCachePath(t.sourceid ?? ''),
          coverType: coverType,
          cover: cover,
          streamUrl: t.path.startsWith('http') ? t.path : null,
        );

      case 'soundcloud':
        return LocalTrack(
          title: t.title ?? '',
          artists: artists,
          albums: albums,
          filepath: 'sc:${t.sourceid}',
          coverType: coverType,
          cover: cover,
        );

      case 'spotify':
        return SpotifyTrack(
          spotifyId: t.sourceid ?? '',
          title: t.title ?? '',
          artists: artists,
          albums: albums,
          filepath: getSpotifyCachePath(t.sourceid ?? ''),
          coverType: coverType,
          cover: cover,
        );

      default:
        return LocalTrack.getFromDatabase(t);
    }
  }
}

class LocalTrack extends PlayerTrack {
  LocalTrack({
    required super.title,
    required super.artists,
    required super.albums,
    required super.filepath,
    required super.coverType,
    super.cover,
    super.coverByted,
  });

  /// Allows you to create a new runtime with the same data of the original class object
  static LocalTrack getNew(LocalTrack track) {
    return LocalTrack(
      title: track.title,
      artists: track.artists,
      albums: track.albums,
      filepath: track.filepath,
      cover: track.cover,
      coverByted: track.coverByted,
      coverType: track.coverType,
    );
  }

  static LocalTrack getDummy() {
    return LocalTrack(
      albums: ['Unknown album'],
      artists: ['Unknown artist'],
      filepath: '',
      title: 'Unknown',
      coverType: CoverType.noCover,
    );
  }
  // OLD
  // static LocalTrack getFromDatabase(db.KnownTrack track) {
  //   Uint8List? coverBytes;
  //   if (track.coverPath != null && File(track.coverPath!).existsSync()) {
  //     coverBytes = File(track.coverPath!).readAsBytesSync();
  //   }

  //   final artists = (track.artists?.isNotEmpty == true)
  //       ? track.artists!.split(',').map((e) => e.trim()).toList()
  //       : ['Unknown artist'];

  //   final albums = (track.album?.isNotEmpty == true)
  //       ? track.album!.split(',').map((e) => e.trim()).toList()
  //       : ['Unknown album'];

  //   final coverType = (track.coverPath != null && track.coverPath!.isNotEmpty)
  //       ? CoverType.builtIn
  //       : CoverType.noCover;

  //   return LocalTrack(
  //     title: track.title?.isNotEmpty == true
  //         ? track.title!
  //         : _titleFromPath(track.path),
  //     artists: artists,
  //     albums: albums,
  //     filepath: track.path,
  //     coverType: coverType,
  //     cover: 'none',
  //     coverByted: coverBytes,
  //   );
  // }

  static LocalTrack getFromDatabase(db.KnownTrack track) {
    Uint8List? coverBytes;
    if (track.coverPath != null && File(track.coverPath!).existsSync()) {
      coverBytes = File(track.coverPath!).readAsBytesSync();
    }

    final artists = (track.artists?.isNotEmpty == true)
        ? track.artists!.split(',').map((e) => e.trim()).toList()
        : ['Unknown artist'];

    final albums = (track.album?.isNotEmpty == true)
        ? track.album!.split(',').map((e) => e.trim()).toList()
        : ['Unknown album'];

    final hasCoverFile = coverBytes != null;
    final hasCoverUrl =
        track.coverUrl?.isNotEmpty == true && track.coverUrl != 'none';
    final coverType = hasCoverFile
        ? CoverType.builtIn
        : hasCoverUrl
        ? CoverType.url
        : CoverType.noCover;

    return LocalTrack(
      title: track.title?.isNotEmpty == true
          ? track.title!
          : _titleFromPath(track.path),
      artists: artists,
      albums: albums,
      filepath: track.path,
      coverType: coverType,
      cover: hasCoverUrl ? track.coverUrl! : 'none',
      coverByted: coverBytes,
    );
  }

  static String _titleFromPath(String path) {
    return path
        .split(Platform.pathSeparator)
        .last
        .replaceAll(RegExp(r'\.[^.]+$'), '');
  }
}

class YandexMusicTrack extends PlayerTrack {
  final Track track;

  static Track createMinimalTrack({
    required String id,
    required String title,
    List<String> artists = const [],
    List<String> albums = const [],
    String? coverUri,
  }) {
    return Track({
      'id': id,
      'title': title,
      'available': true,
      'trackSource': 'OWN',
      'coverUri': coverUri,
      'durationMs': 0,
      'ogImage': '',
      'lyricsInfo': {
        'hasAvailableSyncLyrics': false,
        'hasAvailableTextLyrics': false,
      },
      'artists': artists.map((a) => {'id': '0', 'name': a, 'various': false, 'composer': false, 'available': true}).toList(),
      'albums': albums.map((al) => {'id': 0, 'title': al, 'year': 0, 'trackCount': 0}).toList(),
    });
  }

  YandexMusicTrack({
    required this.track,
    required super.title,
    required super.artists,
    required super.albums,
    required super.filepath,
    required super.coverType,
    super.cover,
    super.coverByted,
  });

  static YandexMusicTrack fromYMTrack(Track track) {
    final path = getTrackPath(track.id).replaceAll('/', Platform.pathSeparator);
    final track2 = YandexMusicTrack(
      track: track,
      title: track.title,
      artists: track.artists.map((toElement) => toElement.title).toList(),
      albums: track.albums.isNotEmpty
          ? track.albums.map((toElement) => toElement.title).toList()
          : ["Unknown album"],
      filepath: path,
      coverType: CoverType.url,
    );
    track2.cover = track.coverUri ?? 'none';
    return track2;
  }

  /// Allows you to create a new runtime with the same data of the original class object
  static YandexMusicTrack getNew(YandexMusicTrack track) {
    return YandexMusicTrack(
      title: track.title,
      artists: track.artists,
      albums: track.albums,
      filepath: track.filepath,
      cover: track.cover,
      coverByted: track.coverByted,
      track: track.track,
      coverType: track.coverType,
    );
  }
}

String getTrackPath(String appendName) {
  return '${ApplicationCacheDirectory.instance.directory.path}/cisum_xednay_krauq$appendName.flac';
}

Map<String, dynamic> serializedLocalTrack(PlayerTrack track) {
  return {
    'title': track.title,
    'artists': track.artists,
    'albums': track.albums,
    'filepath': track.filepath,
    'cover': track.cover,
    'coverByted': Uint8List(0),
    "coverType": track.coverType.value,
  };
}

Future<LocalTrack> deserializedLocalTrack(
  Map<String, dynamic> trackData,
) async {
  List<String> artists = List<String>.from(trackData['artists']);
  List<String> albums = List<String>.from(trackData['albums']);
  AudioMetadata? metadata = null;
  Uint8List? cover;
  if (metadata != null) {
    cover = metadata.pictures.isNotEmpty
        ? metadata.pictures!.first.bytes
        : null;
  }

  return LocalTrack(
    title: trackData['title'],
    artists: artists,
    albums: albums,
    filepath: trackData['filepath'],
    cover: trackData['cover'],
    coverByted: cover,
    coverType: CoverType.parseString(trackData['coverType']),
  );
}

// yt

class YTMusicTrack extends PlayerTrack {
  final String videoId;
  final Map<String, dynamic>? extraData;
  final String? channel;
  final int? durationSeconds;
  String? streamUrl;

  YTMusicTrack({
    required this.videoId,
    required super.title,
    required super.artists,
    required super.albums,
    required super.filepath,
    required super.coverType,
    this.channel,
    this.extraData,
    this.durationSeconds,
    this.streamUrl,
    super.cover,
    super.coverByted,
  });

  String get audioSource {
    if (streamUrl != null &&
        streamUrl!.isNotEmpty &&
        streamUrl!.startsWith('http')) {
      return streamUrl!;
    }
    return filepath;
  }

  bool get isNetworkTrack => audioSource.startsWith('http');

  factory YTMusicTrack.fromApiTrack(dynamic apiTrack) {
    final Map<String, dynamic> json = apiTrack is Map
        ? apiTrack
        : (apiTrack as dynamic).raw ?? {};

    final videoId = json['id']?.toString() ?? json['videoId']?.toString() ?? '';
    final title = json['title']?.toString() ?? 'Unknown';

    final List<String> rawArtists = [
      if (json['artist'] != null) json['artist'].toString(),
      if (json['channel'] != null) json['channel'].toString(),
      if (json['uploader'] != null) json['uploader'].toString(),
      ...(json['artists'] is List
          ? (json['artists'] as List).map((e) => e.toString()).toList()
          : []),
    ].where((s) => s.isNotEmpty).cast<String>().toList();

    final streamUrl = json['streamUrl']?.toString() ?? json['url']?.toString();

    final filepath = streamUrl != null && streamUrl.isNotEmpty
        ? streamUrl
        : getYTMusicCachePath(videoId);

    final List<String> artists = rawArtists.toSet().toList();

    final albums = json['album'] != null
        ? [json['album'].toString()]
        : <String>[];

    final durationSec = json['duration'] is num
        ? (json['duration'] as num).toInt()
        : null;

    final thumbnail =
        json['thumbnail']?.toString() ??
        (json['thumbnails'] is List && (json['thumbnails'] as List).isNotEmpty
            ? (json['thumbnails'] as List).last['url']?.toString()
            : null);

    return YTMusicTrack(
      videoId: videoId,
      title: title,
      artists: artists.isNotEmpty ? artists : ['Unknown artist'],
      albums: albums.isNotEmpty ? albums : ['Unknown album'],
      filepath: filepath,
      coverType: thumbnail != null ? CoverType.url : CoverType.noCover,
      cover: thumbnail ?? 'none',
      channel: json['channel']?.toString(),
      durationSeconds: durationSec,
      streamUrl: streamUrl,
      extraData: json,
    );
  }

  /// Обновление стрим-ссылки (для случаев, когда ссылка временная)
  YTMusicTrack withStreamUrl(String newUrl) {
    return YTMusicTrack(
      videoId: videoId,
      title: title,
      artists: artists,
      albums: albums,
      filepath: filepath,
      coverType: coverType,
      channel: channel,
      extraData: extraData,
      durationSeconds: durationSeconds,
      streamUrl: newUrl,
      cover: cover,
      coverByted: coverByted,
    );
  }

  /// Клонирование трека (паттерн getNew из вашего кода)
  static YTMusicTrack getNew(YTMusicTrack track) {
    return YTMusicTrack(
      videoId: track.videoId,
      title: track.title,
      artists: track.artists,
      albums: track.albums,
      filepath: track.filepath,
      coverType: track.coverType,
      channel: track.channel,
      extraData: track.extraData,
      durationSeconds: track.durationSeconds,
      streamUrl: track.streamUrl,
      cover: track.cover,
      coverByted: track.coverByted,
    );
  }

  /// Пустой трек-заглушка (для инициализации)
  static YTMusicTrack getDummy() {
    return YTMusicTrack(
      videoId: '',
      title: 'Unknown',
      artists: ['Unknown artist'],
      albums: ['Unknown album'],
      filepath: '',
      coverType: CoverType.noCover,
    );
  }

  /// Проверка: является ли трек доступным для воспроизведения
  bool get isPlayable {
    final availability = extraData?['availability']?.toString();
    return availability == null ||
        availability == 'public' ||
        availability == 'unlisted';
  }

  @override
  String toString() => 'YTMusicTrack(videoId: $videoId, title: $title)';
}

// HELPER

/// Путь для кэширования трека YouTube Music
String getYTMusicCachePath(String videoId) {
  return '${ApplicationCacheDirectory.instance.directory.path}'
      '/cisum_ebutuoy_krauq$videoId.flac';
}

/// Сериализация YTMusicTrack для хранения (например, в БД или SharedPreferences)
Map<String, dynamic> serializedYTMusicTrack(YTMusicTrack track) {
  return {
    'type': 'ytmusic', // маркер типа для десериализации
    'videoId': track.videoId,
    'title': track.title,
    'artists': track.artists,
    'albums': track.albums,
    'filepath': track.filepath,
    'cover': track.cover,
    'coverByted': Uint8List(0), // обложки не сериализуем, загружаем по URL
    'coverType': track.coverType.value,
    'channel': track.channel,
    'durationSeconds': track.durationSeconds,
    'streamUrl': track.streamUrl,
    'extraData': track.extraData,
  };
}

/// Десериализация обратно в YTMusicTrack
Future<YTMusicTrack> deserializedYTMusicTrack(
  Map<String, dynamic> trackData,
) async {
  return YTMusicTrack(
    videoId: trackData['videoId']?.toString() ?? '',
    title: trackData['title']?.toString() ?? 'Unknown',
    artists: List<String>.from(trackData['artists'] ?? []),
    albums: List<String>.from(trackData['albums'] ?? []),
    filepath: trackData['filepath']?.toString() ?? '',
    cover: trackData['cover']?.toString() ?? 'none',
    coverByted: Uint8List(0),
    coverType: CoverType.parseString(trackData['coverType'] ?? 'noCover'),
    channel: trackData['channel']?.toString(),
    durationSeconds: trackData['durationSeconds'] is num
        ? (trackData['durationSeconds'] as num).toInt()
        : null,
    streamUrl: trackData['streamUrl']?.toString(),
    extraData: trackData['extraData'] is Map
        ? Map<String, dynamic>.from(trackData['extraData'])
        : null,
  );
}

class SpotifyTrack extends PlayerTrack {
  final String spotifyId;
  String? streamUrl;
  final int? durationSeconds;

  SpotifyTrack({
    required this.spotifyId,
    required super.title,
    required super.artists,
    required super.albums,
    required super.filepath,
    required super.coverType,
    this.streamUrl,
    this.durationSeconds,
    super.cover,
    super.coverByted,
  });

  String get audioSource {
    if (streamUrl != null &&
        streamUrl!.isNotEmpty &&
        streamUrl!.startsWith('http')) {
      return streamUrl!;
    }
    return filepath;
  }

  bool get isNetworkTrack => audioSource.startsWith('http');

  static SpotifyTrack getNew(SpotifyTrack track) {
    return SpotifyTrack(
      spotifyId: track.spotifyId,
      title: track.title,
      artists: track.artists,
      albums: track.albums,
      filepath: track.filepath,
      coverType: track.coverType,
      streamUrl: track.streamUrl,
      durationSeconds: track.durationSeconds,
      cover: track.cover,
      coverByted: track.coverByted,
    );
  }

  @override
  String toString() => 'SpotifyTrack(spotifyId: $spotifyId, title: $title)';
}

String getSpotifyCachePath(String spotifyId) {
  return '${ApplicationCacheDirectory.instance.directory.path}'
      '/cisum_yafitops_krauq$spotifyId.flac';
}

Map<String, dynamic> serializedSpotifyTrack(SpotifyTrack track) {
  return {
    'type': 'spotify',
    'spotifyId': track.spotifyId,
    'title': track.title,
    'artists': track.artists,
    'albums': track.albums,
    'filepath': track.filepath,
    'cover': track.cover,
    'coverByted': Uint8List(0),
    'coverType': track.coverType.value,
    'durationSeconds': track.durationSeconds,
    'streamUrl': track.streamUrl,
  };
}

Future<SpotifyTrack> deserializedSpotifyTrack(
  Map<String, dynamic> trackData,
) async {
  return SpotifyTrack(
    spotifyId: trackData['spotifyId']?.toString() ?? '',
    title: trackData['title']?.toString() ?? 'Unknown',
    artists: List<String>.from(trackData['artists'] ?? []),
    albums: List<String>.from(trackData['albums'] ?? []),
    filepath: trackData['filepath']?.toString() ?? '',
    cover: trackData['cover']?.toString() ?? 'none',
    coverByted: Uint8List(0),
    coverType: CoverType.parseString(trackData['coverType'] ?? 'noCover'),
    streamUrl: trackData['streamUrl']?.toString(),
    durationSeconds: trackData['durationSeconds'] is num
        ? (trackData['durationSeconds'] as num).toInt()
        : null,
  );
}
