import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quark/objects/playlist.dart';
import 'package:quark/services/spotify_services.dart';
import 'package:quark/services/cached_images.dart';

class SpotifyPlaylistsWidget extends StatefulWidget {
  final Function() closeView;
  final List<Map<String, dynamic>> initialPlaylists;
  final Function(PlayerPlaylist playlist) playlistRouter;

  const SpotifyPlaylistsWidget({
    super.key,
    required this.closeView,
    required this.initialPlaylists,
    required this.playlistRouter,
  });

  @override
  State<SpotifyPlaylistsWidget> createState() => _SpotifyPlaylistsWidgetState();
}

class _SpotifyPlaylistsWidgetState extends State<SpotifyPlaylistsWidget> {
  late List<Map<String, dynamic>> _playlists;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _playlists = widget.initialPlaylists;
  }

  Future<void> _refreshPlaylists() async {
    setState(() => _loading = true);
    try {
      final fresh = await SpotifyService().getUserPlaylists();
      if (mounted) {
        setState(() {
          _playlists = fresh;
        });
      }
    } catch (e) {
      print('[SpotifyPlaylistsWidget] Refresh error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
              color: Colors.black.withOpacity(0.4),
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
              children: [
                Column(
                  children: [
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Image.network(
                                'https://storage.googleapis.com/pr-newsroom-wp/1/2023/05/Spotify_Primary_Logo_RGB_Green.png',
                                width: 28,
                                height: 28,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.music_note_rounded,
                                  color: Color(0xFF1DB954),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Spotify Playlists',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                                onPressed: _refreshPlaylists,
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                                onPressed: widget.closeView,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    // Grid of Playlists
                    Expanded(
                      child: _playlists.isEmpty
                          ? const Center(
                              child: Text(
                                'No Spotify playlists found.',
                                style: TextStyle(color: Colors.white60, fontSize: 16),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(24.0),
                              child: Wrap(
                                spacing: 16.0,
                                runSpacing: 16.0,
                                alignment: WrapAlignment.center,
                                children: List.generate(
                                  _playlists.length,
                                  (index) {
                                    final p = _playlists[index];
                                    final coverUrl = p['cover'] as String;
                                    final name = p['name'] as String;
                                    final trackCount = p['track_count'] as int;
                                    final id = p['id'] as String;

                                    return Container(
                                      width: 290,
                                      height: 290,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(Radius.circular(15)),
                                        image: DecorationImage(
                                          image: coverUrl.isNotEmpty
                                              ? CachedImageProvider(coverUrl)
                                              : const AssetImage('assets/nocover.png') as ImageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        clipBehavior: Clip.antiAlias,
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(15),
                                        child: InkWell(
                                          onTap: () async {
                                            if (_loading) return;
                                            setState(() => _loading = true);

                                            try {
                                              final tracks = await SpotifyService().getPlaylistTracks(id);
                                              if (tracks.isEmpty) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Failed to load playlist tracks or playlist is empty.')),
                                                  );
                                                }
                                                return;
                                              }

                                              widget.closeView();

                                              widget.playlistRouter(
                                                PlayerPlaylist(
                                                  ownerUid: 0,
                                                  kind: id.hashCode,
                                                  name: name,
                                                  tracks: tracks,
                                                  source: PlaylistSource.spotify,
                                                ),
                                              );
                                            } catch (e) {
                                              print('[SpotifyPlaylistsWidget] Error loading playlist tracks: $e');
                                            } finally {
                                              if (mounted) setState(() => _loading = false);
                                            }
                                          },
                                          child: Stack(
                                            children: [
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
                                                        Colors.black.withOpacity(0.9),
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
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 20,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '$trackCount tracks',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
                if (_loading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1DB954),
                        ),
                      ),
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
