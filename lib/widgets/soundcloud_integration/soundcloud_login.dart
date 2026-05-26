import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

class SoundCloudLoginPage extends StatefulWidget {
  final Function(String profileUrl, String oauthToken) onLoggedIn;
  const SoundCloudLoginPage({super.key, required this.onLoggedIn});

  @override
  State<SoundCloudLoginPage> createState() => _SoundCloudLoginPageState();
}

class _SoundCloudLoginPageState extends State<SoundCloudLoginPage> {
  bool _extracting = false;
  InAppWebViewController? _webController;
  String? _capturedToken;

  static final _interceptorScript = UserScript(
    source: '''
      (function() {
        // Перехват fetch
        const _origFetch = window.fetch.bind(window);
        window.fetch = async function(input, init) {
          const headers = (init && init.headers) ? init.headers : {};
          const auth = headers['Authorization'] || headers['authorization'];
          if (auth && auth.startsWith('OAuth ') && !window._scToken) {
            window._scToken = auth;
            console.log('[SC Interceptor] fetch token captured');
          }
          return _origFetch(input, init);
        };

        // Перехват XHR
        const _origSetHeader = XMLHttpRequest.prototype.setRequestHeader;
        XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
          if (
            name.toLowerCase() === 'authorization' &&
            value.startsWith('OAuth ') &&
            !window._scToken
          ) {
            window._scToken = value;
            console.log('[SC Interceptor] xhr token captured');
          }
          return _origSetHeader.call(this, name, value);
        };
      })();
    ''',
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  );

  Future<void> _tryExtractProfile() async {
    if (_extracting || _webController == null) return;

    final tokenRaw = await _webController!.evaluateJavascript(
      source: 'window._scToken || null',
    );
    final token = tokenRaw?.toString().replaceAll('"', '').trim();

    if (token == null || token == 'null' || !token.startsWith('OAuth ')) {
      print('[SC Login] token not captured yet');
      return;
    }

    // Не дублируем попытки с тем же токеном
    if (token == _capturedToken) return;
    _capturedToken = token;

    print('[SC Login] token: $token');
    if (!mounted) return;
    setState(() => _extracting = true);

    try {
      // HTTP запрос прямо из Dart — никакого CORS
      final response = await http.get(
        Uri.parse('https://api-v2.soundcloud.com/me'),
        headers: {
          'Authorization': token,
          'Accept': 'application/json',
          'Origin': 'https://soundcloud.com',
          'Referer': 'https://soundcloud.com/',
        },
      );

      print('[SC Login] /me status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final permalink = data['permalink'] as String?;
        print('[SC Login] permalink: $permalink');

        if (permalink != null && permalink.isNotEmpty) {
          final profileUrl = 'https://soundcloud.com/$permalink';
          widget.onLoggedIn(profileUrl, token);
          if (mounted) Navigator.pop(context);
          return;
        }
      } else {
        print('[SC Login] /me error body: ${response.body}');
      }
    } catch (e) {
      print('[SC Login] http error: $e');
    }

    if (mounted) setState(() => _extracting = false);
    _capturedToken = null; // сбрасываем чтобы попробовать снова
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('https://soundcloud.com/signin'),
            ),
            initialUserScripts: UnmodifiableListView<UserScript>([
              _interceptorScript,
            ]),
            initialSettings: InAppWebViewSettings(
              userAgent:
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)'
                  ' AppleWebKit/605.1.15 Mobile/15E148',
              clearCache: true,
              clearSessionCache: true,
              javaScriptEnabled: true,
            ),
            onWebViewCreated: (controller) {
              _webController = controller;
            },
            onLoadStop: (controller, url) async {
              if (url == null || _extracting) return;
              final path = url.path ?? '';
              print('[SC Login] page loaded: ${url.toString()}');

              // Пока на странице логина — ждём
              if (path.contains('signin') ||
                  path.contains('login') ||
                  path.contains('connect'))
                return;

              // Немного ждём чтобы SC-приложение сделало свои запросы
              await Future.delayed(const Duration(seconds: 2));
              if (!mounted) return;

              await _tryExtractProfile();
            },
          ),

          if (_extracting)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF5500),
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }
}
