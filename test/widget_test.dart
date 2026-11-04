import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:untitled/main.dart';
import 'package:untitled/services/auth_service.dart';

import 'support/auth_fixture.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    MockClient client,
    MemoryTokenStore store,
  ) async {
    await tester.pumpWidget(
      LoginApp(
        authService: AuthService(
          client: client,
          tokenStore: store,
          baseUrl: Uri.parse('https://api.example.test/'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextFormField).first,
      'jean@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'userpass');
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
  }

  testWidgets('Le formulaire bloque les champs invalides', (tester) async {
    var requests = 0;
    await open(
      tester,
      MockClient((_) async {
        requests++;
        return successResponse();
      }),
      MemoryTokenStore(),
    );
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Veuillez entrer un email valide'), findsOneWidget);
    expect(find.text('Veuillez entrer votre mot de passe'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('Connexion, profil, actualisation et déconnexion', (
    tester,
  ) async {
    final store = MemoryTokenStore();
    final routes = <String>[];
    await open(
      tester,
      MockClient((request) async {
        routes.add(request.url.path);
        if (request.url.path != '/login') {
          expect(request.headers['authorization'], 'Bearer $token');
        }
        return request.url.path == '/logout'
            ? http.Response('', 204)
            : successResponse();
      }),
      store,
    );
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Jean Dupont'), findsOneWidget);
    expect(find.text('jean@example.com'), findsOneWidget);
    expect(find.text('Utilisateur'), findsOneWidget);
    expect(store.value, token);
    await tester.ensureVisible(find.text('Actualiser mon profil'));
    await tester.tap(find.text('Actualiser mon profil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Se déconnecter'));
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenue.'), findsOneWidget);
    expect(find.text('Jean Dupont'), findsNothing);
    expect(store.value, isNull);
    expect(routes, ['/login', '/me', '/logout']);
  });

  testWidgets('Les identifiants refusés affichent une erreur', (tester) async {
    await open(
      tester,
      MockClient(
        (_) async => http.Response('{"status":400,"message":"Error"}', 400),
      ),
      MemoryTokenStore(),
    );
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);
    expect(find.text('Bienvenue.'), findsOneWidget);
  });

  testWidgets('Le chargement empêche les doubles soumissions', (tester) async {
    final response = Completer<http.Response>();
    var requests = 0;
    await open(
      tester,
      MockClient((_) {
        requests++;
        return response.future;
      }),
      MemoryTokenStore(),
    );
    await submit(tester);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(requests, 1);
    response.complete(successResponse());
    await tester.pumpAndSettle();
    expect(find.text('Jean Dupont'), findsOneWidget);
  });

  testWidgets('Une session enregistrée restaure le profil via me', (
    tester,
  ) async {
    final store = MemoryTokenStore()..value = token;
    await open(
      tester,
      MockClient((request) async {
        expect(request.url.path, '/me');
        expect(request.headers['authorization'], 'Bearer $token');
        return successResponse();
      }),
      store,
    );
    expect(find.text('Jean Dupont'), findsOneWidget);
    expect(find.text('Se connecter'), findsNothing);
  });

  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1280, 900),
  ]) {
    testWidgets('Formulaire et profil adaptés à $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(
        tester,
        MockClient((_) async => successResponse()),
        MemoryTokenStore(),
      );
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Jean Dupont'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Se déconnecter'));
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(find.text('Bienvenue.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
