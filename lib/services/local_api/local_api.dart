import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:quark/objects/playlist.dart';
import 'package:quark/objects/track.dart';
import 'package:quark/services/database/database.dart';
import 'package:quark/services/files.dart';
import 'package:quark/services/player/player.dart';

final Set<String> subscriberEndpoints = {
  "repeat",
  "shuffle",
  "now-playing-track",
  "playlist",
  "play-pause",
  "duration",
  "position",
  "volume",
};

final Map<String, ValueNotifier> notifiers = {
  "repeat": Player.player.repeatModeNotifier,
  "shuffle": Player.player.shuffleModeNotifier,
  "now-playing-track": Player.player.trackNotifier,
  "playlist": Player.player.playlistNotifier,
  "play-pause": Player.player.playingNotifier,
  "position": Player.player.playedNotifier,
  "duration": Player.player.durationNotifier,
  "volume": Player.player.volumeNotifier,
};

class LocalApi {
  LocalApi._internal();
  factory LocalApi() => _instance;
  static final LocalApi _instance = LocalApi._internal();

  HttpServer? serverInstance;

  final int apiVersion = 0;

  bool inited = false;

  int? port;

  // String? secret;

  Future<void> init() async {
    if (!DatabaseStreamerService().localApi.value || inited || Platform.isAndroid) {
      return;
    }
    inited = true;
    try {
      await _startHttp();
      await _createConnectionInfoFile();
      // secret = generateSecret(16); 
      Logger("LocalApi").fine(
        "Started http://${serverInstance!.address.address}:${serverInstance!.port}",
      );
      await _startRequestHandler();
    } catch (e, b) {
      Logger("LocalApi").severe("Failed to activate service.", e, b);
    }
  }

  Future<void> dispose() async {
    try {
      if (!inited) return;
      await serverInstance!.close();
      inited = false;
      port = null;
      Logger("LocalApi").fine("Sucessfulyy disposed");
    } catch (e, b) {
      Logger("LocalApi").severe("Failed to dispose service.", e, b);
    }
  }

  Future<int> _startHttp() async {
    serverInstance = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = serverInstance?.port;
    return serverInstance!.port;
  }

  Future<void> _createConnectionInfoFile() async {
    // TODO: FIX MULTI INSTANCE PLAYER - If several instances are running, only the last one will be in the file
    final file = File(
      join(ApplicationCacheDirectory.instance.directory.path, "api.port"),
    );
    if (file.existsSync()) {
      await file.delete();
    }
    await file.create(recursive: true);
    await file.writeAsString(serverInstance!.port.toString());
  }

