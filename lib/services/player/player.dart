import 'dart:collection';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:logging/logging.dart';
import 'package:quark/objects/playlist.dart';
import 'package:quark/objects/track.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:quark/services/database/database.dart';
import 'package:quark/services/player/net_player.dart';
import 'package:quark/services/yandex_music_singleton.dart';

enum ShuffleMode {
  /// Completely randomizes the list.
  full,

  /// Shuffles tracks after the current track (everything before it will remain unshuffle)
  afterCurrent,

  /// Shuffles the entire list and moves the current track to the top.
  nowOnTop,
}

enum ChangeReason {
  /// If the track has changed for natural reasons
  completed,

  /// If the track has changed due to external interference
  external,
}

class TrackChange {
  final PlayerTrack newTrack;
  final ChangeReason reason;

  const TrackChange({required this.newTrack, required this.reason});
}

class PlaylistInfo {
  final int ownerUid;
  final int kind;
  final String name;
  final PlaylistSource source;

  const PlaylistInfo({
    this.ownerUid = 0,
    this.kind = 0,
    this.source = PlaylistSource.local,
    this.name = 'Local',
  });

  static PlaylistInfo fromPlayerPlaylist(PlayerPlaylist playlist) {
    return PlaylistInfo(
      ownerUid: playlist.ownerUid,
      source: playlist.source,
      kind: playlist.kind,
      name: playlist.name,
    );
  }
}

enum PlayerBackend {
  /// AudioPlayers package ll be used
  audioPlayers("Standart"),
  justAudio("Just Audio"),
  justAudioMediaKit("Just Audio MK");

  final String value;

  const PlayerBackend(this.value);
}

class _Next {
  String path;

  /// false if next is uri
  bool local;
  _Next({required this.local, required this.path});
}

class _PlayerEngine {
  _PlayerEngine._internal();
  factory _PlayerEngine() => _instance;
  static final _PlayerEngine _instance = _PlayerEngine._internal();

  late PlayerBackend playerBackend;

  just_audio.AudioPlayer? justAudioPlayer;
  AudioPlayer? audioPlayersPlayer;

  _Next? next;

  StreamSubscription? _onPlayedChanged;
  StreamSubscription? _onDurationChanged;
  StreamSubscription? _onCompleteSubscription;

  Future<void> init(PlayerBackend playerBackend2) async {
    playerBackend = playerBackend2;
    switch (playerBackend) {
      case PlayerBackend.justAudio:
        justAudioPlayer = just_audio.AudioPlayer(
          userAgent:
              'com.google.android.youtube/17.31.35 (Linux; U; Android 13; en_US) gzip',
        );
      case PlayerBackend.justAudioMediaKit:
        JustAudioMediaKit.ensureInitialized();
        JustAudioMediaKit.pitch = true;
        justAudioPlayer = just_audio.AudioPlayer(
          userAgent:
              'com.google.android.youtube/17.31.35 (Linux; U; Android 13; en_US) gzip',
        );
      default:
        audioPlayersPlayer = AudioPlayer();
    }
  }

  Future<void> play(String filePath) async {
    try {
      switch (playerBackend) {
        case PlayerBackend.justAudioMediaKit:
        case PlayerBackend.justAudio:
          await justAudioPlayer!.setAudioSource(
            just_audio.AudioSource.file(filePath),
          );
          await justAudioPlayer!.play();
        default:
          await audioPlayersPlayer!.play(DeviceFileSource(filePath));
      }
    } catch (e) {
      Logger("PlayerEngine").warning("Failed to play an audiofile", e);
    }
  }

  Future<void> playNet(String url) async {
    try {
      switch (playerBackend) {
        case PlayerBackend.justAudioMediaKit:
        case PlayerBackend.justAudio:
          await justAudioPlayer!.setAudioSource(
            just_audio.AudioSource.uri(Uri.parse(url)),
          );
          await justAudioPlayer!.play();
        default:
          await audioPlayersPlayer!.play(UrlSource(url));
      }
    } catch (e) {
      Logger("PlayerEngine").warning("Failed to play an networkSource", e);
    }
  }

