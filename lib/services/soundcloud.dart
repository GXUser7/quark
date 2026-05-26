import 'package:quark/objects/track.dart';
import 'package:soundcloud_explode_dart/soundcloud_explode_dart.dart';

class SoundCloudTrack {
  final int id;
  final String title;
  final String? artist;
  final String? album;
  final String? thumbnailUrl;
  final double? durationMs;
  final double? fullDurationMs;
  final String? genre;
  final String? permalinkUrl;

  /// Трек полностью доступен (не 30-секундный сниппет)
  bool get isFullyPlayable =>
      durationMs != null &&
      fullDurationMs != null &&
      durationMs == fullDurationMs;

  const SoundCloudTrack({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.thumbnailUrl,
    this.durationMs,
    this.fullDurationMs,
    this.genre,
    this.permalinkUrl,
  });

  static SoundCloudTrack fromSearchResult(TrackSearchResult t) {
    return SoundCloudTrack(
      id: t.id,
      title: t.title ?? 'Unknown',
      artist: t.user?.username,
      thumbnailUrl: t.artworkUrl?.toString(),
      durationMs: t.duration,
      fullDurationMs: t.fullDuration,
      genre: t.genre,
      permalinkUrl: t.permalinkUrl?.toString(),
    );
  }

  static String _fixUrl(String? url) {
    if (url == null) return 'none';
    if (url.startsWith('https//'))
      return url.replaceFirst('https//', 'https://');
    if (url.startsWith('http//')) return url.replaceFirst('http//', 'http://');
    return url;
  }

  LocalTrack toPlayerTrack() {
    return LocalTrack(
      title: title,
      artists: artist != null ? [artist!] : ['Unknown'],
      albums: [],
      filepath: 'sc:$id',
      coverType: thumbnailUrl != null ? CoverType.url : CoverType.noCover,
      cover: _fixUrl(thumbnailUrl) ?? 'none',
    );
  }
}

class SoundCloudPlaylist {
  final int id;
  final String title;
  final String? thumbnailUrl;
  final String? permalinkUrl;
  final num trackCount;
  final bool isAlbum;

  const SoundCloudPlaylist({
    required this.id,
    required this.title,
    this.thumbnailUrl,
    this.permalinkUrl,
    this.trackCount = 0,
    this.isAlbum = false,
  });

  static SoundCloudPlaylist fromSearchResult(PlaylistSearchResult p) {
    return SoundCloudPlaylist(
      id: p.id,
      title: p.title ?? 'Unknown Playlist',
      thumbnailUrl: p.artworkUrl?.toString(),
      permalinkUrl: p.permalinkUrl?.toString(),
      trackCount: p.trackCount ?? 0,
      isAlbum: p.isAlbum ?? false,
    );
  }
}
