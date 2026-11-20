import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Credentials never fall back to plaintext preferences.
class UserSavedLogin {
  UserSavedLogin(this.project, {FlutterSecureStorage? storage})
    : storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
          );
  final String project;
  final FlutterSecureStorage storage;
  String get key => 'user-login-${Uri.parse(project).host}';
  Future<Map<String, String>?> load() async {
    final raw = await storage.read(key: key);
    if (raw == null) return null;
    final value = jsonDecode(raw) as Map<String, dynamic>;
    return {
      'email': value['email'] as String,
      'password': value['password'] as String,
    };
  }

  Future<void> save(String email, String password) => storage.write(
    key: key,
    value: jsonEncode({'email': email, 'password': password}),
  );
  Future<void> forget() => storage.delete(key: key);
}
