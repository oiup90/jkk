import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:growth_circle/push_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('cached FCM token enables push without registration events; refresh, denial and failed writes preserve opt-in', () async {
    SharedPreferences.setMockInitialValues({});
    final events = StreamController<String>.broadcast();
    final foreground = StreamController<RemoteMessage>.broadcast(sync: true);
    final displayed = <String>[];
    void message() => foreground.add(
      const RemoteMessage(
        notification: RemoteNotification(title: 'Admin', body: 'Hello'),
      ),
    );
    final writes = <String>[];
    var allowed = true, fail = false, loads = 0;
    final client = SupabaseClient(
      'https://example.test',
      'synthetic-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(request.body) as Map<String, dynamic>;
        Object? response;
        var status = 200;
        if (request.url.path.endsWith('/token')) {
          response = {
            'access_token': 'synthetic-session',
            'refresh_token': 'synthetic-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'same-user',
              'aud': 'authenticated',
              'email': 'test@example.test',
              'created_at': '2026-11-11T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          };
        } else if (request.url.path.endsWith('/register_push_token')) {
          if (fail) {
            status = 500;
            response = {'message': 'offline'};
          } else {
            writes.add(body['p_token'] as String);
          }
        }
        return http.Response(
          jsonEncode(response),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    const channel = MethodChannel('growth_circle/push_foreground');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'show');
          expect(call.arguments['title'], 'Admin');
          displayed.add(call.arguments['body'] as String);
          return null;
        });
    final push = PushCoordinator.forTesting(
      initialize: () async {},
      permission: () async => allowed,
      tokenLoader: () async {
        loads++;
        return 'synthetic-cached-fcm-token';
      },
      tokenChanges: events.stream,
      foregroundMessages: foreground.stream,
    );
    try {
      await client.auth.signInWithPassword(
        email: 'test@example.test',
        password: 'synthetic',
      );
      allowed = false;
      expect(await push.enable(client), false);
      expect(loads, 0);
      allowed = true;
      fail = true;
      await expectLater(
        push.enable(client),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'push_opt_in_same-user',
        ),
        isNot(true),
      );
      fail = false;
      expect(await push.enable(client), true);
      expect(writes, ['synthetic-cached-fcm-token']);
      message();
      expect(displayed, ['Hello']);
      expect(await push.isEnabled(client), true);
      message();
      expect(displayed, ['Hello', 'Hello']);
      fail = true;
      await expectLater(
        push.isEnabled(client),
        throwsA(isA<PostgrestException>()),
      );
      fail = false;
      await push.detach();
      message();
      expect(displayed, ['Hello', 'Hello']);
      await push.restore(client);
      message();
      expect(displayed, ['Hello', 'Hello', 'Hello']);
      expect(await push.isEnabled(client), true);
      allowed = false;
      expect(await push.isEnabled(client), false);
      message();
      expect(displayed, ['Hello', 'Hello', 'Hello']);
      allowed = true;
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'push_opt_in_same-user',
        ),
        true,
      );
      events.add('synthetic-refreshed-fcm-token');
      // Wait for the synthetic local RPC rather than an arbitrary sleep.
      for (
        var i = 0;
        i < 100 && !writes.contains('synthetic-refreshed-fcm-token');
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(writes, contains('synthetic-refreshed-fcm-token'));
      // Simulate a new process after an app update: only saved opt-in remains.
      final restored = PushCoordinator.forTesting(
        initialize: () async {},
        permission: () async => allowed,
        tokenLoader: () async => 'synthetic-token-after-update',
        tokenChanges: events.stream,
      );
      fail = true;
      await restored.restore(client);
      expect(writes, isNot(contains('synthetic-token-after-update')));
      fail = false;
      await Future.wait([restored.restore(client), restored.restore(client)]);
      expect(
        writes.where((v) => v == 'synthetic-token-after-update').length,
        1,
      );
      allowed = false;
      final beforeDenied = writes.length;
      await restored.restore(client);
      expect(writes.length, beforeDenied);
      allowed = true;
      await (await SharedPreferences.getInstance()).setBool(
        'push_opt_in_same-user',
        false,
      );
      await restored.restore(client);
      expect(writes.length, beforeDenied);
      await restored.stop(client);
    } finally {
      await push.stop(client);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await foreground.close();
      await events.close();
      await client.dispose();
    }
  });
}
