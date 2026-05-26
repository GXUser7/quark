import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quark/objects/playlist.dart';
import 'package:quark/objects/track.dart';
import 'package:quark/services/auth_services.dart';
import 'package:quark/services/database/library_engine.dart' as db;
import 'package:quark/services/soundcloud_services.dart';
import 'package:quark/services/yandex_music_singleton.dart';
import 'package:yandex_music/yandex_music.dart';

const _kBaseUrl = 'https://quarkaudio.ru';

enum _MusicService { yandex, youtube, vk, local, soundcloud }

class MusicSearchWidget extends StatefulWidget {
  final Future<void> Function(
    List<PlayerTrack> tracks, {
    String? newPlaylistName,
    db.PlaylistWithTracks? playlist,
  })
  onTracksChosen;

  final db.PlaylistWithTracks? initialPlaylist;

  const MusicSearchWidget({
    super.key,
    required this.onTracksChosen,
    this.initialPlaylist,
  });

  @override
  State<MusicSearchWidget> createState() => _MusicSearchWidgetState();
}

class _MusicSearchWidgetState extends State<MusicSearchWidget>
    with TickerProviderStateMixin {
  _MusicService _service = _MusicService.yandex;
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<PlayerTrack> _allLocalTracks = [];

  List<PlayerTrack> _results = [];
  final Set<PlayerTrack> _selected = {};
  bool _loading = false;
  String? _error;

  final _dio = Dio();

  List<db.PlaylistWithTracks> _existingPlaylists = [];

  @override
  void initState() {
    super.initState();
    _loadExistingPlaylists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadExistingPlaylists() async {
    final raw = await db.AppDatabase().getAllPlaylistsWithTracks();
    if (mounted) setState(() => _existingPlaylists = raw);
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _results = _service == _MusicService.local ? _allLocalTracks : [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _search(q.trim()),
    );
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final results = switch (_service) {
        _MusicService.yandex => await _searchYandex(query),
        _MusicService.youtube => await _searchYT(query),
        _MusicService.vk => await _searchVK(query),
        _MusicService.local => await _searchLocal(query),
        _MusicService.soundcloud => await _searchSoundCloud(query),
      };
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        String message = e.toString();

        if (message.contains('YandexMusicInitialization') ||
            message.contains('Account ID was not found') ||
            message.contains('serviceAvailable: false')) {
          message =
              'Yandex Music is not available. Check your token or login again.';
        } else if (message.contains('401') ||
            message.contains('unauthorized')) {
          message = 'Session expired. Please login again.';
        } else if (message.contains('SocketException') ||
            message.contains('Failed host lookup')) {
          message = 'No internet connection.';
        }

        setState(() => _error = message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<PlayerTrack>> _searchYandex(String query) async {
    if (!YandexMusicSingleton.inited) {
      throw Exception('Yandex Music is not connected. Please login first.');
    }

    final result = await YandexMusicSingleton.instance.search.search(
      query,
      withBestResults: true,
      pageSize: 20,
    );

    final tracks = <PlayerTrack>[];
    if (result.bestTrack != null) {
      tracks.add(YandexMusicTrack.fromYMTrack(result.bestTrack!));
    }
    for (final t in result.tracks) {
      tracks.add(YandexMusicTrack.fromYMTrack(t));
    }
    return tracks;
  }

  Future<List<PlayerTrack>> _searchSoundCloud(String query) async {
    final tracks = await SoundCloudService().searchTracks(query, limit: 20);
    return tracks.map((t) => t.toPlayerTrack()).toList();
  }

  Future<List<PlayerTrack>> _searchYT(String query) async {
    final resp = await _dio.get(
      '$_kBaseUrl/api/yt/search',
      data: {'query': query, 'max_results': 20},
    );
    final list = resp.data as List<dynamic>;
    return list.map((e) {
      final json = e as Map<String, dynamic>;
      final videoId = json['id']?.toString() ?? '';

      // ← строим thumbnail из videoId если сервер не вернул
      if (json['thumbnail'] == null && videoId.isNotEmpty) {
        json['thumbnail'] = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
      }

      return YTMusicTrack.fromApiTrack(json);
    }).toList();
  }

  Future<List<PlayerTrack>> _searchVK(String query) async {
    final token = AuthService().accessToken ?? '';
    final resp = await _dio.get(
      '$_kBaseUrl/search',
      data: {'query': query, 'count': 20},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = resp.data as Map<String, dynamic>;
    final songs = data['songs'] as List<dynamic>;
    return songs.map((s) => _vkSongToTrack(s as Map<String, dynamic>)).toList();
  }

  Future<List<PlayerTrack>> _searchLocal(String query) async {
    final lower = query.toLowerCase();
    return _allLocalTracks
        .where(
          (t) =>
              t.title.toLowerCase().contains(lower) ||
              t.artists.any((a) => a.toLowerCase().contains(lower)),
        )
        .toList();
  }

  Future<void> _loadLocalTracks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final known = await db.AppDatabase().getKnownTracks();
      _allLocalTracks = known
          .map((t) => LocalTrack.getFromDatabase(t))
          .toList();
      if (mounted) setState(() => _results = _allLocalTracks);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  LocalTrack _vkSongToTrack(Map<String, dynamic> s) {
    return LocalTrack(
      title: s['title']?.toString() ?? 'Unknown',
      artists: [s['artist']?.toString() ?? 'Unknown'],
      albums: [],
      filepath: s['url']?.toString() ?? '',
      coverType: s['thumb'] != null ? CoverType.url : CoverType.noCover,
      cover: s['thumb']?['photo_270']?.toString() ?? 'none',
    );
  }

  Future<void> _addToExisting() async {
    if (_selected.isEmpty) return;

    final playlist = widget.initialPlaylist ?? await _showPlaylistPicker();
    if (playlist == null) return;

    await widget.onTracksChosen(_selected.toList(), playlist: playlist);
    if (mounted) setState(() => _selected.clear());
  }

  Future<void> _createNew() async {
    if (_selected.isEmpty) return;
    final name = await _showNameDialog();
    if (name == null || name.isEmpty) return;
    await widget.onTracksChosen(_selected.toList(), newPlaylistName: name);
    if (mounted) setState(() => _selected.clear());
  }

  Future<db.PlaylistWithTracks?> _showPlaylistPicker() async {
    return showModalBottomSheet<db.PlaylistWithTracks>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PlaylistPickerSheet(playlists: _existingPlaylists),
    );
  }

  Future<String?> _showNameDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'New playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white60),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Center(
        child: Container(
          width: 560,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                _buildHeader(),
                _buildServiceSelector(),
                _buildSearchField(),
                Expanded(child: _buildResults()),
                if (_selected.isNotEmpty) _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
      child: Row(
        children: [
          const Text(
            'Add tracks',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'noto',
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _ServiceChip(
            label: 'Yandex',
            selected: _service == _MusicService.yandex,
            color: const Color(0xFFFFCC00),
            onTap: () => setState(() {
              _service = _MusicService.yandex;
              _results = [];
            }),
          ),
          const SizedBox(width: 8),
          _ServiceChip(
            label: 'YouTube',
            selected: _service == _MusicService.youtube,
            color: const Color(0xFFFF0000),
            onTap: () => setState(() {
              _service = _MusicService.youtube;
              _results = [];
            }),
          ),
          const SizedBox(width: 8),
          _ServiceChip(
            label: 'VK',
            selected: _service == _MusicService.vk,
            color: const Color(0xFF0077FF),
            onTap: () => setState(() {
              _service = _MusicService.vk;
              _results = [];
            }),
          ),
          const SizedBox(width: 8),
          _ServiceChip(
            label: 'Local',
            selected: _service == _MusicService.local,
            color: const Color.fromARGB(255, 255, 255, 255),
            onTap: () {
              setState(() {
                _service = _MusicService.local;
                _results = [];
              });
              _loadLocalTracks();
            },
          ),
          const SizedBox(width: 8),
          _ServiceChip(
            label: 'SoundCloud',
            selected: _service == _MusicService.soundcloud,
            color: const Color(0xFFFF5500),
            onTap: () => setState(() {
              _service = _MusicService.soundcloud;
              _results = [];
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onQueryChanged,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white60,
        decoration: InputDecoration(
          hintText: 'Search tracks…',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 15,
          ),
          prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.white38,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _onQueryChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white30, strokeWidth: 2),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          'Error: $_error',
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_results.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(
        child: Text('No results', style: TextStyle(color: Colors.white38)),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note, color: Colors.white12, size: 48),
            const SizedBox(height: 12),
            Text(
              'Search for tracks',
              style: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (ctx, i) {
        final track = _results[i];
        final isSelected = _selected.contains(track);
        return _TrackResultTile(
          track: track,
          selected: isSelected,
          onToggle: () {
            setState(() {
              if (isSelected) {
                _selected.remove(track);
              } else {
                _selected.add(track);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          Text(
            '${_selected.length} selected',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          _ActionButton(
            label: 'New playlist',
            icon: Icons.add,
            onTap: _createNew,
            filled: false,
          ),
          const SizedBox(width: 10),
          _ActionButton(
            label: 'Add to playlist',
            icon: Icons.playlist_add,
            onTap: _addToExisting,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ServiceChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withOpacity(0.6)
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white54,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontFamily: 'noto',
          ),
        ),
      ),
    );
  }
}

class _TrackResultTile extends StatelessWidget {
  final PlayerTrack track;
  final bool selected;
  final VoidCallback onToggle;

  const _TrackResultTile({
    required this.track,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: selected ? Colors.white.withOpacity(0.06) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _TrackCover(track: track),
            ),
            const SizedBox(width: 12),
            // Title + artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'noto',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artists.join(', '),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      fontFamily: 'noto',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? Colors.white : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.black, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackCover extends StatelessWidget {
  final PlayerTrack track;
  const _TrackCover({required this.track});

  @override
  Widget build(BuildContext context) {
    if (track is LocalTrack && track.coverByted.isNotEmpty) {
      return Image.memory(
        track.coverByted,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      );
    }

    final url = switch (track) {
      YandexMusicTrack t => 'https://${t.cover.replaceAll('%%', '100x100')}',
      YTMusicTrack t => t.cover,
      _ => track.cover,
    };

    if (track is YTMusicTrack) {
      print('YT cover url: "${(track as YTMusicTrack).cover}"');
    }

    if (url == 'none' || url.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        color: Colors.white10,
        child: const Icon(Icons.music_note, color: Colors.white24, size: 20),
      );
    }

    return Image.network(
      url,
      width: 44,
      height: 44,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: 44,
        height: 44,
        color: Colors.white10,
        child: const Icon(Icons.music_note, color: Colors.white24, size: 20),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: filled ? null : Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.black : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.black : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'noto',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Playlist picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PlaylistPickerSheet extends StatelessWidget {
  final List<db.PlaylistWithTracks> playlists;
  const _PlaylistPickerSheet({required this.playlists});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Choose playlist',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'noto',
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No playlists yet',
              style: TextStyle(color: Colors.white38),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (ctx, i) {
                final p = playlists[i];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.queue_music,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    p.playlist.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'noto',
                    ),
                  ),
                  subtitle: Text(
                    '${p.tracks.length} tracks',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(ctx, p),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
