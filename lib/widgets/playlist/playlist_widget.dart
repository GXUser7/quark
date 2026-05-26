import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:quark/services/database/database.dart';
import 'package:quark/services/yandex_music_singleton.dart';
import 'package:quark/widgets/players_widgets/main_player.dart';
import 'package:quark/widgets/yandex_music_integration/yandex_widgets.dart';
import '../../services/cached_images.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quark/services/player/player.dart';
import '/widgets/state_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:quark/objects/track.dart';
import 'package:path_provider/path_provider.dart';

/// TODO: make GestureDetector on ScrollUp/Down to create smooth playlist scrolling as in the SilkyScroll package

Widget playlistSearch(
  TextEditingController searchController,
  Function(String newView) search,
) {
  return SizedBox(
    height: 40,
    child: TextField(
      cursorColor: Colors.white.withOpacity(0.8),
      cursorErrorColor: Colors.white,
      onChanged: (value) {
        search(value);
      },
      controller: searchController,
      style: TextStyle(color: Colors.white.withOpacity(0.8)),
      decoration: InputDecoration(
        hintText: 'Search',
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 14,
        ),
        border: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        filled: false,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    ),
  );
}

class PlaylistOverlay extends StatefulWidget {
  final Function(StateIndicatorOperation operation) showOperation;
  final VoidCallback closePlaylist;
  final double width;
  final BorderRadiusGeometry borderRadiusGeometry;
  final bool background;
  final bool reordable;

  const PlaylistOverlay({
    super.key,
    required this.showOperation,
    required this.closePlaylist,
    this.width = 400,
    this.borderRadiusGeometry = const BorderRadius.only(
      topRight: Radius.circular(20),
      bottomRight: Radius.circular(20),
    ),
    this.background = true,
    this.reordable = true,
  });

  @override
  State<PlaylistOverlay> createState() => _PlaylistOverlayState();
}

class _PlaylistOverlayState extends State<PlaylistOverlay> {
  bool menuOpened = false;

  final ScrollController _scrollController = ScrollController();

  CancelToken? searchCancel = CancelToken();

  List<PlayerTrack> playlistView = [];
  SearchArtist? bestArtistResult;
  SearchAlbum? bestAlbumResult;
  final _menuOpened = ValueNotifier<bool>(false);
  late final TextEditingController _searchController;

  Timer? _searchDebounceTimer;
  final Duration _searchDebounceDuration = const Duration(milliseconds: 500);

  void listener() async {
    if (_searchController.text == '') {
      setState(() => playlistView = Player.player.playlist);
      scrollToCurrentTrack();
    }
  }

  void stater() async {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    setState(() {
      playlistView = Player.player.playlist;
    });

    Player.player.playlistNotifier.addListener(listener);
    Player.player.queueNotifier.addListener(stater);
  }

  @override
  void dispose() {
    _searchController.dispose();
    Player.player.playlistNotifier.removeListener(listener);
    Player.player.queueNotifier.removeListener(stater);
    super.dispose();
  }

