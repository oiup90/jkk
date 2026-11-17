import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/push_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const token = 'synthetic-device-token-123456789';

class PushBackend {
  String? registered;
  bool failRemoval = false;
  Completer<void>? holdRemoval;
  Completer<void>? holdRegistration;
  final registrationStarted = Completer<void>();
  final removalStarted = Completer<void>();
  int registrations = 0;

  late final client = SupabaseClient(
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
            'id': 'test-user',
            'aud': 'authenticated',
            'email': 'test@example.test',
            'created_at': '2026-11-11T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {},
          },
        };
      } else if (request.url.path.endsWith('/register_push_token')) {
        if (!registrationStarted.isCompleted) registrationStarted.complete();
        if (holdRegistration != null) await holdRegistration!.future;
        registered = body['p_token'] as String;
        registrations++;
      } else if (request.url.path.endsWith('/unregister_push_token')) {
        if (!removalStarted.isCompleted) removalStarted.complete();
        if (holdRemoval != null) await holdRemoval!.future;
        if (failRemoval) {
          status = 500;
          response = {'message': 'offline'};
        } else if (registered == body['p_token']) {
          registered = null;
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

  Future<void> signIn() => client.auth
      .signInWithPassword(email: 'test@example.test', password: 'synthetic')
      .then((_) {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Android disable removes the FCM token and can be enabled again',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      final backend = PushBackend();
      final events = StreamController<String>.broadcast();
      final push = PushCoordinator.forTesting(
        initialize: () async {},
        permission: () async => true,
        tokenLoader: () async => token,
        tokenChanges: events.stream,
      );
      try {
        await backend.signIn();
        expect(await push.enable(backend.client), isTrue);
        expect(backend.registered, token);
        await push.disable(backend.client);
        expect(backend.registered, isNull);
        expect(
          (await SharedPreferences.getInstance()).getBool(
            'push_opt_in_test-user',
          ),
          isFalse,
        );
        await push.restore(backend.client);
        expect(await push.isEnabled(backend.client), isFalse);
        expect(backend.registered, isNull);
        expect(await push.enable(backend.client), isTrue);
        expect(backend.registered, token);
      } finally {
        await push.detach();
        await events.close();
        await backend.client.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test('failed server cleanup keeps opt-in and allows retry', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = PushBackend();
    final events = StreamController<String>.broadcast();
    final push = PushCoordinator.forTesting(
      initialize: () async {},
      permission: () async => true,
      tokenLoader: () async => token,
      tokenChanges: events.stream,
    );
    try {
      await backend.signIn();
      await push.enable(backend.client);
      backend.failRemoval = true;
      await expectLater(
        push.disable(backend.client),
        throwsA(isA<PostgrestException>()),
      );
      expect(backend.registered, token);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'push_opt_in_test-user',
        ),
        isTrue,
      );
      backend.failRemoval = false;
      await push.disable(backend.client);
      expect(backend.registered, isNull);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'push_opt_in_test-user',
        ),
        isFalse,
      );
    } finally {
      await push.detach();
      await events.close();
      await backend.client.dispose();
    }
  });

  test(
    'an unavailable device token cannot falsely report push as disabled',
    () async {
      SharedPreferences.setMockInitialValues({'push_opt_in_test-user': true});
      final backend = PushBackend()..registered = token;
      final events = StreamController<String>.broadcast();
      final push = PushCoordinator.forTesting(
        initialize: () async {},
        permission: () async => true,
        tokenLoader: () async => null,
        tokenChanges: events.stream,
      );
      try {
        await backend.signIn();
        await expectLater(
          push.disable(backend.client),
          throwsA(isA<StateError>()),
        );
        expect(backend.registered, token);
        expect(
          (await SharedPreferences.getInstance()).getBool(
            'push_opt_in_test-user',
          ),
          isTrue,
        );
      } finally {
        await push.detach();
        await events.close();
        await backend.client.dispose();
      }
    },
  );

  test(
    'after restart disable recovers the token and blocks concurrent restore',
    () async {
      SharedPreferences.setMockInitialValues({'push_opt_in_test-user': true});
      final backend = PushBackend()..registered = token;
      backend.holdRemoval = Completer<void>();
      final events = StreamController<String>.broadcast();
      final push = PushCoordinator.forTesting(
        initialize: () async {},
        permission: () async => true,
        tokenLoader: () async => token,
        tokenChanges: events.stream,
      );
      try {
        await backend.signIn();
        final disabling = push.disable(backend.client);
        await backend.removalStarted.future;
        var checkCompleted = false;
        final checking = push.isEnabled(backend.client).then((value) {
          checkCompleted = true;
          return value;
        });
        await Future<void>.delayed(Duration.zero);
        expect(checkCompleted, isFalse);
        await push.restore(backend.client);
        expect(backend.registrations, 0);
        backend.holdRemoval!.complete();
        await disabling;
        expect(await checking, isFalse);
        expect(backend.registered, isNull);
        expect(
          (await SharedPreferences.getInstance()).getBool(
            'push_opt_in_test-user',
          ),
          isFalse,
        );
        await push.restore(backend.client);
        expect(backend.registrations, 0);
      } finally {
        if (!backend.holdRemoval!.isCompleted) backend.holdRemoval!.complete();
        await push.detach();
        await events.close();
        await backend.client.dispose();
      }
    },
  );

  test(
    'disable waits for an in-flight registration before removing its token',
    () async {
      SharedPreferences.setMockInitialValues({'push_opt_in_test-user': true});
      final backend = PushBackend()..holdRegistration = Completer<void>();
      final events = StreamController<String>.broadcast();
      final push = PushCoordinator.forTesting(
        initialize: () async {},
        permission: () async => true,
        tokenLoader: () async => token,
        tokenChanges: events.stream,
      );
      try {
        await backend.signIn();
        final enabling = push.enable(backend.client);
        final cancelled = expectLater(enabling, throwsA(isA<StateError>()));
        await backend.registrationStarted.future;
        final disabling = push.disable(backend.client);
        await push.restore(backend.client);
        backend.holdRegistration!.complete();
        await cancelled;
        await disabling;
        expect(backend.registered, isNull);
        expect(
          (await SharedPreferences.getInstance()).getBool(
            'push_opt_in_test-user',
          ),
          isFalse,
        );
        expect(backend.registrations, 1);
      } finally {
        if (!backend.holdRegistration!.isCompleted) {
          backend.holdRegistration!.complete();
        }
        await push.detach();
        await events.close();
        await backend.client.dispose();
      }
    },
  );
}