  Future<void> _startRequestHandler() async {
    await for (HttpRequest request in serverInstance!) {
      final path = request.uri.path;
      request.response.headers.contentType = ContentType.json;
      // final String? secrets =
      //           request.uri.queryParameters["secret"];
      // if (secrets == null || secrets != secret) {
      //       request.response.statusCode = 400;
      //       request.response.write("Failed to get auth secret");
      //       request.response.close();
      //       break;
      // }

      switch (path) {
        case "/subscribe":
          {
            final String? subscriptionParameters =
                request.uri.queryParameters["subscriptions"];

            if (subscriptionParameters == null ||
                !subscriberEndpoints.containsAll(
                  subscriptionParameters.split(","),
                )) {
              request.response.statusCode = 400;
              request.response.write("Failed to get subscription list");
              request.response.close();
              break;
            }
            WebSocketTransformer.upgrade(request)
                .then((socket) {
                  _WSSubscriptions().addSubsriber({
                    socket: subscriptionParameters.split(",").toSet(),
                  });
                })
                .catchError((error) {
                  request.response.statusCode = 400;
                  request.response.write('WebSocket upgrade failed');
                  request.response.close();
                });
          }
          break;

        case "/get-api-version":
          request.response.write(apiVersion);
          request.response.close();
          break;
        case "/get-volume":
          request.response.write(Player.player.volumeNotifier.value);
          request.response.close();
          break;
        case "/set-volume":
          {
            final String? volume = request.uri.queryParameters["value"];
            if (volume == null) {
              request.response.statusCode = 400;
              request.response.write('Failed to get volume value');
              request.response.close();
              break;
            }

            final double? targetVolume = double.tryParse(volume);
            if (targetVolume == null || targetVolume > 1 || targetVolume < 0) {
              request.response.statusCode = 400;
              request.response.write('Incorrect volume value');
              request.response.close();
              break;
            }
            await Player.player.setVolume(targetVolume);
            request.response.statusCode = 204;
            request.response.close();
            break;
          }

        case "/get-repeat":
          request.response.write(Player.player.repeatModeNotifier.value);
          request.response.close();
          break;
        case "/set-repeat":
          {
            final String? repeat = request.uri.queryParameters["value"];
            if (repeat == null) {
              request.response.statusCode = 400;
              request.response.write('Failed to get repeat value');
              request.response.close();
              break;
            }

            final bool? targetValue = bool.tryParse(repeat);
            if (targetValue == null) {
              request.response.statusCode = 400;
              request.response.write('Incorrect repeat value');
              request.response.close();
              break;
            }
            targetValue
                ? await Player.player.enableRepeat()
                : await Player.player.disableRepeat();
            request.response.statusCode = 204;
            request.response.close();
            break;
          }

        case "/get-shuffle":
          request.response.write(Player.player.shuffleModeNotifier.value);
          request.response.close();
          break;
        case "/set-shuffle":
          {
            final String? shuffle = request.uri.queryParameters["value"];
            if (shuffle == null) {
              request.response.statusCode = 400;
              request.response.write('Failed to get repeat value');
              request.response.close();
              break;
            }
            final bool? targetValue = bool.tryParse(shuffle);
            if (targetValue == null) {
              request.response.statusCode = 400;
              request.response.write('Incorrect repeat value');
              request.response.close();
              break;
            }
            targetValue
                ? await Player.player.shuffle(ShuffleMode.nowOnTop)
                : await Player.player.unShuffle();
            request.response.statusCode = 204;
            request.response.close();
            break;
          }

        case "/get-position":
          request.response.write(Player.player.playedNotifier.value.inSeconds);
          request.response.close();
          break;
        case "/get-duration":
          request.response.write(
            Player.player.durationNotifier.value.inSeconds,
          );
          request.response.close();
          break;
        case "/get-quick-parameters":
          request.response.write(
            jsonEncode({
              "repeat": Player.player.repeatModeNotifier.value,
              "shuffle": Player.player.shuffleModeNotifier.value,
              "volume": Player.player.volumeNotifier.value,
              "paused": !Player.player.playingNotifier.value,
            }),
          );
          request.response.close();
          break;
        case "/get-now-playing-track":
          request.response.write(
            _getPlayerTrackJson(Player.player.nowPlayingTrack),
          );
          request.response.close();
          break;
        case "/set-now-playing-track":
          {
            final String? index = request.uri.queryParameters["value"];
            if (index == null) {
              request.response.statusCode = 400;
              request.response.write('Failed to get track index');
              request.response.close();
              break;
            }
            final int? targetValue = int.tryParse(index);
            if (targetValue == null ||
                targetValue > Player.player.playlist.length ||
                targetValue < 0) {
              request.response.statusCode = 400;
              request.response.write('Incorrect track index');
              request.response.close();
              break;
            }
            await Player.player.playCustom(Player.player.playlist[targetValue]);
            request.response.statusCode = 204;
            request.response.close();
            break;
          }
        case "/get-now-playlist":
          {
            final Map<String, dynamic> result = _getNowPlaylist();
            request.response.write(jsonEncode(result));
            await request.response.close();
            break;
          }
        case "/seek":
          {
            final String? seconds = request.uri.queryParameters["value"];
            if (seconds == null) {
              request.response.statusCode = 400;
              request.response.write('Failed to get seek timing');
              request.response.close();
              break;
            }
            final int? targetValue = int.tryParse(seconds);
            if (targetValue == null ||
                targetValue > Player.player.durationNotifier.value.inSeconds ||
                targetValue < 0) {
              request.response.statusCode = 400;
              request.response.write('Incorrect seek timing');
              request.response.close();
              break;
            }
            await Player.player.seek(Duration(seconds: targetValue));
            request.response.statusCode = 204;
            request.response.close();
            break;
          }
        case "/seek-delta-seconds":
          {
            final String? seconds = request.uri.queryParameters["value"];
            if (seconds == null) {
              request.response.statusCode = 400;
              request.response.write('Failed to get seek timing');
              request.response.close();
              break;
            }
            final int? targetValue = int.tryParse(seconds);
            if (targetValue == null ||
                targetValue > Player.player.durationNotifier.value.inSeconds ||
                targetValue < 0) {
              request.response.statusCode = 400;
              request.response.write('Incorrect seek timing');
              request.response.close();
              break;
            }
            await Player.player.seek(
              Duration(
                seconds:
                    targetValue + Player.player.playedNotifier.value.inSeconds,
              ),
            );
            request.response.statusCode = 204;
            request.response.close();
            break;
          }
        case "/play-next":
          await Player.player.playNext(forceNext: true);
          request.response.statusCode = 204;
          request.response.close();
          break;

        case "/play-previous":
          await Player.player.playPrevious();
          request.response.statusCode = 204;
          request.response.close();
          break;
        case "/pause":
          await Player.player.pause();
          request.response.statusCode = 204;
          request.response.close();
          break;
        case "/resume":
          await Player.player.playPause(true);
          request.response.statusCode = 204;
          request.response.close();
          break;
        default:
          request.response.statusCode = 404;
          request.response.write('Not found');
          await request.response.close();
          break;
      }
    }
  }
}

