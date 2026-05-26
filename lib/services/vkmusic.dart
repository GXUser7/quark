import 'package:quark/objects/track.dart';
import 'package:quark/services/yandex_music_singleton.dart';

/// Модель трека из ВКонтакте
class VkSong {
  final String id;
  final int? ownerId;
  final String title;
  final String? artist;
  final int? duration;
  final String? url;
  final String? coverUrl;
  final String? album;
  final int? year;
  final Map<String, dynamic> raw;
  final String? accessKey;

  VkSong({
    required this.id,
    this.ownerId,
    required this.title,
    this.artist,
    this.duration,
    this.url,
    this.coverUrl,
    this.album,
    this.year,
    this.accessKey,
    required this.raw,
  });

  factory VkSong.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawOwnerId = json['owner_id'];
    final String songId;

    if (rawId is String && rawId.contains('_')) {
      songId = rawId;
    } else if (rawOwnerId is int && rawId is int) {
      songId = '${rawOwnerId}_$rawId';
    } else {
      songId = rawId?.toString() ?? '';
    }

    return VkSong(
      id: songId,
      accessKey: json['access_key']?.toString(),
      ownerId: rawOwnerId is int ? rawOwnerId : null,
      title: json['title']?.toString() ?? 'Без названия',
      artist: json['artist']?.toString(),
      duration: json['duration'] is num
          ? (json['duration'] as num).toInt()
          : null,
      url: json['url']?.toString(),
      coverUrl: json['cover_url']?.toString() ?? json['photo']?.toString(),
      album: json['album']?.toString(),
      year: json['year'] is num ? (json['year'] as num).toInt() : null,
      raw: json,
    );
  }
  bool get canLoadSongs => id != null && id!.isNotEmpty && accessKey != null;

  /// Конвертация в общий объект Track для плеера
  Track toTrack() {
    return Track({
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'thumbnail': coverUrl,
      'url': url,
      'streamUrl': url,
      'source': 'vk',
      'raw': raw,
    });
  }

  /// Форматированная длительность (мм:сс)
  String get durationFormatted {
    if (duration == null) return '--:--';
    final mins = duration! ~/ 60;
    final secs = duration! % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Проверка, доступен ли трек для воспроизведения
  bool get isPlayable => url != null && url!.isNotEmpty;

  @override
  String toString() =>
      'VkSong(title: $title, artist: $artist, duration: $durationFormatted)';
}

/// Модель плейлиста ВКонтакте
class VkPlaylist {
  /// ID плейлиста
  final String id;

  /// ID владельца
  final int? ownerId;

  /// Название плейлиста
  final String title;

  /// Описание
  final String? description;

  /// Количество треков в плейлисте
  final int? count;

  /// Количество прослушиваний
  final int? plays;

  /// URL обложки
  final String? photo;

  /// Ключ доступа (для приватных плейлистов)
  final String? accessKey;

  /// Сырой ответ от API
  final Map<String, dynamic> raw;

  VkPlaylist({
    required this.id,
    this.ownerId,
    required this.title,
    this.description,
    this.count,
    this.plays,
    this.photo,
    this.accessKey,
    required this.raw,
  });

  factory VkPlaylist.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawOwnerId = json['owner_id'];
    final String playlistId;

    if (rawId is String && rawId.contains('_')) {
      playlistId = rawId;
    } else if (rawOwnerId is int && rawId is int) {
      playlistId = '${rawOwnerId}_$rawId';
    } else {
      playlistId = rawId?.toString() ?? '';
    }

    return VkPlaylist(
      id: playlistId,
      ownerId: rawOwnerId is int ? rawOwnerId : null,
      title: json['title']?.toString() ?? 'Без названия',
      description: json['description']?.toString(),
      count: json['count'] is num ? (json['count'] as num).toInt() : null,
      plays: json['plays'] is num ? (json['plays'] as num).toInt() : null,
      photo: json['photo']?.toString() ?? json['cover_url']?.toString(),
      accessKey: json['access_key']?.toString(),
      raw: json,
    );
  }

  @override
  String toString() => 'VkPlaylist(title: $title, count: $count)';
}

/// Результат поиска треков
class VkSearchResult {
  final String query;
  final int count;
  final List<VkSong> songs;

  VkSearchResult({
    required this.query,
    required this.count,
    required this.songs,
  });

  factory VkSearchResult.fromJson(Map<String, dynamic> json) {
    final songsJson = json['songs'] as List? ?? [];
    return VkSearchResult(
      query: json['query']?.toString() ?? '',
      count: json['count'] is num ? (json['count'] as num).toInt() : 0,
      songs: songsJson
          .whereType<Map<String, dynamic>>()
          .map((s) => VkSong.fromJson(s))
          .toList(),
    );
  }
}

/// Статус подключения VK-аккаунта
class VkConnectionStatus {
  final bool connected;
  final String? vkUserId;

  VkConnectionStatus({required this.connected, this.vkUserId});

  factory VkConnectionStatus.fromJson(Map<String, dynamic> json) {
    return VkConnectionStatus(
      connected: json['connected'] as bool? ?? false,
      vkUserId: json['vk_user_id']?.toString(),
    );
  }
}

/// Ответ при подключении токена
class VkTokenResponse {
  final bool success;
  final String? vkUserId;
  final String? message;

  VkTokenResponse({required this.success, this.vkUserId, this.message});

  factory VkTokenResponse.fromJson(Map<String, dynamic> json) {
    return VkTokenResponse(
      success: json['success'] as bool? ?? false,
      vkUserId: json['vk_user_id']?.toString(),
      message: json['message']?.toString(),
    );
  }
}

/// Запрос для отправки токена
class VkTokenRequest {
  final String token;
  final String client;

  VkTokenRequest({required this.token, this.client = 'Kate'});

  Map<String, dynamic> toJson() => {'token': token, 'client': client};
}
