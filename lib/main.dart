// Flutter & Dart
import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
// Additional packages
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:file_picker/file_picker.dart';
import 'package:quark/services/database/database.dart';
import 'package:audio_service_mpris/audio_service_mpris.dart';
import 'package:quark/services/database/library_engine.dart';
import 'package:quark/services/database/library_engine.dart' as db;
import 'package:quark/services/database/listen_logger.dart';
import 'package:quark/services/dynamic_window_color_linux.dart';
import 'package:quark/services/playlist_sync_services.dart';
import 'package:quark/services/vkmusic_services.dart';
import 'package:quark/services/ytmusic_services.dart';
import 'package:quark/widgets/main_page_platlists.dart';
import 'package:quark/widgets/multi_search.dart';
import 'package:quark/widgets/new_widgets.dart';
import 'package:quark/widgets/players_widgets/drag_and_drop.dart';
import 'package:quark/widgets/players_widgets/drag_test.dart';
import 'package:quark/widgets/players_widgets/gnome_like_widgets.dart';
import 'package:quark/widgets/soundcloud_integration/soundcloud_playlists_widget.dart';
import 'package:quark/widgets/vkmusic_integration/vk_login.dart';
import 'package:quark/widgets/vkmusic_integration/vkmusic_playlist_widget.dart';
import 'package:quark/widgets/yandex_music_integration/yandex_widgets.dart';
import 'package:cross_file/cross_file.dart';
import 'package:quark/widgets/ytmusic_integration/ytmusic_playlist_widget.dart';

// Local files
import '/objects/track.dart';
import '/services/files.dart';
import '/widgets/settings.dart';
import '/objects/playlist.dart';
import '/playlist_page_router.dart';
import '/services/player/player.dart';
import 'services/database/settings_engine.dart';
import '/services/yandex_music_singleton.dart';
import '/services/native_controls/native_control.dart';
import '/widgets/yandex_music_integration/yandex_login.dart';
import '/widgets/yandex_music_integration/yandex_playlists_widget.dart';
import '/widgets/auth.dart';
import 'package:quark/services/auth_services.dart';
import 'package:quark/widgets/multi_search.dart';

// TODO: fix bug while closing playtlist with iconbutton then if playlist was opened by mouseArea it wont close
// TODO: Lister logger migration
// TODO: REMOVE SETSTATE FROM BUILD METHODS

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApplicationCacheDirectory.instance.init();
  Hive.init(ApplicationCacheDirectory.instance.directory.path);
  Database.init();
  Player.player.init();
  NativeControl().init();
  AudioServiceMpris.registerWith();
  DatabaseStreamerService().init();
  DynamicWindowColor.init();
  await AuthService().init();
  runApp(const Quark());
}

