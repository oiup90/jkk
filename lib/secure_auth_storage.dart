import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool validClientConfiguration(String url, String key) {
  final uri = Uri.tryParse(url);
  var publicKey = key.startsWith('sb_publishable_') && key.length > 20;
  if (!publicKey) {
    try {
      final pieces = key.split('.');
      publicKey =
          pieces.length == 3 &&
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(pieces[1]))),
              )['role'] ==
              'anon';
    } catch (_) {
      publicKey = false;
    }
  }
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      publicKey;
}

Future<void> _removeLegacyValue(
  SharedPreferences preferences,
  String key,
) async {
  // Retry even when SharedPreferences' in-memory cache no longer has the key:
  // remove() drops it from that cache before the platform confirms deletion.
  if (!await preferences.remove(key)) {
    throw StateError('Unable to remove legacy credentials.');
  }
}

/// Fail closed on protected-storage failures; never fall back to preferences.
class ProtectedAuthStorage extends LocalStorage {
  ProtectedAuthStorage(this.key, {FlutterSecureStorage? storage})
    : storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
          );
  final String key;
  final FlutterSecureStorage storage;
  @override
  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final legacy = preferences.getString(key);
      if (legacy != null) {
        if (await storage.read(key: key) == null) {
          await storage.write(key: key, value: legacy);
        }
      }
    } finally {
      // Never retain an old plaintext session when protected storage fails.
      await _removeLegacyValue(preferences, key);
    }
  }

  @override
  Future<bool> hasAccessToken() async => await storage.read(key: key) != null;
  @override
  Future<String?> accessToken() => storage.read(key: key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      storage.write(key: key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() async {
    try {
      await storage.delete(key: key);
    } finally {
      await _removeLegacyValue(await SharedPreferences.getInstance(), key);
    }
  }
}

class ProtectedPkceStorage extends GotrueAsyncStorage {
  ProtectedPkceStorage(this.project, {FlutterSecureStorage? storage})
    : storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
          );
  final String project;
  final FlutterSecureStorage storage;
  String scoped(String key) => '$project-pkce-$key';
  @override
  Future<String?> getItem({required String key}) async {
    // Pending legacy sign-ins must restart rather than reuse plaintext proofs.
    await _removeLegacyValue(await SharedPreferences.getInstance(), key);
    return storage.read(key: scoped(key));
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    try {
      await storage.write(key: scoped(key), value: value);
    } finally {
      await _removeLegacyValue(await SharedPreferences.getInstance(), key);
    }
  }

  @override
  Future<void> removeItem({required String key}) async {
    try {
      await storage.delete(key: scoped(key));
    } finally {
      await _removeLegacyValue(await SharedPreferences.getInstance(), key);
    }
  }
}
