// widgets/ytmusic_integration/ytmusic_playlists_widget.dart
import 'dart:math';
import 'dart:ui';
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quark/objects/playlist.dart';
import 'package:quark/objects/track.dart';
import '../services/youtube_music/ytmusic.dart';
import 'package:quark/services/youtube_music/ytmusic_services.dart';

class YTMusicPlaylists extends StatefulWidget {
  final Function() closeView;
  final XFile cookieFile;
  final Function(PlayerPlaylist playlist) playlistRouter;

  const YTMusicPlaylists({
    super.key,
    required this.closeView,
    required this.cookieFile,
    required this.playlistRouter,
  });

  @override
  State<YTMusicPlaylists> createState() => _YTMusicPlaylistsState();
}

class _YTMusicPlaylistsState extends State<YTMusicPlaylists> {
  bool _loading = true;
  bool _enabled = true;
  String? _error;
  List<YTMusicPlaylist> _playlists = [];

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final response = await YTMusicAPI().getAuthPlaylists(widget.cookieFile);

      if (!mounted) return;
      setState(() {
        _playlists = response.playlists;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _loadPlaylists();
                          },
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(36.0),
                    child: Wrap(
                      spacing: 16.0,
                      runSpacing: 16.0,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: List.generate(_playlists.length, (index) {
                        final playlist = _playlists[index];
                        return _PlaylistCard(
                          playlist: playlist,
                          enabled: _enabled,
                          onTap: () async {
                            if (!_enabled) return;
                            setState(() => _enabled = false);

                            try {
                              final response = await YTMusicAPI().getPlaylist(
                                widget.cookieFile,
                                playlist.id,
                                "ba",
                              );

                              final tracks = response.allTracks
                                  .map(
                                    (yt) => YTMusicTrack.fromApiTrack(yt.raw),
                                  )
                                  .toList();

                              await widget.closeView();

                              widget.playlistRouter(
                                PlayerPlaylist(
                                  kind: 0,
                                  ownerUid: 0,
                                  name: playlist.title,
                                  tracks: tracks,
                                  source: PlaylistSource.youtube,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              setState(() => _enabled = true);
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('err'),
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
                        );
                      }),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final YTMusicPlaylist playlist;
  final bool enabled;
  final VoidCallback onTap;

  const _PlaylistCard({
    required this.playlist,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      height: 310,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        color: Colors.white.withOpacity(0.1),
        image: playlist.thumbnail != null
            ? DecorationImage(
                image: NetworkImage(playlist.thumbnail!),
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
              if (playlist.thumbnail == null)
                const Center(
                  child: Icon(
                    Icons.music_note,
                    color: Colors.white54,
                    size: 64,
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
                  child: Text(
                    playlist.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
