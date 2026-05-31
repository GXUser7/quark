import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:quark/widgets/animated_glow.dart';
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
import 'package:url_launcher/url_launcher.dart';
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
import 'package:quark/services/spotify_services.dart';
import 'package:quark/widgets/spotify_integration/spotify_login.dart';
import 'package:quark/widgets/spotify_integration/spotify_playlists_widget.dart';
import '/widgets/yandex_music_integration/yandex_playlists_widget.dart';
import '/widgets/auth.dart';
import 'package:quark/services/auth_services.dart';
import 'package:quark/l10n/app_localizations.dart';

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
    return ValueListenableBuilder<Locale?>(
      valueListenable: DatabaseStreamerService().appLocale,
      builder: (context, savedLocale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: DatabaseStreamerService().appThemeMode,
          builder: (context, themeMode, _) {
            return MaterialApp(
              home: const MainPage(),
              debugShowCheckedModeBanner: false,
              themeMode: themeMode,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              locale: savedLocale ?? const Locale('ru'),
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF6B52D4),
                  brightness: Brightness.light,
                  surface: const Color(0xFFF5F3FF),
                ),
                textTheme: GoogleFonts.plusJakartaSansTextTheme(
                  ThemeData.light().textTheme,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF9E86FF),
                  brightness: Brightness.dark,
                  surface: const Color(0xFF0C0A0E),
                ),
                textTheme: GoogleFonts.plusJakartaSansTextTheme(
                  ThemeData.dark().textTheme,
                ),
              ),
            );
          },
        );
      },
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
  bool spotifyInited = false;
  List<Map<String, dynamic>> spotifyPlaylists = [];
  bool spotifyLoginView = false;
  bool spotifyPlaylistView = false;
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

  Future<void> pickFolder() async {
    try {
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
          await AppDatabase().saveTracks(result);
        }
      }
    } catch (e) {
      log.shout('Unexpected error while pickFolder()', e);
    }
  }

  Future<void> closeLogin([bool? openPlaylists]) async {
    setState(() {
      loginView = false;
      ymUpdate();
      playlistView = true;
    });
  }

  Future<void> closePlaylist([bool? openPlaylists]) async {
    setState(() => playlistView = false);
  }

  Future<void> closeSettings() async {
    setState(() => settingsView = false);
  }

  Future<void> closeCookieDragAndDrop() async {
    setState(() => dragAndDropView = false);
  }

  Future<void> playlistRoute(PlayerPlaylist playlist) async {
    lastPlaylist = playlist;
    Player.player.updatePlaylistInfo(PlaylistInfo.fromPlayerPlaylist(playlist));
    Player.player.updatePlaylist(playlist.tracks);

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
    Player.player.pause();
    Player.player.playCustom(trackToPlay);

    if (foundTrack != null) {
      if (Duration(seconds: DatabaseStreamerService().lastTrackPosition.value) <
          Player.player.durationNotifier.value) {
        await Player.player.seek(
          Duration(seconds: DatabaseStreamerService().lastTrackPosition.value),
        );
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        settings: const RouteSettings(name: "/player"),
        builder: (context) =>
            PlaylistPage(playlist: playlist, yandexMusic: yandexMusic),
      ),
    );
  }

  Future<void> playlistRestore() async {
    String token = DatabaseStreamerService().yandexMusicToken.value;
    if (lastPlaylist == null) return;
    bool isYMInited = await yandexMusic.checkInit();
    if (!isYMInited) {
      yandexMusic = YandexMusic(token: token);
    }
    playlistRoute(lastPlaylist!);
  }

  Future<void> ymUpdate() async {
    if (inited && userPlaylists.isNotEmpty) {
      setState(() => playlistView = true);
      return;
    }
    try {
      if (!inited) {
        String token = DatabaseStreamerService().yandexMusicToken.value;
        if (token == '') {
          setState(() => loginView = true);
          return;
        }

        yandexMusic = YandexMusic(token: token);
        await yandexMusic.init();
        inited = true;
        YandexMusicSingleton.init(yandexMusic);
      }

      if (userPlaylists.isEmpty) {
        yandexMusic.usertracks.getPlaylistsWithLikes().then((playlists) {
          setState(() {
            userPlaylists = playlists;
            playlistView = true;
          });
        });
      } else {
        setState(() => playlistView = true);
      }
    } on YandexMusicException catch (e) {
      if (e.type == YandexMusicException.unauthorized) {
        setState(() => loginView = true);
      } else {
        log.shout('Unexpected error while ymUpdate()', e);
      }
    }
  }

  Future<void> spotifyUpdate() async {
    final db = DatabaseStreamerService();
    if (spotifyInited && spotifyPlaylists.isNotEmpty) {
      setState(() => spotifyPlaylistView = true);
      return;
    }
    
    final oauthToken = db.spotifyOauthToken.value;
    if (oauthToken.isEmpty) {
      setState(() => spotifyLoginView = true);
      return;
    }

    try {
      final playlists = await SpotifyService().getUserPlaylists();
      setState(() {
        spotifyPlaylists = playlists;
        spotifyInited = true;
        spotifyPlaylistView = true;
      });
    } catch (e) {
      log.shout('Unexpected error while spotifyUpdate()', e);
      setState(() => spotifyLoginView = true);
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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.playlistError(e.toString())),
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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.playlistError(e.toString())),
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

  void _onDatabaseChanged() async => await restoreLast();

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
      yandexMusic = YandexMusic(token: token);
      if (AuthService().isLoggedIn) {
        await AuthService().saveYandexToken(token);
      }
      await yandexMusic.init();
      if (!mounted) return;
      setState(() => inited = true);
      YandexMusicSingleton.init(yandexMusic);
      if (DatabaseStreamerService().yandexMusicPreload.value) {
        unawaited(_playlistPreload());
      }
    } catch (_) {
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

  @override
  void initState() {
    super.initState();
    _databaseBootStrap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedGlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, l10n),
                const SizedBox(height: 20),
                if (lastPlaylist != null) ...[
                  ResumePlaylistCard(
                    playlistName: lastPlaylist!.name,
                    trackCount: lastPlaylist!.tracks.length,
                    onTap: () async => playlistRestore(),
                  ),
                  const SizedBox(height: 28),
                ] else ...[
                  _buildWelcomeHero(context, l10n),
                  const SizedBox(height: 28),
                ],
                Text(
                  'Music Services',
                  style: GoogleFonts.plusJakartaSans(
                    color: theme.colorScheme.onSurface.withOpacity(0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                _buildServicesGrid(context, l10n),
                const SizedBox(height: 36),
                Row(
                  children: [
                    Icon(
                      Icons.library_music_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your Playlists',
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.colorScheme.onSurface.withOpacity(0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LocalPlaylistsSection(
                  key: _playlistsKey,
                  playlistRoute: playlistRoute,
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildOverlays(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset('assets/icon512.png', height: 40, width: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.colorScheme.onSurface,
                        fontSize: isMobile ? 19 : 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'where sound begins',
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.colorScheme.onSurface.withOpacity(0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Theme toggle button
                  IconButton(
                    onPressed: () {
                      final current = DatabaseStreamerService().appThemeMode.value;
                      DatabaseStreamerService().appThemeMode.value =
                          current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                    },
                    icon: Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.onSurface.withOpacity(0.04),
                      hoverColor: theme.colorScheme.onSurface.withOpacity(0.09),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  isMobile
                      ? IconButton(
                          onPressed: () async {
                            if (!AuthService().isLoggedIn) {
                              await Navigator.push(
                                context,
                                CupertinoPageRoute(builder: (_) => const AuthPage()),
                              );
                              if (AuthService().isLoggedIn) unawaited(_syncPlaylists());
                            } else {
                              await AuthService().logout();
                            }
                            setState(() {});
                          },
                          icon: Icon(
                            AuthService().isLoggedIn
                                ? Icons.logout_rounded
                                : Icons.login_rounded,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                theme.colorScheme.onSurface.withOpacity(0.04),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(10),
                          ),
                        )
                      : SizedBox(
                          width: 115,
                          height: 38,
                          child: GnomeStyleAuthButton(
                            isLoggedIn: AuthService().isLoggedIn,
                            onTap: () async {
                              if (!AuthService().isLoggedIn) {
                                await Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                      builder: (_) => const AuthPage()),
                                );
                                if (AuthService().isLoggedIn)
                                  unawaited(_syncPlaylists());
                              } else {
                                await AuthService().logout();
                              }
                              setState(() {});
                            },
                          ),
                        ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => settingsView = true),
                    icon: Icon(
                      Icons.settings_outlined,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          theme.colorScheme.onSurface.withOpacity(0.04),
                      hoverColor: theme.colorScheme.onSurface.withOpacity(0.09),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHero(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.onSurface.withOpacity(0.04),
            theme.colorScheme.onSurface.withOpacity(0.01),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ready to listen?',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.selectFolderHint,
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid(BuildContext context, AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = width > 700 ? 3 : 2;
        final double spacing = 14.0;
        final double cardWidth =
            (width - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            ExpressiveServiceCard(
              width: cardWidth,
              onTap: () async => await pickFolder(),
              label: l10n.pickFolder,
              icon: Icons.folder_open_rounded,
              color: Colors.blueAccent,
            ),
            ExpressiveServiceCard(
              width: cardWidth,
              onTap: () async => await ymUpdate(),
              label: l10n.yandexMusic,
              iconWidget: Image.asset(
                'assets/ym_w_alt.png',
                width: 26,
                height: 26,
              ),
              color: const Color(0xFFFFCC00),
              badge: inited ? "Active" : null,
            ),
            ExpressiveServiceCard(
              width: cardWidth,
              onTap: () => setState(() => dragAndDropView = true),
              label: l10n.youtubeMusic,
              iconWidget: Image.asset(
                'assets/y_w_alt.png',
                width: 26,
                height: 26,
              ),
              color: const Color(0xFFFF0000),
            ),
            ExpressiveServiceCard(
              width: cardWidth,
              onTap: () => setState(() => soundCloudView = true),
              label: l10n.soundCloud,
              iconWidget: Image.asset(
                'assets/soundcloud_w.png',
                width: 32,
                height: 32,
              ),
              color: const Color(0xFFFF5500),
            ),
            ExpressiveServiceCard(
              width: cardWidth,
              onTap: () async => await spotifyUpdate(),
              label: 'Spotify',
              iconWidget: const Icon(
                Icons.spatial_audio_rounded,
                color: Colors.white,
                size: 26,
              ),
              color: const Color(0xFF1DB954),
              badge: spotifyInited ? "Active" : null,
            ),
            ExpressiveServiceCard(
              width: cardWidth,
              onTap: () async {
                await Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => MusicSearchWidget(
                      onTracksChosen: (tracks, {newPlaylistName, playlist}) =>
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
              label: l10n.search,
              icon: Icons.search_rounded,
              color: Colors.tealAccent,
            ),
            ExpressiveServiceCard(
              width: cardWidth,
              onTap: () async {
                final Uri url = Uri.parse('https://github.com/z3nsh0w/quark/');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
              label: 'Мы на GitHub',
              icon: Icons.code_rounded,
              color: const Color(0xFFF0F6FC),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverlays() {
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: loginView
              ? GlassOverlay(
                  key: const ValueKey('login'),
                  onClose: () => setState(() => loginView = false),
                  child: YandexLogin(closeView: closeLogin),
                )
              : const SizedBox.shrink(key: ValueKey('empty_login')),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: playlistView
              ? GlassOverlay(
                  key: const ValueKey('playlist'),
                  onClose: () => setState(() => playlistView = false),
                  child: YandexPlaylists(
                    closeView: closePlaylist,
                    yandexMusic: yandexMusic,
                    playlistRouter: playlistRoute,
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty_playlist')),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: settingsView
              ? GlassOverlay(
                  key: const ValueKey('settings'),
                  onClose: () => setState(() => settingsView = false),
                  child: Settings(closeView: closeSettings),
                )
              : const SizedBox.shrink(key: ValueKey('empty_settings')),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: soundCloudView
              ? GlassOverlay(
                  key: const ValueKey('soundcloud'),
                  onClose: () => setState(() => soundCloudView = false),
                  child: SoundCloudPlaylistsWidget(
                    closeView: () {},
                    playlistRouter: _onSoundCloudPlaylistSelected,
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty_soundcloud')),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: dragAndDropView
              ? GlassOverlay(
                  key: const ValueKey('dragAndDrop'),
                  onClose: () => setState(() {
                    dragAndDropView = false;
                    _cookieFiles = [];
                  }),
                  child: _cookieFiles.isEmpty
                      ? GlassDropZone(
                          closeView: closeCookieDragAndDrop,
                          onFileDropped: (files) =>
                              setState(() => _cookieFiles = files),
                        )
                      : YTMusicPlaylists(
                          cookieFile: _cookieFiles.first,
                          closeView: closeCookieDragAndDrop,
                          playlistRouter: _onYTMusicPlaylistSelected,
                        ),
                )
              : const SizedBox.shrink(key: ValueKey('empty_drag_drop')),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: spotifyLoginView
              ? GlassOverlay(
                  key: const ValueKey('spotify_login'),
                  onClose: () => setState(() => spotifyLoginView = false),
                  child: SpotifyLogin(closeView: () {
                    setState(() {
                      spotifyLoginView = false;
                      spotifyUpdate();
                    });
                  }),
                )
              : const SizedBox.shrink(key: ValueKey('empty_spotify_login')),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: spotifyPlaylistView
              ? GlassOverlay(
                  key: const ValueKey('spotify_playlist'),
                  onClose: () => setState(() => spotifyPlaylistView = false),
                  child: SpotifyPlaylistsWidget(
                    closeView: () => setState(() => spotifyPlaylistView = false),
                    initialPlaylists: spotifyPlaylists,
                    playlistRouter: playlistRoute,
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty_spotify_playlist')),
        ),
      ],
    );
  }
}

class ExpressiveServiceCard extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final Color color;
  final String? badge;
  final double width;

  const ExpressiveServiceCard({
    super.key,
    required this.onTap,
    required this.label,
    this.icon,
    this.iconWidget,
    required this.color,
    this.badge,
    required this.width,
  });

  @override
  State<ExpressiveServiceCard> createState() => _ExpressiveServiceCardState();
}

class _ExpressiveServiceCardState extends State<ExpressiveServiceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = widget.color;
    final baseColor = theme.colorScheme.onSurface.withOpacity(isDark ? 0.12 : 0.06);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isHovered
                  ? [
                      accentColor.withOpacity(0.18),
                      accentColor.withOpacity(0.06),
                    ]
                  : [baseColor, baseColor.withOpacity(0.03)],
            ),
            border: Border.all(
              color: _isHovered
                  ? accentColor.withOpacity(0.4)
                  : theme.colorScheme.outlineVariant.withOpacity(isDark ? 0.3 : 0.5),
              width: 1.2,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: accentColor.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              splashColor: accentColor.withOpacity(0.15),
              highlightColor: accentColor.withOpacity(0.06),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isHovered
                                ? accentColor.withOpacity(0.15)
                                : theme.colorScheme.onSurface.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: widget.iconWidget ??
                              Icon(
                                widget.icon,
                                color: _isHovered
                                    ? accentColor
                                    : theme.colorScheme.onSurface.withOpacity(0.8),
                                size: 22,
                              ),
                        ),
                        if (widget.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: accentColor.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              widget.badge!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      widget.label,
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.colorScheme.onSurface.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ResumePlaylistCard extends StatefulWidget {
  final VoidCallback onTap;
  final String playlistName;
  final int trackCount;

  const ResumePlaylistCard({
    super.key,
    required this.onTap,
    required this.playlistName,
    required this.trackCount,
  });

  @override
  State<ResumePlaylistCard> createState() => _ResumePlaylistCardState();
}

class _ResumePlaylistCardState extends State<ResumePlaylistCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withOpacity(0.18),
                primaryColor.withOpacity(0.04),
              ],
            ),
            border: Border.all(
              color: _isHovered
                  ? primaryColor.withOpacity(0.4)
                  : primaryColor.withOpacity(0.12),
              width: 1.5,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: primaryColor.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(24),
              splashColor: primaryColor.withOpacity(0.15),
              highlightColor: primaryColor.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 18.0,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "RESUME LISTEN",
                            style: GoogleFonts.plusJakartaSans(
                              color: primaryColor.withOpacity(0.85),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.playlistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: theme.colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${widget.trackCount} tracks",
                            style: GoogleFonts.plusJakartaSans(
                              color: theme.colorScheme.onSurface.withOpacity(0.55),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassOverlay extends StatelessWidget {
  final Widget child;
  final VoidCallback onClose;

  const GlassOverlay({super.key, required this.child, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: Colors.black.withOpacity(isDark ? 0.65 : 0.35),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Stack(
          children: [
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 620,
                  maxHeight: 720,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF131118).withOpacity(0.82)
                        : Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: child,
                      ),
                      Positioned(
                        right: 14,
                        top: 14,
                        child: IconButton(
                          onPressed: onClose,
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                theme.colorScheme.onSurface.withOpacity(0.04),
                            hoverColor:
                                theme.colorScheme.onSurface.withOpacity(0.09),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WarningMessage extends StatelessWidget {
  final String messageHeader;
  final String messageDiscription;
  final List<String> buttons;
  final int transparency;
  final Color color;
  final Color? borderColor;

  const WarningMessage({
    super.key,
    required this.messageHeader,
    required this.messageDiscription,
    required this.buttons,
    this.transparency = 15,
    this.color = Colors.white,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: transparency > 200
          ? color.withOpacity(0.85)
          : theme.colorScheme.surfaceContainerHigh,
      title: Text(
        messageHeader,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: messageDiscription.isNotEmpty
          ? Text(messageDiscription, textAlign: TextAlign.center)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: borderColor != null
            ? BorderSide(color: borderColor!)
            : BorderSide.none,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowDirection: VerticalDirection.down,
      actions: buttons.map((text) {
        return SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(buttons.indexOf(text)),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      }).toList(),
    );
  }
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
  } else if (playlist != null) {
    playlistId = playlist.playlist.id;
  } else {
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
      uniquePath = track.filepath;
      coverUrl = (track.cover != 'none' && track.cover.isNotEmpty)
          ? track.cover
          : null;
    } else if (track is LocalTrack && track.filepath.startsWith('sc:')) {
      source = 'soundcloud';
      sourceId = track.filepath.replaceFirst('sc:', '');
      uniquePath = track.filepath;
      coverUrl = track.cover != 'none' ? track.cover : null;
    } else {
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
    String uniquePath = track is YandexMusicTrack
        ? 'yandex:${track.track.id}'
        : track is YTMusicTrack
            ? 'youtube:${track.videoId}'
            : track is SpotifyTrack
                ? track.filepath
                : track.filepath;

    final knownTrack = await (dbInstance.select(
      dbInstance.knownTracks,
    )..where((t) => t.path.equals(uniquePath)))
        .getSingleOrNull();
    if (knownTrack != null) {
      await dbInstance.insertTrackIntoPlaylist(playlistId, knownTrack.id);
    }
  }
}