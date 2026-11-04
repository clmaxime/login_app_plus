import 'package:flutter/foundation.dart';

class ApiConfig {
  static Uri get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    final value = configured.isNotEmpty
        ? configured
        : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
              ? 'http://10.0.2.2:8080/'
              : 'http://localhost:8080/');
    final uri = Uri.tryParse(value.endsWith('/') ? value : '$value/');
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'API_BASE_URL doit être une URL HTTP(S) absolue.',
      );
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw const FormatException(
        'API_BASE_URL doit utiliser HTTPS en production.',
      );
    }
    return uri;
  }
}
