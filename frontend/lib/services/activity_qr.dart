import 'dart:convert';

import 'api_config.dart';

/// Carries the activity context from the organizer's display to student check-in.
class ActivityQr {
  static ActivityQr? pendingCheckIn;
  const ActivityQr({required this.token, this.activityId});

  final int? activityId;
  final String token;

  String encode() => jsonEncode({'activity_id': activityId, 'token': token});

  String toLink({Uri? origin}) {
    final base = origin ?? Uri.parse(ApiConfig.baseUrl);
    return base
        .replace(
          path: '/',
          query: null,
          fragment: Uri(
            path: '/check-in',
            queryParameters: {'activity_id': '$activityId', 'token': token},
          ).toString(),
        )
        .toString();
  }

  static void captureLink(Uri uri) {
    if (!uri.fragment.startsWith('/check-in?')) return;
    try {
      pendingCheckIn = parse(uri.toString());
    } on FormatException {
      /* Show the normal app for an invalid link. */
    }
  }

  static ActivityQr parse(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && ['http', 'https'].contains(uri.scheme)) {
      final target = uri.fragment.startsWith('/check-in?')
          ? Uri.parse(uri.fragment)
          : uri;
      final id = int.tryParse(target.queryParameters['activity_id'] ?? '');
      final token = target.queryParameters['token']?.trim();
      if (id == null ||
          id <= 0 ||
          token == null ||
          token.isEmpty ||
          target.path != '/check-in') {
        throw const FormatException('Invalid QR code');
      }
      return ActivityQr(activityId: id, token: token);
    }
    if (trimmed.startsWith('{')) {
      final data = jsonDecode(trimmed);
      if (data is! Map || data['token'] is! String) {
        throw const FormatException('Invalid QR code');
      }
      final id = int.tryParse('${data['activity_id']}');
      final token = (data['token'] as String).trim();
      if (id == null || id <= 0 || token.isEmpty) {
        throw const FormatException('Invalid QR code');
      }
      return ActivityQr(activityId: id, token: token);
    }
    if (trimmed.isEmpty) throw const FormatException('Invalid QR code');
    // Existing printed QR codes contained only the token.
    return ActivityQr(token: trimmed);
  }
}
