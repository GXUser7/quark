import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class VkAuthPage extends StatefulWidget {
  final Function(String token) onTokenReceived;
  const VkAuthPage({super.key, required this.onTokenReceived});

  @override
  State<VkAuthPage> createState() => _VkAuthPageState();
}

class _VkAuthPageState extends State<VkAuthPage> {
  static const _clientId = '2685278'; // Kate 

  final _url = Uri.parse(
    'https://oauth.vk.com/authorize'
    '?client_id=2685278'
    '&scope=audio,offline'  
    '&redirect_uri=https://oauth.vk.com/blank.html'
    '&display=mobile'
    '&response_type=token'
    '&revoke=1',             
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_url.toString())),
        initialSettings: InAppWebViewSettings(
          userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)'
                     ' AppleWebKit/605.1.15 Mobile/15E148',
          clearCache: true,
          clearSessionCache: true,
        ),
        onLoadStop: (controller, url) async {
          if (url == null) return;
          final fragment = url.fragment; // всё после #

          if (url.host == 'oauth.vk.com' &&
              url.path == '/blank.html' &&
              fragment.contains('access_token=')) {

            final params = Uri.splitQueryString(fragment);
            final token = params['access_token'];

            if (token != null && token.isNotEmpty) {
              widget.onTokenReceived(token);
              if (mounted) Navigator.pop(context);
            }
          }
        },
        onReceivedError: (controller, request, error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: ${error.description}')),
          );
        },
      ),
    );
  }
}