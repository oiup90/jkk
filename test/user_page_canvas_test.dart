import 'dart:convert';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/coin_purchase.dart';
import 'package:growth_circle/legal_pages.dart';
import 'package:growth_circle/main.dart' show NotificationsPage;
import 'package:growth_circle/personal_information.dart';
import 'package:growth_circle/user_features.dart';
import 'package:growth_circle/user_page_canvas.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'coin_purchase_test.dart' show FakePurchases;
import 'personal_information_test.dart' show FakePersonalGateway;

void main() {
  testWidgets(
    'each page backdrop is distinct and leaves controls interactive',
    (tester) async {
      final images = <String>{};
      var taps = 0;
      for (final identity in UserPageIdentity.values) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 160,
                  height: 180,
                  child: UserPageCanvas(
                    identity: identity,
                    child: Center(
                      child: TextButton(
                        onPressed: () => taps++,
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final data = await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return bytes;
        });
        expect(
          images.add(sha256.convert(data!.buffer.asUint8List()).toString()),
          isTrue,
          reason: '${identity.name} repeats another page backdrop',
        );
        await tester.tap(find.text('Open'));
      }
      expect(taps, UserPageIdentity.values.length);
    },
  );

  testWidgets('redesigned pages fit at narrow width with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = SupabaseClient(
      'https://example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(() {
      client.dispose();
    });
    for (final page in <Widget>[
      CoinPurchasePage(source: FakePurchases(), isMalayalam: true),
      EmailChangePage(
        currentEmail: 'old@example.test',
        gateway: FakePersonalGateway(),
      ),
      const LegalPage(),
      const LegalPage(terms: true),
      SubmissionHistoryPage(client: client),
      NotificationsPage(
        stream: Stream.value([
          {'id': '1', 'kind': 'coins_received', 'amount': 20, 'read_at': null},
        ]),
        markRead: (_) async {},
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: page,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: page.runtimeType.toString(),
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