String _getPlayerTrackJson(PlayerTrack track) {
  final trackData = _serializeTrack(track, true);
  return jsonEncode(trackData);
}

Map<String, dynamic> _serializeTrack(
  PlayerTrack track,
  bool returnPosition, {
  Map<PlayerTrack, int>? playlistIndexMap,
  Map<PlayerTrack, int>? queueIndexMap,
  Set<PlayerTrack>? queueSet,
}) {
  final result = serializedLocalTrack(track, returnCoverByted: false);

  result.addAll({
    if (returnPosition)
      "position": Player.player.playedNotifier.value.inSeconds,
    "duration": Player.player.durationNotifier.value.inSeconds,
    "paused": Player.player.isPlaying,
    "local": track is LocalTrack,
    "from-queue":
        queueSet?.contains(track) ?? Player.player.queue.contains(track),
    "index": playlistIndexMap?[track] ?? Player.player.playlist.indexOf(track),
    "queue-index": queueIndexMap?[track] ?? Player.player.queue.indexOf(track),
  });

  return result;
}

Map<String, dynamic> _getNowPlaylist() {
  final tracks = [...Player.player.playlist, ...Player.player.queue];

  final playlistIndexMap = {
    for (var i = 0; i < Player.player.playlist.length; i++)
      Player.player.playlist[i]: i,
  };
  final queueIndexMap = {
    for (var i = 0; i < Player.player.queue.length; i++)
      Player.player.queue[i]: i,
  };
  final queueSet = Player.player.queue.toSet();

  return {
    "length": Player.player.playlist.length,
    "source": PlaylistSource.getName(Player.player.playlistInfo.source),
    "name": Player.player.playlistInfo.name,
    "unqueued-track-index": Player.player.unQueuedLastTrack != null
        ? Player.player.playlist.indexOf(Player.player.unQueuedLastTrack!)
        : -1,
    "tracks": tracks
        .map(
          (t) => _serializeTrack(
            t,
            false,
            playlistIndexMap: playlistIndexMap,
            queueIndexMap: queueIndexMap,
            queueSet: queueSet,
          ),
        )
        .toList(),
  };
}

class _WSSubscriptions {
  _WSSubscriptions._internal();
  factory _WSSubscriptions() => _instance;
  static final _WSSubscriptions _instance = _WSSubscriptions._internal();
  bool subscribed = false;

  final Map<WebSocket, Set<String>> subscribers = {};

  void addSubsriber(Map<WebSocket, Set<String>> sub) {
    subscribers.addAll(sub);
    _subscribeOnPlayer();
  }

  Future<void> _subscribeOnPlayer() async {
    if (!subscribed) {
      subscribed = true;
      Player.player.repeatModeNotifier.addListener(
        () => processSubscribers("repeat"),
      );
      Player.player.trackNotifier.addListener(
        () => processSubscribers("now-playing-track"),
      );
      Player.player.shuffleModeNotifier.addListener(
        () => processSubscribers("shuffle"),
      );
      Player.player.durationNotifier.addListener(
        () => processSubscribers("duration"),
      );
      Player.player.playingNotifier.addListener(
        () => processSubscribers("play-pause"),
      );
      Player.player.volumeNotifier.addListener(
        () => processSubscribers("volume"),
      );
      Player.player.playlistNotifier.addListener(
        () => processSubscribers("playlist"),
      );
    }
  }

