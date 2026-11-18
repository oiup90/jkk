import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/secure_transport.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  test('HTTPS requests work, while HTTP and URL credentials never reach the client', () async {
    var requests = 0;
    final client = SecureHttpClient(
      MockClient((request) async {
        requests++;
        expect(request.followRedirects, isFalse);
        expect(request.headers['authorization'], 'Bearer synthetic');
        return http.Response('ok', 200);
      }),
    );
    addTearDown(client.close);
    final response = await client.get(
      Uri.parse('https://example.test/path'),
      headers: {'authorization': 'Bearer synthetic'},
    );
    expect(response.body, 'ok');
    for (final url in [
      'http://example.test/path',
      'https://user:pass@example.test/path',
    ]) {
      await expectLater(
        client.get(
          Uri.parse(url),
          headers: {'authorization': 'Bearer synthetic'},
        ),
        throwsA(isA<http.ClientException>()),
      );
    }
    expect(requests, 1);
  });

  test('redirects are rejected and never followed', () async {
    for (final location in ['http://other.test/', 'https://other.test/']) {
      var requests = 0;
      final client = SecureHttpClient(
        MockClient((request) async {
          requests++;
          expect(request.followRedirects, isFalse);
          return http.Response('', 302, headers: {'location': location});
        }),
      );
      await expectLater(
        client.get(Uri.parse('https://example.test/')),
        throwsA(isA<http.ClientException>()),
      );
      expect(requests, 1);
      client.close();
    }
  });

  test('Realtime rejects insecure or credential-bearing WebSocket URLs', () {
    for (final url in [
      'ws://example.test/socket',
      'wss://user:pass@example.test/socket',
    ]) {
      expect(() => secureRealtimeTransport(url, {}), throwsFormatException);
    }
  });

  test(
    'real TLS verifies certificates and does not downgrade HTTP or WebSocket redirects',
    () async {
      final temp = await Directory.systemTemp.createTemp('freelan-tls-test-');
      addTearDown(() => temp.delete(recursive: true));
      final cert = '${temp.path}/cert.pem';
      final key = '${temp.path}/key.pem';
      final result = await Process.run('openssl', [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-sha256',
        '-nodes',
        '-keyout',
        key,
        '-out',
        cert,
        '-days',
        '1',
        '-subj',
        '/CN=localhost',
        '-addext',
        'subjectAltName=IP:127.0.0.1,DNS:localhost',
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'Synthetic test certificate generation failed',
      );

      final insecure = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var insecureHits = 0;
      insecure.listen((request) {
        insecureHits++;
        request.response.close();
      });
      addTearDown(() => insecure.close(force: true));

      final serverContext = SecurityContext()
        ..useCertificateChain(cert)
        ..usePrivateKey(key);
      final secure = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        serverContext,
      );
      var secureHits = 0;
      secure.listen((request) async {
        secureHits++;
        if (request.uri.path == '/ok') {
          request.response.write('secure');
          await request.response.close();
          return;
        }
        if (request.uri.path == '/socket') {
          final socket = await WebSocketTransformer.upgrade(request);
          socket.listen(socket.add);
          return;
        }
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          'http://127.0.0.1:${insecure.port}/downgraded',
        );
        request.response.close();
      });
      addTearDown(() => secure.close(force: true));
      final endpoint = Uri.parse('https://127.0.0.1:${secure.port}/');

      final untrusted = SecureHttpClient(IOClient(HttpClient()));
      addTearDown(untrusted.close);
      await expectLater(untrusted.get(endpoint), throwsA(anything));
      expect(secureHits, 0);

      final trusted = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(cert);
      final httpsClient = SecureHttpClient(
        IOClient(HttpClient(context: trusted)),
      );
      addTearDown(httpsClient.close);
      await expectLater(
        httpsClient.get(
          endpoint,
          headers: {'authorization': 'Bearer synthetic'},
        ),
        throwsA(isA<http.ClientException>()),
      );
      expect(secureHits, 1);
      expect(insecureHits, 0);

      final wsClient = SecureWebSocketHttpClient(HttpClient(context: trusted));
      addTearDown(() => wsClient.close(force: true));
      final socket = IOWebSocketChannel.connect(
        'wss://127.0.0.1:${secure.port}/',
        customClient: wsClient,
        headers: {'authorization': 'Bearer synthetic'},
      );
      await expectLater(socket.ready, throwsA(anything));
      expect(secureHits, 2);
      expect(insecureHits, 0);

      final successful = await httpsClient.get(endpoint.resolve('/ok'));
      expect(successful.body, 'secure');
      final connected = IOWebSocketChannel.connect(
        'wss://127.0.0.1:${secure.port}/socket',
        customClient: wsClient,
      );
      await connected.ready.timeout(const Duration(seconds: 5));
      connected.sink.add('message');
      expect(
        await connected.stream.first.timeout(const Duration(seconds: 5)),
        'message',
      );
      await connected.sink.close();
      expect(secureHits, 4);
      expect(insecureHits, 0);
    },
    skip: !Platform.isLinux
        ? 'Synthetic TLS fixture requires openssl on Linux'
        : false,
  );
}
