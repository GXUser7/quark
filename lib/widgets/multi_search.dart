import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quark/objects/playlist.dart';
import 'package:quark/objects/track.dart';
import 'package:quark/services/auth_services.dart';
import 'package:quark/services/database/library_engine.dart' as db;
import 'package:quark/services/soundcloud_services.dart';
import 'package:quark/services/yandex_music_singleton.dart';
import 'package:yandex_music/yandex_music.dart';
import 'package:quark/services/spotify_services.dart';
import 'package:quark/services/database/database.dart';

const _kBaseUrl = 'https://quarkaudio.ru';

enum _MusicService { yandex, youtube, vk, local, soundcloud, spotify }

class MusicSearchWidget extends StatefulWidget {
  final Future<void> Function(
    List<PlayerTrack> tracks, {
    String? newPlaylistName,
    db.PlaylistWithTracks? playlist,
  }) onTracksChosen;

  final db.PlaylistWithTracks? initialPlaylist;

  const MusicSearchWidget({
    super.key,
    required this.onTracksChosen,
    this.initialPlaylist,
  });

  @override
  State<MusicSearchWidget> createState() => _MusicSearchWidgetState();
}

class _MusicSearchWidgetState extends State<MusicSearchWidget> with TickerProviderStateMixin {
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
        _MusicService.spotify => await _searchSpotify(query),
      };
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        String message = e.toString();
        if (message.contains('YandexMusicInitialization') ||
            message.contains('Account ID was not found') ||
            message.contains('serviceAvailable: false')) {
          message = 'Яндекс Музыка недоступна. Проверьте токен или войдите снова.';
        } else if (message.contains('401') || message.contains('unauthorized')) {
          message = 'Сессия устарела. Пожалуйста, авторизуйтесь заново.';
        } else if (message.contains('SocketException') || message.contains('Failed host lookup')) {
          message = 'Отсутствует подключение к интернету.';
        }
        setState(() => _error = message);
      }
    } 
      if (mounted) setState(() => _loading = false);
    
  }

  Future<List<PlayerTrack>> _searchYandex(String query) async {
    if (!YandexMusicSingleton.inited) {
      throw Exception('Яндекс Музыка не подключена.');
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

  Future<List<PlayerTrack>> _searchSpotify(String query) async {
    return await SpotifyService().search(query, limit: 20);
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
        .where((t) => t.title.toLowerCase().contains(lower) || t.artists.any((a) => a.toLowerCase().contains(lower)))
        .toList();
  }

  Future<void> _loadLocalTracks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final known = await db.AppDatabase().getKnownTracks();
      _allLocalTracks = known.map((t) => LocalTrack.getFromDatabase(t)).toList();
      if (mounted) setState(() => _results = _allLocalTracks);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } 
      if (mounted) setState(() => _loading = false);
    
  }

  LocalTrack _vkSongToTrack(Map<String, dynamic> s) {
    return LocalTrack(
      title: s['title']?.toString() ?? 'Неизвестно',
      artists: [s['artist']?.toString() ?? 'Неизвестный исполнитель'],
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
      backgroundColor: const Color(0xFF0C0A0E),
      barrierColor: Colors.black.withOpacity(0.6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PlaylistPickerSheet(playlists: _existingPlaylists),
    );
  }

  Future<String?> _showNameDialog() async {
    final ctrl = TextEditingController();
    final theme = Theme.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131118),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Новый плейлист',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
          cursorColor: theme.colorScheme.primary,
          decoration: InputDecoration(
            hintText: 'Название плейлиста',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text('Создать', style: GoogleFonts.plusJakartaSans(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 650;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Container(
            width: isMobile ? double.infinity : 560,
            height: isMobile ? double.infinity : MediaQuery.of(context).size.height * 0.85,
            margin: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0A0E),
              borderRadius: BorderRadius.circular(isMobile ? 0 : 24),
              border: isMobile ? null : Border.all(color: Colors.white.withOpacity(0.06), width: 1.2),
              boxShadow: [
                if (!isMobile)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
              ],
            ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
      child: Row(
        children: [
          Text(
            'Добавление треков',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.03),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSelector() {
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _ServiceChip(
            label: 'Yandex',
            selected: _service == _MusicService.yandex,
            color: const Color(0xFFFFCC00),
            onTap: () => setState(() { _service = _MusicService.yandex; _results = []; }),
          ),
          const SizedBox(width: 8),
          _ServiceChip(
            label: 'YouTube',
            selected: _service == _MusicService.youtube,
            color: const Color(0xFFFF0000),
            onTap: () => setState(() { _service = _MusicService.youtube; _results = []; }),
          ),
          const SizedBox(width: 8),
          // _ServiceChip(
          //   label: 'VK',
          //   selected: _service == _MusicService.vk,
          //   color: const Color(0xFF0077FF),
          //   onTap: () => setState(() { _service = _MusicService.vk; _results = []; }),
          // ),
          const SizedBox(width: 8),
          _ServiceChip(
            label: 'Локальные',
            selected: _service == _MusicService.local,
            color: Colors.blueAccent,
            onTap: () {
              setState(() { _service = _MusicService.local; _results = []; });
              _loadLocalTracks();
            },
          ),
          const SizedBox(width: 8),
          _ServiceChip(
            label: 'SoundCloud',
            selected: _service == _MusicService.soundcloud,
            color: const Color(0xFFFF5500),
            onTap: () => setState(() { _service = _MusicService.soundcloud; _results = []; }),
          ),
          if (DatabaseStreamerService().spotifySearch.value) ...[
            const SizedBox(width: 8),
            _ServiceChip(
              label: 'Spotify',
              selected: _service == _MusicService.spotify,
              color: const Color(0xFF1DB954),
              onTap: () => setState(() { _service = _MusicService.spotify; _results = []; }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: _onQueryChanged,
        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15),
        cursorColor: theme.colorScheme.primary,
        decoration: InputDecoration(
          hintText: 'Поиск треков или исполнителей…',
          hintStyle: GoogleFonts.plusJakartaSans(
            color: Colors.white.withOpacity(0.25),
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.3), size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onQueryChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.02),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(
        child: CupertinoActivityIndicator(color: Colors.white70, radius: 12),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            _error!,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFF453A), fontSize: 14, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_results.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Text('Ничего не найдено', style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 15)),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note_rounded, color: Colors.white.withOpacity(0.04), size: 64),
            const SizedBox(height: 12),
            Text(
              'Начните вводить поисковый запрос',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white.withOpacity(0.2),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      physics: const BouncingScrollPhysics(),
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
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131118).withOpacity(0.4),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Text(
            'Выбрано: ${_selected.length}',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _ActionButton(
            label: 'Создать',
            icon: Icons.add_rounded,
            onTap: _createNew,
            filled: false,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            label: 'В плейлист',
            icon: Icons.playlist_add_rounded,
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withOpacity(0.4) : Colors.white.withOpacity(0.06),
            width: 1.2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: selected ? color : Colors.white.withOpacity(0.4),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
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
    final theme = Theme.of(context);

    return InkWell(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: selected ? theme.colorScheme.primary.withOpacity(0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _TrackCover(track: track),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: selected ? Colors.white : Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artists.join(', '),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? theme.colorScheme.primary : Colors.white.withOpacity(0.12),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
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
      return Image.memory(track.coverByted, width: 46, height: 46, fit: BoxFit.cover);
    }

    final url = switch (track) {
      YandexMusicTrack t => 'https://${t.cover.replaceAll('%%', '100x100')}',
      YTMusicTrack t => t.cover,
      _ => track.cover,
    };

    if (url == 'none' || url.isEmpty) {
      return Container(
        width: 46,
        height: 46,
        color: Colors.white.withOpacity(0.04),
        child: const Icon(Icons.music_note_rounded, color: Colors.white24, size: 20),
      );
    }

    return Image.network(
      url,
      width: 46,
      height: 46,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: 46,
        height: 46,
        color: Colors.white.withOpacity(0.04),
        child: const Icon(Icons.music_note_rounded, color: Colors.white24, size: 20),
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
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? theme.colorScheme.primary : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: filled ? Colors.white : Colors.white.withOpacity(0.7)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: filled ? Colors.white : Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistPickerSheet extends StatelessWidget {
  final List<db.PlaylistWithTracks> playlists;
  const _PlaylistPickerSheet({required this.playlists});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0A0E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Выберите плейлист',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'У вас пока нет плейлистов',
                style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: playlists.length,
                itemBuilder: (ctx, i) {
                  final p = playlists[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: const Icon(Icons.queue_music_rounded, color: Colors.white54, size: 22),
                    ),
                    title: Text(
                      p.playlist.title,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${p.tracks.length} треков',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, p),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}