class Quark extends StatelessWidget {
  const Quark({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool inited = false;
  String? lastTrackPath;
  bool loginView = false;
  bool playlistView = false;
  bool settingsView = false;
  bool dragAndDropView = false;
  bool soundCloudView = false;
  PlayerPlaylist? lastPlaylist;
  final log = Logger('MainPage');
  bool hasLatestPlaylist = false;
  List<PlaylistWShortTracks> userPlaylists = [];
  YandexMusic yandexMusic = YandexMusic(token: '');
  List<XFile> _cookieFiles = [];
  late final path = _cookieFiles.first.path;
  final GlobalKey<LocalPlaylistsSectionState> _playlistsKey = GlobalKey();

  bool localPlaylistView = false;
  List<LocalPlaylistAbout> localPlaylists = [];

  Future<void> openLocalPlaylists() async {
    final raw = await AppDatabase().getAllPlaylistsWithTracks();
    final mapped = raw
        .map((e) => LocalPlaylistAbout.getFromDatabase(e))
        .toList();
    setState(() {
      localPlaylists = mapped;
      localPlaylistView = true;
    });
  }

  /// Reacting on pick folder button
  Future<void> pickFolder() async {
    try {
      print('FilePicker registered: ${FilePicker.platform.runtimeType}');

      final bool rfa = DatabaseStreamerService().recursiveFilesAdding.value;
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        List<PlayerTrack> result = await Files().getFilesFromDirectory(
          directoryPath: selectedDirectory,
          recursiveEnable: rfa,
        );
        if (result.isNotEmpty) {
          playlistRoute(
            PlayerPlaylist(
              kind: 0,
              ownerUid: 0,
              name: "Local",
              tracks: result,
              source: PlaylistSource.local,
            ),
          );
          final stopwatch = Stopwatch()..start();
          await AppDatabase().saveTracks(result);
          stopwatch.stop();

          print('Время выполнения: ${stopwatch.elapsedMilliseconds} мс');
          print('Время выполнения: ${stopwatch.elapsedMicroseconds} мкс');
        }
      }
    } catch (e) {
      log.shout('Unexcepted error while pickFolder()', e);
    }
  }

  /// Reacting on close login button
  Future<void> closeLogin([bool? openPlaylists]) async {
    setState(() {
      loginView = false;
      ymUpdate();
      playlistView = true;
    });
  }

  /// Reacting on close playlist button
  Future<void> closePlaylist([bool? openPlaylists]) async {
    setState(() {
      playlistView = false;
    });
  }

  /// Reacting on close settings button
  Future<void> closeSettings() async {
    setState(() {
      settingsView = false;
    });
  }

  /// Reacting on close dragAndDrop button
  Future<void> closeCookieDragAndDrop() async {
    setState(() {
      dragAndDropView = false;
    });
  }

  /// Routing to playlist page
  Future<void> playlistRoute(PlayerPlaylist playlist) async {
    final stopwatch = Stopwatch()..start();
    lastPlaylist = playlist;
    print("------------------------------ UPDATING PLAYLIST INFO");
    Player.player.updatePlaylistInfo(PlaylistInfo.fromPlayerPlaylist(playlist));
    Player.player.updatePlaylist(playlist.tracks);
    print("------------------------------ SEARCHING LAST TRAACK");

    PlayerTrack? foundTrack;
    if (lastTrackPath != null) {
      for (final track in playlist.tracks) {
        if (track.filepath == lastTrackPath) {
          foundTrack = track;
          break;
        }
      }
    }

    final trackToPlay = foundTrack ?? playlist.tracks[0];

    print(
      "------------------------------ PLAYING CUSTOM - ${trackToPlay.filepath}",
    );
    Player.player.pause();
    Player.player.playCustom(trackToPlay);
    print("------------------------------ SEEKING");
    if (foundTrack != null) {
      if (Duration(seconds: DatabaseStreamerService().lastTrackPosition.value) <
          Player.player.durationNotifier.value) {
        await Player.player.seek(
          Duration(seconds: DatabaseStreamerService().lastTrackPosition.value),
        );
      }
    }

    print(
      '------------------------------ GETTING READY COSTS ${stopwatch.elapsedMilliseconds} ms',
    );
    print("------------------------------ PUSHING INTO");
    stopwatch.stop();
    Navigator.push(
      context,
      CupertinoPageRoute(
        settings: RouteSettings(name: "/player"),
        builder: (context) =>
            PlaylistPage(playlist: playlist, yandexMusic: yandexMusic),
      ),
    );
    print("------------------------------ PUSHED");
  }

  /// Reaction on playlist restore button
  Future<void> playlistRestore() async {
    String token = DatabaseStreamerService().yandexMusicToken.value;
    if (lastPlaylist == null) {
      return;
    }
    bool inited = await yandexMusic.checkInit();
    if (!inited) {
      yandexMusic = YandexMusic(token: token);
    }

    playlistRoute(lastPlaylist!);
  }

  /// Update playlists from yandex music
  Future<void> ymUpdate() async {
    if (inited && userPlaylists.isNotEmpty) {
      setState(() {
        playlistView = true;
      });
      return;
    }
    try {
      if (!inited) {
        String token = DatabaseStreamerService().yandexMusicToken.value;

        if (token == '') {
          setState(() {
            loginView = true;
          });
          return;
        }

        yandexMusic = YandexMusic(token: token);
        log.warning('Trying to initialize yandex music instance...');

        await yandexMusic.init();
        inited = true;
        YandexMusicSingleton.init(yandexMusic);
      }

      if (userPlaylists.isEmpty) {
        yandexMusic.usertracks.getPlaylistsWithLikes().then((playlists) async {
          setState(() {
            userPlaylists = playlists;
            playlistView = true;
          });
        });
      } else {
        setState(() {
          playlistView = true;
        });
      }
    } on YandexMusicException catch (e) {
      switch (e.type) {
        case YandexMusicException.unauthorized:
          log.warning(
            'Yandex Music initizalization failed. Redirecting to login widget...',
          );
          setState(() {
            loginView = true;
          });
        default:
          log.shout('Unexcepted error while ymUpdate()', e);
          return;
      }
    }
  }

  Future<void> _onYTMusicPlaylistSelected(PlayerPlaylist playlist) async {
    try {
      Player.player.updatePlaylistInfo(
        PlaylistInfo(
          kind: 0,
          source: PlaylistSource.ytmusic,
          name: playlist.name,
        ),
      );
      await Player.player.updatePlaylist(playlist.tracks);

      if (playlist.tracks.isNotEmpty) {
        await Player.player.playCustom(playlist.tracks.first);
      }

      if (!mounted) return;
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) =>
              PlaylistPage(playlist: playlist, yandexMusic: yandexMusic),
        ),
      );
    } catch (e) {
      Logger('MainPage').severe('YTMusic playlist error: $e');
    }
  }

  Future<void> _onVkMusicPlaylistSelected(PlayerPlaylist playlist) async {
    try {
      Player.player.updatePlaylistInfo(
        PlaylistInfo(
          kind: 0,
          source: PlaylistSource.vkmusic,
          name: playlist.name,
        ),
      );

      await Player.player.updatePlaylist(playlist.tracks);

      if (playlist.tracks.isNotEmpty) {
        await Player.player.playCustom(playlist.tracks.first);
      }
      if (!mounted) return;
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) =>
              PlaylistPage(playlist: playlist, yandexMusic: yandexMusic),
        ),
      );
    } catch (e) {
      Logger('MainPage').severe('VKMusic playlist error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки плейлиста: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _onSoundCloudPlaylistSelected(PlayerPlaylist playlist) async {
    try {
      Player.player.updatePlaylistInfo(
        PlaylistInfo(
          kind: 0,
          source: PlaylistSource.local,
          name: playlist.name,
        ),
      );
      await Player.player.updatePlaylist(playlist.tracks);
      if (playlist.tracks.isNotEmpty) {
        await Player.player.playCustom(playlist.tracks.first);
      }
      if (!mounted) return;
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) =>
              PlaylistPage(playlist: playlist, yandexMusic: yandexMusic),
        ),
      );
    } catch (e) {
      Logger('MainPage').severe('SoundCloud playlist error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки плейлиста: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> restoreLast() async {
    if (!mounted) return;

    final playlist = DatabaseStreamerService().lastPlaylist.value;
    if (playlist != null && !hasLatestPlaylist) {
      setState(() => hasLatestPlaylist = true);
    }

    lastTrackPath = DatabaseStreamerService().lastTrack.value;

    if (playlist != null) {
      final ls = await deserializePlaylist(playlist.cast<String, dynamic>());
      if (!mounted) return;
      setState(() => lastPlaylist = ls);
    }
  }

  void _onDatabaseChanged() async {
    await restoreLast();
  }

  void addDatabaseListeners() {
    DatabaseStreamerService().yandexMusicToken.addListener(_ymListener);
    DatabaseStreamerService().lastTrack.addListener(_onDatabaseChanged);
    DatabaseStreamerService().lastPlaylist.addListener(_onDatabaseChanged);
  }

  void removeDatabaseListeners() {
    DatabaseStreamerService().lastTrack.removeListener(_onDatabaseChanged);
    DatabaseStreamerService().lastPlaylist.removeListener(_onDatabaseChanged);
  }

  void _ymListener() async {
    final token = DatabaseStreamerService().yandexMusicToken.value;
    if (token.isNotEmpty) {
      await _initYM(token);
    }
  }

  Future<void> _initYM(String token) async {
    if (inited) return;
    try {
      log.info('Initializing Yandex Music...');
      yandexMusic = YandexMusic(token: token);

      if (AuthService().isLoggedIn) {
        await AuthService().saveYandexToken(token);
      } else {
        print('NOT logged in, skipping saveYandexToken');
        print('accessToken: ${AuthService().accessToken}');
      }

      await yandexMusic.init();
      if (!mounted) return;
      setState(() => inited = true);
      YandexMusicSingleton.init(yandexMusic);
      log.fine('Yandex Music initialized successfully.');
      if (DatabaseStreamerService().yandexMusicPreload.value) {
        unawaited(_playlistPreload());
      }
    } on YandexMusicException {
      log.warning('Yandex Music initialization failed.');
      inited = false;
    }
  }

  Future<void> _playlistPreload() async {
    try {
      final playlists = await yandexMusic.usertracks.getPlaylistsWithLikes();
      if (!mounted) return;
      setState(() => userPlaylists = playlists);
    } catch (e) {
      log.shout('Preload playlists failed', e);
    }
  }

  Future<void> _databaseBootStrap() async {
    await DatabaseStreamerService().init();
    addDatabaseListeners();
    final token = DatabaseStreamerService().yandexMusicToken.value;

    await restoreLast();
    if (token.isNotEmpty) {
      await _initYM(token);
    }

    if (AuthService().isLoggedIn) {
      unawaited(_syncPlaylists());
    }
  }

  Future<void> _syncPlaylists() async {
    try {
      await PlaylistSyncService().downloadAndSave();
      await PlaylistSyncService().uploadAll();
      if (mounted) {
        _playlistsKey.currentState?.reload();
        setState(() {});
      }
    } catch (e) {
      log.warning('Playlist sync failed: $e');
    }
  }

  @override
  void activate() {
    restoreLast();
    addDatabaseListeners();
    super.activate();
  }

  @override
  void deactivate() {
    removeDatabaseListeners();
    super.deactivate();
  }

  @override
  void dispose() {
    removeDatabaseListeners();
    super.dispose();
  }

  Future<void> initLogger() async {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print(
        '${record.loggerName} || ${record.level.name}: ${record.message} || ${record.error != null ? 'Error: ${record.error}' : ''}',
      );
      if (record.stackTrace != null) print(record.stackTrace);
    });
    log.finest('Hello world!');
  }

  @override
  void initState() {
    super.initState();
    initLogger();
    _databaseBootStrap();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Material(
      child: Stack(
        children: [
          Center(
            child: Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(color: Color.fromRGBO(24, 24, 26, 1)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/icon512.png', height: 150, width: 150),
                  const SizedBox(height: 15),
                  const Text(
                    'quark: where sound begins',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      decoration: TextDecoration.none,
                      fontFamily: 'noto',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const SizedBox(
                    width: 400,
                    child: Text(
                      'Select the folder with tracks. \nYou can also link your streaming account to use it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,

                        fontSize: 16,
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.normal,
                        fontFamily: 'noto',
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // GnomeTile(
                      //   onTap: () async {
                      //     final confirm = await showDialog<bool>(
                      //       context: context,
                      //       builder: (ctx) => AlertDialog(
                      //         backgroundColor: const Color(0xFF1C1C1E),
                      //         title: const Text(
                      //           'Delete all playlists?',
                      //           style: TextStyle(color: Colors.white),
                      //         ),
                      //         content: const Text(
                      //           'This will permanently delete all local playlists and their tracks.',
                      //           style: TextStyle(color: Colors.white70),
                      //         ),
                      //         actions: [
                      //           TextButton(
                      //             onPressed: () => Navigator.pop(ctx, false),
                      //             child: const Text(
                      //               'Cancel',
                      //               style: TextStyle(color: Colors.white54),
                      //             ),
                      //           ),
                      //           TextButton(
                      //             onPressed: () => Navigator.pop(ctx, true),
                      //             child: const Text(
                      //               'Delete',
                      //               style: TextStyle(color: Colors.redAccent),
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //     );

                      //     if (confirm != true) return;

                      //     final raw = await AppDatabase()
                      //         .getAllPlaylistsWithTracks();
                      //     for (final p in raw) {
                      //       await AppDatabase().deletePlaylist(p.playlist.id);
                      //     }
                      //     setState(() {});
                      //   },
                      //   label: 'Delete all',
                      //   icon: Icons.delete_forever,
                      //   color: const Color(0xFF8B0000),
                      // ),
                      if (lastPlaylist != null)
                        Row(
                          children: [
                            GnomeTile(
                              onTap: () async => playlistRestore(),
                              label: "Restore playlist",
                              icon: Icons.restore_rounded,
                            ),
                          ],
                        ),

                      GnomeTile(
                        onTap: () async => await {pickFolder()},
                        label: "Pick folder",
                        icon: Icons.folder,
                      ),

                      GnomeTile(
                        onTap: () async => await ymUpdate(),
                        label: "Yandex Music",
                        iconWidget: Image.asset(
                          'assets/ym_w_alt.png',
                          width: 30,
                          height: 30,
                        ),
                      ),

                      GnomeTile(
                        onTap: () async => {
                          setState(() {
                            dragAndDropView = true;
                          }),
                        },
                        label: "YouTube Music",
                        iconWidget: Image.asset(
                          'assets/y_w_alt.png',
                          width: 30,
                          height: 30,
                        ),
                      ),

                      // VKMUSIC
                      GnomeTile(
                        // onTap: () => AuthService().loginVk(
                        //   "+79876081986",
                        //   "LBSAgKZ64d7piGzybAaJgP",
                        // ),
                        onTap: () async => {
                          await Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => VkAuthPage(
                                onTokenReceived: (token) async {
                                  try {
                                    await AuthService().saveVkToken(token);
                                  } catch (e) {
                                    print('err: $e');
                                  }
                                },
                              ),
                              // builder: (_) => VkMusicPlaylists(
                              //   closeView: () => Navigator.pop(context),
                              //   playlistRouter: (playlist) => _onVkMusicPlaylistSelected(playlist),
                              // ),
                            ),
                          ),
                        },
                        label: "VK Music",
                        iconWidget: Image.asset(
                          'assets/vk_w_alt.png',
                          width: 30,
                          height: 30,
                        ),
                      ),
                      GnomeTile(
                        onTap: () async {
                          setState(() => soundCloudView = true);
                        },
                        label: "Sound Cloud",
                        iconWidget: Image.asset(
                          'assets/soundcloud_w.png',
                          width: 37,
                          height: 37,
                        ),
                      ),
                      GnomeTile(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => MusicSearchWidget(
                                onTracksChosen:
                                    (tracks, {newPlaylistName, playlist}) =>
                                        _handleTracksChosen(
                                          tracks,
                                          playlist: playlist,
                                          newPlaylistName: newPlaylistName,
                                        ),
                              ),
                            ),
                          );
                          _playlistsKey.currentState?.reload();
                        },
                        label: "Search",
                        icon: Icons.search,
                      ),
                    ],
                  ),

                  LocalPlaylistsSection(
                    key: _playlistsKey,
                    playlistRoute: playlistRoute,
                  ),
                ],
              ),
            ),
          ),

          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: loginView
                ? GestureDetector(
                    onTap: () => setState(() {
                      // if (Platform.isLinux) {
                      // loginView = false;
                      // }
                    }),
                    child: Container(
                      key: ValueKey('login'),
                      color: Colors.black.withAlpha(25),
                      child: Stack(
                        children: [
                          YandexLogin(closeView: closeLogin),
                          Positioned(
                            right: Platform.isAndroid ? 15 : 0,
                            top: Platform.isAndroid ? 15 : 0,
                            child: IconButton(
                              onPressed: () =>
                                  setState(() => loginView = false),
                              icon: Icon(Icons.close, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox.shrink(key: ValueKey('empty')),
          ),

          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: playlistView
                ? GestureDetector(
                    onTap: () => setState(() => playlistView = false),
                    child: Container(
                      key: ValueKey('playlist'),
                      color: Colors.black.withAlpha(25),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () {},
                            child: YandexPlaylists(
                              closeView: closePlaylist,
                              yandexMusic: yandexMusic,
                              // playlists: userPlaylists,
                              playlistRouter: playlistRoute,
                            ),
                          ),
                          Positioned(
                            right: Platform.isAndroid ? 15 : 5,
                            top: Platform.isAndroid ? 15 : 5,
                            child: IconButton(
                              onPressed: () =>
                                  setState(() => playlistView = false),
                              icon: Icon(Icons.close, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox.shrink(key: ValueKey('empty')),
          ),

          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: settingsView
                ? GestureDetector(
                    onTap: () => setState(() => settingsView = false),
                    child: Container(
                      color: Colors.black.withAlpha(25),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () {},
                            child: Settings(closeView: closeSettings),
                          ),
                          Positioned(
                            right: Platform.isAndroid ? 15 : 5,
                            top: Platform.isAndroid ? 20 : 10,
                            child: IconButton(
                              onPressed: () =>
                                  setState(() => settingsView = false),
                              icon: Icon(Icons.close, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox.shrink(key: ValueKey('empty')),
          ),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: soundCloudView
                ? GestureDetector(
                    onTap: () => setState(() => soundCloudView = false),
                    child: Container(
                      color: Colors.black.withAlpha(25),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () {},
                            child: SoundCloudPlaylistsWidget(
                              closeView: () {},
                              playlistRouter: _onSoundCloudPlaylistSelected,
                            ),
                          ),
                          Positioned(
                            right: Platform.isAndroid ? 15 : 5,
                            top: Platform.isAndroid ? 15 : 5,
                            child: IconButton(
                              onPressed: () =>
                                  setState(() => soundCloudView = false),
                              icon: Icon(Icons.close, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox.shrink(),
          ),

          // TO AUTH BUTTON
          Positioned(
            right: Platform.isAndroid ? 55 : 45,
            top: Platform.isAndroid ? 15 : 10,
            child: SizedBox(
              width: 100,
              height: 35,
              child: GnomeStyleAuthButton(
                isLoggedIn: AuthService().isLoggedIn,
                onTap: () async {
                  if (!AuthService().isLoggedIn) {
                    await Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => AuthPage()),
                    );
                    if (AuthService().isLoggedIn) {
                      unawaited(_syncPlaylists());
                    }
                  } else {
                    await AuthService().logout();
                  }
                  setState(() {});
                },
              ),
            ),
          ),

          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: dragAndDropView
                ? GestureDetector(
                    onTap: () => setState(() => dragAndDropView = false),
                    child: Container(
                      color: Colors.black.withAlpha(25),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () {},
                            child: _cookieFiles.isEmpty
                                ? GlassDropZone(
                                    closeView: closeCookieDragAndDrop,
                                    onFileDropped: (files) {
                                      setState(() => _cookieFiles = files);
                                    },
                                  )
                                : YTMusicPlaylists(
                                    cookieFile: _cookieFiles.first,
                                    closeView: closeCookieDragAndDrop,
                                    playlistRouter: _onYTMusicPlaylistSelected,
                                  ),
                          ),
                          Positioned(
                            right: Platform.isAndroid ? 15 : 5,
                            top: Platform.isAndroid ? 15 : 5,
                            child: IconButton(
                              onPressed: () => setState(() {
                                dragAndDropView = false;
                                _cookieFiles = []; // close when close
                              }),
                              icon: Icon(Icons.close, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox.shrink(),
          ),
          if (playlistView == false &&
              loginView == false &&
              settingsView == false &&
              dragAndDropView == false &&
              soundCloudView == false)
            Positioned(
              right: Platform.isAndroid ? 15 : 5,
              top: Platform.isAndroid ? 30 : 5,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    settingsView = true;
                  });
                },
                icon: Icon(
                  Icons.settings,
                  color: Color.fromRGBO(255, 255, 255, 0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Material _mainPageButton(Function() onTap, String text) {
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 45,
        width: 350,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Color.fromARGB(6, 255, 255, 255),
          border: Border.all(width: 1, color: Colors.white.withAlpha(50)),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    ),
  );
}

Widget _serviceIconTile({required Function() onTap, required IconData icon}) {
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: Colors.white.withAlpha(20),
      highlightColor: Colors.white.withAlpha(12),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withAlpha(15),
          border: Border.all(width: 1, color: Colors.white.withAlpha(30)),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white.withOpacity(0.75), size: 28),
        ),
      ),
    ),
  );
}

Future<void> _handleTracksChosen(
  List<PlayerTrack> tracks, {
  String? newPlaylistName,
  db.PlaylistWithTracks? playlist,
}) async {
  if (tracks.isEmpty) return;

  final dbInstance = AppDatabase();
  int playlistId;

  if (newPlaylistName != null && newPlaylistName.isNotEmpty) {
    playlistId = await dbInstance.createPlaylist(newPlaylistName);
    debugPrint('Created playlist: "$newPlaylistName"');
  } else if (playlist != null) {
    playlistId = playlist.playlist.id;
    debugPrint('Using playlist: "${playlist.playlist.title}"');
  } else {
    debugPrint('No target playlist specified');
    return;
  }

  final companions = tracks.map((track) {
    String source = 'local';
    String? sourceId;
    String uniquePath = track.filepath;
    String? coverUrl;

    if (track is YandexMusicTrack) {
      source = 'yandex';
      sourceId = track.track.id;
      uniquePath = 'yandex:${track.track.id}';
      coverUrl = track.cover.contains('%%')
          ? 'https://${track.cover.replaceAll('%%', '300x300')}'
          : track.cover;
    } else if (track is YTMusicTrack) {
      source = 'youtube';
      sourceId = track.videoId;
      uniquePath = 'youtube:${track.videoId}';
      coverUrl = track.cover;
    } else if (track is SpotifyTrack) {
      source = 'spotify';
      sourceId = track.spotifyId;
      uniquePath = 'spotify:${track.spotifyId}';
      coverUrl = track.cover != 'none' ? track.cover : null;
    } else if (track is LocalTrack && track.filepath.startsWith('sc:')) {
      source = 'soundcloud';
      sourceId = track.filepath.replaceFirst('sc:', '');
      uniquePath = track.filepath;
      coverUrl = track.cover != 'none' ? track.cover : null;
    } else {
      // local or vk(parasha)
      uniquePath = track.filepath.isNotEmpty
          ? track.filepath
          : '${track.title}_${track.artists.join('_')}';
      coverUrl = (track.cover != 'none' && track.cover.isNotEmpty)
          ? track.cover
          : null;
    }

    return db.KnownTracksCompanion.insert(
      path: uniquePath,
      title: track.title,
      artists: track.artists.join(', '),
      album: track.albums.isNotEmpty ? track.albums.first : '',
      source: Value(source),
      sourceid: Value(sourceId),
      coverUrl: Value(coverUrl),
      downloaded: false,
    );
  }).toList();

  await dbInstance.batch((batch) {
    batch.insertAll(
      dbInstance.knownTracks,
      companions,
      mode: InsertMode.insertOrReplace,
    );
  });

  for (final track in tracks) {
    String uniquePath;
    if (track is YandexMusicTrack) {
      uniquePath = 'yandex:${track.track.id}';
    } else if (track is YTMusicTrack) {
      uniquePath = 'youtube:${track.videoId}';
    } else if (track is SpotifyTrack) {
      uniquePath = 'spotify:${track.spotifyId}';
    } else {
      uniquePath = track.filepath;
    }

    final knownTrack = await (dbInstance.select(
      dbInstance.knownTracks,
    )..where((t) => t.path.equals(uniquePath))).getSingleOrNull();

    if (knownTrack != null) {
      await dbInstance.insertTrackIntoPlaylist(playlistId, knownTrack.id);
    }
  }
}
