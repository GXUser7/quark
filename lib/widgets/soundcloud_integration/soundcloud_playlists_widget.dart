import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quark/objects/playlist.dart';
import 'package:quark/objects/track.dart';
import 'package:quark/services/database/library_engine.dart';
import 'package:quark/services/database/settings_engine.dart';
import 'package:quark/services/soundcloud.dart';
import 'package:quark/services/soundcloud_services.dart';
import 'package:quark/widgets/soundcloud_integration/soundcloud_login.dart';

class SoundCloudPlaylistsWidget extends StatefulWidget {
  final Function() closeView;
  final Function(PlayerPlaylist playlist) playlistRouter;

  const SoundCloudPlaylistsWidget({
    super.key,
    required this.closeView,
    required this.playlistRouter,
  });

  @override
  State<SoundCloudPlaylistsWidget> createState() =>
      _SoundCloudPlaylistsWidgetState();
}

class _SoundCloudPlaylistsWidgetState extends State<SoundCloudPlaylistsWidget> {
  bool _loading = false;
  bool _enabled = true;
  String? _error;
  String? _profileUrl;
  List<SoundCloudPlaylist> _playlists = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final savedUrl = await Database.get("scProfileUrl");
      if (savedUrl != null && savedUrl.isNotEmpty) {
        setState(() => _profileUrl = savedUrl);
        _loadPlaylists(savedUrl);
      } else {
        _openLogin();
      }
    });
  }

  void _openLogin() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => SoundCloudLoginPage(
          onLoggedIn: (profileUrl, oauthToken) {
            Database.put("scOauthToken", oauthToken);
            Database.put("scProfileUrl", profileUrl);
            if (mounted) {
              setState(() => _profileUrl = profileUrl);
              _loadPlaylists(profileUrl);
            }
          },
        ),
      ),
    );
  }

  Future<void> _loadPlaylists(String url) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final playlists = await SoundCloudService().getUserPlaylists(url);
      if (!mounted) return;
      setState(() {
        _playlists = playlists;
        _loading = false;
      });
      // _debugStreamUrls(playlists);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _debugStreamUrls(List<SoundCloudPlaylist> playlists) async {
    print('[SC Debug] === Resolving stream URLs ===');
    for (final playlist in playlists) {
      print('[SC Debug] Playlist: ${playlist.title}');
      try {
        final tracks = await SoundCloudService().getPlaylistTracks(playlist.id);
        for (final track in tracks) {
          final url = await SoundCloudService().getStreamUrlWithOAuth(track.id);
          print('[SC Debug]   ${track.title} → $url');
        }
      } catch (e) {
        print('[SC Debug]   error: $e');
      }
    }
    print('[SC Debug] === Done ===');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Center(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
          child: Container(
            width: min(size.width * 0.92, 1040),
            height: min(size.height * 0.92, 1036),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
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
            child: Column(
              children: [
                // шапка с профилем и кнопкой смены аккаунта
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_queue,
                        color: Color(0xFFFF5500),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _profileUrl ?? '—',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                            fontFamily: 'noto',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: _openLogin,
                        child: Text(
                          'Сменить аккаунт',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),

                // контент
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _loadPlaylists(_profileUrl!),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    if (_playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_queue,
              color: Colors.white.withOpacity(0.2),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _profileUrl == null
                  ? 'Войдите в аккаунт SoundCloud'
                  : 'Плейлистов не найдено',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: _playlists
            .map(
              (playlist) => _SCPlaylistCard(
                playlist: playlist,
                enabled: _enabled,
                onTap: () async {
                  if (!_enabled) return;
                  setState(() => _enabled = false);
                  try {
                    final tracks = await SoundCloudService().getPlaylistTracks(
                      playlist.id,
                    );
                    final playerTracks = tracks
                        .map((t) => t.toPlayerTrack())
                        .toList();
                    await widget.closeView();
                    widget.playlistRouter(
                      PlayerPlaylist(
                        kind: 0,
                        ownerUid: 0,
                        name: playlist.title,
                        tracks: playerTracks,
                        source: PlaylistSource.local,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _enabled = true);
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Error'),
                        content: Text(e.toString()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SCPlaylistCard extends StatelessWidget {
  final SoundCloudPlaylist playlist;
  final bool enabled;
  final VoidCallback onTap;

  const _SCPlaylistCard({
    required this.playlist,
    required this.enabled,
    required this.onTap,
  });

  String? get _fixedThumbnail {
    final t = playlist.thumbnailUrl;
    if (t == null) return null;
    if (t.startsWith('https//')) return t.replaceFirst('https//', 'https://');
    if (t.startsWith('http//')) return t.replaceFirst('http//', 'http://');
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      height: 310,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        color: Colors.white.withOpacity(0.1),
        image: _fixedThumbnail != null
            ? DecorationImage(
                image: NetworkImage(_fixedThumbnail!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Material(
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Stack(
            children: [
              if (_fixedThumbnail == null)
                const Center(
                  child: Icon(
                    Icons.cloud_queue,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),

              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: playlist.isAlbum
                        ? const Color(0xFFFF5500).withOpacity(0.85)
                        : Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    playlist.isAlbum ? 'Album' : 'Playlist',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(15),
                      bottomRight: Radius.circular(15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'noto',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (playlist.trackCount > 0)
                        Text(
                          '${playlist.trackCount.toInt()} tracks',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (!enabled)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
