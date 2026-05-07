import 'dart:io';
import 'dart:isolate';

import 'package:quark/services/database/library_engine.dart';

import 'settings_engine.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:quark/objects/playlist.dart';
import 'package:quark/services/player/player.dart';

class DatabaseStreamerService {
  static final DatabaseStreamerService _instance =
      DatabaseStreamerService._internal();

  factory DatabaseStreamerService() => _instance;

  DatabaseStreamerService._internal();

  Future<void> init() async {
    await reload();
    _attachSavers();
    _attachListeners();
    Logger('DatabaseStreamerService').fine('Inited');
  }

  final volume = ValueNotifier<double>(0.7);
  final stateIndicator = ValueNotifier<bool>(true);
  final recursiveFilesAdding = ValueNotifier<bool>(true);
  final playlistOpeningArea = ValueNotifier<bool>(false);
  final yandexMusicToken = ValueNotifier<String>('');
  final transitionSpeed = ValueNotifier<double>(1.0);
  final yandexMusicSearch = ValueNotifier<bool>(true);
  final yandexMusicPreload = ValueNotifier<bool>(true);
  final yandexMusicQuality = ValueNotifier<String>('nq');
  final lastTrack = ValueNotifier<String?>(null);
  final lastPlaylist = ValueNotifier<Map<dynamic, dynamic>?>(null);
  final yandexMusicLogin = ValueNotifier<String>('');
  final yandexMusicFullName = ValueNotifier<String>('');
  final yandexMusicDisplayName = ValueNotifier<String>('');
  final yandexMusicUid = ValueNotifier<int?>(null);
  final yandexMusicEmail = ValueNotifier<String>('');
  final yandexMusicTokenExpires = ValueNotifier<int>(0);
  final dbChangeNotifier = ChangeNotifier();
  final gradientMode = ValueNotifier<bool>(false);
  final lastPlaylistState = ValueNotifier<bool>(false);
  final yandexMusicPlaylists = ValueNotifier<List?>(null);
  final lastTrackPosition = ValueNotifier<int>(0);
  final windowManager = ValueNotifier<bool>(false);
  final logListenedTracks = ValueNotifier<bool>(false);
  final dynamicWindowColor = ValueNotifier<bool>(true);
  final originalImageSizeForCoverView = ValueNotifier<bool>(false);
  final playerBackend = ValueNotifier<String>('standart');
  final justAudioPrefetch = ValueNotifier<bool>(false);
  final changePlaylistWhileSelectCategory = ValueNotifier<bool>(false);
  final localApi = ValueNotifier<bool>(false);
  final categories = ValueNotifier<bool>(true);
  late final Listenable all = Listenable.merge([
    volume,
    stateIndicator,
    recursiveFilesAdding,
    playlistOpeningArea,
    yandexMusicToken,
    gradientMode,
    lastPlaylistState,
    yandexMusicPlaylists,
    windowManager,
    logListenedTracks,
    transitionSpeed,
    yandexMusicSearch,
    yandexMusicPreload,
    yandexMusicQuality,
    yandexMusicLogin,
    yandexMusicFullName,
    yandexMusicDisplayName,
    yandexMusicUid,
    yandexMusicEmail,
    playerBackend,
    justAudioPrefetch,
    dynamicWindowColor,
    originalImageSizeForCoverView,
    categories
  ]);