  Future<void> stop() async {
    try {
      switch (playerBackend) {
        case PlayerBackend.justAudioMediaKit:
        case PlayerBackend.justAudio:
          await justAudioPlayer!.stop();
        default:
          await audioPlayersPlayer!.stop();
      }
    } catch (e) {
      Logger("PlayerEngine").warning("Failed to play an networkSource", e);
    }
  }

  // Future<void> playPause(bool play) async {
  //   try {
  //     switch (playerBackend) {
  //       case PlayerBackend.justAudioMediaKit:
  //       case PlayerBackend.justAudioVlc:
  //       case PlayerBackend.justAudio:
  //         if (play) await justAudioPlayer!.pause();
  //         if (!play) await justAudioPlayer!.play();
  //       default:
  //         if (play) await audioPlayersPlayer!.pause();
  //         if (!play) await audioPlayersPlayer!.resume();
  //     }
  //   } catch (e) {
  //     Logger("PlayerEngine").warning("Failed to play an networkSource", e);
  //   }
  // }

  Future<void> resume() async {
    try {
      switch (playerBackend) {
        case PlayerBackend.justAudioMediaKit:
        case PlayerBackend.justAudio:
          await justAudioPlayer!.play();
        default:
          await audioPlayersPlayer!.resume();
      }
    } catch (e) {
      Logger("PlayerEngine").warning("Failed to play an networkSource", e);
    }
  }

  Future<void> pause() async {
    try {
      switch (playerBackend) {
        case PlayerBackend.justAudioMediaKit:
        case PlayerBackend.justAudio:
          await justAudioPlayer!.pause();
        default:
          await audioPlayersPlayer!.pause();
      }
    } catch (e) {
      Logger("PlayerEngine").warning("Failed to play an networkSource", e);
    }
  }

  Future<void> setupListeners(
    void Function(void) onComplete,
    void Function(Duration) onDuration,
    void Function(Duration) onPlayed,
  ) async {
    switch (playerBackend) {
      case PlayerBackend.justAudioMediaKit:
      case PlayerBackend.justAudio:
        await _onCompleteSubscription?.cancel();
        await _onDurationChanged?.cancel();
        await _onPlayedChanged?.cancel();

        // _onCompleteSubscription = justAudioPlayer!.playerStateStream
        //     .where(
        //       (state) =>
        //           state.processingState == just_audio.ProcessingState.completed,
        //     )
        //     .listen((_) => onComplete(null));

        _onDurationChanged = justAudioPlayer!.durationStream
            .where((d) => d != null)
            .cast<Duration>()
            .listen(onDuration);
        justAudioPlayer!.currentIndexStream
            .where((index) => index != null)
            .distinct()
            .listen((index) async {
              final sequenceLength = justAudioPlayer!.sequence.length;
              if (index! > 0 && sequenceLength > 1) {
                await justAudioPlayer!.removeAudioSourceAt(0);
                onComplete(null);
              }
            });
        _onPlayedChanged = justAudioPlayer!.positionStream.listen(onPlayed);

      default:
        await _onCompleteSubscription?.cancel();
        await _onDurationChanged?.cancel();
        await _onPlayedChanged?.cancel();
        _onCompleteSubscription = audioPlayersPlayer!.onPlayerComplete.listen((
          _,
        ) async {
          onComplete(null);
          if (playerBackend == PlayerBackend.audioPlayers) {
            if (next == null) return;
            await audioPlayersPlayer!.play(
              next!.local
                  ? DeviceFileSource(next!.path)
                  : UrlSource(next!.path),
            );
          }
        });
        _onDurationChanged = audioPlayersPlayer!.onDurationChanged.listen(
          onDuration,
        );
        _onPlayedChanged = audioPlayersPlayer!.onPositionChanged.listen(
          onPlayed,
        );
    }
  }

  Future<void> seek(Duration duration) async {
    switch (playerBackend) {
      case PlayerBackend.justAudioMediaKit:
      case PlayerBackend.justAudio:
        await justAudioPlayer!.seek(duration);
      default:
        await audioPlayersPlayer!.seek(duration);
    }
  }

  Future<void> setVolume(double volume) async {
    switch (playerBackend) {
      case PlayerBackend.justAudioMediaKit:
      case PlayerBackend.justAudio:
        await justAudioPlayer!.setVolume(volume);
      default:
        await audioPlayersPlayer!.setVolume(volume);
    }
  }

