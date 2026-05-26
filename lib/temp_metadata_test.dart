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

String spotifyEntityIDToGID(String entityID, String alphabet) {
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

void main() async {
  final dio = Dio();
  
  print('1. Getting access token...');
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
  print('✓ Access token obtained.');

  const trackId = '0VjIjW4GlUZAMYd2vXMi3b';
  const alphabet1 = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const alphabet2 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

  final gid1 = spotifyEntityIDToGID(trackId, alphabet1);
  final gid2 = spotifyEntityIDToGID(trackId, alphabet2);

  print('✓ GID (lowercase first): $gid1');
  print('✓ GID (uppercase first): $gid2');

  for (var entry in [MapEntry('lowercase first', gid1), MapEntry('uppercase first', gid2)]) {
    final name = entry.key;
    final gid = entry.value;
    print('\nTrying $name: GID = $gid');
    final metadataUrl = 'https://spclient.wg.spotify.com/metadata/4/track/$gid?market=from_token';
    try {
      final resp = await dio.get(
        metadataUrl,
        options: Options(
          headers: {
            'authorization': 'Bearer $accessToken',
            'accept': 'application/json',
            'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
          },
        ),
      );
      print('✓ Success! Status: ${resp.statusCode}');
      final encoder = JsonEncoder.withIndent('  ');
      print('✓ Data: ${resp.data is Map ? encoder.convert(resp.data) : resp.data}');
      return;
    } on DioException catch (e) {
      print('✗ Failed: ${e.response?.statusCode} ${e.response?.statusMessage}');
    }
  }
}
