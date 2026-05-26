import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:quark/objects/playlist.dart';
import 'package:quark/objects/track.dart';
import 'package:quark/services/cached_images.dart';
import 'package:quark/services/database/library_engine.dart' as db;
import 'package:quark/services/dynamic_window_color_linux.dart';
import 'package:quark/services/player/player.dart';
import 'package:quark/widgets/players_widgets/macro_player.dart';
import 'package:yandex_music/yandex_music.dart';

class PlaylistInfoAbout {
  final String title;
  final String? ownerName;
  final Function() onOwnerTapped;
  final String type; // Playlist or Album or custom ui type
  /// Excludes play button
  final List<InterractionButton> buttons;
  final bool owner;
  final bool visibility;
  final bool canChangeName;
  final bool canChangeCover;
  final bool canChangeVisibility;
  final bool Function(String) onNameChanged;
  final bool Function(String) onCoverChanged;
  final bool Function(bool) onVisibilityChange;
  final Uint8List? cover;
  final Color accentColor;
  final List<PlayerTrack> tracks;

  const PlaylistInfoAbout({
    required this.title,
    required this.owner,
    required this.visibility,
    required this.accentColor,
    required this.buttons,
    required this.canChangeCover,
    required this.canChangeName,
    required this.canChangeVisibility,
    required this.onCoverChanged,
    required this.onNameChanged,
    required this.onOwnerTapped,
    required this.onVisibilityChange,
    this.cover,
    required this.ownerName,
    required this.tracks,
    this.type = "Playlist",
  });

  static Future<PlaylistInfoAbout> getFromDatabase(
    db.PlaylistWithTracks playlist,
  ) async {
    List<InterractionButton> buttons = [];
    buttons.add(
      InterractionButton(
        icon: Symbols.add_2,
        onTap: (BuildContext context) async {
          await showDialog(
            context: context,
            builder: (_) {
              return AddingTracks(playlistId: playlist.playlist.id);
            },
          );
        },
      ),
    );
    buttons.add(
      InterractionButton(
        icon: Symbols.add_photo_alternate_sharp,
        onTap: (_) async {
          final result = await FilePicker.platform.pickFiles(
            allowMultiple: false,
          );
          if (result == null ||
              result.files.isEmpty ||
              result.files[0].path == null)
            return;
          await db.AppDatabase().changeCover(
            playlist.playlist.id,
            result!.files[0].path!,
          );
        },
      ),
    );

    buttons.add(
      InterractionButton(
        icon: Icons.delete_forever,
        onTap: (_) async {
          await db.AppDatabase().deletePlaylist(playlist.playlist.id);
        },
        iconColor: Colors.redAccent,
      ),
    );

    Uint8List? cover;
    if (playlist.playlist.coverPath != null) {
      try {
        cover = await File(playlist.playlist.coverPath!).readAsBytes();
      } finally {}
    }
    return PlaylistInfoAbout(
      title: playlist.playlist.title,
      owner: true,
      visibility: false,
      accentColor: Colors.grey,
      buttons: buttons,
      canChangeCover: true,
      cover: cover,
      canChangeName: true,
      canChangeVisibility: false,
      onCoverChanged: (String coverPath) {
        return true;
      },
      onNameChanged: (String name) {
        db.AppDatabase().renamePlaylist(playlist.playlist.id, name);
        return true;
      },
      onOwnerTapped: () {
        return true;
      },
      onVisibilityChange: (_) {
        return true;
      },
      ownerName: "you",
      type: playlist.playlist.type,
      tracks: playlist.tracks
          .map((e) => PlayerTrack.fromKnownTrack(e))
          .toList(),

      // tracks: []
    );
  }
}

class InterractionButton {
  final IconData icon;
  final String buttonTooltip;
  final Function(BuildContext context) onTap;
  final Color iconColor;
  InterractionButton({
    required this.icon,
    required this.onTap,
    this.buttonTooltip = "",
    this.iconColor = Colors.white,
  });
}

class LocalPlaylistAbout {
  final String coverPath;
  final String title;
  final int id;
  final Function() onTap;
  final Function() onEyeTap;
  final List<PlayerTrack> tracks;

  LocalPlaylistAbout({
    required this.coverPath,
    required this.onEyeTap,
    required this.title,
    required this.id,
    required this.onTap,
    required this.tracks,
  });

  String? get firstTrackCover {
    if (tracks.isEmpty) return null;
    final first = tracks.first;
    if (first.cover != 'none' && first.cover.isNotEmpty) return first.cover;
    return null;
  }

