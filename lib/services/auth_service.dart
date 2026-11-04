import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user.dart';
import 'token_store.dart';

enum AuthFailure {
  credentials,
  expired,
  network,
  timeout,
  server,
  protocol,
  storage,
}

class AuthException implements Exception {
  const AuthException(this.kind, this.message);
  final AuthFailure kind;
  final String message;
}

class AuthService {
  AuthService({
    http.Client? client,
    TokenStore? tokenStore,
    Uri? baseUrl,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client(),
       _store = tokenStore ?? SecureTokenStore(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl;
  final http.Client _client;
  final TokenStore _store;
  final Uri _baseUrl;
  final Duration timeout;
  String? _token;
  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };
  Uri _uri(String path) => _baseUrl.resolve(path);

  Future<http.Response> _request(Future<http.Response> Function() send) async {
    try {
      return await send().timeout(timeout);
    } on TimeoutException {
      throw const AuthException(
        AuthFailure.timeout,
        'Le serveur met trop de temps à répondre. Réessayez.',
      );
    } on http.ClientException {
      throw const AuthException(
        AuthFailure.network,
        'Connexion impossible. Vérifiez votre réseau et l’adresse de l’API.',
      );
    }
  }

  User _user(http.Response response, {bool login = false}) {
    if (response.statusCode >= 500) {
      throw const AuthException(
        AuthFailure.server,
        'Le serveur est indisponible. Réessayez plus tard.',
      );
    }
    if (response.statusCode == 401) {
      throw const AuthException(
        AuthFailure.expired,
        'Votre session a expiré. Reconnectez-vous.',
      );
    }
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) throw const FormatException();
      if (login &&
          response.statusCode == 400 &&
          json['status'] == 400 &&
          json['message'] == 'Error') {
        throw const AuthException(
          AuthFailure.credentials,
          'Email ou mot de passe incorrect.',
        );
      }
      if (response.statusCode != 200 ||
          json['status'] != 200 ||
          json['message'] != 'Success') {
        throw const FormatException();
      }
      return User.fromJson(json);
    } on FormatException {
      throw const AuthException(
        AuthFailure.protocol,
        'Réponse du serveur inattendue. Vérifiez la configuration de l’API.',
      );
    }
  }

  Future<T> _storage<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException {
      throw const AuthException(
        AuthFailure.storage,
        'Le stockage sécurisé est indisponible sur cet appareil.',
      );
    } on MissingPluginException {
      throw const AuthException(
        AuthFailure.storage,
        'Le stockage sécurisé nécessite un redémarrage complet de l’application.',
      );
    } catch (_) {
      throw const AuthException(
        AuthFailure.storage,
        'Impossible d’accéder au stockage sécurisé. Vérifiez les autorisations de votre appareil.',
      );
    }
  }

  Future<User> login(String email, String password) async {
    final response = await _request(
      () => _client.post(
        _uri('login'),
        headers: {'Accept': 'application/json'},
        body: {'email': email.trim(), 'password': password},
      ),
    );
    final user = _user(response, login: true);
    final token = response.headers['x-auth-token'];
    if (token == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
      throw const AuthException(
        AuthFailure.protocol,
        'Le serveur n’a pas fourni de session valide.',
      );
    }
    _token = token;
    try {
      await _storage(() => _store.write(token));
    } catch (_) {
      try {
        await _request(() => _client.post(_uri('logout'), headers: _headers));
      } catch (_) {}
      _token = null;
      rethrow;
    }
    return user;
  }

  Future<User?> restore() async {
    _token = await _storage(_store.read);
    if (_token == null) return null;
    return me();
  }

  Future<User> me() async {
    try {
      return _user(
        await _request(() => _client.get(_uri('me'), headers: _headers)),
      );
    } on AuthException catch (error) {
      if (error.kind == AuthFailure.expired) {
        _token = null;
        try {
          await _storage(_store.delete);
        } on AuthException {
          throw const AuthException(
            AuthFailure.expired,
            'Votre session a expiré. Le stockage local n’a pas pu être nettoyé.',
          );
        }
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    AuthException? remoteError;
    try {
      if (_token != null) {
        final response = await _request(
          () => _client.post(_uri('logout'), headers: _headers),
        );
        if (response.statusCode != 204 && response.statusCode != 401) {
          throw const AuthException(
            AuthFailure.server,
            'Déconnexion distante impossible.',
          );
        }
      }
    } on AuthException catch (error) {
      remoteError = error;
    }
    await _storage(_store.delete);
    _token = null;
    if (remoteError != null) {
      throw const AuthException(
        AuthFailure.network,
        'Session effacée de cet appareil. Révocation distante non confirmée ; expiration sous une heure.',
      );
    }
  }

  void dispose() => _client.close();
}
