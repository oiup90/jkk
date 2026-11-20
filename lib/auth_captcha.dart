import 'dart:async';
import 'dart:io' show Platform;

import 'auth_languages.dart';

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
  Timer? poll, timeout;
  int generation = 0;
  bool delayed = false;

  @override
  void initState() {
    super.initState();
    startTimeout();
  }

  void startTimeout() {
    timeout?.cancel();
    timeout = Timer(const Duration(seconds: 25), () {
      if (mounted && !completed) setState(() => delayed = true);
    });
  }

  void retry() {
    poll?.cancel();
    setState(() {
      failed = false;
      delayed = false;
      generation++;
    });
    startTimeout();
  }

  @override
  void dispose() {
    poll?.cancel();
    timeout?.cancel();
    super.dispose();
  }

  void startPolling(InAppWebViewController controller, int viewGeneration) {
    if (!mounted || generation != viewGeneration) return;
    poll?.cancel();
    poll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted || generation != viewGeneration || completed || checking) {
        return;
      }
      checking = true;
      try {
        final current = await controller.getUrl();
        if (current?.toString() != widget.page.toString()) return;
        final token = await controller.evaluateJavascript(
          source: 'window.__freelanCaptchaToken || null',
        );
        if (!mounted ||
            generation != viewGeneration ||
            failed ||
            completed ||
            token is! String ||
            token.isEmpty ||
            token.length > 4096) {
          return;
        }
        completed = true;
        poll?.cancel();
        timeout?.cancel();
        Navigator.of(context).pop(token);
      } catch (_) {
        // A loading or disposed WebView may not be ready for JavaScript yet.
      } finally {
        checking = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewGeneration = generation;
    return SecurityCheckPanel(
      failed: failed,
      delayed: delayed,
      onRetry: retry,
      challenge: InAppWebView(
        key: ValueKey(generation),
        initialUrlRequest: URLRequest(url: WebUri(widget.page.toString())),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useShouldOverrideUrlLoading: true,
          supportMultipleWindows: false,
        ),
        onLoadStop: (controller, url) {
          if (url?.toString() == widget.page.toString()) {
            startPolling(controller, viewGeneration);
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
          if (request.isForMainFrame == true &&
              mounted &&
              generation == viewGeneration) {
            poll?.cancel();
            setState(() => failed = true);
          }
        },
      ),
    );
  }
}

/// Visual frame for the hosted challenge; the WebView and token stay separate.
class SecurityCheckPanel extends StatelessWidget {
  const SecurityCheckPanel({
    super.key,
    required this.challenge,
    required this.failed,
    required this.delayed,
    required this.onRetry,
  });
  final Widget challenge;
  final bool failed, delayed;
  final VoidCallback onRetry;

  String copy(
    BuildContext context,
    String en,
    String ml,
    String hi,
    String ta,
    String ar,
  ) => switch (Localizations.localeOf(context).languageCode) {
    'ml' => ml,
    'hi' => hi,
    'ta' => ta,
    'ar' => ar,
    _ => en,
  };

  @override
  Widget build(BuildContext context) {
    final title =
        authTranslations[Localizations.localeOf(context)
            .languageCode]?['securityCheck'] ??
        (Localizations.localeOf(context).languageCode == 'ml'
            ? 'സുരക്ഷാ പരിശോധന'
            : 'Security check');
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xffeee8ff),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xff5722c9),
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 19,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff20143d),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          copy(
                            context,
                            'One quick step to continue',
                            'തുടരാൻ ഒരു ചെറിയ പരിശോധന',
                            'आगे बढ़ने के लिए एक छोटा कदम',
                            'தொடர ஒரு சிறிய படி',
                            'خطوة بسيطة للمتابعة',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xff6d6680),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff5f2fc),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 220,
                    child: failed
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                copy(
                                  context,
                                  'Could not load the check. Check your connection and try again.',
                                  'പരിശോധന ലഭ്യമായില്ല. Internet പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
                                  'जाँच लोड नहीं हुई। इंटरनेट जाँचें और फिर कोशिश करें।',
                                  'சோதனை ஏற்றப்படவில்லை. இணையத்தைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
                                  'تعذر تحميل الفحص. تحقق من الاتصال وحاول مجددًا.',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xff544a68),
                                ),
                              ),
                            ),
                          )
                        : ColoredBox(color: Colors.white, child: challenge),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                child: Text(
                  failed
                      ? copy(
                          context,
                          'Check your connection',
                          'Internet പരിശോധിക്കുക',
                          'अपना इंटरनेट जाँचें',
                          'இணைப்பைச் சரிபார்க்கவும்',
                          'تحقق من الاتصال',
                        )
                      : delayed
                      ? copy(
                          context,
                          'Taking longer than expected?',
                          'കൂടുതൽ സമയം എടുക്കുന്നുണ്ടോ?',
                          'क्या ज़्यादा समय लग रहा है?',
                          'அதிக நேரம் ஆகிறதா?',
                          'هل يستغرق وقتًا أطول؟',
                        )
                      : copy(
                          context,
                          'You’ll continue automatically when it’s complete.',
                          'പരിശോധന കഴിഞ്ഞാൽ സ്വയം തുടരും.',
                          'जाँच पूरी होने पर आप अपने आप आगे बढ़ेंगे।',
                          'சோதனை முடிந்ததும் தானாகத் தொடரும்.',
                          'ستتابع تلقائيًا عند اكتمال الفحص.',
                        ),
                  style: const TextStyle(
                    color: Color(0xff6d6680),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
              if (failed || delayed) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    copy(
                      context,
                      'Try again',
                      'വീണ്ടും ശ്രമിക്കുക',
                      'फिर कोशिश करें',
                      'மீண்டும் முயற்சிக்கவும்',
                      'حاول مجددًا',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
