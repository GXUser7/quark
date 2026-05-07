import 'package:quark/objects/track.dart';

enum VideoSource {
  /// Video from public YouTube
  PUBLIC('PUBLIC'),

  /// Video requiring authorization (private/unlisted)
  AUTHORIZED('AUTHORIZED'),

  /// Video unavailable or restricted
  UNAVAILABLE('UNAVAILABLE');

  final String value;

  const VideoSource(this.value);

  static VideoSource tryFromString(String? value) {
    if (value == null) return VideoSource.PUBLIC;
    for (final source in VideoSource.values) {
      if (source.value.toLowerCase() == value.toLowerCase()) {
        return source;
      }
    }
    return VideoSource.PUBLIC;
  }
}

class FormatInfo {
  final String? formatId;
  final String? ext;
  final String? protocol;
  final String? acodec;
  final String? vcodec;
  final int? abr;
  final int? vbr;
  final int? tbr;
  final int? width;
  final int? height;
  final double? fps;
  final int? filesize;
  final String? url;

  const FormatInfo({
    this.formatId,
    this.ext,
    this.protocol,
    this.acodec,
    this.vcodec,
    this.abr,
    this.vbr,
    this.tbr,
    this.width,
    this.height,
    this.fps,
    this.filesize,
    this.url,
  });

  static FormatInfo fromJson(Map<String, dynamic> json) {
    return FormatInfo(
      formatId: json['format_id']?.toString(),
      ext: json['ext']?.toString(),
      protocol: json['protocol']?.toString(),
      acodec: json['acodec']?.toString(),
      vcodec: json['vcodec']?.toString(),
      abr: json['abr'] is num ? (json['abr'] as num).toInt() : null,
      vbr: json['vbr'] is num ? (json['vbr'] as num).toInt() : null,
      tbr: json['tbr'] is num ? (json['tbr'] as num).toInt() : null,
      width: json['width'] is num ? (json['width'] as num).toInt() : null,
      height: json['height'] is num ? (json['height'] as num).toInt() : null,
      fps: json['fps'] is num ? (json['fps'] as num).toDouble() : null,
      filesize: json['filesize'] is num
          ? (json['filesize'] as num).toInt()
          : null,
      url: json['url']?.toString(),
    );
  }
}

class Thumbnail {
  final String? url;
  final int? width;
  final int? height;
  final String? id;

  const Thumbnail({this.url, this.width, this.height, this.id});

  static Thumbnail fromJson(Map<String, dynamic> json) {
    return Thumbnail(
      url: json['url']?.toString(),
      width: json['width'] is num ? (json['width'] as num).toInt() : null,
      height: json['height'] is num ? (json['height'] as num).toInt() : null,
      id: json['id']?.toString(),
    );
  }
}

class Track {
  /// Video/Track ID (YouTube video ID)
  final String id;

  /// Title of the video/track
  final String title;

  /// Alternative title (if available)
  final String? altTitle;

  /// Description
  final String? description;

  /// Direct stream URL (from yt-dlp extraction)
  final String? streamUrl;

  /// Original webpage URL
  final String? webpageUrl;

  /// Thumbnail URL (main)
  final String? thumbnail;

  /// List of available thumbnails
  final List<Thumbnail> thumbnails;

  /// Duration in seconds
  final int? duration;

  /// Duration as formatted string (e.g. "3:45")
  final String? durationString;

  /// Channel name
  final String? channel;

  /// Channel ID
  final String? channelId;

  /// Channel URL
  final String? channelUrl;

  /// Uploader name (may differ from channel)
  final String? uploader;

  /// Uploader ID
  final String? uploaderId;

  /// Artist name (for music videos, from metadata)
  final String? artist;

  /// Album name (for music videos)
  final String? album;

  /// View count
  final int? viewCount;

  /// Like count
  final int? likeCount;

  /// Upload date as YYYYMMDD string
  final String? uploadDate;

  /// Unix timestamp of upload
  final int? timestamp;

  /// Live status: 'is_live', 'was_live', 'not_live', etc.
  final String? liveStatus;

  /// Is currently live
  final bool? isLive;

  /// Availability status: 'public', 'private', 'unlisted', 'needs_auth', etc.
  final String? availability;

  /// Age limit (0 if none)
  final int? ageLimit;

  /// Categories list
  final List<String> categories;

  /// Tags list
  final List<String> tags;

  /// List of available formats (detailed)
  final List<FormatInfo> formats;

  /// Selected format info (ext, resolution, etc.)
  final String? ext;
  final String? formatNote;
  final int? width;
  final int? height;
  final double? fps;

  /// Raw server response for debugging/extensibility
  final Map<String, dynamic> raw;