  Future<void> reload() async {
    final allData = await Database.getAll();

    T _get<T>(DatabaseKeys key, T defaultValue) =>
        allData[key.value] as T? ?? defaultValue;

    gradientMode.value = _get(DatabaseKeys.gradientMode, false);
    lastPlaylistState.value = _get(DatabaseKeys.lastPlaylistState, false);
    yandexMusicPlaylists.value =
        allData[DatabaseKeys.yandexMusicPlaylists.value];
    windowManager.value = _get(DatabaseKeys.windowManager, false);
    logListenedTracks.value = _get(DatabaseKeys.logListenedTracks, false);

    volume.value = _get(DatabaseKeys.volume, 0.7);
    stateIndicator.value = _get(DatabaseKeys.stateIndicatorState, true);
    recursiveFilesAdding.value = _get(DatabaseKeys.recursiveFilesAdding, true);
    playlistOpeningArea.value = _get(DatabaseKeys.playlistOpeningArea, false);
    yandexMusicToken.value = _get(DatabaseKeys.yandexMusicToken, '');
    transitionSpeed.value = _get(DatabaseKeys.transitionSpeed, 1.0);
    yandexMusicSearch.value = _get(DatabaseKeys.yandexMusicSearch, true);
    yandexMusicPreload.value = _get(DatabaseKeys.yandexMusicPreload, true);
    yandexMusicQuality.value = _get(DatabaseKeys.yandexMusicTrackQuality, 'nq');

    lastTrack.value = allData[DatabaseKeys.lastTrack.value] as String?;
    lastPlaylist.value =
        allData[DatabaseKeys.lastPlaylist.value] as Map<dynamic, dynamic>?;

    yandexMusicLogin.value = _get(DatabaseKeys.yandexMusicLogin, '');
    yandexMusicFullName.value = _get(DatabaseKeys.yandexMusicFullName, '');
    yandexMusicDisplayName.value = _get(
      DatabaseKeys.yandexMusicDisplayName,
      '',
    );
    yandexMusicUid.value = allData[DatabaseKeys.yandexMusicUid.value] as int?;
    yandexMusicEmail.value = _get(DatabaseKeys.yandexMusicEmail, '');
    yandexMusicTokenExpires.value = _get(
      DatabaseKeys.yandexMusicTokenExpires,
      0,
    );

    lastTrackPosition.value = _get(DatabaseKeys.lastTrackPosition, 0);
    dynamicWindowColor.value = _get(DatabaseKeys.dynamicWindowColor, true);
    originalImageSizeForCoverView.value = _get(
      DatabaseKeys.originalImageSizeCoverView,
      false,
    );
    playerBackend.value = _get(DatabaseKeys.playerBackend, "standart");
    justAudioPrefetch.value = _get(DatabaseKeys.justAudioPrefetch, false);
    changePlaylistWhileSelectCategory.value = _get(
      DatabaseKeys.changePlaylistWhileSelectCategory,
      false,
    );
    localApi.value = _get(DatabaseKeys.localApi, false);
    categories.value = _get(DatabaseKeys.playlistCategories, true);
  }

  Future<void> reset() async {
    await Database.clear();
    await reload();
  }

  void _attachSavers() {
    if (!Database.isInited) {
      Logger(
        'DatabaseStreamerService',
      ).warning('DB not available, changes will not be persisted.');
      return;
    }
    void bind<T>(ValueNotifier<T> notifier, DatabaseKeys key) async {
      notifier.addListener(() async {
        // print("Saving ${key.value} - ${notifier.value}");
        Database.put(key.value, notifier.value);
      });
    }

    bind(gradientMode, DatabaseKeys.gradientMode);
    bind(lastPlaylistState, DatabaseKeys.lastPlaylistState);
    bind(yandexMusicPlaylists, DatabaseKeys.yandexMusicPlaylists);
    bind(windowManager, DatabaseKeys.windowManager);
    bind(logListenedTracks, DatabaseKeys.logListenedTracks);
    bind(volume, DatabaseKeys.volume);
    bind(stateIndicator, DatabaseKeys.stateIndicatorState);
    bind(recursiveFilesAdding, DatabaseKeys.recursiveFilesAdding);
    bind(playlistOpeningArea, DatabaseKeys.playlistOpeningArea);
    bind(yandexMusicToken, DatabaseKeys.yandexMusicToken);
    bind(transitionSpeed, DatabaseKeys.transitionSpeed);
    bind(yandexMusicSearch, DatabaseKeys.yandexMusicSearch);
    bind(yandexMusicPreload, DatabaseKeys.yandexMusicPreload);
    bind(yandexMusicQuality, DatabaseKeys.yandexMusicTrackQuality);
    bind(yandexMusicLogin, DatabaseKeys.yandexMusicLogin);
    bind(yandexMusicFullName, DatabaseKeys.yandexMusicFullName);
    bind(lastTrack, DatabaseKeys.lastTrack);
    bind(lastPlaylist, DatabaseKeys.lastPlaylist);
    bind(yandexMusicTokenExpires, DatabaseKeys.yandexMusicTokenExpires);
    bind(yandexMusicDisplayName, DatabaseKeys.yandexMusicDisplayName);
    bind(yandexMusicUid, DatabaseKeys.yandexMusicUid);
    bind(yandexMusicEmail, DatabaseKeys.yandexMusicEmail);
    bind(lastTrackPosition, DatabaseKeys.lastTrackPosition);
    bind(dynamicWindowColor, DatabaseKeys.dynamicWindowColor);
    bind(
      changePlaylistWhileSelectCategory,
      DatabaseKeys.changePlaylistWhileSelectCategory,
    );
    bind(
      originalImageSizeForCoverView,
      DatabaseKeys.originalImageSizeCoverView,
    );
    bind(localApi, DatabaseKeys.localApi);
    bind(categories, DatabaseKeys.playlistCategories);
    bind(playerBackend, DatabaseKeys.playerBackend);
  }