  dynamic getNewValue(String subscriberEndboint) {
    switch (subscriberEndboint) {
      case "now-playing-track":
        return _getPlayerTrackJson(notifiers[subscriberEndboint]!.value);
      case "duration":
        return (notifiers[subscriberEndboint]!.value as Duration).inSeconds;
      case "position":
        return (notifiers[subscriberEndboint]!.value as Duration).inSeconds;
      case "playlist":
        return _getNowPlaylist();
      default:
        return notifiers[subscriberEndboint]!.value;
    }
  }

  Future<void> processSubscribers(String subscriberEndboint) async {
    final Map<String, dynamic> result = {
      "event": "$subscriberEndboint-update",
      "new": getNewValue(subscriberEndboint),
    };

    subscribers.forEach((key, value) {
      if (value.contains(subscriberEndboint)) {
        if (key.readyState == WebSocket.closed ||
            key.readyState == WebSocket.closing) {
          subscribers.remove(key);
          return;
        }
        try {
          key.add(jsonEncode(result));
        } catch (e) {
          subscribers.remove(key);
        }
      }
    });
  }
}

String generateSecret(int length) {
  const charset =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
  final random = Random.secure();

  return List.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

// /// GET SETTINGS
// Map<String, dynamic> settings = {
//   "audio_engine": "JustAudioMK",
//   "recursievly_adding_files": true,
//   "playlist_opening_area": true,
//   "state_indicator": true,
//   "transition_speed": 1.2,
//   "dynamic_window_color": true,
//   "yandex_music_search": true,
//   "yandex_music_preload": true,
//   "yandex_music_original_cover_size": true,
//   "yandex_music_original_quality": "Lossless",
//   "yandex_music_token": NONE, // security violation
// };

// /// GET PARAMS
// Map<String, dynamic> params = {
//   "type": "params",
//   "shuffle": true,
//   "repeat": true,
//   "playback_speed": 1.0,
//   "volume": 0.5620501,
// };

// /// GET NOW PLAYING TRACK
// Map<String, dynamic> npt = {
//   "paused": true,
//   "from_queue": false,
//   "position": 195000, // MS
//   "total_duration": 3000000,
//   "type": "now_playing_track",
//   "items": [jsonTrack2],
// };

// /// GET QUEUE (NOT PLAYLIST)
// Map<String, dynamic> queue = {
//   "type": "queue",
//   "items": [jsonTrack2],
// };

// /// GET PLAYLIST
// Map<String, dynamic> jsonPlaylist = {
//   "type": "playlist",
//   "source": "combined",
//   "id": "",
//   "owner": "",
//   "items": [jsonTrack, jsonTrack2],
// };

// Map<String, dynamic> track = {
//   "type": "track",
//   "from_queue": false,
//   "item": jsonTrack,
// };

// /// GET TRACK
// Map<String, dynamic> jsonTrack = {
//   "artists": ["Radiohead"],
//   "title": "Creep",
//   "album": "Pablo Honey",
//   "filepath": "/mnt/Music/Radiohead - Pablo Honey/Creep.flac",
//   "cover_path": "/mnt/Music/Radiohead - Pablo Honey/folder.jpg",

//   /// MAYBE /home/user/.cache/com.quark.quark/cached_images/646720e4995ef3375e4b690b40c7fc50
//   "cover_type": "external",
//   "source": "local",
// };

// Map<String, dynamic> jsonTrack2 = {
//   "type": "track",
//   "artists": ["Queen"],
//   "title": "Under Pressure",
//   "album": "Bohemian Rhapsody (OST)",
//   "filepath":
//       "/home/user/.cache/com.quark.quark/cisum_xenday_krauq5918512.flac",
//   "stream_url": null,
//   "cover_path":
//       "/home/user/.cache/com.quark.quark/cached_images/646720e4995ef3375e4b690b40c7fc50",
//   "cover_url": "url",
//   "cover_type": "external",
//   "source": "yandex_music",
//   "source_id": "591203",
//   "source_album_id": "59195", // OR NULL
// };

// Map<String, dynamic> jsonTrack3 = {
//   "type": "track",
//   "artists": ["Queen"],
//   "title": "Under Pressure",
//   "album": "Bohemian Rhapsody (OST)",
//   "filepath":
//       "/home/user/.cache/com.quark.quark/cisum_xenday_krauq5918512.flac",
//   "stream_url": "https://yandex/stream////////",
//   "cover_path":
//       "/home/user/.cache/com.quark.quark/cached_images/646720e4995ef3375e4b690b40c7fc50",
//   "cover_url": "url",
//   "cover_type": "external",
//   "source": "yandex_music",
//   "source_id": "591203",
//   "source_album_id": "59195", // OR NULL
// };
