import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:quark/objects/track.dart';
import 'package:quark/services/database/database.dart';

class SpotifyService {
  static final SpotifyService _instance = SpotifyService._internal();
  factory SpotifyService() => _instance;

  final Dio _dio = Dio();
  String? _accessToken;
  String? _clientToken;
  String? _clientVersion;
  String? _clientId;
  int _tokenExpiryMs = 0;
  final _cookies = <String, String>{};

  // Tidal token (public, unauthenticated web player token)
  static const _tidalToken = 'CzET4vdadNUFQ5JU';

  // GDStudio hosts (fallback order)
  static const _gdStudioHosts = [
    'music.gdstudio.xyz',
    'music.gdstudio.org',
  ];

  SpotifyService._internal() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_cookies.isNotEmpty) {
          options.headers['Cookie'] = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final rawCookies = response.headers['set-cookie'];
        if (rawCookies != null) {
          for (var c in rawCookies) {
            final parts = c.split(';')[0].split('=');
            if (parts.length >= 2) {
              _cookies[parts[0].trim()] = parts.sublist(1).join('=').trim();
            }
          }
        }
        return handler.next(response);
      },
    ));
  }

  List<int> _decodeBase32(String secret) {
    const base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final cleanSecret = secret.replaceAll('=', '').toUpperCase();
    final bits = StringBuffer();
    for (var i = 0; i < cleanSecret.length; i++) {
      final val = base32Chars.indexOf(cleanSecret[i]);
      if (val == -1) continue;
      bits.write(val.toRadixString(2).padLeft(5, '0'));
    }
    final bytes = <int>[];
    final bitString = bits.toString();
    for (var i = 0; i + 8 <= bitString.length; i += 8) {
      bytes.add(int.parse(bitString.substring(i, i + 8), radix: 2));
    }
    return bytes;
  }

  String _generateTOTP(String secret, int timeMs) {
    final secretBytes = _decodeBase32(secret);
    final seconds = timeMs ~/ 1000;
    final counter = seconds ~/ 30;

    final counterBytes = Uint8List(8);
    var temp = counter;
    for (var i = 7; i >= 0; i--) {
      counterBytes[i] = temp & 0xff;
      temp >>= 8;
    }

    final hmac = Hmac(sha1, secretBytes);
    final hash = hmac.convert(counterBytes).bytes;

    final offset = hash[hash.length - 1] & 0x0f;
    var binary = ((hash[offset] & 0x7f) << 24) |
                 ((hash[offset + 1] & 0xff) << 16) |
                 ((hash[offset + 2] & 0xff) << 8) |
                 (hash[offset + 3] & 0xff);

    final digits = 6;
    final otp = binary % pow(10, digits).toInt();
    return otp.toString().padLeft(digits, '0');
  }

  Future<void> _ensureAuth() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_accessToken != null && _clientToken != null && now < _tokenExpiryMs) {
      return;
    }

    print('[SpotifyService] Authenticating Spotify anonymously...');
    _cookies.clear();

    // 1. Get open.spotify.com
    final mainResp = await _dio.get(
      'https://open.spotify.com',
      options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
        },
      ),
    );

    final body = mainResp.data.toString();
    final re = RegExp(r'<script id="appServerConfig" type="text/plain">([^<]+)</script>');
    final match = re.firstMatch(body);
    _clientVersion = '1.2.3.4';
    if (match != null) {
      try {
        final decoded = utf8.decode(base64.decode(match.group(1)!));
        final cfg = json.decode(decoded) as Map<String, dynamic>;
        _clientVersion = cfg['clientVersion'] as String;
      } catch (e) {
        print('[SpotifyService] Warning parsing clientVersion: $e');
      }
    }

    final deviceID = _cookies['sp_t'] ?? '';

    // 2. Get access token via TOTP
    final totp = _generateTOTP('GM3TMMJTGYZTQNZVGM4DINJZHA4TGOBYGMZTCMRTGEYDSMJRHE4TEOBUG4YTCMRUGQ4DQOJUGQYTAMRRGA2TCMJSHE3TCMBY', DateTime.now().millisecondsSinceEpoch);
    final tokenResp = await _dio.get(
      'https://open.spotify.com/api/token',
      queryParameters: {
        'reason': 'init',
        'productType': 'web-player',
        'totp': totp,
        'totpVer': '61',
        'totpServer': totp,
      },
      options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
        },
      ),
    );

    final tokenData = tokenResp.data as Map<String, dynamic>;
    _accessToken = tokenData['accessToken'] as String;
    _clientId = tokenData['clientId'] as String;

    // 3. Get client token
    final clientTokenResp = await _dio.post(
      'https://clienttoken.spotify.com/v1/clienttoken',
      data: {
        'client_data': {
          'client_version': _clientVersion,
          'client_id': _clientId,
          'js_sdk_data': {
            'device_brand': 'unknown',
            'device_brand_model': 'unknown',
            'device_model': 'unknown',
            'os': 'windows',
            'os_version': 'NT 10.0',
            'device_id': _cookies['sp_t'] ?? deviceID,
            'device_type': 'computer',
          },
        },
      },
      options: Options(
        headers: {
          'Authority': 'clienttoken.spotify.com',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
        },
      ),
    );

    final clientTokenData = clientTokenResp.data as Map<String, dynamic>;
    _clientToken = (clientTokenData['granted_token'] as Map<String, dynamic>)['token'] as String;

    _tokenExpiryMs = DateTime.now().millisecondsSinceEpoch + 55 * 60 * 1000;
    print('[SpotifyService] Spotify authenticated. Expiry in 55m.');
  }

  Future<List<SpotifyTrack>> search(String query, {int limit = 20, int offset = 0}) async {
    try {
      await _ensureAuth();
      final searchResp = await _dio.post(
        'https://api-partner.spotify.com/pathfinder/v2/query',
        data: {
          'variables': {
            'searchTerm': query,
            'offset': offset,
            'limit': limit,
            'numberOfTopResults': 5,
            'includeAudiobooks': true,
            'includeArtistHasConcertsField': false,
            'includePreReleases': true,
            'includeAuthors': false,
          },
          'operationName': 'searchDesktop',
          'extensions': {
            'persistedQuery': {
              'version': 1,
              'sha256Hash': 'fcad5a3e0d5af727fb76966f06971c19cfa2275e6ff7671196753e008611873c',
            },
          },
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Client-Token': _clientToken,
            'Spotify-App-Version': _clientVersion,
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
          },
        ),
      );

      final data = searchResp.data as Map<String, dynamic>;
      final searchV2 = data['data']?['searchV2'];
      final items = searchV2?['tracksV2']?['items'] ?? searchV2?['tracks']?['items'] ?? [];
      final List<SpotifyTrack> results = [];
      for (final item in items) {
        final trackData = item['item']?['data'];
        if (trackData == null) continue;
        final id = trackData['id'] as String? ?? '';
        final name = trackData['name'] as String? ?? 'Unknown';
        final durationMs = trackData['duration']?['milliseconds'] as num?;
        final durationSeconds = durationMs != null ? durationMs ~/ 1000 : 0;

        final albumData = trackData['albumOfTrack'];
        final albumName = albumData?['name'] as String? ?? '';
        final coverSources = albumData?['coverArt']?['sources'] as List? ?? [];
        final coverUrl = coverSources.isNotEmpty ? (coverSources[0]['url'] as String? ?? '') : '';

        final artistItems = trackData['artists']?['items'] as List? ?? [];
        final List<String> artists = [];
        for (final artist in artistItems) {
          final artistName = artist['profile']?['name'] as String?;
          if (artistName != null && artistName.isNotEmpty) {
            artists.add(artistName);
          }
        }
        if (artists.isEmpty) artists.add('Unknown Artist');

        results.add(SpotifyTrack(
          spotifyId: id,
          title: name,
          artists: artists,
          albums: [albumName],
          filepath: getSpotifyCachePath(id),
          coverType: coverUrl.isNotEmpty ? CoverType.url : CoverType.noCover,
          cover: coverUrl.isNotEmpty ? coverUrl : 'none',
          durationSeconds: durationSeconds,
        ));
      }
      return results;
    } catch (e, stackTrace) {
      print('[SpotifyService] Search failed: $e\n$stackTrace');
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        _accessToken = null;
        _clientToken = null;
      }
      return [];
    }
  }

  String spotifyEntityIDToGID(String entityID) {
    const alphabet = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    var value = BigInt.zero;
    final base = BigInt.from(62);
    for (var i = 0; i < entityID.length; i++) {
      final char = entityID[i];
      final index = alphabet.indexOf(char);
      if (index < 0) {
        throw Exception('Invalid base62 character: $char');
      }
      value = value * base + BigInt.from(index);
    }
    var hexValue = value.toRadixString(16);
    if (hexValue.length < 32) {
      hexValue = hexValue.padLeft(32, '0');
    }
    return hexValue;
  }

  Future<String?> getIsrc(String spotifyId) async {
    try {
      await _ensureAuth();
      final gid = spotifyEntityIDToGID(spotifyId);
      final url = 'https://spclient.wg.spotify.com/metadata/4/track/$gid?market=from_token';

      final resp = await _dio.get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Client-Token': _clientToken,
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
          },
        ),
      );

      final data = resp.data as Map<String, dynamic>;
      final extIds = data['external_id'] as List? ?? [];
      for (final extId in extIds) {
        if (extId['type']?.toString().toLowerCase() == 'isrc') {
          return extId['id']?.toString().toUpperCase();
        }
      }
    } catch (e) {
      print('[SpotifyService] Failed to fetch ISRC: $e');
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        _accessToken = null;
        _clientToken = null;
      }
    }
    return null;
  }

  /// Search for a Tidal track ID by ISRC.
  /// Uses Tidal's public unauthenticated web player API.
  Future<int?> getTidalIdByIsrc(String isrc) async {
    try {
      final resp = await _dio.get(
        'https://listen.tidal.com/v1/tracks',
        queryParameters: {'isrc': isrc, 'countryCode': 'US'},
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
            'X-Tidal-Token': _tidalToken,
          },
        ),
      );

      if (resp.data is Map) {
        final items = resp.data['items'] as List? ?? [];
        if (items.isNotEmpty) {
          final id = items[0]['id'];
          if (id is int) return id;
          if (id is num) return id.toInt();
        }
      }
    } catch (e) {
      print('[SpotifyService] Tidal ISRC lookup failed: $e');
    }
    return null;
  }

  /// Build GDStudio signature for a given host, timestamp, and track ID.
  String _gdStudioSignature(String host, String ts9, String trackId) {
    final escaped = Uri.encodeQueryComponent(trackId).replaceAll('+', '%20');
    final signBase = '$host|20260510|$ts9|$escaped';
    final digest = md5.convert(utf8.encode(signBase)).toString().toLowerCase();
    return digest.substring(digest.length - 8).toUpperCase();
  }

  List<String> _bitratePreferenceOrder() {
    const allBrValues = ['1400', '999', '740', '320'];
    final preferred = mapSpotifyQuality(DatabaseStreamerService().spotifyQuality.value);
    final ordered = <String>[preferred];
    for (final br in allBrValues) {
      if (!ordered.contains(br)) ordered.add(br);
    }
    return ordered;
  }

  /// Resolve a stream URL from GDStudio for a given Tidal track ID.
  Future<String?> _resolveGDStudioTidal(int tidalId) async {
    final brValues = _bitratePreferenceOrder();

    for (final host in _gdStudioHosts) {
      String ts9;
      try {
        final timeResp = await _dio.get(
          'https://$host/time',
          options: Options(
            headers: {'User-Agent': 'Mozilla/5.0'},
          ),
        );
        final tsStr = timeResp.data?.toString().trim() ?? '';
        ts9 = tsStr.length >= 9 ? tsStr.substring(0, 9) : tsStr;
      } catch (_) {
        ts9 = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
        if (ts9.length >= 9) ts9 = ts9.substring(0, 9);
      }

      final sig = _gdStudioSignature(host, ts9, tidalId.toString());

      for (final br in brValues) {
        try {
          final resp = await _dio.post(
            'https://$host/api.php',
            data: {
              'types': 'url',
              'id': tidalId.toString(),
              'source': 'tidal',
              'br': br,
              's': sig,
            },
            options: Options(
              contentType: Headers.formUrlEncodedContentType,
              headers: {
                'Origin': 'https://$host',
                'Referer': 'https://$host/',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
              },
            ),
          );

          if (resp.data is Map) {
            final url = resp.data['url'] as String?;
            if (url != null && url.isNotEmpty) {
              print('[SpotifyService] Resolved via GDStudio/$host (Tidal/$tidalId, br=$br)');
              return url;
            }
          }
        } catch (e) {
          print('[SpotifyService] GDStudio/$host br=$br failed: $e');
        }
      }
    }
    return null;
  }

  String mapSpotifyQuality(String dbQuality) {
    switch (dbQuality) {
      case 'hires':
        return '1400';
      case 'lossless':
        return '999';
      case 'nq':
      case 'lq':
      case 'mp3':
      default:
        return '320';
    }
  }

  String? extractStreamUrl(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    bool isStreamable(String? url) {
      if (url == null) return false;
      final uri = Uri.tryParse(url.trim());
      return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    }

    try {
      final decoded = jsonDecode(trimmed);

      String? findInPayload(dynamic payload) {
        if (payload is String) {
          final candidate = payload.replaceAll(r'\/', '/').trim();
          if (isStreamable(candidate)) return candidate;
        } else if (payload is List) {
          for (final item in payload) {
            final res = findInPayload(item);
            if (res != null) return res;
          }
        } else if (payload is Map) {
          for (final key in ["download_url", "url", "play_url", "stream_url", "link", "file"]) {
            if (payload.containsKey(key)) {
              final res = findInPayload(payload[key]);
              if (res != null) return res;
            }
          }
          for (final val in payload.values) {
            final res = findInPayload(val);
            if (res != null) return res;
          }
        }
        return null;
      }

      final res = findInPayload(decoded);
      if (res != null) return res;
    } catch (_) {}

    final openIdx = trimmed.indexOf('(');
    if (openIdx >= 0) {
      final closeIdx = trimmed.lastIndexOf(')');
      if (closeIdx > openIdx + 1) {
        final callbackBody = trimmed.substring(openIdx + 1, closeIdx).trim();
        final res = extractStreamUrl(callbackBody);
        if (res != null) return res;
      }
    }

    final urlRegex = RegExp(r'https?://[^\s"<>\\)]+');
    final matches = urlRegex.allMatches(trimmed);
    for (final match in matches) {
      final candidate = match.group(0)!.replaceAll(r'\/', '/').trim();
      if (isStreamable(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  Future<String?> getStreamUrl(SpotifyTrack track) async {
    final cached = track.streamUrl;
    if (cached != null && cached.isNotEmpty && cached.startsWith('http')) {
      return cached;
    }

    print('[SpotifyService] Resolving stream url for: ${track.title}');

    // Step 1: Get ISRC from Spotify metadata
    final isrc = await getIsrc(track.spotifyId);
    if (isrc == null || isrc.isEmpty) {
      print('[SpotifyService] Failed to find ISRC for track: ${track.title}');
      return null;
    }
    print('[SpotifyService] Found ISRC: $isrc');

    // Step 2: Look up Tidal track ID by ISRC
    final tidalId = await getTidalIdByIsrc(isrc);
    if (tidalId == null) {
      print('[SpotifyService] Tidal track not found for ISRC: $isrc');
      return null;
    }
    print('[SpotifyService] Found Tidal Track ID: $tidalId');

    // Step 3: Resolve stream URL from GDStudio (Tidal source)
    final streamUrl = await _resolveGDStudioTidal(tidalId);
    if (streamUrl != null) {
      track.streamUrl = streamUrl;
      print('[SpotifyService] Successfully resolved stream url.');
      return streamUrl;
    }

    print('[SpotifyService] All resolvers failed.');
    return null;
  }
}