  void _attachListeners() {
    Player.player.volumeNotifier.addListener(
      () => volume.value = Player.player.volumeNotifier.value,
    );
  }
}

class DatabaseSaver {
  static final DatabaseSaver _instance = DatabaseSaver._internal();

  factory DatabaseSaver() => _instance;

  DatabaseSaver._internal();

  late final VoidCallback _trackListener;
  late final VoidCallback _playlistListener;

  void init() async {
    _trackListener = () async {
      saveLastTrack();
    };
    _playlistListener = () async {
      if (Player.player.shuffleModeNotifier.value == true) {
        return;
      }
      updateDatabasePlaylist();
    };

    Player.player.playlistNotifier.addListener(_playlistListener);
    Player.player.trackChangeNotifier.addListener(_trackListener);
    _LastTrackPositionSaver().init();
    Logger('DatabaseSaverService').fine('Inited');
  }

  void dispose() {
    Player.player.playlistNotifier.removeListener(_playlistListener);
    Player.player.trackChangeNotifier.removeListener(_trackListener);
  }

  Future<void> saveLastTrack() async {
    DatabaseStreamerService().lastTrack.value =
        Player.player.nowPlayingTrack.filepath;
  }

  Future<void> updateDatabasePlaylist() async {
    if (Player.player.playlist.isEmpty) return;
    PlayerPlaylist pl = PlayerPlaylist(
      ownerUid: Player.player.playlistInfo.ownerUid,
      kind: Player.player.playlistInfo.kind,
      name: Player.player.playlistInfo.name,
      tracks: Player.player.unShuffledPlaylist,
      source: Player.player.playlistInfo.source,
    );
    Map play = await Isolate.run(() => serializePlaylist(pl));
    DatabaseStreamerService().lastPlaylist.value = play;
    AppDatabase().saveTracks(Player.player.playlist);
  }
}

class _LastTrackPositionSaver {
  static final _LastTrackPositionSaver _instance =
      _LastTrackPositionSaver._internal();
  factory _LastTrackPositionSaver() => _instance;
  _LastTrackPositionSaver._internal();

  int _lastSavedSeconds = 0;
  DateTime _lastSaved = DateTime.now();

  void init() {
    Player.player.playedNotifier.addListener(_playedListener);
  }

  void dispose() {
    Player.player.playedNotifier.removeListener(_playedListener);
  }

  final Duration _timeThreshold = const Duration(seconds: 2);
  void _saveLastPosition() {
    final timeDiff = DateTime.now().difference(_lastSaved);
    if (timeDiff < _timeThreshold) return;
    DatabaseStreamerService().lastTrackPosition.value =
        Player.player.playedNotifier.value.inSeconds;
  }

  int _lastCountedSecond = 0;
  int _totalPlayedSeconds = 0;
  Duration _lastPosition = Duration.zero;
  static const int _seekThreshold = 2;

  void _playedListener() async {
    Duration currentPosition = Player.player.playedNotifier.value;
    int currentSecond = currentPosition.inSeconds;

    int diff = currentSecond - _lastCountedSecond;

    if (diff > 0 && diff <= _seekThreshold) {
      _totalPlayedSeconds += diff;
      _lastCountedSecond = currentSecond;
      if (_totalPlayedSeconds - _lastSavedSeconds > 15) {
        _saveLastPosition();
        _lastSavedSeconds = _totalPlayedSeconds;
      }
    } else if (diff > _seekThreshold || diff < 0) {
      _lastCountedSecond = currentSecond;
    }

    _lastPosition = currentPosition;
  }
}
