import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/coin_purchase.dart';
import 'package:growth_circle/personal_information.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final operation in ['plans', 'orders', 'photo']) {
    test(
      'ignores $operation response after another account signs in',
      () async {
        final pending = Completer<http.Response>();
        final started = Completer<http.Request>();
        var owner = 'first';
        final client = SupabaseClient(
          'https://example.test',
          'synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/token')) {
              return http.Response(
                jsonEncode({
                  'access_token': 'synthetic-$owner',
                  'refresh_token': 'synthetic',
                  'token_type': 'bearer',
                  'expires_in': 3600,
                  'user': {
                    'id': owner,
                    'aud': 'authenticated',
                    'created_at': '2026-01-01T00:00:00Z',
                    'app_metadata': {},
                    'user_metadata': {},
                  },
                }),
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            started.complete(request);
            return pending.future;
          }),
        );
        try {
          await client.auth.signInWithPassword(
            email: 'first@example.test',
            password: 'synthetic',
          );
          final purchases = SupabaseCoinPurchases(client);
          final profile = SupabasePersonalInformationGateway(
            client,
            () => throw StateError('unused'),
          );
          final Future<Object?> result = operation == 'plans'
              ? purchases.plans()
              : operation == 'orders'
              ? purchases.pending()
              : profile.loadPhoto();
          final request = await started.future;
          final check = expectLater(
            result,
            throwsA(
              operation == 'photo' ? isA<AuthException>() : isA<StateError>(),
            ),
          );
          owner = 'second';
          await client.auth.signInWithPassword(
            email: 'second@example.test',
            password: 'synthetic',
          );
          pending.complete(
            http.Response(
              operation == 'photo' ? 'null' : '[]',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            ),
          );
          await check;
        } finally {
          await client.dispose();
        }
      },
    );
  }

  test('profile gateway cannot mutate the account signed in later', () async {
    var owner = 'first';
    var writes = 0;
    final client = SupabaseClient(
      'https://example.test',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object? data;
        if (request.url.path.endsWith('/token')) {
          data = {
            'access_token': 'synthetic-$owner',
            'refresh_token': 'synthetic',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': owner,
              'aud': 'authenticated',
              'created_at': '2026-01-01T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          };
        } else {
          writes++;
          data = null;
        }
        return http.Response(
          jsonEncode(data),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    try {
      await client.auth.signInWithPassword(
        email: 'first@example.test',
        password: 'synthetic',
      );
      final profile = SupabasePersonalInformationGateway(
        client,
        () => throw StateError('unused'),
      );
      await profile.loadPhoto();
      owner = 'second';
      await client.auth.signInWithPassword(
        email: 'second@example.test',
        password: 'synthetic',
      );
      writes = 0;
      for (final action in [
        () => profile.saveName('Changed'),
        () => profile.savePhoto(Uint8List(0), 'image/png'),
        () => profile.requestEmailChange('new@example.test'),
        () => profile.verifyOldEmail('123456'),
        () => profile.verifyNewEmail('new@example.test', '123456'),
      ]) {
        await expectLater(action(), throwsA(isA<AuthException>()));
      }
      expect(writes, 0);
    } finally {
      await client.dispose();
    }
  });
}