  Future<void> setSpeed(double speed) async {
    switch (playerBackend) {
      case PlayerBackend.justAudioMediaKit:
      case PlayerBackend.justAudio:
        await justAudioPlayer!.setSpeed(speed);
      default:
        await audioPlayersPlayer!.setPlaybackRate(speed);
    }
  }

  Future<void> setNextFile(String filepath) async {
    switch (playerBackend) {
      case PlayerBackend.justAudioMediaKit:
      case PlayerBackend.justAudio:
              if (justAudioPlayer!.audioSources.length > 1) {
          await justAudioPlayer!.removeAudioSourceRange(
            1,
            justAudioPlayer!.audioSources.length,
          );
        }
        await justAudioPlayer!.addAudioSource(
          just_audio.AudioSource.file(filepath),
        );
      default:
    }
    next = _Next(local: true, path: filepath);
  }

  Future<void> setNextNet(String uri) async {
    switch (playerBackend) {
      case PlayerBackend.justAudioMediaKit:
      case PlayerBackend.justAudio:
        if (justAudioPlayer!.audioSources.length > 1) {
          await justAudioPlayer!.removeAudioSourceRange(
            1,
            justAudioPlayer!.audioSources.length,
          );
        }
        await justAudioPlayer!.addAudioSource(
          just_audio.AudioSource.uri(Uri.parse(uri)),
        );
        next = _Next(local: false, path: uri);
      default:
        next = _Next(local: false, path: uri);
    }
  }

  Future<void> getReadyFile(String filepath) async {
    switch (playerBackend) {
      case PlayerBackend.justAudioMediaKit:
      case PlayerBackend.justAudio:
        await justAudioPlayer!.setAudioSource(
          just_audio.AudioSource.file(filepath),
        );
      default:
        await audioPlayersPlayer!.setSource(DeviceFileSource(filepath));
    }
  }

  Future<void> getReadyNet(String url) async {
    switch (playerBackend) {
      case PlayerBackend.justAudioMediaKit:
      case PlayerBackend.justAudio:
        await justAudioPlayer!.setAudioSource(
          just_audio.AudioSource.uri(Uri.parse(url)),
        );
      default:
        await audioPlayersPlayer!.setSource(UrlSource(url));
    }
  }

  Future<void> playNext() async {
    switch (playerBackend) {
      case PlayerBackend.justAudioMediaKit:
      case PlayerBackend.justAudio:
        await justAudioPlayer!.seekToNext();
      default:
    }
  }

  Future<void> clearPlaylist() async {
    switch (playerBackend) {
      case PlayerBackend.justAudioMediaKit:
      case PlayerBackend.justAudio:
        await justAudioPlayer!.clearAudioSources();
      default:
    }
  }

  Future<void> dispose() async {
    await _onCompleteSubscription?.cancel();
    await _onDurationChanged?.cancel();
    await _onPlayedChanged?.cancel();

    _onCompleteSubscription = null;
    _onDurationChanged = null;
    _onPlayedChanged = null;

    if (justAudioPlayer != null) {
      await justAudioPlayer!.dispose();
      justAudioPlayer = null;
    }
    if (audioPlayersPlayer != null) {
      await audioPlayersPlayer!.dispose();
      audioPlayersPlayer = null;
    }
  }
}

/// A standalone player running in the background, independent of the stream UI
class Player {
  // SINGLETON INTERNAL REALISATION
  Player._internal() : playlist = [], nowPlayingTrack = LocalTrack.getDummy();

  static final Player _player = Player._internal();

  static Player get player => _player;

  PlayerTrack nowPlayingTrack;
  List<PlayerTrack> playlist;

  Player({required this.playlist, required this.nowPlayingTrack});

  // SETUP NOTIFIERS FOR UI LISTENERS
  final trackNotifier = ValueNotifier<PlayerTrack>(LocalTrack.getDummy());

  final trackChangeNotifier = ValueNotifier<TrackChange>(
    TrackChange(newTrack: LocalTrack.getDummy(), reason: ChangeReason.external),
  );
  final playedNotifier = ValueNotifier<Duration>(Duration());
  final durationNotifier = ValueNotifier<Duration>(Duration());
  final playlistNotifier = ValueNotifier<List<PlayerTrack>>([]);
  final repeatModeNotifier = ValueNotifier<bool>(false);
  final shuffleModeNotifier = ValueNotifier<bool>(false);
  final volumeNotifier = ValueNotifier<double>(0.5);
  final queueNotifier = ValueNotifier<List<PlayerTrack>>(
    List<PlayerTrack>.from([]),
  );