  void search(String query, [bool? nonuser]) async {
    _searchDebounceTimer?.cancel();
    searchCancel?.cancel();
    searchCancel = null;
    setState(() {
      bestAlbumResult = null;
      bestArtistResult = null;
    });

    if (query == '') {
      setState(() {
        playlistView = Player.player.playlist;
      });
      scrollToCurrentTrack();
      return;
    }

    var filtered = Player.player.playlist.where((track) {
      final searchLower = query.toLowerCase().replaceAll(" ", "").trim();
      if (track.title
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(" ", "")
          .contains(searchLower)) {
        return true;
      }

      for (final artist in track.artists) {
        final artistTitle = artist;
        if (artistTitle
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), '')
            .replaceAll(" ", "")
            .contains(searchLower)) {
          return true;
        }
      }

      for (final album in track.albums) {
        final albumtitle = album;
        if (albumtitle
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), '')
            .replaceAll(" ", "")
            .contains(searchLower)) {
          return true;
        }
      }

      return false;
    }).toList();

    setState(() {
      playlistView = filtered;
    });

    if (nonuser == null) {
      // return;
      final currentQuery = query;

      _searchDebounceTimer = Timer(_searchDebounceDuration, () async {
        bool enable = DatabaseStreamerService().yandexMusicSearch.value;
        if (query.isEmpty || currentQuery != query || enable == false) {
          return;
        }

        searchCancel = CancelToken();

        try {
          final SearchResult result = await YandexMusicSingleton.instance.search
              .search(
                query,
                withBestResults: true,
                withLikesCount: true,
                pageSize: 10,
                cancelToken: searchCancel,
              );

          List<Track> results = result.tracks;
          setState(() {
            bestAlbumResult = result.bestAlbum;
            bestArtistResult = result.bestArtist;
          });

          if (result.bestTrack != null) {
            results.insert(0, result.bestTrack!);
          }
          for (var track in result.tracks) {
            final tr = YandexMusicTrack.fromYMTrack(track);
            filtered.add(tr);
          }

          if (currentQuery == query && currentQuery.isNotEmpty) {
            setState(() {
              playlistView = filtered;
            });
          }
        } on YandexMusicException catch (e) {
          switch (e.type) {
            case YandexMusicExceptionType.initialization:
              try {
                await YandexMusicSingleton.instance.init();
                search(query, nonuser);
              } catch (e) {
                Logger('Playlist_Widget').warning(
                  'SEARCH: Failed to initizalie YandexMusic instance',
                  e,
                );
                break;
              }
            default:
              break;
          }
        } catch (e) {
          widget.showOperation(StateIndicatorOperation.error);
          Logger(
            'Playlist_Widget',
          ).warning('SEARCH: YandexMusic instance has not been initalized', e);
        }
      });
    }
  }

  void findSimilar(int index) async {
    try {
      _searchController.text = 'Similar: ${playlistView[index].title}';
      List<PlayerTrack> filtered = [];
      var result = await YandexMusicSingleton.instance.tracks.getSimilar(
        (playlistView[index] as YandexMusicTrack).track.id,
      );

      for (Track track in result) {
        final tr = YandexMusicTrack.fromYMTrack(track);

        filtered.add(tr);
      }
      setState(() {
        playlistView = filtered;
      });
    } catch (e) {
      Logger(
        'Playlist_Widget',
      ).warning('findSimilar: Failed to find similar tracks', e);
      widget.showOperation(StateIndicatorOperation.error);
    }
  }

  void scrollToCurrentTrack() {
    int currentIndex = playlistView.indexWhere(
      (track) => track == Player.player.nowPlayingTrack,
    );
    if (currentIndex == -1 && Player.player.unQueuedLastTrack != null) {
      currentIndex = playlistView.indexWhere(
        (e) => e == Player.player.unQueuedLastTrack,
      );
    }

    final height = 61.0; // DEFAULT 71 - songElement cover size 55x55
    final offset = currentIndex * height;
    if (currentIndex != -1 && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.offset == offset ? 0 : offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void scrollToStart() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void moveTrack(int oldIndex, int newIndex) async {
    if (_searchController.text == '') {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      Player.player.moveTrack(playlistView[oldIndex], newIndex);
    }
  }

  void locateToAlbum(String name) {
    if (_searchController.text == '') {
      final List<PlayerTrack> album = Player.player.playlist
          .where((e) => e.albums.contains(name))
          .toList();
      setState(() {
        playlistView = album;
      });
      scrollToStart();
      return;
    }
  }

  void sortByArtist(String name) {
    if (_searchController.text == '') {
      final List<PlayerTrack> byArtist = Player.player.playlist
          .where((e) => e.artists.contains(name))
          .toList();
      setState(() {
        playlistView = byArtist;
      });
      scrollToStart();
      return;
    }
  }

  void showAll() {
    setState(() {
      playlistView = Player.player.playlist;
    });
    scrollToCurrentTrack();
    return;
  }

  List<Widget> getCategories() {
    final List<Widget> result = [];

    final SizedBox gap = const SizedBox(width: 5);

    final artists = Player.player.playlist
        .expand((track) => track.artists)
        .toSet();
    final albums = Player.player.playlist
        .expand((track) => track.albums)
        .toSet();
    result.add(
      TextButton(
        onPressed: () {
          showAll();
        },
        style: TextButton.styleFrom(
          backgroundColor: Colors.black.withAlpha(50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text("All"),
      ),
    );
    result.add(gap);

    for (String album in albums) {
      result.add(
        TextButton(
          onPressed: () {
            locateToAlbum(album);
          },
          style: TextButton.styleFrom(
            backgroundColor: Colors.black.withAlpha(50),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(album),
        ),
      );
      result.add(gap);
    }
    for (String artist in artists) {
      result.add(
        TextButton(
          onPressed: () {
            sortByArtist(artist);
          },
          style: TextButton.styleFrom(
            backgroundColor: Colors.black.withAlpha(50),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(artist),
        ),
      );
      result.add(gap);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity!.abs() > 500) {
            widget.closePlaylist();
          }
        },
        child: ClipRRect(
          borderRadius: widget.borderRadiusGeometry,
          child: Stack(
            children: [
              if (widget.background)
                AnimatedSwitcher(
                  duration: Duration(
                    milliseconds:
                        (750 * DatabaseStreamerService().transitionSpeed.value)
                            .round(),
                  ),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  layoutBuilder: (currentChild, previousChildren) => SizedBox(
                    width: 400,
                    height: MediaQuery.of(context).size.height,
                    child: Stack(
                      fit: StackFit.loose,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    ),
                  ),
                  child: SizedBox(
                    key: ValueKey(Player.player.nowPlayingTrack.filepath),
                    width: widget.width,
                    height: MediaQuery.of(context).size.height,
                    child: OverflowBox(
                      maxWidth: MediaQuery.of(context).size.width,
                      maxHeight: MediaQuery.of(context).size.height,
                      alignment: Alignment.centerLeft,
                      child:
                          (Player.player.nowPlayingTrack is LocalTrack &&
                              !listEquals(
                                Player.player.nowPlayingTrack.coverByted,
                                Uint8List(0),
                              ))
                          ? CachedBlurredImageFromBytes(
                              key: ValueKey(
                                Player.player.nowPlayingTrack.filepath,
                              ),
                              bytes: Player.player.nowPlayingTrack.coverByted,
                              width: MediaQuery.of(context).size.width,
                              height: MediaQuery.of(context).size.height,
                              fit: BoxFit.cover,
                            )
                          : CachedBlurredNetworkImage(
                              key: ValueKey(
                                Player.player.nowPlayingTrack.cover,
                              ),
                              coverUri:
                                  (Player.player.nowPlayingTrack
                                      is YandexMusicTrack)
                                  ? 'https://${Player.player.nowPlayingTrack.cover.replaceAll('%%', '300x300')}'
                                  : Player.player.nowPlayingTrack.cover,
                              width: MediaQuery.of(context).size.width,
                              height: MediaQuery.of(context).size.height,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              if (widget.background)
                Positioned.fill(
                  child: ColoredBox(color: Colors.black.withOpacity(0.5)),
                ),
              Container(
                width: widget.width,
                height: MediaQuery.of(context).size.height,
                decoration: overlayBoxDecoration(),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: EdgeInsetsGeometry.fromLTRB(10, 5, 10, 0),
                          child: appBar(
                            widget.closePlaylist,
                            () {},
                            () {},
                            scrollToCurrentTrack,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 15,
                            right: 15,
                            bottom: 10,
                          ),
                          child: playlistSearch(_searchController, search),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 15,
                            right: 15,
                            bottom: 10,
                          ),
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              dragDevices: {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.trackpad,
                              },
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(children: getCategories()),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ReorderableListView.builder(
                            // controller: _scrollController,
                            scrollController: _scrollController,
                            itemCount: playlistView.length,
                            itemExtent: 61.0,
                            cacheExtent: 100.0,
                            onReorder: (int oldIndex, int newIndex) async {
                              moveTrack(oldIndex, newIndex);
                            },

                            buildDefaultDragHandles: false,
                            proxyDecorator:
                                (
                                  Widget child,
                                  int index,
                                  Animation<double> animation,
                                ) {
                                  return Material(
                                    color: Colors.transparent,
                                    child: child,
                                  );
                                },
                            itemBuilder: (context, index) {
                              final track = playlistView[index];
                              final mainKey = ValueKey(
                                'main_${track.title}_$index',
                              );
                              if (playlistView[index] ==
                                      Player.player.unQueuedLastTrack &&
                                  Player.player.queue.isNotEmpty) {
                                List<Widget> widgets = [
                                  ReorderableDragStartListener(
                                    index: index,
                                    enabled:
                                        _searchController.text.isEmpty &&
                                        widget.reordable,
                                    child: PlaylistTileWidget(
                                      index: index,
                                      queued: false,
                                      track: playlistView[index],
                                      menuOpenedNotifier: _menuOpened,
                                      showOperation: widget.showOperation,
                                      findSimilar: findSimilar,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsGeometry.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'From queue',
                                          style: TextStyle(
                                            color: const Color.fromARGB(
                                              175,
                                              255,
                                              255,
                                              255,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 5),
                                        Expanded(
                                          child: Divider(
                                            height: 1,
                                            color: const Color.fromARGB(
                                              175,
                                              255,
                                              255,
                                              255,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 5),
                                        IconButton(
                                          highlightColor: const Color.fromARGB(
                                            50,
                                            255,
                                            255,
                                            255,
                                          ),
                                          onPressed: () async =>
                                              Player.player.clearQueue(),
                                          icon: Icon(
                                            Icons.delete,
                                            color: const Color.fromARGB(
                                              175,
                                              255,
                                              255,
                                              255,
                                            ),
                                            size: 21,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ];
                                for (PlayerTrack track in Player.player.queue) {
                                  widgets.add(
                                    ReorderableDragStartListener(
                                      index: index,
                                      enabled: false,
                                      child: PlaylistTileWidget(
                                        queued: true,
                                        index: index,
                                        track: track,
                                        menuOpenedNotifier: _menuOpened,
                                        showOperation: widget.showOperation,
                                        findSimilar: findSimilar,
                                      ),
                                    ),
                                  );
                                }
                                widgets.add(
                                  Container(
                                    color: const Color.fromARGB(
                                      50,
                                      255,
                                      255,
                                      255,
                                    ),
                                    width: 320,
                                    height: 2,
                                  ),
                                );
                                return Column(key: mainKey, children: widgets);
                              }
                              return ReorderableDragStartListener(
                                key: mainKey,
                                index: index,
                                enabled:
                                    _searchController.text.isEmpty &&
                                    widget.reordable,
                                child: PlaylistTileWidget(
                                  queued: false,
                                  index: index,
                                  track: playlistView[index],
                                  menuOpenedNotifier: _menuOpened,
                                  findSimilar: findSimilar,
                                  showOperation: widget.showOperation,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaylistTileWidget extends StatelessWidget {
  final int index;
  final PlayerTrack track;
  final bool queued;
  final void Function(int) findSimilar;
  final void Function(StateIndicatorOperation) showOperation;

  final double popupIconSize = 22;
  final double popupSpaceBetween = 10;
  final Color popupTextColor = const Color.fromARGB(220, 255, 255, 255);
  final Color popupIconsColor = const Color.fromARGB(170, 255, 255, 255);
  final ValueNotifier<bool> menuOpenedNotifier;
  const PlaylistTileWidget({
    super.key,
    required this.index,
    required this.track,
    required this.findSimilar,
    required this.queued,
    required this.showOperation,
    required this.menuOpenedNotifier,
  });

  void likeUnlike(int index) async {
    final List<String> likedTrack =
        YandexMusicSingleton.likedTracksNotifier.value;
    final track2 = (track as YandexMusicTrack).track;
    if (likedTrack.contains(track2.id)) {
      await YandexMusicSingleton.unlikeTrack(track2.id);
    } else {
      await YandexMusicSingleton.likeTrack(track2.id);
    }
  }

  void removeTrackFromPlaylist(int index) async {
    await Player.player.removeTrack(track);
  }

  void addNextQueue(int index) async {
    if (track is LocalTrack) {
      await Player.player.addTracks([LocalTrack.getNew((track as LocalTrack))]);
    } else if (track is YandexMusicTrack) {
      await Player.player.addTracks([
        YandexMusicTrack.getNew((track as YandexMusicTrack)),
      ]);
    }
  }

  List<PopupMenuEntry> _buildMenuItems(BuildContext context) {
    return [
      if (track is YandexMusicTrack)
        PopupMenuItem(
          onTap: () => likeUnlike(index),
          child: Row(
            children: [
              Icon(Icons.favorite, size: popupIconSize, color: popupIconsColor),
              SizedBox(width: popupSpaceBetween),
              Text(
                YandexMusicSingleton.likedTracksNotifier.value.contains(
                      (track as YandexMusicTrack).track.id,
                    )
                    ? 'Unlike'
                    : 'Like',
                style: TextStyle(fontFamily: 'noto', color: popupTextColor),
              ),
            ],
          ),
        ),
      if (!queued)
        PopupMenuItem(
          onTap: () => removeTrackFromPlaylist(index),
          child: Row(
            children: [
              Icon(
                Icons.delete_sweep_rounded,
                size: popupIconSize,
                color: popupIconsColor,
              ),
              SizedBox(width: popupSpaceBetween),
              Text(
                'Remove from playlist',
                style: TextStyle(fontFamily: 'noto', color: popupTextColor),
              ),
            ],
          ),
        ),
      if (queued)
        PopupMenuItem(
          onTap: () async => await Player.player.removeFromQueue(track),
          child: Row(
            children: [
              Icon(
                Icons.delete_sweep_rounded,
                size: popupIconSize,
                color: popupIconsColor,
              ),
              SizedBox(width: popupSpaceBetween),
              Text(
                'Remove from queue',
                style: TextStyle(fontFamily: 'noto', color: popupTextColor),
              ),
            ],
          ),
        ),
      if (!queued)
        PopupMenuItem(
          onTap: () => addNextQueue(index),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.arrow_up_to_line,
                size: popupIconSize,
                color: popupIconsColor,
              ),
              SizedBox(width: popupSpaceBetween),
              Text(
                'Play next',
                style: TextStyle(fontFamily: 'noto', color: popupTextColor),
              ),
            ],
          ),
        ),
      if (track is YandexMusicTrack)
        PopupMenuItem(
          onTap: () async {
            int selected = 0;
            final value = await showDialog<int>(
              context: context,
              builder: (context) => WarningMessage(
                messageHeader: 'Choose playlist',
                messageDiscription: '',
                buttons: YandexMusicSingleton.playlists
                    .map((e) => e.title)
                    .toList(),
              ),
            );

            if (value == null) return;
            selected = value;
            try {
              await YandexMusicSingleton.instance.playlists.insertTrack(
                YandexMusicSingleton.playlists[selected].kind,
                (track as YandexMusicTrack).track.id,
                albumId:
                    (track as YandexMusicTrack).track.trackSource ==
                        TrackSource.UGC
                    ? null
                    : (track as YandexMusicTrack).track.albums[0].id.toString(),
              );
              showOperation(StateIndicatorOperation.success);
            } catch (e) {
              showOperation(StateIndicatorOperation.error);
            }
          },
          enabled: track.albums.isNotEmpty,
          child: Row(
            children: [
              Icon(
                Icons.queue_outlined,
                size: popupIconSize,
                color: popupIconsColor,
              ),
              SizedBox(width: popupSpaceBetween),
              Text(
                'Add to yandex playlist',
                style: TextStyle(fontFamily: 'noto', color: popupTextColor),
              ),
            ],
          ),
        ),
      if (track is YandexMusicTrack &&
          (track as YandexMusicTrack).track.trackSource != TrackSource.UGC)
        PopupMenuItem(
          onTap: () => findSimilar(index),
          enabled: track.albums.isNotEmpty,
          child: Row(
            children: [
              Icon(
                CupertinoIcons.search,
                size: popupIconSize,
                color: popupIconsColor,
              ),
              SizedBox(width: popupSpaceBetween),
              Text(
                'Find similar',
                style: TextStyle(fontFamily: 'noto', color: popupTextColor),
              ),
            ],
          ),
        ),
      if (track is YandexMusicTrack &&
          (track as YandexMusicTrack).track.trackSource != TrackSource.UGC)
        PopupMenuItem(
          enabled: track.albums.isNotEmpty,
          onTap: () async {
            try {
              if (!YandexMusicSingleton.inited) {
                final String tok =
                    DatabaseStreamerService().yandexMusicToken.value;
                YandexMusicSingleton.init(YandexMusic(token: tok));
              }
              final artist = await YandexMusicSingleton.getArtistInfo(
                ((track as YandexMusicTrack).track.artists[0] as OfficialArtist)
                    .id,
              );
              if (context.mounted) {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => ArtistInfoWidget(artist: artist!),
                  ),
                );
              }
            } catch (e) {
              Logger("PlaylistWidget").warning("Failed to get album info.", e);
              showOperation(StateIndicatorOperation.error);
            }
          },
          child: Row(
            children: [
              Icon(
                CupertinoIcons.person,
                size: popupIconSize,
                color: popupIconsColor,
              ),
              SizedBox(width: popupSpaceBetween),
              Text(
                'View artist',
                style: TextStyle(fontFamily: 'noto', color: popupTextColor),
              ),
            ],
          ),
        ),
      if (track is YandexMusicTrack &&
          (track as YandexMusicTrack).track.albums.isNotEmpty &&
          (track as YandexMusicTrack).track.trackSource != TrackSource.UGC)
        PopupMenuItem(
          enabled: track.albums.isNotEmpty,
          onTap: () async {
            try {
              if (!YandexMusicSingleton.inited) {
                final String tok =
                    DatabaseStreamerService().yandexMusicToken.value;
                YandexMusicSingleton.init(YandexMusic(token: tok));
              }

              final album = await YandexMusicSingleton.getAlbumInfo(
                (track as YandexMusicTrack).track.albums[0].id,
              );
              if (context.mounted) {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => AlbumInfoWidget(album: album),
                  ),
                );
              }
            } catch (e) {
              Logger("PlaylistWidget").warning("Failed to get album info.", e);
              showOperation(StateIndicatorOperation.error);
            }
          },
          child: Row(
            children: [
              Icon(
                CupertinoIcons.music_albums,
                size: popupIconSize,
                color: popupIconsColor,
              ),
              SizedBox(width: popupSpaceBetween),
              Text(
                'View album',
                style: TextStyle(fontFamily: 'noto', color: popupTextColor),
              ),
            ],
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListTile(
        onTap: () async => await Player.player.playCustom(track),
        title: songElement(track),
        trailing: GestureDetector(
          onTapDown: (details) async {
            final position = RelativeRect.fromLTRB(
              details.globalPosition.dx,
              details.globalPosition.dy,
              details.globalPosition.dx,
              details.globalPosition.dy,
            );
            await showMenu(
              context: context,
              position: position,
              items: _buildMenuItems(context),
            );
          },
          child: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.6)),
        ),
      ),
    );
  }
}

Widget songElement(PlayerTrack track) {
  return Row(
    children: [
      Container(
        height: 45,
        width: 45,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 21, 21, 21),
              blurRadius: 10,
              offset: Offset(-2, -2),
            ),
          ],
        ),
        child:
            (track is LocalTrack && !listEquals(track.coverByted, Uint8List(0)))
            ? ClipRRect(
                borderRadius: BorderRadiusGeometry.circular(3),
                child: Image.memory(track.coverByted, height: 270, width: 270),
              )
            : CachedImage(
                borderRadius: 3,
                coverUri: (track is YandexMusicTrack)
                    ? 'https://${track.cover.replaceAll('%%', '300x300')}'
                    : track.cover,

                height: 55,
                width: 55,
                alphaChannel: 255,
                backgroundColor: const Color.fromARGB(255, 77, 77, 77),
                iconColor: Colors.grey,
                alphaChannelIcon: 255,
              ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              track.title,
              overflow: TextOverflow.ellipsis,

              style: TextStyle(
                color: Colors.white,
                fontFamily: 'noto',
                fontSize: 14,
              ),
            ),
            Text(
              track.artists.join(', '),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color.fromARGB(255, 185, 185, 185),
                fontFamily: 'noto',
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget yandexMusicArtist(SearchArtist track) {
  return Row(
    children: [
      Container(
        height: 55,
        width: 55,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 21, 21, 21),
              blurRadius: 10,
              offset: Offset(-2, -2),
            ),
          ],
        ),
        child: CachedImage(
          borderRadius: 3,
          coverUri: 'https://${track.cover.uri.replaceAll('%%', '300x300')}',
          height: 55,
          width: 55,
          alphaChannel: 255,
          backgroundColor: const Color.fromARGB(255, 77, 77, 77),
          iconColor: Colors.grey,
          alphaChannelIcon: 255,
        ),
      ),
      const SizedBox(width: 10),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              track.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'noto',
                fontSize: 16,
              ),
            ),
            Text(
              track.likesCount.toString(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color.fromARGB(255, 185, 185, 185),
                fontFamily: 'noto',
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget appBar(
  Function() togglePlaylist,
  Function() refreshPlaylist,
  Function() search,
  Function() scrollTo,
) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        onPressed: scrollTo,
        icon: Icon(Icons.keyboard_double_arrow_down),
        color: Colors.white.withOpacity(0.8),
        tooltip: 'Scroll to now track',
      ),
      Text(
        Player.player.playlistInfo.name,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
          fontFamily: 'noto',
        ),
      ),

      IconButton(
        onPressed: togglePlaylist,
        icon: Icon(Icons.close),
        color: Colors.white.withOpacity(0.8),
      ),
    ],
  );
}

BoxDecoration overlayBoxDecoration() {
  return BoxDecoration(
    color: Colors.white.withOpacity(0.025),
    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
    borderRadius: const BorderRadius.only(
      topRight: Radius.circular(20),
      bottomRight: Radius.circular(20),
    ),
  );
}
