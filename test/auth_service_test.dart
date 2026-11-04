import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:untitled/services/auth_service.dart';

import 'support/auth_fixture.dart';

void main() {
  late MemoryTokenStore store;
  late AuthService service;

  AuthService create(
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 1),
  }) {
    service = AuthService(
      client: MockClient(handler),
      tokenStore: store,
      baseUrl: Uri.parse('https://api.example.test/api/'),
      timeout: timeout,
    );
    return service;
  }

  Matcher failure(AuthFailure kind) =>
      isA<AuthException>().having((e) => e.kind, 'type', kind);
  setUp(() {
    store = MemoryTokenStore();
  });
  tearDown(() {
    service.dispose();
  });

  test('POST formulaire conserve le mot de passe et le préfixe URL', () async {
    create((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://api.example.test/api/login');
      expect(
        request.headers['content-type'],
        contains('application/x-www-form-urlencoded'),
      );
      expect(request.bodyFields, {
        'email': 'jean@example.com',
        'password': ' user+pass&= ',
      });
      return successResponse();
    });
    final user = await service.login(' jean@example.com ', ' user+pass&= ');
    expect(user.id, 1);
    expect(user.fullName, 'Jean Dupont');
    expect(user.roleLabel, 'Utilisateur');
    expect(store.value, token);
  });

  test('Les identifiants refusés ne créent pas de session', () async {
    create((_) async => http.Response('{"status":400,"message":"Error"}', 400));
    await expectLater(
      service.login('jean@example.com', 'wrong'),
      throwsA(failure(AuthFailure.credentials)),
    );
    expect(store.value, isNull);
  });

  for (final body in [
    '<html>Erreur</html>',
    'null',
    '[]',
    '{}',
    jsonEncode({...profile, 'id': '1'}),
    jsonEncode({...profile, 'role': 'User'}),
    jsonEncode({...profile, 'firstName': ''}),
  ]) {
    test('Une réponse JSON inattendue est rejetée : $body', () async {
      create(
        (_) async => http.Response(body, 200, headers: {'x-auth-token': token}),
      );
      await expectLater(
        service.login('jean@example.com', 'userpass'),
        throwsA(failure(AuthFailure.protocol)),
      );
      expect(store.value, isNull);
    });
  }

  for (final value in [null, '', 'short', List.filled(64, 'z').join()]) {
    test('Un token absent ou invalide est rejeté : ${value?.length}', () async {
      create(
        (_) async => http.Response(
          jsonEncode(profile),
          200,
          headers: {'x-auth-token': ?value},
        ),
      );
      await expectLater(
        service.login('jean@example.com', 'userpass'),
        throwsA(failure(AuthFailure.protocol)),
      );
      expect(store.value, isNull);
    });
  }

  test(
    'Une erreur serveur reste distincte des identifiants incorrects',
    () async {
      create((_) async => http.Response('Unavailable', 503));
      await expectLater(
        service.login('jean@example.com', 'userpass'),
        throwsA(failure(AuthFailure.server)),
      );
    },
  );

  test('Une panne réseau produit une erreur exploitable', () async {
    create((_) async => throw http.ClientException('offline'));
    await expectLater(
      service.login('jean@example.com', 'userpass'),
      throwsA(failure(AuthFailure.network)),
    );
  });

  test(
    'Le délai dépassé interrompt l’attente sans ouvrir de session',
    () async {
      final pending = Completer<http.Response>();
      create((_) => pending.future, timeout: const Duration(milliseconds: 10));
      await expectLater(
        service.login('jean@example.com', 'userpass'),
        throwsA(failure(AuthFailure.timeout)),
      );
      expect(store.value, isNull);
      pending.complete(successResponse());
      await Future<void>.delayed(Duration.zero);
      expect(store.value, isNull);
    },
  );

  test('Sans token enregistré, aucun appel de restauration', () async {
    var requests = 0;
    create((_) async {
      requests++;
      return successResponse();
    });
    expect(await service.restore(), isNull);
    expect(requests, 0);
  });

  test('La restauration vérifie le profil avec Bearer', () async {
    store.value = token;
    create((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/me');
      expect(request.headers['authorization'], 'Bearer $token');
      return successResponse();
    });
    expect((await service.restore())!.email, 'jean@example.com');
  });

  test('Une session expirée est effacée du stockage', () async {
    store.value = token;
    create((_) async => http.Response('{"status":400,"message":"Error"}', 401));
    await expectLater(service.restore(), throwsA(failure(AuthFailure.expired)));
    expect(store.value, isNull);
  });

  test(
    'Une panne réseau conserve le token pour une reconnexion ultérieure',
    () async {
      store.value = token;
      create((_) async => throw http.ClientException('offline'));
      await expectLater(
        service.restore(),
        throwsA(failure(AuthFailure.network)),
      );
      expect(store.value, token);
    },
  );

  test(
    'Une expiration reste signalée même si le nettoyage local échoue',
    () async {
      store.value = token;
      store.deleteError = PlatformException(code: 'locked');
      create((_) async => http.Response('', 401));
      await expectLater(
        service.restore(),
        throwsA(failure(AuthFailure.expired)),
      );
    },
  );

  for (final status in [204, 401]) {
    test('La déconnexion efface le token après HTTP $status', () async {
      store.value = token;
      create((request) async {
        if (request.url.path.endsWith('/me')) return successResponse();
        expect(request.method, 'POST');
        expect(request.url.path, '/api/logout');
        expect(request.headers['authorization'], 'Bearer $token');
        return http.Response('', status);
      });
      await service.restore();
      await service.logout();
      expect(store.value, isNull);
    });
  }

  test('Hors ligne, la déconnexion efface le token et signale la révocation non confirmée', () async {
    store.value = token;
    create((request) async {
      if (request.url.path.endsWith('/me')) return successResponse();
      throw http.ClientException('offline');
    });
    await service.restore();
    await expectLater(service.logout(), throwsA(failure(AuthFailure.network)));
    expect(store.value, isNull);
  });

  test(
    'Un échec de suppression locale ne prétend pas terminer la déconnexion',
    () async {
      store.value = token;
      store.deleteError = PlatformException(code: 'locked');
      create(
        (request) async => request.url.path.endsWith('/me')
            ? successResponse()
            : http.Response('', 204),
      );
      await service.restore();
      await expectLater(
        service.logout(),
        throwsA(failure(AuthFailure.storage)),
      );
      expect(store.value, token);
    },
  );

  test('Un échec de stockage révoque le nouveau token', () async {
    store.writeError = PlatformException(code: 'locked');
    var revoked = false;
    create((request) async {
      if (request.url.path.endsWith('/logout')) {
        expect(request.headers['authorization'], 'Bearer $token');
        revoked = true;
        return http.Response('', 204);
      }
      return successResponse();
    });
    await expectLater(
      service.login('jean@example.com', 'userpass'),
      throwsA(failure(AuthFailure.storage)),
    );
    expect(revoked, isTrue);
    expect(store.value, isNull);
  });

  for (final error in [
    PlatformException(code: 'locked'),
    MissingPluginException(),
    UnsupportedError('insecure context'),
  ]) {
    test('Erreur de stockage présentée pour ${error.runtimeType}', () async {
      store.readError = error;
      create((_) async => successResponse());
      await expectLater(
        service.restore(),
        throwsA(failure(AuthFailure.storage)),
      );
    });
  }
}
