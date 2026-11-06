import 'package:flutter/foundation.dart';

class ApiConfig {
  static const _configuredUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredUrl.isNotEmpty) {
      return _configuredUrl.replaceFirst(RegExp(r'/+$'), '');
    }

    // Chrome / Flutter Web
    if (kIsWeb) {
      return kReleaseMode ? Uri.base.origin : 'http://localhost:3000';
    }

    // Android Emulator
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }

    // Windows Desktop
    return 'http://localhost:3000';
  }
}
