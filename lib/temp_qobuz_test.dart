import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  
  const isrc = 'USUG11904206'; // Blinding Lights ISRC
  
  // Step 1: Get Tidal ID via ISRC
  print('=== Step 1: Tidal ISRC lookup ===');
  int? tidalId;
  try {
    final r = await dio.get(
      'https://listen.tidal.com/v1/tracks',
      queryParameters: {'isrc': isrc, 'countryCode': 'US'},
      options: Options(
        validateStatus: (s) => true,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'X-Tidal-Token': 'CzET4vdadNUFQ5JU',
        },
      ),
    );
    print('Status: ${r.statusCode}');
    if (r.data is Map) {
      final items = r.data['items'] as List? ?? [];
      print('Found ${items.length} tracks for ISRC $isrc');
      if (items.isNotEmpty) {
        tidalId = items[0]['id'] as int?;
        print('Best Tidal ID: $tidalId (title: ${items[0]['title']})');
      }
    }
  } catch (e) { print('Error: $e'); }

  if (tidalId == null) {
    print('Could not get Tidal ID, aborting.');
    return;
  }

  // Step 2: Resolve stream URL via GDStudio
  print('\n=== Step 2: GDStudio stream resolution ===');
  final host = 'music.gdstudio.xyz';
  var ts9 = '';
  try {
    final t = await dio.get('https://$host/time', options: Options(headers: {'User-Agent': 'Mozilla/5.0'}));
    final tsStr = t.data?.toString().trim() ?? '';
    if (tsStr.length >= 9) ts9 = tsStr.substring(0, 9);
  } catch (_) {}
  if (ts9.isEmpty) {
    ts9 = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    if (ts9.length >= 9) ts9 = ts9.substring(0, 9);
  }

  final escaped = Uri.encodeQueryComponent(tidalId.toString()).replaceAll('+', '%20');
  final signBase = '$host|20260510|$ts9|$escaped';
  final digest = md5.convert(utf8.encode(signBase)).toString();
  final sig = digest.substring(digest.length - 8).toUpperCase();

  String? streamUrl;
  for (final br in ['1400', '999', '740', '320']) {
    final r = await dio.post(
      'https://music.gdstudio.xyz/api.php',
      data: {'types': 'url', 'id': tidalId.toString(), 'source': 'tidal', 'br': br, 's': sig},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        validateStatus: (s) => true,
        headers: {'Origin': 'https://$host', 'Referer': 'https://$host/', 'User-Agent': 'Mozilla/5.0'},
      ),
    );
    final body = r.data?.toString() ?? '';
    print('br=$br → ${r.statusCode}: $body');
    if (r.data is Map && (r.data['url'] as String?)?.isNotEmpty == true) {
      streamUrl = r.data['url'] as String;
      break;
    }
  }

  if (streamUrl != null) {
    print('\n✓ Got stream URL: $streamUrl');
    // Verify it's accessible
    try {
      final headResp = await dio.head(
        streamUrl,
        options: Options(
          validateStatus: (s) => true,
          headers: {'User-Agent': 'Mozilla/5.0'},
        ),
      );
      print('HEAD response: ${headResp.statusCode}');
      print('Content-Type: ${headResp.headers.value('content-type')}');
      print('Content-Length: ${headResp.headers.value('content-length')}');
    } catch (e) { print('HEAD check failed: $e'); }
  }
}
