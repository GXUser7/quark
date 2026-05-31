import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

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

  final ValueNotifier<Locale?> _appLocale = ValueNotifier<Locale?>(null);
  ValueNotifier<Locale?> get appLocale => _appLocale;
  ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.dark);

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
  final accessToken = ValueNotifier<String>('');
  final refreshToken = ValueNotifier<String>('');
  final vkMusicToken = ValueNotifier<String>('');
  final isLoggedIn = ValueNotifier<bool>(false);
  final scOauthToken = ValueNotifier<String>('');
  final scProfileUrl = ValueNotifier<String>('');
  final spotifySearch = ValueNotifier<bool>(true);
  final spotifyQuality = ValueNotifier<String>('lossless');
  final spotifySourcePriority = ValueNotifier<String>('gdstudio');
  final spotifyOauthToken = ValueNotifier<String>('');
  final spotifyRefreshToken = ValueNotifier<String>('');
  final spotifyLoggedIn = ValueNotifier<bool>(false);

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
    accessToken,
    refreshToken,
    vkMusicToken,
    isLoggedIn,
    scOauthToken,
    scProfileUrl,
    spotifySearch,
    spotifyQuality,
    spotifySourcePriority,
    spotifyOauthToken,
    spotifyRefreshToken,
    spotifyLoggedIn,
  ]);

  Future<void> reload() async {
    final lp = await Database.get(DatabaseKeys.lastPlaylist.value);
    lastPlaylist.value = lp;
    final v = await Database.get(DatabaseKeys.volume.value);
    final s = await Database.get(DatabaseKeys.stateIndicatorState.value);
    final poa = await Database.get(DatabaseKeys.playlistOpeningArea.value);
    final ymt = await Database.get(DatabaseKeys.yandexMusicToken.value);
    final ts = await Database.get(DatabaseKeys.transitionSpeed.value);
    final yms = await Database.get(DatabaseKeys.yandexMusicSearch.value);
    final ymq = await Database.get(DatabaseKeys.yandexMusicTrackQuality.value);
    final rfs = await Database.get(DatabaseKeys.recursiveFilesAdding.value);
    final ymp = await Database.get(DatabaseKeys.yandexMusicPreload.value);
    final lt = await Database.get(DatabaseKeys.lastTrack.value);
    final yml = await Database.get(DatabaseKeys.yandexMusicLogin.value);
    final ymfn = await Database.get(DatabaseKeys.yandexMusicFullName.value);
    final ymdn = await Database.get(DatabaseKeys.yandexMusicDisplayName.value);
    final ymuid = await Database.get(DatabaseKeys.yandexMusicUid.value);
    final yme = await Database.get(DatabaseKeys.yandexMusicEmail.value);
    final tE = await Database.get(DatabaseKeys.yandexMusicTokenExpires.value);
    final gm = await Database.get(DatabaseKeys.gradientMode.value);
    final lps = await Database.get(DatabaseKeys.lastPlaylistState.value);
    final ymp2 = await Database.get(DatabaseKeys.yandexMusicPlaylists.value);
    final wm = await Database.get(DatabaseKeys.windowManager.value);
    final llt = await Database.get(DatabaseKeys.logListenedTracks.value);
    final ltp = await Database.get(DatabaseKeys.lastTrackPosition.value);
    final dwc = await Database.get(DatabaseKeys.dynamicWindowColor.value);
    final oisfc = await Database.get(
      DatabaseKeys.originalImageSizeCoverView.value,
    );
    final pb = await Database.get(DatabaseKeys.playerBackend.value);
    final jp = await Database.get(DatabaseKeys.justAudioPrefetch.value);
    final cpwsc = await Database.get(
      DatabaseKeys.changePlaylistWhileSelectCategory.value,
    );
    final at = await Database.get(DatabaseKeys.accessToken.value);
    final rt = await Database.get(DatabaseKeys.refreshToken.value);
    final vkt = await Database.get(DatabaseKeys.vkMusicToken.value);
    final ili = await Database.get(DatabaseKeys.isLoggedIn.value);
    final sco = await Database.get(DatabaseKeys.scOauthToken.value);
    final scu = await Database.get(DatabaseKeys.scProfileUrl.value);
    final sps = await Database.get(DatabaseKeys.spotifySearch.value);
    final spq = await Database.get(DatabaseKeys.spotifyQuality.value);
    final spp = await Database.get(DatabaseKeys.spotifySourcePriority.value);
    final spot = await Database.get(DatabaseKeys.spotifyOauthToken.value);
    final sprt = await Database.get(DatabaseKeys.spotifyRefreshToken.value);
    final spl = await Database.get(DatabaseKeys.spotifyLoggedIn.value);

    gradientMode.value = gm ?? false;
    lastPlaylistState.value = lps ?? false;
    yandexMusicPlaylists.value = ymp2;
    windowManager.value = wm ?? false;
    logListenedTracks.value = llt ?? false;
    yandexMusicLogin.value = yml ?? '';
    yandexMusicFullName.value = ymfn ?? '';
    yandexMusicDisplayName.value = ymdn ?? '';
    yandexMusicUid.value = ymuid;
    yandexMusicEmail.value = yme ?? '';
    volume.value = v ?? 0.7;
    stateIndicator.value = s ?? true;
    recursiveFilesAdding.value = rfs ?? true;
    playlistOpeningArea.value = poa ?? false;
    yandexMusicToken.value = ymt ?? '';
    transitionSpeed.value = ts ?? 1.0;
    yandexMusicSearch.value = yms ?? true;
    yandexMusicPreload.value = ymp ?? true;
    yandexMusicQuality.value = ymq ?? 'nq';
    lastTrack.value = lt;
    yandexMusicTokenExpires.value = tE ?? 0;
    lastTrackPosition.value = ltp ?? 0;
    dynamicWindowColor.value = dwc ?? true;
    originalImageSizeForCoverView.value = oisfc ?? false;
    playerBackend.value = pb ?? "standart";
    justAudioPrefetch.value = jp ?? false;
    changePlaylistWhileSelectCategory.value = cpwsc ?? false;
    accessToken.value = at ?? '';
    refreshToken.value = rt ?? '';
    vkMusicToken.value = vkt ?? '';
    isLoggedIn.value = ili ?? false;
    scOauthToken.value = sco ?? '';
    scProfileUrl.value = scu ?? '';
    spotifySearch.value = sps ?? true;
    spotifyQuality.value = spq ?? 'lossless';
    spotifySourcePriority.value = spp ?? 'gdstudio';
    spotifyOauthToken.value = spot ?? '';
    spotifyRefreshToken.value = sprt ?? '';
    spotifyLoggedIn.value = spl ?? false;

    await Player.player.setVolume(Platform.isAndroid ? 1.0 : volume.value);
  }

  Future<void> reset() async {
    await Database.clear();
    await reload();
  }

  Future<void> setAppLocale(Locale locale) async {
    _appLocale.value = locale;
  }

  Locale? getAppLocale() => _appLocale.value;

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
        await Database.put(key.value, notifier.value);
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
    bind(accessToken, DatabaseKeys.accessToken);
    bind(refreshToken, DatabaseKeys.refreshToken);
    bind(vkMusicToken, DatabaseKeys.vkMusicToken);
    bind(isLoggedIn, DatabaseKeys.isLoggedIn);
    bind(scOauthToken, DatabaseKeys.scOauthToken);
    bind(scProfileUrl, DatabaseKeys.scProfileUrl);
    bind(spotifySearch, DatabaseKeys.spotifySearch);
    bind(spotifyQuality, DatabaseKeys.spotifyQuality);
    bind(spotifySourcePriority, DatabaseKeys.spotifySourcePriority);
    bind(spotifyOauthToken, DatabaseKeys.spotifyOauthToken);
    bind(spotifyRefreshToken, DatabaseKeys.spotifyRefreshToken);
    bind(spotifyLoggedIn, DatabaseKeys.spotifyLoggedIn);
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
      await saveLastTrack();
    };
    _playlistListener = () async {
      if (Player.player.shuffleModeNotifier.value == true) {
        return;
      }
      await updateDatabasePlaylist();
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
    PlayerPlaylist pl = PlayerPlaylist(
      ownerUid: Player.player.playlistInfo.ownerUid,
      kind: Player.player.playlistInfo.kind,
      name: Player.player.playlistInfo.name,
      tracks: Player.player.unShuffledPlaylist,
      source: Player.player.playlistInfo.source,
    );
    Map play = await Isolate.run(() => serializePlaylist(pl));
    DatabaseStreamerService().lastPlaylist.value = play;
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
