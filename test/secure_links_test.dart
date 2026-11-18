import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart' as app;

void main() {
  test('campaign links match the server allowlist and strip query data', () {
    expect(
      app.normalizeCampaignLink(
        'like',
        ' https://instagram.com/p/abc_12/?utm=x#y ',
      ),
      'https://www.instagram.com/p/abc_12/',
    );
    expect(
      app.normalizeCampaignLink(
        'follow',
        'https://www.instagram.com/some.user/',
      ),
      'https://www.instagram.com/some.user/',
    );
    for (final link in [
      'http://instagram.com/p/abc',
      'https://instagram.com.evil.test/p/abc',
      'https://instagram.com@evil.test/p/abc',
      'https://instagram.com/p/abc/extra',
      'https://instagram.com/p/<script>',
      'https://instagram.com/p/${'a' * 501}',
    ]) {
      expect(app.normalizeCampaignLink('like', link), isNull, reason: link);
    }
    expect(
      app.normalizeCampaignLink('follow', 'https://instagram.com/reel/'),
      isNull,
    );
  });

  testWidgets('Instagram links reject cleartext before launching', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await app.openInstagram(context, 'http://example.test/path');
    await tester.pump();
    expect(find.text(app.words['openError']![0]), findsOneWidget);
  });

  testWidgets('Instagram links reject deceptive HTTPS origins', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await app.openInstagram(context, 'https://instagram.com@evil.test/p/abc');
    await tester.pump();
    expect(find.text(app.words['openError']![0]), findsOneWidget);
  });
}
