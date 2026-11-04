import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this.service);
  final AuthService service;
  User? user;
  bool busy = false;
  bool restoring = true;
  String? error;
  bool _disposed = false;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    try {
      user = await service.restore();
    } on AuthException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Impossible de restaurer la session. Réessayez.';
    }
    restoring = false;
    _changed();
  }

  Future<void> login(String email, String password) async {
    if (busy) return;
    busy = true;
    error = null;
    _changed();
    try {
      user = await service.login(email, password);
    } on AuthException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Une erreur est survenue. Réessayez.';
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> refresh() async {
    if (busy) return;
    busy = true;
    error = null;
    _changed();
    try {
      user = await service.me();
    } on AuthException catch (e) {
      error = e.message;
      if (e.kind == AuthFailure.expired) user = null;
    } catch (_) {
      error = 'Impossible d’actualiser le profil.';
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> logout() async {
    if (busy) return;
    busy = true;
    error = null;
    _changed();
    try {
      await service.logout();
      user = null;
    } on AuthException catch (e) {
      error = e.message;
      if (e.kind != AuthFailure.storage) user = null;
    } catch (_) {
      error = 'Impossible d’effacer la session. Réessayez.';
    } finally {
      busy = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    service.dispose();
    super.dispose();
  }
}
