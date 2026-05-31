import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pool/pool.dart';
import 'package:quark/services/soundcloud_services.dart';
import 'package:quark/services/ytmusic_services.dart';
import 'package:quark/services/spotify_services.dart';

import 'player.dart';
import 'package:async/async.dart';
import 'package:logging/logging.dart';
import '../database/settings_engine.dart';
import 'package:quark/objects/track.dart';
import 'package:yandex_music/yandex_music.dart';
import 'package:quark/services/database/database.dart';
import 'package:quark/services/ytmusic.dart' as ytm;

/// Controls playback and caching of non-local and non-cached tracks

class NetConductor {
  late final Player _player;
  late final YandexMusic _yandex;

  static final NetConductor _singleton = NetConductor._internal();

  factory NetConductor() {
    return _singleton;
  }

  bool _isInitialized = false;
  bool _isLoading = false;
  bool disabledCaching = false;

  NetConductor._internal();

  CancelableOperation? _operation;

  final Set<String> caching = {};
  PlayerTrack? _lastTrack;

  void init(Player player, YandexMusic yandex) async {
    if (_isInitialized) {
      return;
    }
    _player = player;
    _yandex = yandex;
    _player.trackChangeNotifier.addListener(_onTrackChanged);
    _isInitialized = true;
    Logger('NetConductorSerivce').fine('Inited');
  }

  Future<void> playYandex(PlayerTrack track) async {
    try {
      String link = await _yandex.tracks.getDownloadLink(
        (track as YandexMusicTrack).track.id,
      );
      await _player.playNetTrack(link, track);
    } catch (e) {
      Logger(
        'NetPlayer',
      ).severe('An error has occured while processing online track');
    }
  }

  void _onTrackChanged() async {
    final track = _player.trackNotifier.value;

    if (track == _lastTrack || _isLoading) return;
    _lastTrack = track;
    _isLoading = true;

    await _operation?.cancel();

    // yandex music
    if (track is YandexMusicTrack && !await File(track.filepath).exists()) {
          print('[NetConductor] playing yandex track');
      try {
        _operation = CancelableOperation.fromFuture(_getLinkAndPlay(track));
        await _operation!.value;
      } catch (e) {
        Logger('NetConductor').severe('Error: $e');
        print('[NetConductor] yandex error: $e');
      }
    }

    // ytmusic
    if (track is YTMusicTrack && !await File(track.filepath).exists()) {
      try {
        _operation = CancelableOperation.fromFuture(_playYoutube(track));
        await _operation!.value;
      } catch (e) {
        Logger('NetConductor').severe('Error: $e');
      }
    }
    // sc
    if (track is LocalTrack && track.filepath.startsWith('sc:')) {
      print('[NetConductor] playing SoundCloud track: ${track.filepath}');
      final scId = int.tryParse(track.filepath.replaceFirst('sc:', ''));
      if (scId != null) {
        try {
          final url = await SoundCloudService().getStreamUrlWithOAuth(
            scId,
          ); // ← не getStreamUrl
          if (url != null) {
            await _player.playNetTrack(url, track);
          } else {
            print('[NetConductor] SoundCloud track stream URL resolved to null.');
            await _player.stop();
          }
        } catch (e) {
          print('[NetConductor] Failed to resolve SoundCloud stream: $e');
          await _player.stop();
        }
      } else {
        print('[NetConductor] Invalid SoundCloud ID.');
        await _player.stop();
      }
    }

    // spotify
    if (track is SpotifyTrack && !await File(track.filepath).exists()) {
      try {
        if (track.streamUrl?.startsWith('http') ?? false) {
          _operation = CancelableOperation.fromFuture(_player.playNetTrack(track.streamUrl!, track));
          await _operation!.value;
        } else {
          _operation = CancelableOperation.fromFuture(_playSpotify(track));
          await _operation!.value;
        }
      } catch (e) {
        Logger('NetConductor').severe('Spotify play error: $e');
      }
    }

    _isLoading = false;
    await cacheFiles();
  }

