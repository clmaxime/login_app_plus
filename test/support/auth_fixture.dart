import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:untitled/services/token_store.dart';

const profile = {
  'status': 200,
  'message': 'Success',
  'id': 1,
  'firstName': 'Jean',
  'lastName': 'Dupont',
  'email': 'jean@example.com',
  'role': 2,
};

final token = List.filled(64, 'a').join();

http.Response successResponse() => http.Response(
  jsonEncode(profile),
  200,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'x-auth-token': token,
  },
);

class MemoryTokenStore implements TokenStore {
  String? value;
  Object? readError;
  Object? writeError;
  Object? deleteError;
  @override
  Future<String?> read() async {
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> write(String token) async {
    if (writeError != null) throw writeError!;
    value = token;
  }

  @override
  Future<void> delete() async {
    if (deleteError != null) throw deleteError!;
    value = null;
  }
}
