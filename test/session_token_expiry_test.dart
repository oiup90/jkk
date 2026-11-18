import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:growth_circle/secure_auth_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('expired sessions refresh securely and invalid refresh signs out', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final store = ProtectedAuthStorage('session');
    String fakeJwt(int seconds) =>
        'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + seconds}))).replaceAll('=', '')}.c2ln';
    final oldAccess = fakeJwt(-100);
    final newAccess = fakeJwt(3600);
    final requests = <String>[];
    var denyRefresh = false;
    final user = {
      'id': '11111111-1111-4111-8111-111111111111',
      'aud': 'authenticated',
      'email': 'synthetic@example.test',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
    };
    final expired = jsonEncode({
      'access_token': oldAccess,
      'refresh_token': 'synthetic-old-refresh',
      'token_type': 'bearer',
      'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 100,
      'expires_in': 3600,
      'user': user,
    });
    final supabase = await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'synthetic-public-key',
      httpClient: MockClient((request) async {
        requests.add(
          '${request.method} ${request.url.path} ${request.url.query}',
        );
        if (denyRefresh) {
          return http.Response(
            jsonEncode({
              'code': 'refresh_token_not_found',
              'message': 'invalid',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(
          jsonDecode(request.body)['refresh_token'],
          'synthetic-old-refresh',
        );
        return http.Response(
          jsonEncode({
            'access_token': newAccess,
            'refresh_token': 'synthetic-new-refresh',
            'token_type': 'bearer',
            'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            'expires_in': 3600,
            'user': user,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: true,
        detectSessionInUri: false,
        localStorage: store,
        pkceAsyncStorage: ProtectedPkceStorage('example.test'),
      ),
    );
    final auth = supabase.client.auth;
    try {
      await auth.setInitialSession(expired);
      await Future<void>.delayed(Duration.zero);
      final session = await auth.getSession();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(session?.accessToken, newAccess);
      expect(session?.refreshToken, 'synthetic-new-refresh');
      expect(requests.single, contains('grant_type=refresh_token'));
      expect(
        jsonDecode((await store.accessToken())!)['refresh_token'],
        'synthetic-new-refresh',
      );
      expect(
        (await SharedPreferences.getInstance()).containsKey('session'),
        isFalse,
      );

      denyRefresh = true;
      await auth.setInitialSession(expired);
      await Future<void>.delayed(Duration.zero);
      await expectLater(auth.getSession(), throwsA(isA<AuthException>()));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(auth.currentSession, isNull);
      expect(await store.hasAccessToken(), isFalse);
    } finally {
      await supabase.dispose();
    }
  });
}
