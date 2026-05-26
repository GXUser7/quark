import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quark/objects/playlist.dart';
import 'package:quark/services/database/library_engine.dart' as db;
import 'package:quark/services/yandex_music_singleton.dart';
import 'package:quark/widgets/new_widgets.dart';

class LocalPlaylistsSection extends StatefulWidget {
  final Future<void> Function(PlayerPlaylist playlist) playlistRoute;

  const LocalPlaylistsSection({super.key, required this.playlistRoute});

  @override
  State<LocalPlaylistsSection> createState() => LocalPlaylistsSectionState();
}

class LocalPlaylistsSectionState extends State<LocalPlaylistsSection> {
  List<LocalPlaylistAbout> _all = [];
  List<LocalPlaylistAbout> _filtered = [];
  final _search = TextEditingController();
  bool _loading = true;
  Future<void> reload() => _load();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_filter);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final raw = await db.AppDatabase().getAllPlaylistsWithTracks();
    final mapped = raw
        .map((e) => LocalPlaylistAbout.getFromDatabase(e))
        .toList();
    if (mounted) {
      setState(() {
        _all = mapped;
        _filtered = mapped;
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _search.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((p) => p.title.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_all.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: SizedBox(
        width: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'My playlists',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      fontFamily: 'noto',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_all.length}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search ───────────────────────────────────────────────────
            _SearchField(controller: _search),
            const SizedBox(height: 14),

            // ── Grid ─────────────────────────────────────────────────────
            if (_filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No playlists match "${_search.text}"',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _filtered
                    .map(
                      (p) => _PlaylistChip(
                        playlist: p,
                        onTap: () async {
                          if (p.tracks.isEmpty) return;
                          await widget.playlistRoute(
                            PlayerPlaylist(
                              kind: p.id,
                              ownerUid: 0,
                              name: p.title,
                              tracks: p.tracks,
                              source: PlaylistSource.local,
                            ),
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.09), width: 1),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontFamily: 'noto',
            ),
            cursorColor: Colors.white38,
            cursorWidth: 1.5,
            decoration: InputDecoration(
              hintText: 'Search playlists…',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 13,
                fontFamily: 'noto',
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 17,
                color: Colors.white.withOpacity(0.3),
              ),
              suffixIcon: ValueListenableBuilder(
                valueListenable: controller,
                builder: (_, v, __) => v.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        onPressed: controller.clear,
                        padding: EdgeInsets.zero,
                      ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistChip extends StatefulWidget {
  final LocalPlaylistAbout playlist;
  final VoidCallback onTap;

  const _PlaylistChip({required this.playlist, required this.onTap});

  @override
  State<_PlaylistChip> createState() => _PlaylistChipState();
}

class _PlaylistChipState extends State<_PlaylistChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _hover.forward(),
      onExit: (_) => _hover.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _hover,
          builder: (_, __) {
            return Container(
              width: 188,
              height: 56,
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.10),
                  _hover.value,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Color.lerp(
                    Colors.white.withOpacity(0.07),
                    Colors.white.withOpacity(0.16),
                    _hover.value,
                  )!,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Row(
                  children: [
                    SizedBox(width: 56, height: 56, child: _buildCover()),

                    // Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.playlist.title,
                              style: TextStyle(
                                color: Colors.white.withOpacity(
                                  0.75 + _hover.value * 0.25,
                                ),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'noto',
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.playlist.tracks.length} tracks',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 11,
                                fontFamily: 'noto',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Arrow
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Colors.white.withOpacity(
                          0.15 + _hover.value * 0.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCover() {
    final p = widget.playlist;

    if (p.coverPath != 'none' && p.coverPath.isNotEmpty) {
      final file = File(p.coverPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover, width: 56, height: 56);
      }
    }

    final coverUrl = p.firstTrackCover;
    if (coverUrl != null) {
      var url = coverUrl
          .replaceFirst('https//', 'https://')
          .replaceAll('%%', '100x100');
      if (!url.startsWith('http')) url = 'https://$url';

      return Image.network(
        url,
        fit: BoxFit.cover,
        width: 56,
        height: 56,
        errorBuilder: (_, __, ___) => _iconFallback(),
      );
    }
    if (p.tracks.isNotEmpty && p.tracks.first.coverByted.isNotEmpty) {
      return Image.memory(
        p.tracks.first.coverByted,
        fit: BoxFit.cover,
        width: 56,
        height: 56,
      );
    }

    return _iconFallback();
  }

  Widget _iconFallback() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.white.withOpacity(0.05),
      child: Icon(
        Icons.queue_music_rounded,
        color: Colors.white.withOpacity(0.3),
        size: 22,
      ),
    );
  }
}
