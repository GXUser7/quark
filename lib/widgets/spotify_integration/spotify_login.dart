import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quark/services/spotify_services.dart';
import 'package:quark/services/database/database.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class SpotifyLogin extends StatefulWidget {
  final Function() closeView;
  const SpotifyLogin({super.key, required this.closeView});

  @override
  State<SpotifyLogin> createState() => _SpotifyLoginState();
}

class _SpotifyLoginState extends State<SpotifyLogin> {
  Timer? searchDebounceTimer;
  final Duration _searchDebounceDuration = const Duration(milliseconds: 500);
  final TextEditingController controller = TextEditingController(text: '');
  Color borderColor = Colors.white.withAlpha(78);

  final Uri loginUrl = Uri.parse(
    'https://accounts.spotify.com/authorize?client_id=598a5a932ba2414fbc203483596f2391&response_type=code&redirect_uri=https://oauth.pstmn.io/v1/browser-callback&scope=playlist-read-private%20playlist-read-collaborative%20user-library-read%20user-read-private%20user-read-email&show_dialog=true',
  );

  late bool webview2 = false;
  InAppWebViewController? webViewController;
  bool _loading = false;

  void spotifyCodeChecker(String value) async {
    searchDebounceTimer?.cancel();
    searchDebounceTimer = Timer(_searchDebounceDuration, () async {
      if (value.isEmpty) return;
      setState(() {
        borderColor = Colors.orange;
        _loading = true;
      });

      // Attempt token exchange
      final success = await SpotifyService().exchangeCodeForToken(value.trim());
      if (success) {
        setState(() {
          borderColor = Colors.greenAccent;
          _loading = false;
        });
        widget.closeView();
      } else {
        setState(() {
          borderColor = Colors.red;
          _loading = false;
        });
      }
    });
  }

  Future<void> _launchUrl() async {
    if (!await launchUrl(loginUrl)) {
      throw Exception('Could not launch $loginUrl');
    }
  }

  Future<void> _checkWebView2Inapp() async {
    try {
      String? version = await WebViewEnvironment.getAvailableVersion();
      setState(() {
        webview2 = version != null;
      });
    } catch (e) {
      setState(() {
        webview2 = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkWebView2Inapp();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (!webview2 && !Platform.isAndroid && !Platform.isMacOS) {
      return Center(
        child: Container(
          alignment: AlignmentDirectional.center,
          width: min(480, size.width - 50),
          height: min(360, size.height - 50),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(15)),
            color: const Color.fromARGB(15, 255, 255, 255),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(15)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
              child: Container(
                width: min(size.width * 0.92, 1040),
                height: min(size.height * 0.92, 1036),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(2),
                  border: Border.all(
                    color: Colors.white.withAlpha(51),
                    width: 1,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withAlpha(25),
                      Colors.white.withAlpha(12),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_person_rounded,
                        color: Color(0xFF1DB954),
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Spotify Authorization',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Click the link to log in via browser, then copy and paste the "code" query parameter from the resulting URL.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _launchUrl,
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: const Text('Open Login Page'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        onChanged: spotifyCodeChecker,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Paste code here (e.g. AQD...)',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.key_rounded, color: Colors.white54),
                          suffixIcon: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954)),
                                  ),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        alignment: AlignmentDirectional.center,
        width: min(420, size.width - 50),
        height: min(650, size.height - 50),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          color: const Color.fromARGB(30, 255, 255, 255),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                border: Border.all(color: Colors.white.withAlpha(51), width: 1),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withAlpha(25),
                    Colors.white.withAlpha(12),
                  ],
                ),
              ),
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    title: const Text('Spotify Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: widget.closeView,
                    ),
                  ),
                  Expanded(
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(loginUrl.toString())),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
                      ),
                      onWebViewCreated: (controller) {
                        webViewController = controller;
                      },
                      onLoadStop: (controller, url) async {
                        if (url != null && url.toString().startsWith('https://oauth.pstmn.io/v1/browser-callback')) {
                          final code = url.queryParameters['code'];
                          if (code != null && code.isNotEmpty) {
                            setState(() => _loading = true);
                            final success = await SpotifyService().exchangeCodeForToken(code);
                            setState(() => _loading = false);
                            if (success) {
                              widget.closeView();
                            }
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