  Future<void> _getLinkAndPlay(PlayerTrack track) async {
    if (_operation?.isCanceled ?? false) return;
    final ytrack = (track as YandexMusicTrack);
    print('[NetConductor] Resolving Yandex Music stream URL for track: "${ytrack.track.title}" (ID: ${ytrack.track.id})');
    try {
      final quality = DatabaseStreamerService().yandexMusicQuality.value;
      AudioQuality downloadQuality = switch (quality) {
        'lossless' => AudioQuality.lossless,
        'nq' => AudioQuality.normal,
        'lq' => AudioQuality.low,
        'mp3' => AudioQuality.normal,
        _ => AudioQuality.normal,
      };
      print('[NetConductor] Requested Yandex quality: $quality -> $downloadQuality');
      
      final link = await _yandex.tracks.getDownloadLink(
        ytrack.track.id,
        quality: downloadQuality,
      );
      print('[NetConductor] Resolved Yandex stream URL successfully: $link');

      if (_operation?.isCanceled ?? true) return;
      await _player.playNetTrack(link, track);
    } catch (e, st) {
      print('[NetConductor] Failed to resolve Yandex stream: $e');
      print('[NetConductor] Stack: $st');
      if (!(_operation?.isCanceled ?? false)) {
        print('[NetConductor] Stopping player to prevent playing previous track.');
        await _player.stop();
      }
      rethrow;
    }
  }

  Future<void> _playYoutube(PlayerTrack track) async {
    if (_operation?.isCanceled ?? false) return;
    try {
      print('[NetConductor] Resolving YTMusic stream URL for track: "${track.title}" (Video ID: ${(track as YTMusicTrack).videoId})');
      final ytTrack = await YTMusicAPI().getTrack(
        (track as YTMusicTrack).videoId,
      );

      String? link = ytTrack.streamUrl;
      if (link == null) {
        print('[NetConductor] YTMusic track stream URL resolved to null.');
        if (!(_operation?.isCanceled ?? false)) {
          print('[NetConductor] Stopping player to prevent playing previous track.');
          await _player.stop();
        }
        return;
      }
      print('[NetConductor] Resolved YTMusic stream URL successfully.');

      if (_operation?.isCanceled ?? true) return;
      await _player.playNetTrack(link, track);
    } catch (e, st) {
      print('[NetConductor] Failed to resolve YTMusic stream: $e');
      print('[NetConductor] Stack: $st');
      if (!(_operation?.isCanceled ?? false)) {
        print('[NetConductor] Stopping player to prevent playing previous track.');
        await _player.stop();
      }
      rethrow;
    }
  }

  Future<void> _playSpotify(SpotifyTrack track) async {
    if (_operation?.isCanceled ?? false) return;
    try {
      print('[NetConductor] Resolving Spotify stream URL for track: "${track.title}" (ID: ${track.spotifyId})');
      final url = await SpotifyService().getStreamUrl(track);
      if (url == null) {
        print('[NetConductor] Spotify track stream URL resolved to null.');
        if (!(_operation?.isCanceled ?? false)) {
          print('[NetConductor] Stopping player to prevent playing previous track.');
          await _player.stop();
        }
        return;
      }
      print('[NetConductor] Resolved Spotify stream URL successfully.');

      track.streamUrl = url;

      if (_operation?.isCanceled ?? true) return;
      await _player.playNetTrack(url, track);
    } catch (e, st) {
      print('[NetConductor] Failed to resolve Spotify stream: $e');
      print('[NetConductor] Stack: $st');
      if (!(_operation?.isCanceled ?? false)) {
        print('[NetConductor] Stopping player to prevent playing previous track.');
        await _player.stop();
      }
      rethrow;
    }
  }

  Future<List<PlayerTrack>> getUncached(List<PlayerTrack> tracks) async {
    final List<PlayerTrack> result = [];
    for (PlayerTrack track in tracks) {
      if (track.filepath.startsWith('http')) continue;
      if (!await File(track.filepath).exists()) {
        result.add(track);
      }
    }
    return result;
  }