  /// Notifies whether the playback is playing or stopped
  final playingNotifier = ValueNotifier<bool>(false);

  /// It is not recommended to change this value yourself by using ```Player.unShuffledPlaylist = []```.
  List<PlayerTrack> unShuffledPlaylist = [];

  double speed = 1.0;

  bool isPlaying = false;
  bool isRepeat = false;
  bool isShuffle = false;

  ShuffleMode shuffleMode = ShuffleMode.nowOnTop;

  PlaylistInfo playlistInfo = PlaylistInfo();

  List<PlayerTrack> queue = List<PlayerTrack>.from([]);
  PlayerTrack? unQueuedLastTrack;
  List<PlayerTrack> queue2 = [];

  PlayerBackend playerBackend = PlayerBackend.justAudioMediaKit;


  Future<void> init({PlayerBackend? backend}) async {
    playlistNotifier.value = playlist;
    unShuffledPlaylist = playlist;
    final PlayerBackend engine = backend ?? playerBackend;
    DatabaseStreamerService().playerBackend.value =
        backend?.value ?? engine.value;
      playerBackend = backend ?? playerBackend;
    await _PlayerEngine().init(backend ?? engine);
    await setupListeners();
  }

  Future<void> dispose() async {
    await _PlayerEngine().dispose();
  }

  Future<void> setupListeners() async {
    _PlayerEngine().setupListeners(
      (event) async {
        await playNext(completed: true);
      },
      (event) {
        durationNotifier.value = event;
      },
      (event) {
        playedNotifier.value = event;
      },
    );
  }

  Future<void> _afterFn() async {
    if (Platform.isLinux) {
      // Fixing the bug where changing the source cause the maximum player's volume (1.0 instead previous value)
      await _PlayerEngine().setVolume(volumeNotifier.value);
      await _PlayerEngine().setSpeed(speed);
    }
  }

  Future<void> playNext({bool? forceNext, bool? completed}) async {
    queue.remove(nowPlayingTrack);

    nowPlayingTrack = _getNext();
    trackNotifier.value = nowPlayingTrack;
    trackChangeNotifier.value = TrackChange(
      newTrack: nowPlayingTrack,
      reason: (completed ?? false)
          ? ChangeReason.completed
          : ChangeReason.external,
    );
    if (forceNext == true) {
      await _playIsPlaying();
    }
    await _sendNext();
    return;
  }

  PlayerTrack _getNext() {
    if (queue.isNotEmpty && queue.length > 1) {
      if (queue.contains(nowPlayingTrack)) {
        final nextIndex = queue.indexOf(nowPlayingTrack) + 1;
        return queue[nextIndex];
      } else {
        return queue.first;
      }
    } else {
      if (unQueuedLastTrack != null) {
        final track = unQueuedLastTrack;
        unQueuedLastTrack = null;
        return track!;
      }
    }
    int nowIndex = playlist.indexWhere((t) => t == nowPlayingTrack);

    int nextIndex = (isRepeat)
        ? nowIndex
        : playlist.length - 1 != nowIndex
        ? nowIndex + 1
        : 0;
    return playlist[nextIndex];
  }

  PlayerTrack _getPrevious() {
    if (queue.isNotEmpty) {
      if (queue.contains(nowPlayingTrack)) {
        if (queue.first != nowPlayingTrack) {
          final index = queue.indexOf(nowPlayingTrack) - 1;
          return queue[index];
        } else {
          if (unQueuedLastTrack != null) return unQueuedLastTrack!;
        }
      }
    }

    int nowIndex = playlist.indexWhere((t) => t == nowPlayingTrack);
    int nextIndex = nowIndex == 0
        ? playlist.length - 1
        : nowIndex > 0
        ? nowIndex - 1
        : 0;
    return playlist[nextIndex];
  }

