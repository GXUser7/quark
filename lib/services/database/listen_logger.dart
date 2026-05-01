import 'dart:math';
import 'package:logging/logging.dart';
import 'package:quark/services/database/library_engine.dart';

import '../../objects/track.dart';
// import 'package:isar/isar.dart';
import 'package:quark/services/player/player.dart';

// export 'package:isar/isar.dart';
//
// part 'listen_logger.g.dart';

// MAIN SERVICE

class ListenLogger {
  static final ListenLogger _instance = ListenLogger._internal();

  factory ListenLogger() => _instance;

  ListenLogger._internal();
  bool inited = false;
  int initTries = 0;
  Object? lastError;

  Future<void> init() async {
    initTries += 1;
    try {
      Player.player.trackChangeNotifier.addListener(trackListen);
      Player.player.durationNotifier.addListener(totalDurationListener);
      Player.player.playedNotifier.addListener(playedListener);

      lastTrack = Player.player.trackNotifier.value;
      lastPosition = Player.player.playedNotifier.value;
      lastCountedSecond = lastPosition.inSeconds;
      lastDuration = Player.player.durationNotifier.value;
      Logger('ListenLogger').fine('Started.', e);
    } catch (e) {
      Logger(
        'ListenLogger',
      ).severe('Failed to initialize the ListenLogger module.', e);
      lastError = e;
      return;
    }
    inited = true;
  }

  int lastCountedSecond = 0;
  int totalPlayedSeconds = 0;
  late PlayerTrack lastTrack;
  late Duration lastDuration;
  Duration lastPosition = Duration.zero;
  Duration totalDuration = Duration.zero;

  // Cache
  final Map<String, String> hashes = {}; // Filepath => Hash

  static const int seekThreshold = 2;

  void saveListen(PlayerTrack track, PlayerTrackStat stat) async {
    await AppDatabase().saveStats(
      track,
      stat.playedSeconds,
      stat.totalTrackDuration,
      (stat.playedSeconds / stat.totalTrackDuration * 100).round(),
      stat.changeType == PlayedType.skipped,
    );
  }

  void trackListen() async {
    final int tps = totalPlayedSeconds;
    final PlayerTrack lt = lastTrack;
    final Duration ld = lastDuration;

    totalDuration = Player.player.durationNotifier.value;
    totalPlayedSeconds = 0;
    lastPosition = Duration.zero;
    lastCountedSecond = 0;
    lastTrack = Player.player.trackNotifier.value;

    if (tps > 10) {
      TrackChange track = Player.player.trackChangeNotifier.value;

      saveListen(
        lt,
        PlayerTrackStat(
          playedSeconds: tps,
          totalTrackDuration: ld.inSeconds,
          progressPercent: min(((tps / ld.inSeconds) * 100).round(), 100),
          changeType: PlayedType.fromChangeReason(track.reason),
          time: DateTime.now(),
        ),
      );
    }
  }

  void totalDurationListener() async {
    totalDuration = lastDuration = Player.player.durationNotifier.value;
  }

  void playedListener() async {
    Duration currentPosition = Player.player.playedNotifier.value;
    int currentSecond = currentPosition.inSeconds;

    int diff = currentSecond - lastCountedSecond;

    if (diff > 0 && diff <= seekThreshold) {
      totalPlayedSeconds += diff;
      lastCountedSecond = currentSecond;
    } else if (diff > seekThreshold || diff < 0) {
      lastCountedSecond = currentSecond;
    }

    lastPosition = currentPosition;
  }

  void dispose() async {
    Player.player.trackChangeNotifier.removeListener(trackListen);
    Player.player.durationNotifier.removeListener(totalDurationListener);
    Player.player.playedNotifier.removeListener(playedListener);
    inited = false;
  }
}

// class ListenStats {
//   static final ListenStats _instance = ListenStats._internal();

//   factory ListenStats() => _instance;

//   ListenStats._internal();

//   late final Isar isar;
//   bool inited = false;

