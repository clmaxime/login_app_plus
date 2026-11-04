import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:untitled/services/auth_service.dart';

import 'support/auth_fixture.dart';

void main() {
  late Directory directory;
  late Process server;
  late Uri baseUrl;
  var started = false;
  late AuthService service;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('login-api-test-');
    final environment = {
      'APP_ENV': 'development',
      'DB_PATH': '${directory.path}${Platform.pathSeparator}auth.sqlite',
    };
    final seed = await Process.run('php', [
      'api/bin/seed.php',
    ], environment: environment);
    if (seed.exitCode != 0) {
      throw StateError('Initialisation PHP impossible : ${seed.stderr}');
    }
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    baseUrl = Uri.parse('http://127.0.0.1:$port/');
    server = await Process.start('php', [
      '-S',
      '127.0.0.1:$port',
      'api/router.php',
    ], environment: environment);
    started = true;
    server.stdout.drain<void>();
    server.stderr.drain<void>();
    final probe = http.Client();
    try {
      for (var attempt = 0; attempt < 100; attempt++) {
        try {
          final response = await probe
              .get(baseUrl.resolve('me'))
              .timeout(const Duration(seconds: 1));
          if (response.statusCode == 401) return;
        } on Exception {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
      throw StateError('Le serveur PHP ne répond pas.');
    } finally {
      probe.close();
    }
  });

  tearDownAll(() async {
    if (started) {
      server.kill();
      await server.exitCode.timeout(const Duration(seconds: 5));
    }
    await directory.delete(recursive: true);
  });

  tearDown(() {
    service.dispose();
  });

  test('Le service Flutter communique réellement avec PHP : connexion, me, révocation', () async {
    final store = MemoryTokenStore();
    service = AuthService(baseUrl: baseUrl, tokenStore: store);
    final user = await service.login('jean@example.com', 'userpass');
    expect(user.fullName, 'Jean Dupont');
    expect(user.role, 2);
    final issuedToken = store.value!;
    expect(issuedToken, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect((await service.me()).email, user.email);
    await service.logout();
    expect(store.value, isNull);
    final client = http.Client();
    try {
      final response = await client.get(
        baseUrl.resolve('me'),
        headers: {'Authorization': 'Bearer $issuedToken'},
      );
      expect(response.statusCode, 401);
    } finally {
      client.close();
    }
  });

  test('PHP refuse les mauvais identifiants transmis par Flutter', () async {
    final store = MemoryTokenStore();
    service = AuthService(baseUrl: baseUrl, tokenStore: store);
    await expectLater(
      service.login('jean@example.com', 'wrong'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.kind,
          'type',
          AuthFailure.credentials,
        ),
      ),
    );
    expect(store.value, isNull);
  });

  test(
    'Flutter restaure une session réelle enregistrée après connexion',
    () async {
      final store = MemoryTokenStore();
      final initial = AuthService(baseUrl: baseUrl, tokenStore: store);
      try {
        await initial.login('julie@example.com', 'adminpass');
      } finally {
        initial.dispose();
      }
      service = AuthService(baseUrl: baseUrl, tokenStore: store);
      final user = await service.restore();
      expect(user!.fullName, 'Julie Martin');
      expect(user.roleLabel, 'Administrateur');
      await service.logout();
      expect(store.value, isNull);
    },
  );
}
