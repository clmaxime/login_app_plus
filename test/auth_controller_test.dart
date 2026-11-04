import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:untitled/controllers/auth_controller.dart';
import 'package:untitled/services/auth_service.dart';

import 'support/auth_fixture.dart';

void main() {
  late MemoryTokenStore store;
  late AuthController auth;
  AuthController create(Future<http.Response> Function(http.Request) handler) {
    auth = AuthController(
      AuthService(
        client: MockClient(handler),
        tokenStore: store,
        baseUrl: Uri.parse('https://api.example.test/'),
      ),
    );
    return auth;
  }

  setUp(() {
    store = MemoryTokenStore();
  });
  tearDown(() {
    auth.dispose();
  });

  test('Une double soumission ne crée qu’une requête', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    var requests = 0;
    create((_) {
      requests++;
      started.complete();
      return pending.future;
    });
    final first = auth.login('jean@example.com', 'userpass');
    await auth.login('jean@example.com', 'userpass');
    await started.future;
    expect(auth.busy, isTrue);
    expect(requests, 1);
    pending.complete(successResponse());
    await first;
    expect(auth.busy, isFalse);
    expect(auth.user!.fullName, 'Jean Dupont');
  });

  test(
    'Une erreur remet le chargement à zéro et permet de réessayer',
    () async {
      var fail = true;
      create(
        (_) async => fail
            ? http.Response('{"status":400,"message":"Error"}', 400)
            : successResponse(),
      );
      await auth.login('jean@example.com', 'wrong');
      expect(auth.busy, isFalse);
      expect(auth.user, isNull);
      expect(auth.error, isNotNull);
      fail = false;
      await auth.login('jean@example.com', 'userpass');
      expect(auth.error, isNull);
      expect(auth.user, isNotNull);
    },
  );

  test('Une restauration impossible termine l’écran de chargement', () async {
    store.readError = PlatformException(code: 'locked');
    create((_) async => successResponse());
    await auth.restore();
    expect(auth.restoring, isFalse);
    expect(auth.user, isNull);
    expect(auth.error, isNotNull);
  });

  test('Une expiration lors de l’actualisation ferme le profil', () async {
    create(
      (request) async => request.url.path == '/login'
          ? successResponse()
          : http.Response('', 401),
    );
    await auth.login('jean@example.com', 'userpass');
    await auth.refresh();
    expect(auth.user, isNull);
    expect(auth.error, contains('expiré'));
    expect(auth.busy, isFalse);
    expect(store.value, isNull);
  });

  test(
    'Une panne lors de l’actualisation conserve le profil affiché',
    () async {
      create((request) async {
        if (request.url.path == '/login') return successResponse();
        throw http.ClientException('offline');
      });
      await auth.login('jean@example.com', 'userpass');
      await auth.refresh();
      expect(auth.user!.fullName, 'Jean Dupont');
      expect(auth.error, isNotNull);
      expect(auth.busy, isFalse);
    },
  );

  test('La déconnexion hors ligne ferme le profil et avertit', () async {
    create((request) async {
      if (request.url.path == '/login') return successResponse();
      throw http.ClientException('offline');
    });
    await auth.login('jean@example.com', 'userpass');
    await auth.logout();
    expect(auth.user, isNull);
    expect(store.value, isNull);
    expect(auth.error, contains('Révocation distante non confirmée'));
    expect(auth.busy, isFalse);
  });

  test(
    'Un échec de suppression du token laisse la déconnexion réessayable',
    () async {
      create(
        (request) async => request.url.path == '/login'
            ? successResponse()
            : http.Response('', 204),
      );
      await auth.login('jean@example.com', 'userpass');
      store.deleteError = PlatformException(code: 'locked');
      await auth.logout();
      expect(auth.user, isNotNull);
      expect(auth.error, isNotNull);
      expect(auth.busy, isFalse);
      store.deleteError = null;
      await auth.logout();
      expect(auth.user, isNull);
      expect(store.value, isNull);
    },
  );
}