  Future<void> _sendNext() async {
    final PlayerTrack nextAfter = _getNext();
    if (await File(nextAfter.filepath).exists()) {
      await _PlayerEngine().setNextFile(nextAfter.filepath);
    } else {
      final String? nextLink = await NetConductor().getPlayableLink(nextAfter);
      if (nextLink != null) {
        await _PlayerEngine().setNextNet(nextLink);
      }
    }
  }

  Future<void> _playIsPlaying() async {
    bool exists = await File(nowPlayingTrack.filepath).exists();
    if (!exists) {
      return;
    }
    if (isPlaying) {
      await _PlayerEngine().play(nowPlayingTrack.filepath);
    } else {
      await _PlayerEngine().getReadyFile(nowPlayingTrack.filepath);
    }
    await _afterFn();
  }

  Future<void> playPrevious() async {
    nowPlayingTrack = _getPrevious();
    trackNotifier.value = nowPlayingTrack;
    trackChangeNotifier.value = TrackChange(
      newTrack: nowPlayingTrack,
      reason: ChangeReason.external,
    );
    await _playIsPlaying();
    await _sendNext();
  }

  Future<void> playPause(bool play) async {
    playingNotifier.value = play;
    isPlaying = play ? true : false;
    play ? await _PlayerEngine().resume() : await _PlayerEngine().pause();
  }

  Future<void> setVolume(double volume) async {
    volumeNotifier.value = volume;
    await _PlayerEngine().setVolume(volume);
  }

  Future<void> seek(Duration seek) async {
    await _PlayerEngine().seek(seek);
  }

  Future<void> updatePlaylist(List<PlayerTrack> newPlaylist) async {
    playlist = newPlaylist;
    unShuffledPlaylist = newPlaylist;
    playlistNotifier.value = newPlaylist;
    // await _sendNext();
  }

  Future<void> insertTrack(
    PlayerTrack track,
    int index, {
    bool shuffleFix = true,
  }) async {
    playlist.insert(index, track);
    if (shuffleFix == true) unShuffledPlaylist.insert(index, track);
    playlistNotifier.value = playlist;
    await _sendNext();
  }

  Future<void> moveTrack(PlayerTrack track, int newIndex) async {
    final index = playlist.indexOf(track);
    if (index == -1) return;
    playlist.removeAt(index);
    playlist.insert(newIndex, track);
    playlistNotifier.value = playlist;
    await _sendNext();
  }

  Future<void> removeTrack(
    PlayerTrack track, {
    bool unshuffleRemove = true,
  }) async {
    playlist.remove(track);
    playlistNotifier.value = playlist;
    if (unshuffleRemove) {
      unShuffledPlaylist.remove(track);
    }
    await _sendNext();
  }

  Future<void> addTracks(List<PlayerTrack> tracks, {PlayerTrack? after}) async {
    after ??= nowPlayingTrack;
    int index = playlist.indexOf(after) + 1;
    if (index == -1) return;
    for (PlayerTrack track in tracks) {
      playlist.insert(index, track);
      index += 1;
    }
    playlistNotifier.value = playlist;
    await _sendNext();
  }

  Future<void> playTemporaryQueue(
    List<PlayerTrack> tracks, {
    bool? startsNow,
    bool? first,
  }) async {
    if (tracks.isEmpty) {
      return;
    }
    _createQueue();
    startsNow ??= false;
    if (first == true) {
      for (PlayerTrack track in tracks.reversed) {
        queue.insert(0, track);
      }
    } else {
      queue.addAll(tracks);
    }
    _notifyQueueListeners();
    if (startsNow) {
      await Player.player.playNext(forceNext: true, completed: false);
    }
    return;
  }

  void insertInQueue(PlayerTrack track) {
    _createQueue();
    queue.insert(0, track);
    _notifyQueueListeners();
  }

  void addEndQueue(PlayerTrack track) {
    _createQueue();
    queue.add(track);
    _notifyQueueListeners();
  }

  void _createQueue() {
    if (queue.isEmpty) {
      unQueuedLastTrack = nowPlayingTrack;
    }
  }

  Future<void> playNetTrack(String link, PlayerTrack track) async {
    nowPlayingTrack = track;
    trackNotifier.value = nowPlayingTrack;
    trackChangeNotifier.value = TrackChange(
      newTrack: nowPlayingTrack,
      reason: ChangeReason.external,
    );

    await _PlayerEngine().stop();
    await _PlayerEngine().playNet(link);
    await _afterFn();
  }

