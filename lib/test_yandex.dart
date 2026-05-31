import 'package:flutter/material.dart';
import 'package:quark/services/database/database.dart';
import 'package:quark/services/yandex_music_singleton.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('=== Yandex Music Playlist Integration Test ===');
  
  // Initialize Database settings streamer (requires Hive initialized)
  try {
    print('Initializing Hive database...');
    await Database.init();
    print('✓ Hive initialized successfully.');
  } catch (e) {
    print('⚠ Hive initialization warning/failure (expected in pure command runs): $e');
  }

  final token = DatabaseStreamerService().yandexMusicToken.value;
  print('Yandex Music Token: ${token.isNotEmpty ? "Found (Truncated: ${token.substring(0, 10)}...)" : "NOT FOUND (Empty)"}');

  if (token.isEmpty) {
    print('❌ Error: Yandex Music token is empty. Please log in via the app interface first.');
    return;
  }

  print('\n[1] Initializing Yandex Music instance...');
  final yandex = YandexMusic(token: token);
  YandexMusicSingleton.init(yandex);
  print('✓ Yandex Music initialized.');

  print('\n[2] Fetching user playlists...');
  try {
    final playlists = await yandex.usertracks.getPlaylistsWithLikes();
    print('✓ Successfully loaded ${playlists.length} playlists.');
    
    for (int i = 0; i < playlists.length; i++) {
      final pl = playlists[i];
      print('  [$i] "${pl.title}" (UUID: ${pl.playlistUuid}, track count: ${pl.tracks.length})');
    }

    if (playlists.isEmpty) {
      print('❌ No playlists found on this Yandex Music account!');
      return;
    }

    // Grab first playlist and load its tracks
    final targetPlaylist = playlists.first;
    print('\n[3] Fetching tracks for playlist: "${targetPlaylist.title}" (UUID: ${targetPlaylist.playlistUuid})...');
    
    // Get full playlist details (which contains actual track metadata)
    final fullPlaylist = await yandex.playlists.getPlaylistByUuid(targetPlaylist.playlistUuid);
    final tracks = fullPlaylist.tracks;
    print('✓ Found ${tracks.length} tracks in this playlist.');

    if (tracks.isEmpty) {
      print('❌ The playlist is empty!');
      return;
    }

    // Try resolving download link for the first track
    final firstTrack = tracks.first;
    print('\n[4] Resolving playable stream link for track: "${firstTrack.title}" (ID: ${firstTrack.id})');
    
    final link = await yandex.tracks.getDownloadLink(
      firstTrack.id,
      quality: AudioQuality.normal,
    );
    print('✓ Resolved Stream URL: $link');
    print('\n🎉 All Yandex Music playlist resolution checks passed!');
  } catch (e, st) {
    print('❌ Error during Yandex Music playlist testing: $e');
    print(st);
  }
}
