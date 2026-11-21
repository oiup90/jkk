import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/guest_support_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('signed-out visitor sends and receives support replies', (
    tester,
  ) async {
    final sent = <Map<String, dynamic>>[];
    var status = 'open';
    final messages = <Map<String, dynamic>>[];
    final client = (await tester.runAsync(
      () async => SupabaseClient(
        'https://example.test',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path.endsWith('guest_support_send')) {
            sent.add(body);
            if (body['p_new'] == true) {
              status = 'open';
              messages.clear();
            }
            messages.add({'body': body['p_body'], 'is_admin': false});
            messages.add({'body': 'Support reply', 'is_admin': true});
          }
          return http.Response(
            request.url.path.endsWith('guest_support_get')
                ? jsonEncode({'status': status, 'messages': messages})
                : 'null',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: GuestSupportPage(
          client: client,
          project: 'test',
          loadKey: () async => 'a' * 64,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Please help');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(sent.single['p_body'], 'Please help');
    expect(sent.single['p_new'], false);
    expect(find.text('Support reply'), findsOneWidget);
    status = 'closed';
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('New chat'), findsOneWidget);
    await tester.tap(find.text('New chat'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Another issue');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(sent.last['p_new'], true);
    expect(find.text('Support reply'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(client.dispose);
  });
}
