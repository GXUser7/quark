import 'package:quark/services/spotify_services.dart';

void main() async {
  print('=== Spotify service end-to-end test ===');
  final svc = SpotifyService();
  
  print('\n[1] Search for "Blinding Lights"...');
  final tracks = await svc.search('Blinding Lights', limit: 2);
  print('Found ${tracks.length} tracks.');
  
  if (tracks.isEmpty) {
    print('❌ Search returned no results!');
    return;
  }
  
  final track = tracks.first;
  print('✓ Track: ${track.title} by ${track.artists.join(", ")}');
  print('  Spotify ID: ${track.spotifyId}');
  print('  Cover: ${track.cover}');
  
  print('\n[2] Getting ISRC...');
  final isrc = await svc.getIsrc(track.spotifyId);
  print(isrc != null ? '✓ ISRC: $isrc' : '❌ ISRC not found');
  
  if (isrc != null) {
    print('\n[3] Getting Tidal ID by ISRC...');
    final tidalId = await svc.getTidalIdByIsrc(isrc);
    print(tidalId != null ? '✓ Tidal ID: $tidalId' : '❌ Tidal ID not found');
  }
  
  print('\n[4] Getting stream URL (full pipeline)...');
  final url = await svc.getStreamUrl(track);
  if (url != null) {
    print('✓ Stream URL: $url');
  } else {
    print('❌ Stream URL not resolved');
  }
}