//   void init(Isar isarInstance) {
//     isar = isarInstance;
//     inited = true;
//   }

//   Future<List<Map<PlayerTrack1, PlayerTrackStat>>> getAllStats({
//     DateTime? time,
//   }) async {
//     late List<PlayerTrackStat> stats;
//     if (time != null) {
//       stats = await isar.playerTrackStats
//           .where()
//           .filter()
//           .timeGreaterThan(time)
//           .findAll();
//     } else {
//       stats = await isar.playerTrackStats.where().findAll();
//     }

//     for (var stat in stats) {
//       await stat.track.load();
//     }
//     return stats.where((stat) => stat.track.value != null).map((stat) {
//       return {stat.track.value!: stat};
//     }).toList();
//   }

//   Future<MapEntry<PlayerTrack1, int>?> getMostPlayedTrack({
//     DateTime? time,
//   }) async {
//     late List<PlayerTrackStat> stats;
//     if (time != null) {
//       stats = await isar.playerTrackStats
//           .where()
//           .filter()
//           .timeGreaterThan(time)
//           .findAll();
//     } else {
//       stats = await isar.playerTrackStats.where().findAll();
//     }

//     final Map<PlayerTrack1, int> playDurationMap = {};

//     for (var stat in stats) {
//       await stat.track.load();
//       final track = stat.track.value;
//       if (track != null) {
//         bool founded = false;
//         for (var entr in playDurationMap.entries) {
//           if (entr.key.md5Hash == track.md5Hash) {
//             playDurationMap.update(entr.key, (a) => a + stat.playedSeconds);
//             founded = true;
//             break;
//           }
//         }
//         if (!founded) {
//           playDurationMap[track] =
//               (playDurationMap[track] ?? 0) + stat.playedSeconds;
//         }
//       }
//     }

//     if (playDurationMap.isEmpty) return null;
//     final a = playDurationMap.entries.reduce(
//       (a, b) => a.value > b.value ? a : b,
//     );

//     return a;
//   }

//   Future<MapEntry<String, int>?> getMostPlayedArtist({
//     DateTime? time,
//   }) async {
//     late List<PlayerTrackStat> stats;
//     if (time != null) {
//       stats = await isar.playerTrackStats
//           .where()
//           .filter()
//           .timeGreaterThan(time)
//           .findAll();
//     } else {
//       stats = await isar.playerTrackStats.where().findAll();
//     }

//     final Map<String, int> artistMap = {};

//     for (var stat in stats) {
//       await stat.track.load();
//       final track = stat.track.value;
//       if (track != null) {
//         bool founded = false;
//         for (String artist in track.artists) {
//           for (var a in artistMap.entries) {
//             if (artist == a.key) {
//               founded = true;
//               artistMap.update(a.key, (a) => a + stat.playedSeconds);
//             }
//           }
//           if (!founded) {
//             artistMap[artist] = (artistMap[artist] ?? 0) + stat.playedSeconds;
//           }
//         }
//       }
//     }

//     if (artistMap.isEmpty) return null;
//     final a = artistMap.entries.reduce((a, b) => a.value > b.value ? a : b);
//     return a;
//   }
// }

// DATABASE SETTINGS

enum Source {
  yandexMusic,
  local;

  factory Source.getFromPlayerTrack(PlayerTrack track) {
    if (track is YandexMusicTrack) {
      return Source.yandexMusic;
    }

    return Source.local;
  }
}

enum PlayedType {
  completed,
  skipped;

  static PlayedType fromChangeReason(ChangeReason reason) {
    return (reason == ChangeReason.completed)
        ? PlayedType.completed
        : PlayedType.skipped;
  }
}

class PlayerTrackStat {
  final track = PlayerTrack;
  DateTime time;
  int playedSeconds;
  int totalTrackDuration;
  int progressPercent;
  PlayedType changeType;

  PlayerTrackStat({
    required this.playedSeconds,
    required this.totalTrackDuration,
    required this.changeType,
    required this.time,
    required this.progressPercent,
  });
}