  static LocalPlaylistAbout getFromDatabase(db.PlaylistWithTracks playlist) {
    return LocalPlaylistAbout(
      coverPath: playlist.playlist.coverPath ?? "none",
      onEyeTap: () {},
      onTap: () {},
      tracks: playlist.tracks
          .map((e) => PlayerTrack.fromKnownTrack(e))
          .toList(),
      title: playlist.playlist.title,
      id: playlist.playlist.id,
    );
  }
}

class LocalPlaylists extends StatelessWidget {
  final List<LocalPlaylistAbout> playlists;
  final Function() closeView;
  final Function(PlayerPlaylist playlist) playlistRouter;

  const LocalPlaylists({
    super.key,
    required this.closeView,
    required this.playlists,
    required this.playlistRouter,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Center(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 75, sigmaY: 75),
          child: Container(
            width: min(size.width * 0.92, 1040),
            height: min(size.height * 0.92, 1036),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.all(36.0),
                  child: Wrap(
                    spacing: 16.0,
                    runSpacing: 16.0,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    direction: Axis.horizontal,
                    children: List.generate(playlists.length + 1, (index) {
                      if (index == 0) {
                        return Container(
                          width: 310,
                          height: 310,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(15)),
                          ),
                          child: Material(
                            clipBehavior: Clip.antiAlias,
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(15),

                            child: InkWell(
                              onTap: () async {
                                final playlistID = await db.AppDatabase()
                                    .createPlaylist("New Playlist");
                                final playlist = await db.AppDatabase()
                                    .watchPlaylist(playlistID);
                                if (playlist == null) return;

                                final playli =
                                    await PlaylistInfoAbout.getFromDatabase(
                                      playlist,
                                    );
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) {
                                      return PlaylistInfoWidget(
                                        playlist: playli,
                                      );
                                    },
                                  ),
                                );
                              },

                              child: Stack(
                                children: [
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.8),
                                            Colors.black.withOpacity(0.4),
                                            Colors.transparent,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(15),
                                          bottomRight: Radius.circular(15),
                                        ),
                                      ),
                                      child: Text(
                                        "New Playlist",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Icon(Icons.add, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      index -= 1;
                      return Container(
                        width: 310,
                        height: 310,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(15)),
                          image: DecorationImage(
                            image: CachedImageProvider(
                              playlists[index].coverPath,
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Material(
                          clipBehavior: Clip.antiAlias,
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(15),

                          child: InkWell(
                            onTap: () async {
                              print(
                                'tracks count: ${playlists[index].tracks.length}',
                              );

                              if (playlists[index].tracks.isEmpty) {
                                print('TRACKS ARE EMPTY - nothing to play');
                                return;
                              }

                              final playlist = PlayerPlaylist(
                                kind: playlists[index].id,
                                ownerUid: 0,
                                name: playlists[index].title,
                                tracks: playlists[index].tracks,
                                source: PlaylistSource.local,
                              );

                              await playlistRouter(playlist);
                            },

                            child: Stack(
                              children: [
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.8),
                                          Colors.black.withOpacity(0.4),
                                          Colors.transparent,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(15),
                                        bottomRight: Radius.circular(15),
                                      ),
                                    ),
                                    child: Text(
                                      playlists[index].title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 5,
                                  top: 5,
                                  child: IconButton2(
                                    icon: Icons.remove_red_eye_outlined,
                                    onTap: () async {
                                      final playlist = await db.AppDatabase()
                                          .watchPlaylist(playlists[index].id);
                                      if (playlist == null) return;
                                      final playli =
                                          await PlaylistInfoAbout.getFromDatabase(
                                            playlist,
                                          );
                                      Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (_) {
                                            return PlaylistInfoWidget(
                                              playlist: playli,
                                            );
                                          },
                                        ),
                                      );
                                    },
                                    height: 35,
                                    width: 35,
                                    iconColor: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: IconButton(
                    onPressed: () async {},
                    icon: Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlaylistInfoWidget extends StatefulWidget {
  final PlaylistInfoAbout playlist;
  const PlaylistInfoWidget({super.key, required this.playlist});

  @override
  State<StatefulWidget> createState() => _PlaylistInfo();
}

class _PlaylistInfo extends State<PlaylistInfoWidget> {
  bool visibility = false;
  bool isProcessing = false;
  bool cached = false;
  PlaylistInfoAbout get playlist => widget.playlist;
  Color borderColor = Colors.white.withAlpha(78);
  late TextEditingController controller = TextEditingController(
    text: playlist.title,
  );
  Timer? debounceTimer;
  final Duration _debounceDuration = const Duration(milliseconds: 500);
  double _width = 400;
  final Color playlistColor = Colors.white;

  void _updateWidth(String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text.isEmpty ? 'hint' : text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 42,
          letterSpacing: -1.2,
        ),
      ),
      textDirection: ui.TextDirection.ltr,

      maxLines: 1,
    )..layout();

    setState(() {
      _width = (painter.width + 12).clamp(5, 1200);
    });
  }

  void changeTitle(String value) async {
    if (!playlist.canChangeName) return;
    debounceTimer?.cancel();
    debounceTimer = Timer(_debounceDuration, () async {
      if (value.isEmpty) {
        return;
      }
      setState(() {
        borderColor = Colors.orange;
      });
      final bool result = playlist.onNameChanged(value);
      if (result) {
        setState(() {
          borderColor = Colors.green;
        });
      }
      Future.delayed(
        Duration(seconds: 2),
        () => setState(() {
          borderColor = Colors.white.withAlpha(78);
        }),
      );
    });
  }

  void setHeader() async {
    DynamicWindowColor.pause();
    await DynamicWindowColor.setHeaderColor([playlistColor]);
  }

  List<Widget> getButtons() {
    final List<Widget> result = [];
    for (InterractionButton button in playlist.buttons) {
      result.add(
        IconButton2(
          icon: button.icon,
          onTap: () => button.onTap(context),
          iconColor: button.iconColor,
        ),
      );
      result.add(const SizedBox(width: 2));
    }
    return result;
  }

  @override
  void dispose() {
    DynamicWindowColor.resume();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _updateWidth(playlist.title);
    setState(() {
      visibility = playlist.visibility;
    });
    setHeader();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 10, 10, 10),
      bottomNavigationBar: Container(
        height: 55,
        color: playlistColor.withAlpha(50),
        child: Center(
          child: MacroPlayer(
            maxWidth: MediaQuery.of(context).size.width - 30,
            height: 45,
          ),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // if (MediaQuery.of(context).size.width > 460)
          // UserLibraryBar(accentColor: playlistColor),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _mainHeader(),
                  if (playlist.tracks.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: Text(
                        'Tracks',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    ...playlist.tracks.map(
                      (track) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              await Player.player.playCustom(track);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: track.coverByted.isNotEmpty
                                        ? Image.memory(
                                            track.coverByted,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 44,
                                            height: 44,
                                            color: Colors.white12,
                                            child: const Icon(
                                              Icons.music_note,
                                              color: Colors.white38,
                                              size: 20,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Название и артист
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          track.artists.join(', '),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _ownerHeader() {
    return [
      // Padding(
      //   padding: EdgeInsetsGeometry.only(top: 10),
      //   child: CoverView(
      //     smallCoverLink: playlist.cover != null
      //         ? YandexMusicSingleton.instance.playlists.getPlaylistCoverArtUrl(
      //             playlist.cover!,
      //           )
      //         : 'none',
      //     bigCoverLink: playlist.cover != null
      //         ? YandexMusicSingleton.instance.playlists.getPlaylistCoverArtUrl(
      //             playlist.cover!,
      //             imageSize: '1000x1000',
      //           )
      //         : 'none',
      //   ),
      // ),
      Padding(
        padding: EdgeInsetsGeometry.only(top: 10),
        child: Container(
          height: 180,
          width: 180,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: MemoryBytesImageProvider(playlist.cover ?? Uint8List(0)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 32),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                'PLAYLIST',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 10),
            SizedBox(
              width: _width,
              height: 60,

              child: TextField(
                onChanged: (value) {
                  _updateWidth(value);
                  changeTitle(value);
                },
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 42,
                  letterSpacing: -1.2,
                  height: 1.1,
                ),
                maxLines: 1,
                controller: controller,
                decoration: InputDecoration(
                  hintStyle: TextStyle(
                    color: Colors.white.withAlpha(178),
                    overflow: TextOverflow.ellipsis,
                    fontSize: 14,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withAlpha(100),
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor, width: 1.5),
                  ),
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                    // horizontal: 8,
                    vertical: 6,
                  ),
                  disabledBorder: null,
                ),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'by ${widget.playlist.ownerName ?? 'Unknown'}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 24,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _itemInfo(
                  icon: Icons.music_note,
                  label: 'Tracks',
                  value: '${playlist.tracks.length}',
                ),
                if (playlist.canChangeVisibility)
                  Tooltip(
                    message: "Change visibility",
                    child: InkWell(
                      onTap: () async {
                        setState(() {
                          isProcessing = true;
                        });

                        playlist.onVisibilityChange(!visibility);

                        setState(() {
                          visibility = !visibility;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _itemInfo(
                            icon: visibility ? Icons.public : Icons.lock,
                            label: 'Visibility',
                            value: visibility ? 'Public' : 'Private',
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.edit, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _nowOwnerHeader() {
    return [
      // Padding(
      //   padding: EdgeInsetsGeometry.only(top: 10),
      //   child: CoverView(
      //     smallCoverLink: playlist.cover != null
      //         ? YandexMusicSingleton.instance.playlists.getPlaylistCoverArtUrl(
      //             playlist.cover!,
      //           )
      //         : 'none',
      //     bigCoverLink: playlist.cover != null
      //         ? YandexMusicSingleton.instance.playlists.getPlaylistCoverArtUrl(
      //             playlist.cover!,
      //             imageSize: '1000x1000',
      //           )
      //         : 'none',
      //   ),
      // ),
      const SizedBox(width: 32),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                'PLAYLIST',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              playlist.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 42,
                letterSpacing: -1.2,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            Text(
              'by ${playlist.ownerName ?? 'Unknown'}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 24,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _itemInfo(
                  icon: Icons.music_note,
                  label: 'Tracks',
                  value: '${playlist.tracks.length}',
                ),

                _itemInfo(
                  icon: visibility ? Icons.public : Icons.lock,
                  label: 'Visibility',
                  value: visibility ? 'Public' : 'Private',
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _mainHeader() {
    final bool isOwner = playlist.owner;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            playlistColor.withOpacity(0.3),
            playlistColor.withOpacity(0.0),
          ],
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: isOwner ? _ownerHeader() : _nowOwnerHeader(),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadiusGeometry.all(Radius.circular(10)),
                  child: Material(
                    color: playlistColor.withOpacity(0.2),
                    child: InkWell(
                      onTap: () async {},
                      child: SizedBox(
                        height: 40,
                        width: 180,
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 30),
                Row(children: getButtons()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white60, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class IconButton2 extends StatelessWidget {
  final Color accentColor;
  final VoidCallback onTap;
  final IconData icon;
  final double width;
  final double height;
  final Color iconColor;
  final double iconSize;
  final BorderRadiusGeometry? borderRadius;

  const IconButton2({
    super.key,
    this.accentColor = Colors.white,
    this.height = 40,
    required this.icon,
    this.iconColor = Colors.white,
    this.iconSize = 21,
    required this.onTap,
    this.width = 40,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: Material(
          color: accentColor.withOpacity(0.2),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: height,
              width: width,
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
          ),
        ),
      );
    }

    return ClipOval(
      child: Material(
        color: accentColor.withOpacity(0.2),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            width: width,
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class AddingTracks extends StatefulWidget {
  final int playlistId;
  const AddingTracks({super.key, required this.playlistId});

  @override
  State<StatefulWidget> createState() => _AddingTracksState();
}

class _AddingTracksState extends State<AddingTracks> {
  List<PlayerTrack> knownTracks = [];
  List<PlayerTrack> alreadyInPlaylist = [];
  List<db.KnownTrack> tracks = [];

  void fetchKnownTracks() async {
    tracks = await db.AppDatabase().getKnownTracks();
    knownTracks = tracks.map((e) => PlayerTrack.fromKnownTrack(e)).toList();
    final playlist = await db.AppDatabase().watchPlaylist(widget.playlistId);
    if (playlist != null) {
      alreadyInPlaylist = playlist.tracks
          .map((e) => PlayerTrack.fromKnownTrack(e))
          .toList();
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    fetchKnownTracks();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: const ui.Color.fromARGB(255, 22, 28, 31),
          borderRadius: BorderRadius.circular(16),
        ),
        height: size.height * 0.8,
        width: size.width * 0.8,
        child: Column(
          children: [
            Text(
              "All tracks that you did could see",
              style: TextStyle(color: Colors.white),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: knownTracks.length,
                itemBuilder: (context, index) {
                  return AddingTrack(
                    track: knownTracks[index],
                    alreadyAdded: alreadyInPlaylist.contains(
                      knownTracks[index],
                    ),
                    onTap: () async {
                      final trackID = tracks
                          .where((e) => e.path == knownTracks[index].filepath)
                          .first;
                      await db.AppDatabase().insertTrackIntoPlaylist(
                        widget.playlistId,
                        trackID.id,
                      );
                      alreadyInPlaylist.add(knownTracks[index]);
                      setState(() {});
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddingTrack extends StatelessWidget {
  final PlayerTrack track;
  final bool alreadyAdded;
  final Function() onTap;
  const AddingTrack({
    super.key,
    required this.track,
    required this.alreadyAdded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              if (!listEquals(track.coverByted, Uint8List(0)))
                ClipRRect(
                  borderRadius: BorderRadiusGeometry.circular(5),
                  child: Image.memory(
                    track.coverByted,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.fromARGB(132, 158, 158, 158),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      track.artists.join(', '),
                      style: TextStyle(color: Colors.white.withAlpha(160)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const Spacer(),
              if (alreadyAdded) Icon(Icons.favorite, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