  Future<void> enableRepeat() async {
    isRepeat = true;
    repeatModeNotifier.value = true;
  }

  Future<void> removeFromQueue(PlayerTrack track) async {
    // queue.remove(track);
    _notifyQueueListeners();
  }

  Future<void> disableRepeat() async {
    isRepeat = false;
    repeatModeNotifier.value = false;
  }

  void updatePlaylistInfo(PlaylistInfo info) {
    playlistInfo = info;
  }

  Future<List<PlayerTrack>> shuffle(ShuffleMode? shuffleMode1) async {
    _clearQueue();
    shuffleMode1 ??= ShuffleMode.nowOnTop;
    shuffleMode = shuffleMode1;

    if (isShuffle) {
      return playlist;
    }
    final List<PlayerTrack> newPlaylist;
    isShuffle = true;

    if (!playlist.contains(nowPlayingTrack)) {
      isShuffle = true;
      newPlaylist = Shuffles.full(playlist);
    } else {
      switch (shuffleMode1) {
        case ShuffleMode.afterCurrent:
          newPlaylist = Shuffles.afterCurrent(playlist, nowPlayingTrack);
        case ShuffleMode.full:
          newPlaylist = Shuffles.full(playlist);
        case ShuffleMode.nowOnTop:
          newPlaylist = Shuffles.nowOnTop(playlist, nowPlayingTrack);
      }
    }

    playlist = newPlaylist;
    shuffleModeNotifier.value = true;
    playlistNotifier.value = playlist;
    await _sendNext();
    return playlist;
  }

  /// completely
  void _clearQueue() {
    queue.clear();
    unQueuedLastTrack = null;
    _notifyQueueListeners();
  }

  void clearQueue() async {
    queue.clear();
    _notifyQueueListeners();
  }

  void _notifyQueueListeners() async {
    queueNotifier.value = List<PlayerTrack>.from(queue);
    await _sendNext();
  }

  Future<List<PlayerTrack>> unShuffle() async {
    queue.clear();
    isShuffle = false;
    playlist = unShuffledPlaylist;
    shuffleModeNotifier.value = false;
    playlistNotifier.value = playlist;
    await _sendNext();
    return playlist;
  }

  Future<void> playCustom(PlayerTrack track) async {
    if (queue.contains(track)) {
      final int indexOfNPT = queue.indexOf(nowPlayingTrack);
      final int indexOfNext = queue.indexOf(track);
      if (indexOfNPT < indexOfNext) {
        if (indexOfNext != -1) {
          queue.removeRange(indexOfNPT != -1 ? indexOfNPT : 0, indexOfNext);
        }
      }
    } else {
      if (playlist.contains(track)) {
        unQueuedLastTrack = track;
      }
    }
    nowPlayingTrack = track;
    trackNotifier.value = nowPlayingTrack;
    trackChangeNotifier.value = TrackChange(
      newTrack: nowPlayingTrack,
      reason: ChangeReason.external,
    );
    _notifyQueueListeners();
    await _playIsPlaying();
    await _sendNext();
  }

  Future<void> pause() async {
    playingNotifier.value = false;
    await _PlayerEngine().pause();
  }

  Future<void> resume() async {
    playingNotifier.value = true;
    isPlaying = true;
    await _PlayerEngine().resume();
  }

  Future<void> stop() async {
    playingNotifier.value = false;
    await _PlayerEngine().stop();
  }

  Future<void> setSpeed(double sp) async {
    speed = sp;
    await _PlayerEngine().setSpeed(sp);
  }
}

class Shuffles {
  static List<T> nowOnTop<T>(List<T> list, T topValue) {
    list = [...list];
    list.remove(topValue);
    list.shuffle();
    list.insert(0, topValue);
    return list;
  }

  static List<T> full<T>(List<T> list) {
    list = [...list];
    list.shuffle();
    return list;
  }

  static List<T> afterCurrent<T>(List<T> list, T afterValue) {
    list = [...list];
    final currentIndex = list.indexOf(afterValue);
    if (currentIndex == -1) {
      return list;
    }

    final fixedPart = list.sublist(0, currentIndex + 1);
    final queue = list.sublist(currentIndex + 1);
    queue.shuffle();

    return [...fixedPart, ...queue];
  }
}
