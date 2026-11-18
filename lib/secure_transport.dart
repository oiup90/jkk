import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

bool _secureUrl(Uri uri, String scheme) =>
    uri.scheme == scheme && uri.host.isNotEmpty && uri.userInfo.isEmpty;

/// Reject insecure requests and redirects before credentials can be forwarded.
class SecureHttpClient extends http.BaseClient {
  SecureHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_secureUrl(request.url, 'https')) {
      throw http.ClientException('HTTPS is required.');
    }
    request.followRedirects = false;
    final response = await _inner.send(request);
    if (response.statusCode >= 300 &&
        response.statusCode < 400 &&
        response.statusCode != 304) {
      await response.stream.listen((_) {}).cancel();
      throw http.ClientException('Redirects are not permitted.');
    }
    return response;
  }

  @override
  void close() => _inner.close();
}

/// Only WebSocket.connect's openUrl is supported; other methods fail closed.
class SecureWebSocketHttpClient implements HttpClient {
  SecureWebSocketHttpClient([HttpClient? inner])
    : _inner = inner ?? HttpClient();
  final HttpClient _inner;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (!_secureUrl(url, 'https')) {
      throw const FormatException('Secure WebSocket transport is required.');
    }
    final request = await _inner.openUrl(method, url);
    request.followRedirects = false;
    return request;
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Supabase SDK instances receive these shared clients and do not own them.
final secureHttpClient = SecureHttpClient();
final _webSocketHttpClient = SecureWebSocketHttpClient();

WebSocketChannel secureRealtimeTransport(
  String url,
  Map<String, String> headers,
) {
  final uri = Uri.tryParse(url);
  if (uri == null || !_secureUrl(uri, 'wss')) {
    throw const FormatException('Secure WebSocket transport is required.');
  }
  return IOWebSocketChannel.connect(
    uri,
    headers: headers,
    customClient: _webSocketHttpClient,
    pingInterval: const Duration(seconds: 25),
  );
}
