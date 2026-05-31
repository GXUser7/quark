import 'dart:io';
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
    if (_loading || _all.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16, top: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'My Playlists',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_all.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        _SearchField(controller: _search),
        const SizedBox(height: 16),

        if (_filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No playlists match "${_search.text}"',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filtered.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 68,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final p = _filtered[index];
              return _PlaylistChip(
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
              );
            },
          ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(isDark ? 0.1 : 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(isDark ? 0.08 : 0.4),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
            ),
            cursorColor: theme.colorScheme.primary,
            decoration: InputDecoration(
              hintText: 'Search playlists…',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              suffixIcon: ValueListenableBuilder(
                valueListenable: controller,
                builder: (_, v, __) => v.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        onPressed: controller.clear,
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
    duration: const Duration(milliseconds: 200),
  );

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => _hover.forward(),
      onExit: (_) => _hover.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _hover,
          builder: (context, __) {
            final double hoverValue = _hover.value;

            return Container(
              decoration: BoxDecoration(
                color: Color.lerp(
                  theme.colorScheme.surfaceVariant.withOpacity(isDark ? 0.08 : 0.25),
                  theme.colorScheme.surfaceVariant.withOpacity(isDark ? 0.16 : 0.45),
                  hoverValue,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Color.lerp(
                    theme.colorScheme.outlineVariant.withOpacity(isDark ? 0.05 : 0.4),
                    theme.colorScheme.primary.withOpacity(0.35),
                    hoverValue,
                  )!,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: _buildCover(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.playlist.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Color.lerp(
                                  theme.colorScheme.onSurface.withOpacity(0.85),
                                  theme.colorScheme.onSurface,
                                  hoverValue,
                                ),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.playlist.tracks.length} tracks',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color.lerp(
                          theme.colorScheme.onSurface.withOpacity(0.15),
                          theme.colorScheme.primary,
                          hoverValue,
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
        return Image.file(file, fit: BoxFit.cover);
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
        errorBuilder: (_, __, ___) => _iconFallback(),
      );
    }
    if (p.tracks.isNotEmpty && p.tracks.first.coverByted.isNotEmpty) {
      return Image.memory(p.tracks.first.coverByted, fit: BoxFit.cover);
    }

    return _iconFallback();
  }

  Widget _iconFallback() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
      child: Icon(
        Icons.queue_music_rounded,
        color: theme.colorScheme.onSurface.withOpacity(0.4),
        size: 22,
      ),
    );
  }
}