import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:growth_circle/secure_auth_storage.dart';
import 'package:growth_circle/admin_login_tools.dart';

class _FailingSecureStorage extends FlutterSecureStorage {
  const _FailingSecureStorage(this.operation);
  final String operation;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (operation == 'read') throw StateError('secure read failed');
    return null;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (operation == 'write') throw StateError('secure write failed');
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (operation == 'delete') throw StateError('secure delete failed');
  }
}

class _FailingRemovalStore extends InMemorySharedPreferencesStore {
  _FailingRemovalStore()
    : super.withData({'flutter.session': 'synthetic-token'});
  bool allowRemoval = false;

  @override
  Future<bool> remove(String key) async =>
      allowRemoval ? super.remove(key) : false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  test(
    'migrates session to protected storage then removes plaintext and logs out',
    () async {
      SharedPreferences.setMockInitialValues({'session': 'synthetic-session'});
      final store = ProtectedAuthStorage('session');
      await store.initialize();
      expect(await store.accessToken(), 'synthetic-session');
      expect(
        (await SharedPreferences.getInstance()).containsKey('session'),
        false,
      );
      await store.persistSession('refreshed');
      expect(await store.accessToken(), 'refreshed');
      await store.removePersistedSession();
      expect(await store.hasAccessToken(), false);
    },
  );
  test('existing encrypted session wins during migration', () async {
    SharedPreferences.setMockInitialValues({'session': 'stale'});
    FlutterSecureStorage.setMockInitialValues({'session': 'current'});
    final store = ProtectedAuthStorage('session');
    await store.initialize();
    expect(await store.accessToken(), 'current');
    expect(
      (await SharedPreferences.getInstance()).containsKey('session'),
      false,
    );
  });
  test(
    'failed plaintext removal continues to fail closed until retried',
    () async {
      final backing = _FailingRemovalStore();
      SharedPreferencesStorePlatform.instance = backing;
      final store = ProtectedAuthStorage('session');
      await expectLater(store.initialize(), throwsStateError);
      await expectLater(store.initialize(), throwsStateError);
      expect((await backing.getAll())['flutter.session'], 'synthetic-token');
      backing.allowRemoval = true;
      await store.initialize();
      expect((await backing.getAll()).containsKey('flutter.session'), false);
      expect(await store.accessToken(), 'synthetic-token');
    },
  );
  test('PKCE proofs are protected and removed on completion', () async {
    SharedPreferences.setMockInitialValues({'verifier': 'old'});
    final store = ProtectedPkceStorage('project');
    expect(await store.getItem(key: 'verifier'), null);
    await store.setItem(key: 'verifier', value: 'synthetic-proof');
    expect(await store.getItem(key: 'verifier'), 'synthetic-proof');
    expect(
      (await SharedPreferences.getInstance()).containsKey('verifier'),
      false,
    );
    await store.removeItem(key: 'verifier');
    expect(await store.getItem(key: 'verifier'), null);
  });
  test(
    'failed secure migration removes legacy plaintext and fails closed',
    () async {
      for (final failure in ['read', 'write']) {
        SharedPreferences.setMockInitialValues({'session': 'synthetic-token'});
        final store = ProtectedAuthStorage(
          'session',
          storage: _FailingSecureStorage(failure),
        );
        await expectLater(store.initialize(), throwsStateError);
        expect(
          (await SharedPreferences.getInstance()).containsKey('session'),
          false,
        );
      }
    },
  );
  test('failed secure deletion still removes a legacy session', () async {
    SharedPreferences.setMockInitialValues({'session': 'synthetic-token'});
    final store = ProtectedAuthStorage(
      'session',
      storage: const _FailingSecureStorage('delete'),
    );
    await expectLater(store.removePersistedSession(), throwsStateError);
    expect(
      (await SharedPreferences.getInstance()).containsKey('session'),
      false,
    );
  });
  test('failed PKCE writes and deletes remove legacy plaintext', () async {
    for (final failure in ['write', 'delete']) {
      SharedPreferences.setMockInitialValues({'verifier': 'synthetic-proof'});
      final store = ProtectedPkceStorage(
        'project',
        storage: _FailingSecureStorage(failure),
      );
      final action = failure == 'write'
          ? store.setItem(key: 'verifier', value: 'new-proof')
          : store.removeItem(key: 'verifier');
      await expectLater(action, throwsStateError);
      expect(
        (await SharedPreferences.getInstance()).containsKey('verifier'),
        false,
      );
    }
  });
  test('failed secure PKCE read removes legacy plaintext', () async {
    SharedPreferences.setMockInitialValues({'verifier': 'synthetic-proof'});
    final store = ProtectedPkceStorage(
      'project',
      storage: const _FailingSecureStorage('read'),
    );
    await expectLater(store.getItem(key: 'verifier'), throwsStateError);
    expect(
      (await SharedPreferences.getInstance()).containsKey('verifier'),
      false,
    );
  });
  test('Android sessions and PKCE use Keystore-backed AES-GCM options', () {
    for (final storage in [
      ProtectedAuthStorage('session').storage,
      ProtectedPkceStorage('project').storage,
    ]) {
      final options = storage.aOptions.toMap();
      expect(options['storageCipherAlgorithm'], 'AES_GCM_NoPadding');
      expect(
        options['keyCipherAlgorithm'],
        'RSA_ECB_OAEPwithSHA_256andMGF1Padding',
      );
      expect(options['resetOnError'], 'false');
    }
  });
  test('failed admin secure storage never falls back to preferences', () async {
    final login = AdminSavedLogin(
      'https://example.test',
      storage: const _FailingSecureStorage('write'),
    );
    await expectLater(
      login.save('admin@example.test', 'synthetic-password'),
      throwsStateError,
    );
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
  test('checked-in production config uses public client credentials', () {
    final config =
        jsonDecode(File('config/production.json').readAsStringSync()) as Map;
    expect(config.keys.toSet(), {'SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY'});
    expect(
      validClientConfiguration(
        config['SUPABASE_URL'] as String,
        config['SUPABASE_PUBLISHABLE_KEY'] as String,
      ),
      true,
    );
    expect(
      (config['SUPABASE_PUBLISHABLE_KEY'] as String).startsWith(
        'sb_publishable_',
      ),
      true,
    );
  });
  test('rejects unsafe project configuration', () {
    const key = 'sb_publishable_syntheticpublickey';
    expect(validClientConfiguration('https://example.supabase.co', key), true);
    for (final url in [
      'http://example.test',
      'https://user@example.test',
      'https://example.test/?x=1',
      'https://example.test/path',
    ]) {
      expect(validClientConfiguration(url, key), false);
    }
    expect(
      validClientConfiguration('https://example.test', 'sb_secret_synthetic'),
      false,
    );
  });
}