  Track(Map<String, dynamic> json)
    : id = json['id']?.toString() ?? '',
      title = json['title']?.toString() ?? 'Untitled',
      altTitle = json['alt_title']?.toString(),
      description = json['description']?.toString(),
      streamUrl = json['streamUrl']?.toString() ?? json['url']?.toString(),
      webpageUrl = json['webpage_url']?.toString(),
      thumbnail = json['thumbnail']?.toString(),
      thumbnails = json['thumbnails'] is List
          ? (json['thumbnails'] as List)
                .map((t) => Thumbnail.fromJson(t as Map<String, dynamic>))
                .toList()
          : [],
      duration = json['duration'] is num
          ? (json['duration'] as num).toInt()
          : null,
      durationString = json['duration_string']?.toString(),
      channel = json['channel']?.toString(),
      channelId = json['channel_id']?.toString(),
      channelUrl = json['channel_url']?.toString(),
      uploader = json['uploader']?.toString(),
      uploaderId = json['uploader_id']?.toString(),
      artist = json['artist']?.toString(),
      album = json['album']?.toString(),
      viewCount = json['view_count'] is num
          ? (json['view_count'] as num).toInt()
          : null,
      likeCount = json['like_count'] is num
          ? (json['like_count'] as num).toInt()
          : null,
      uploadDate = json['upload_date']?.toString(),
      timestamp = json['timestamp'] is num
          ? (json['timestamp'] as num).toInt()
          : null,
      liveStatus = json['live_status']?.toString(),
      isLive = json['is_live'] as bool?,
      availability = json['availability']?.toString(),
      ageLimit = json['age_limit'] is num
          ? (json['age_limit'] as num).toInt()
          : null,
      categories = json['categories'] is List
          ? (json['categories'] as List)
                .map((e) => e?.toString() ?? '')
                .toList()
          : [],
      tags = json['tags'] is List
          ? (json['tags'] as List).map((e) => e?.toString() ?? '').toList()
          : [],
      formats = json['formats'] is List
          ? (json['formats'] as List)
                .map((f) => FormatInfo.fromJson(f as Map<String, dynamic>))
                .toList()
          : [],
      ext = json['ext']?.toString(),
      formatNote = json['format_note']?.toString(),
      width = json['width'] is num ? (json['width'] as num).toInt() : null,
      height = json['height'] is num ? (json['height'] as num).toInt() : null,
      fps = json['fps'] is num ? (json['fps'] as num).toDouble() : null,
      raw = json;

  /// Helper: get best thumbnail URL with desired size approximation
  String? getBestThumbnail({int preferredWidth = 480}) {
    if (thumbnails.isEmpty) return thumbnail;

    Thumbnail? best;
    for (final t in thumbnails) {
      if (t.width == null) continue;
      if (best == null ||
          (t.width! - preferredWidth).abs() <
              (best.width! - preferredWidth).abs()) {
        best = t;
      }
    }
    return best?.url ?? thumbnail;
  }

  static YTMusicTrack? getYTMusicTrack(Track track) {
    return YTMusicTrack(
      videoId: track.id,
      title: track.title,
      artists: [track.artist.toString()],
      albums: [track.album.toString()],
      filepath: '',
      coverType: CoverType.url,
    );
  }

  /// Helper: check if track is playable
  bool get isPlayable =>
      availability == null ||
      availability == 'public' ||
      availability == 'unlisted';
}

class SearchResult {
  final String id;
  final String title;
  final String? channel;
  final String? channelId;
  final int? duration;
  final String? thumbnail;
  final String? url;
  final int? viewCount;
  final String? uploadDate;

  SearchResult(Map<String, dynamic> json)
    : id = json['id']?.toString() ?? '',
      title = json['title']?.toString() ?? 'Untitled',
      channel = json['channel']?.toString(),
      channelId = json['channel_id']?.toString(),
      duration = json['duration'] is num
          ? (json['duration'] as num).toInt()
          : null,
      thumbnail = json['thumbnail']?.toString(),
      url = json['url']?.toString(),
      viewCount = json['view_count'] is num
          ? (json['view_count'] as num).toInt()
          : null,
      uploadDate = json['upload_date']?.toString();

  /// Convert SearchResult to full Track if needed
  Track toTrack() => Track({
    'id': id,
    'title': title,
    'channel': channel,
    'channel_id': channelId,
    'duration': duration,
    'thumbnail': thumbnail,
    'url': url,
    'view_count': viewCount,
    'upload_date': uploadDate,
  });
}

class PlaylistEntry {
  /// List of tracks in this playlist entry (usually 1 item per YouTube video)
  final List<Track> tracks;

