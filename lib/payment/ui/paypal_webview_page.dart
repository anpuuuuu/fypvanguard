// lib/payment/ui/paypal_webview_page.dart
// In-app WebView for PayPal Sandbox login & approve – no external browser, works in emulator

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// PayPal approval URL is loaded here. When user approves, PayPal redirects to
/// vanguardfyp://paypal-return?token=ORDER_ID – we intercept and return the orderId.
class PayPalWebViewPage extends StatefulWidget {
  final String approvalUrl;
  final String returnScheme;

  const PayPalWebViewPage({
    Key? key,
    required this.approvalUrl,
    this.returnScheme = 'vanguardfyp://paypal-return',
  }) : super(key: key);

  @override
  State<PayPalWebViewPage> createState() => _PayPalWebViewPageState();
}

class _PayPalWebViewPageState extends State<PayPalWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (e) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith(widget.returnScheme)) {
              final uri = Uri.parse(url);
              final token = uri.queryParameters['token'];
              if (token != null && token.isNotEmpty && mounted) {
                Navigator.pop(context, token);
                return NavigationDecision.prevent;
              }
            }
            if (url.startsWith('vanguardfyp://paypal-cancel')) {
              if (mounted) Navigator.pop(context);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.approvalUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'PayPal',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
