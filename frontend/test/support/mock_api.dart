import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Empty lists for the screens exercised by the team's navigation tests.
/// Requests from later taps stay in the same mock-client zone.
Future<void> withEmptyListsApi(Future<void> Function() action) =>
    http.runWithClient(
      action,
      () => MockClient((request) async {
        const paths = {
          '/api/activities',
          '/api/registrations/my',
          '/api/admin/users',
        };
        if (request.method != 'GET' || !paths.contains(request.url.path)) {
          throw StateError(
            'Unexpected test API request: ${request.method} '
            '${request.url.path}',
          );
        }
        return http.Response(
          jsonEncode({'success': true, 'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
