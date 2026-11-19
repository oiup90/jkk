import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/support_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final send in [false, true]) {
    testWidgets('${send ? 'creating' : 'cancelling'} a support chat is safe', (
      tester,
    ) async {
      final creates = <Map<String, dynamic>>[];
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://example.test',
          'synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            final creating = request.url.path.endsWith('support_create_ticket');
              if (creating) {
              creates.add(jsonDecode(request.body) as Map<String, dynamic>);
              }
            return http.Response(
              creating ? '"ticket"' : '[]',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: SupportPage(client: client, loadTickets: () async => []),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        '  Help with my account  ',
      );
      await tester.tap(find.text(send ? 'Send' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (send) {
        expect(creates.single, {
          'p_subject': 'Help with my account',
          'p_body': 'Help with my account',
        });
        expect(find.byType(SupportConversation), findsOneWidget);
      } else {
        expect(creates, isEmpty);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(client.dispose);
    });
  }

  for (final leavePage in [false, true]) {
    testWidgets(
      leavePage
          ? 'reply completion after leaving is safe'
          : 'sending a reply preserves the next draft',
      (tester) async {
        final response = Completer<http.Response>();
        http.Request? sent;
        final client = (await tester.runAsync(
          () async => SupabaseClient(
            'https://example.test',
            'synthetic',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
              if (request.url.path.endsWith('support_reply')) {
                sent = request;
                return response.future;
              }
              return http.Response(
                '[]',
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        ))!;
        await tester.pumpWidget(
          MaterialApp(
            home: SupportConversation(
              client: client,
              id: 'ticket',
              subject: 'Help',
              open: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'First reply');
        await tester.tap(find.text('Send'));
        await tester.pump();
        expect(jsonDecode(sent!.body)['p_body'], 'First reply');
        if (leavePage) {
          await tester.pumpWidget(const SizedBox.shrink());
        } else {
          await tester.enterText(find.byType(TextField), 'Next draft');
        }
        response.complete(
          http.Response(
            'null',
            200,
            request: sent!,
            headers: {'content-type': 'application/json'},
          ),
        );
        await tester.pumpAndSettle();
        if (!leavePage) {
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'Next draft',
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(client.dispose);
      },
    );
  }
}