  /// Top function for caching tracks in storage
  Future<void> cacheFiles([List<PlayerTrack>? tracks]) async {
    if (disabledCaching) {
      return;
    }
    if (tracks == null) {
      tracks = [];
      if (Player.player.playlist.length < 3) {
        return;
      }
      for (int i = -1; i < 2; i++) {
        tracks.add(
          Player.player.playlist[(Player.player.playlist.indexOf(
                    Player.player.nowPlayingTrack,
                  ) +
                  i) %
              Player.player.playlist.length],
        );
      }
    }

    final pool = Pool(8);
    final futures = <Future<void>>[];
    final List<PlayerTrack> unCached = await getUncached(tracks);
    Logger("NetConductor").info(
      "Requested caching ${unCached.length} tracks. ${tracks.length - unCached.length} already exists.",
    );
    tracks = unCached;
    final lenght = tracks.length;
    for (int i = 0; i < lenght; i++) {
      PlayerTrack track = tracks[i];
      if (track is YandexMusicTrack) {
        if (caching.contains(track.filepath)) {
          continue;
        }
        final quality = DatabaseStreamerService().yandexMusicQuality.value;
        AudioQuality downloadQuality =
            AudioQuality.fromString(quality) ?? AudioQuality.normal;
        Logger("NetConductor").info("Caching ${track.track.id} $i / $lenght");
        caching.add(track.filepath);
        futures.add(
          pool.withResource(
            () => _cacheFileInBackground((track, _yandex, downloadQuality)),
          ),
        );
      }
    }
    await Future.wait(futures);
    Logger("NetConductor").info("Finished caching ${futures.length} tracks");
  }

  static Future<void> _cacheFileInBackground(
    (PlayerTrack, YandexMusic, AudioQuality) data,
  ) async {
    final track = data.$1;
    final instance = data.$2;
    final quality = data.$3;
    int attempt = 0;
    const maxRetries = 3;
    while (attempt < maxRetries) {
      if (track is YandexMusicTrack && track.track.available != false) {
        try {
          attempt += 1;
          final exists = await File(track.filepath).exists();
          if (!exists) {
            final download = await instance.tracks.download(
              track.track.id,
              quality: quality,
            );
            await compute(writeFile, (track.filepath, download));
          }
          Logger("NetConductor").info("Cached ID: ${track.track.id}");
        } catch (e) {
          if (attempt < maxRetries) {
            final delay = Duration(seconds: 1 << attempt);
            Logger("NetConductor").warning(
              "Error occured while caching yandex music track. ID: ${track.track.id}' Retrying in ${delay.inSeconds}s...",
            );
            await Future.delayed(delay);
          } else {
            Logger("NetConductor").severe(
              'Failed to cache ${track.track.id} after $attempt attempts. '
              'Available: ${track.track.available}',
              e,
            );
            rethrow;
          }
        }
      }
    }
  }

  static Future<void> writeFile((String, Uint8List) data) async {
    await File(data.$1).parent.create(recursive: true);
    await File(data.$1).writeAsBytes(data.$2);
  }

  Future<String?> getPlayableLink(PlayerTrack track) async {
    switch (track) {
      case YandexMusicTrack track:
        try {
          return await _yandex.tracks.getDownloadLink(track.track.id);
        } catch (e) {
          Logger(
            'NetConductor',
          ).warning('An error has occured while getting playable link', e);
          return null;
        }
      case YTMusicTrack track:
        try {
          ytm.Track? track2 = await YTMusicAPI().getTrack(track.videoId);
          String? link = track2.streamUrl;
          return link;
        } catch (e) {
          return null;
        }
      case SpotifyTrack track:
        if (track.streamUrl != null && track.streamUrl!.startsWith('http')) {
          return track.streamUrl;
        }
        try {
          return await SpotifyService().getStreamUrl(track);
        } catch (e) {
          return null;
        }
      case LocalTrack _:
        return null;
      default:
        return null;
    }
  }
}
