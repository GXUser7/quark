import 'dart:convert';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  const apiURL = 'https://www.musicdl.me/api/qobuz/download';
  const trackId = 341032040;
  const debugKey = 'ryzmicisgoatedandnothingcomesevenclose';

  print('Sending POST to MusicDL download API...');
  try {
    final resp = await dio.post(
      apiURL,
      data: {
        'url': 'https://open.qobuz.com/track/$trackId',
        'quality': '6',
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-Debug-Key': debugKey,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
        },
      ),
    );
    print('✓ Status code: ${resp.statusCode}');
    print('✓ Response data: ${resp.data}');
  } on DioException catch (e) {
    print('✗ POST request failed: $e');
    print('Response body: ${e.response?.data}');
  } catch (e) {
    print('✗ POST request failed: $e');
  }
}
