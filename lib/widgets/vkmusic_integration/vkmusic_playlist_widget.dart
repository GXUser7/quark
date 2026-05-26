import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:quark/objects/playlist.dart';
import 'package:quark/objects/track.dart';
import 'package:quark/services/database/database.dart';
import 'package:quark/services/vkmusic.dart';
import 'package:quark/services/vkmusic_services.dart';


class VkMusicPlaylists extends StatefulWidget {
  final Function() closeView;
  final Function(PlayerPlaylist playlist) playlistRouter;
  final String? authToken; // JWT токен пользователя для авторизации в API

  const VkMusicPlaylists({
    super.key,
    required this.closeView,
    required this.playlistRouter,
    this.authToken,
  });

  @override
  State<VkMusicPlaylists> createState() => _VkMusicPlaylistsState();
}

class _VkMusicPlaylistsState extends State<VkMusicPlaylists> {
  bool _loading = true;
  bool _enabled = true;
  String? _error;
  List<VkPlaylist> _playlists = [];

  late final VkMusicService _vkService;

  @override
  void initState() {
    super.initState();
    _vkService = VkMusicService();
    _vkService.setAuthToken(DatabaseStreamerService().accessToken.value);
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final playlists = await _vkService.getMyPlaylists(count: 50, offset: 0);

      if (!mounted) return;
      setState(() {
        _playlists = playlists;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _formatError(e);
        _loading = false;
      });
    }
  }
  

  String _formatError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('private') || msg.contains('access denied') || msg.contains('403')) {
      return 'Аудиозаписи приватны.\nПроверьте настройки приватности ВКонтакте.';
    }
    if (msg.contains('token') || msg.contains('401') || msg.contains('unauthorized')) {
      return 'VK-токен не подключён.\nПодключите аккаунт в настройках.';
    }
    if (msg.contains('timeout') || msg.contains('connection')) {
      return 'Ошибка соединения.\nПроверьте интернет и попробуйте снова.';
    }
    return 'Ошибка: ${e.toString()}';
  }

  Future<void> _onPlaylistTap(VkPlaylist playlist) async {
    if (!_enabled) return;
    setState(() => _enabled = false);

    try {
      final pureId = playlist.id.contains('_')
          ? playlist.id.split('_').last
          : playlist.id;

      final songs = await _vkService.getPlaylistSongs(count: 100, playlistId: playlist.id, accessKey: playlist.accessKey!);

      if (!mounted) return;

      final tracks = songs.map((s) => s.toTrack()).cast<PlayerTrack>().toList();

      await widget.closeView();

      widget.playlistRouter(
        PlayerPlaylist(
          kind: 0,
          ownerUid: playlist.ownerId ?? 0,
          name: playlist.title,
          tracks: tracks,
          source: PlaylistSource.vkmusic,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enabled = true);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Ошибка загрузки',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            _formatError(e),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _error = null;
                                });
                                _loadPlaylists();
                              },
                              child: const Text(
                                'Повторить',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: widget.closeView,
                              child: const Text(
                                'Закрыть',
                                style: TextStyle(color: Colors.white60),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : _playlists.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.playlist_play_outlined,
                          color: Colors.white54,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Плейлисты не найдены',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Создайте плейлисты во ВКонтакте,\nчтобы они появились здесь',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
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
                          onTap: () => _onPlaylistTap(playlist),
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

// ============================================================================
// Карточка плейлиста (визуально идентична YTMusic версии)
// ============================================================================

class _PlaylistCard extends StatelessWidget {
  final VkPlaylist playlist;
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
        image: playlist.photo != null
            ? DecorationImage(
                image: NetworkImage(playlist.photo!),
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
              // Placeholder если нет обложки
              if (playlist.photo == null)
                const Center(
                  child: Icon(
                    Icons.music_note,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),

              // Градиент и название внизу
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        playlist.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (playlist.count != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${playlist.count} трек${_pluralize(playlist.count!, 'а', 'ов')}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Индикатор загрузки при блокировке
              if (!enabled)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  ),
                ),

              // Оверлей при наведении (опционально, для десктопа)
              // if (enabled)
              //   Positioned.fill(
              //     child: Material(
              //       color: Colors.transparent,
              //       child: InkWell(
              //         onTap: onTap,
              //         hoverColor: Colors.white.withOpacity(0.1),
              //       ),
              //     ),
              //   ),
            ],
          ),
        ),
      ),
    );
  }

  /// Склонение слов "трек/трека/треков"
  String _pluralize(int count, String one, String many) {
    final remainder = count % 10;
    final tens = count % 100;
    if (tens >= 11 && tens <= 14) return many;
    if (remainder == 1) return '';
    if (remainder >= 2 && remainder <= 4) return one;
    return many;
  }
}