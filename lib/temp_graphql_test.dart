import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

List<int> decodeBase32(String secret) {
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

String generateTOTP(String secret, int timeMs) {
  final secretBytes = decodeBase32(secret);
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

const spotifyTOTPSecret = 'GM3TMMJTGYZTQNZVGM4DINJZHA4TGOBYGMZTCMRTGEYDSMJRHE4TEOBUG4YTCMRUGQ4DQOJUGQYTAMRRGA2TCMJSHE3TCMBY';

void main() async {
  final dio = Dio();
  final cookies = <String, String>{};
  
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (cookies.isNotEmpty) {
        options.headers['Cookie'] = cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      }
      return handler.next(options);
    },
    onResponse: (response, handler) {
      final rawCookies = response.headers['set-cookie'];
      if (rawCookies != null) {
        for (var c in rawCookies) {
          final parts = c.split(';')[0].split('=');
          if (parts.length >= 2) {
            cookies[parts[0].trim()] = parts.sublist(1).join('=').trim();
          }
        }
      }
      return handler.next(response);
    },
  ));

  print('1. Getting session info (open.spotify.com)...');
  final mainResp = await dio.get(
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
  String clientVersion = '1.2.3.4';
  if (match != null) {
    try {
      final decoded = utf8.decode(base64.decode(match.group(1)!));
      final cfg = json.decode(decoded) as Map<String, dynamic>;
      clientVersion = cfg['clientVersion'] as String;
    } catch (e) {
      print('Warning parsing clientVersion: $e');
    }
  }
  print('✓ clientVersion: $clientVersion');

  final deviceID = cookies['sp_t'] ?? '';
  print('✓ deviceID (sp_t): $deviceID');

  print('2. Getting access token...');
  final totp = generateTOTP(spotifyTOTPSecret, DateTime.now().millisecondsSinceEpoch);
  final tokenResp = await dio.get(
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
  final accessToken = tokenData['accessToken'] as String;
  final clientId = tokenData['clientId'] as String;
  print('✓ accessToken obtained.');

  print('3. Getting client token...');
  final clientTokenResp = await dio.post(
    'https://clienttoken.spotify.com/v1/clienttoken',
    data: {
      'client_data': {
        'client_version': clientVersion,
        'client_id': clientId,
        'js_sdk_data': {
          'device_brand': 'unknown',
          'device_model': 'unknown',
          'os': 'windows',
          'os_version': 'NT 10.0',
          'device_id': cookies['sp_t'] ?? deviceID,
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
  final clientToken = (clientTokenData['granted_token'] as Map<String, dynamic>)['token'] as String;
  print('✓ clientToken obtained.');

  print('4. Querying GraphQL searchDesktop for "Blinding Lights"...');
  String? foundTrackId;
  try {
    final searchResp = await dio.post(
      'https://api-partner.spotify.com/pathfinder/v2/query',
      data: {
        'variables': {
          'searchTerm': 'The Weeknd Blinding Lights',
          'offset': 0,
          'limit': 10,
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
          'Authorization': 'Bearer $accessToken',
          'Client-Token': clientToken,
          'Spotify-App-Version': clientVersion,
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
        },
      ),
    );
    
    final data = searchResp.data as Map<String, dynamic>;
    final searchV2 = data['data']?['searchV2'];
    final tracks = searchV2?['tracksV2']?['items'] ?? searchV2?['tracks']?['items'] ?? [];
    print('✓ Found ${tracks.length} tracks in search.');
    if (tracks.isNotEmpty) {
      final firstTrack = tracks[0]['item']?['data'];
      if (firstTrack != null) {
        foundTrackId = firstTrack['id'] as String?;
        final trackName = firstTrack['name'];
        print('✓ First track: ID=$foundTrackId, Name=$trackName');
      }
    }
  } on DioException catch (e) {
    print('✗ Search request failed: $e');
  }

  if (foundTrackId != null) {
    print('5. Querying GraphQL getTrack for ID $foundTrackId...');
    try {
      final gqlResp = await dio.post(
        'https://api-partner.spotify.com/pathfinder/v2/query',
        data: {
          'variables': {
            'uri': 'spotify:track:$foundTrackId',
          },
          'operationName': 'getTrack',
          'extensions': {
            'persistedQuery': {
              'version': 1,
              'sha256Hash': '612585ae06ba435ad26369870deaae23b5c8800a256cd8a57e08eddc25a37294',
            },
          },
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Client-Token': clientToken,
            'Spotify-App-Version': clientVersion,
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
          },
        ),
      );
      print('✓ GraphQL getTrack response status: ${gqlResp.statusCode}');
      final respData = gqlResp.data as Map<String, dynamic>;
      final trackUnion = respData['data']?['trackUnion'];
      if (trackUnion != null) {
        print('✓ trackUnion type: ${trackUnion['__typename']}');
        print('✓ Name: ${trackUnion['name']}');
        print('✓ Album: ${trackUnion['albumOfTrack']?['name']}');
        print('✓ ISRC: ${trackUnion['externalIds']?['isrcs']?['items']}');
      } else {
        print('✗ trackUnion is null: $respData');
      }
    } on DioException catch (e) {
      print('✗ GraphQL request failed: $e');
    }
  }
}
