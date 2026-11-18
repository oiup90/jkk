import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Enable in updated clients before enabling the project-wide Auth setting.
const bool authCaptchaEnabled = bool.fromEnvironment('AUTH_CAPTCHA_ENABLED');
const String authCaptchaPage = String.fromEnvironment(
  'AUTH_CAPTCHA_PAGE',
  defaultValue: 'https://captcha.freelan.space/',
);

typedef AuthCaptchaProvider = Future<String?> Function(BuildContext context);

class CaptchaCancelled implements Exception {
  const CaptchaCancelled();
}

Future<String?> requestAuthCaptcha(BuildContext context) async {
  if (!authCaptchaEnabled) return null;
  final page = Uri.tryParse(authCaptchaPage);
  if (page == null ||
      page.scheme != 'https' ||
      page.host.isEmpty ||
      page.userInfo.isNotEmpty ||
      page.hasQuery ||
      page.hasFragment ||
      kIsWeb ||
      !(Platform.isAndroid || Platform.isWindows)) {
    throw StateError('Security check is unavailable.');
  }
  final token = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CaptchaDialog(page: page),
  );
  if (token == null || token.isEmpty) throw const CaptchaCancelled();
  return token;
}

class _CaptchaDialog extends StatefulWidget {
  const _CaptchaDialog({required this.page});
  final Uri page;
  @override
  State<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<_CaptchaDialog> {
  bool failed = false;
  bool completed = false;
  bool checking = false;
  Timer? poll;

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  void startPolling(InAppWebViewController controller) {
    poll?.cancel();
    poll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted || completed || checking) return;
      checking = true;
      try {
        final current = await controller.getUrl();
        if (current?.toString() != widget.page.toString()) return;
        final token = await controller.evaluateJavascript(
          source: 'window.__freelanCaptchaToken || null',
        );
        if (!mounted ||
            completed ||
            token is! String ||
            token.isEmpty ||
            token.length > 4096) {
          return;
        }
        completed = true;
        poll?.cancel();
        Navigator.of(context).pop(token);
      } catch (_) {
        // A loading or disposed WebView may not be ready for JavaScript yet.
      } finally {
        checking = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    title: Text(
      Localizations.localeOf(context).languageCode == 'ml'
          ? 'സുരക്ഷാ പരിശോധന'
          : 'Security check',
    ),
    content: SizedBox(
      width: 400,
      height: 220,
      child: failed
          ? Text(
              Localizations.localeOf(context).languageCode == 'ml'
                  ? 'സുരക്ഷാ പരിശോധന ലഭിച്ചില്ല. അടച്ചശേഷം വീണ്ടും ശ്രമിക്കുക.'
                  : 'Security check could not load. Close and try again.',
            )
          : InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(widget.page.toString()),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
                supportMultipleWindows: false,
              ),
              onLoadStop: (controller, url) {
                if (url?.toString() == widget.page.toString()) {
                  startPolling(controller);
                }
              },
              shouldOverrideUrlLoading: (controller, action) async {
                if (action.isForMainFrame &&
                    action.request.url.toString() != widget.page.toString()) {
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
              onReceivedError: (controller, request, error) {
                if (request.isForMainFrame == true && mounted) {
                  setState(() => failed = true);
                }
              },
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(
          Localizations.localeOf(context).languageCode == 'ml'
              ? 'റദ്ദാക്കുക'
              : 'Cancel',
        ),
      ),
    ],
  );
}