  PlaylistEntry({required this.tracks});

  static PlaylistEntry fromJson(Map<String, dynamic> json) {
    final tracksJson = json['tracks'] as List?;
    return PlaylistEntry(
      tracks: tracksJson != null
          ? tracksJson.map((t) => Track(t as Map<String, dynamic>)).toList()
          : [],
    );
  }
}

class PlaylistResponse {
  final bool success;
  final String playlistId;
  final String? title;
  final int? videoCount;
  final int videosReturned;
  final int videosSkipped;
  final List<PlaylistEntry> playlist;

  PlaylistResponse({
    required this.success,
    required this.playlistId,
    this.title,
    this.videoCount,
    required this.videosReturned,
    required this.videosSkipped,
    required this.playlist,
  });

  static PlaylistResponse fromJson(Map<String, dynamic> json) {
    final playlistJson = json['playlist'] as List?;
    return PlaylistResponse(
      success: json['success'] as bool? ?? false,
      playlistId: json['playlist_id']?.toString() ?? '',
      title: json['title']?.toString(),
      videoCount: json['video_count'] is num
          ? (json['video_count'] as num).toInt()
          : null,
      videosReturned: json['videos_returned'] is num
          ? (json['videos_returned'] as num).toInt()
          : 0,
      videosSkipped: json['videos_skipped'] is num
          ? (json['videos_skipped'] as num).toInt()
          : 0,
      playlist: playlistJson != null
          ? playlistJson
                .map((e) => PlaylistEntry.fromJson(e as Map<String, dynamic>))
                .toList()
          : [],
    );
  }

  /// Flat list of all tracks from playlist (convenience getter)
  List<Track> get allTracks =>
      playlist.expand((entry) => entry.tracks).toList();
}

/// Request models for API calls
class StreamRequest {
  final String videoId;
  final String format; // e.g. 'ba', 'bv', 'b', etc.

  StreamRequest({required this.videoId, this.format = 'ba'});

  Map<String, dynamic> toJson() => {'video_id': videoId, 'format': format};
}

class SearchRequest {
  final String query;
  final int maxResults;

  SearchRequest({required this.query, this.maxResults = 20});

  Map<String, dynamic> toJson() => {'query': query, 'max_results': maxResults};
}

class AuthorizedPlaylistRequest {
  final String playlist_id;
  final String format;
  final String? cookies; // MAYBE KALICH

  AuthorizedPlaylistRequest({
    required this.playlist_id,
    this.format = 'ba',
    this.cookies,
  });

  Map<String, dynamic> toJson() => {
    'playlist_id': playlist_id,
    'format': format,
    if (cookies != null) 'cookies': cookies,
  };
}

// for playlists entry after cookie/oauth auth

class YTMusicPlaylist {
  final String id;
  final String title;
  final String url;
  final String? thumbnail;

  const YTMusicPlaylist({
    required this.id,
    required this.title,
    required this.url,
    this.thumbnail,
  });

  factory YTMusicPlaylist.fromJson(Map<String, dynamic> json) {
    return YTMusicPlaylist(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      thumbnail: json['thumbnail'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'thumbnail': thumbnail,
  };
}

class YTMusicPlaylistsResponse {
  final bool success;
  final String title;
  final int videoCount;
  final List<YTMusicPlaylist> playlists;

  const YTMusicPlaylistsResponse({
    required this.success,
    required this.title,
    required this.videoCount,
    required this.playlists,
  });

  factory YTMusicPlaylistsResponse.fromJson(Map<String, dynamic> json) {
    // сервер возвращает playlist[].tracks[0] где каждый трек — это плейлист
    final playlistEntries = json['playlist'] as List? ?? [];

    final playlists = playlistEntries
        .map((entry) {
          final tracks = (entry['tracks'] as List?) ?? [];
          if (tracks.isEmpty) return null;
          final track = tracks[0] as Map<String, dynamic>;

          final thumbnails = track['thumbnails'] as List?;
          final thumbnail = thumbnails?.isNotEmpty == true
              ? thumbnails!.last['url'] as String?
              : null;

          return YTMusicPlaylist(
            id: track['id'] as String,
            title: track['title'] as String,
            url: track['url'] as String? ?? '',
            thumbnail: thumbnail,
          );
        })
        .whereType<YTMusicPlaylist>()
        .toList();

    return YTMusicPlaylistsResponse(
      success: json['success'] as bool? ?? false,
      title: json['title']?.toString() ?? '',
      videoCount: json['video_count'] is num
          ? (json['video_count'] as num).toInt()
          : 0,
      playlists: playlists,
    );
  }
}