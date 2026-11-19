import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/l10n/app_language.dart';
import 'package:frontend/screens/app_shell.dart';
import 'package:frontend/screens/management_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/student_activity_alerts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response response(dynamic data) => http.Response.bytes(
  utf8.encode(jsonEncode({'success': true, 'data': data})),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const alert = {
  'qr_id': 10,
  'activity_id': 42,
  'activity_title': 'Campus workshop',
  'location': 'E4',
  'starts_at': '2026-11-17T10:00:00Z',
  'expires_at': '2099-01-01T12:00:00Z',
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.token = 'student-session';
    ApiService.currentUser = {'role': 'student', 'user_id': 3};
  });
  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  for (final width in [390.0, 1200.0]) {
    testWidgets(
      'new QR alerts poll, group, persist dismissal and reopen at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final language = AppLanguage();
        addTearDown(language.dispose);
        await language.select('en');
        var feed = <Map<String, dynamic>>[];
        int? opened;
        Widget app() => AppLanguageScope(
          controller: language,
          child: MaterialApp(
            home: Scaffold(
              body: StudentActivityAlerts(onOpenActivity: (id) => opened = id),
            ),
          ),
        );
        await http.runWithClient(
          () async {
            await tester.pumpWidget(app());
            await tester.pumpAndSettle();
            expect(find.text('New Activity alert'), findsNothing);
            feed = [
              {...alert, 'qr_id': 11},
              alert,
            ];
            await tester.pump(const Duration(seconds: 15));
            await tester.pumpAndSettle();
            expect(find.text('New Activity alert'), findsOneWidget);
            expect(find.text('Campus workshop'), findsOneWidget);
            await tester.tap(find.text('View activity'));
            await tester.pumpAndSettle();
            expect(opened, 42);
            expect(
              (await SharedPreferences.getInstance()).getInt(
                'activity-alert-seen-3',
              ),
              11,
            );
            await tester.pump(const Duration(seconds: 15));
            await tester.pumpAndSettle();
            expect(find.text('New Activity alert'), findsNothing);
            // A fresh app instance must not announce the same QR again.
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(app());
            await tester.pumpAndSettle();
            expect(find.text('New Activity alert'), findsNothing);
            await tester.tap(
              find.byKey(const ValueKey('student-activity-alerts')),
            );
            await tester.pumpAndSettle();
            expect(find.text('Campus workshop'), findsOneWidget);
            await tester.tap(find.text('Close'));
            await tester.pumpAndSettle();
            feed = [
              {
                ...alert,
                'qr_id': 12,
                'activity_title': 'Another workshop',
                'activity_id': 43,
              },
            ];
            await tester.pump(const Duration(seconds: 15));
            await tester.pumpAndSettle();
            expect(find.text('Another workshop'), findsOneWidget);
            await tester.tap(find.text('Close'));
            await tester.pumpAndSettle();
            expect(
              (await SharedPreferences.getInstance()).getInt(
                'activity-alert-seen-3',
              ),
              12,
            );
            // Another student on this device receives their own initial alert.
            await tester.pumpWidget(const SizedBox.shrink());
            ApiService.currentUser = {'role': 'student', 'user_id': 4};
            await tester.pumpWidget(app());
            await tester.pumpAndSettle();
            expect(find.text('Another workshop'), findsOneWidget);
            await tester.tap(find.text('Close'));
            await tester.pumpAndSettle();
            await tester.pumpWidget(const SizedBox.shrink());
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/qr/alerts');
            return response(feed);
          }),
        );
      },
    );
  }

  testWidgets('student popup opens the matching activity details in the app', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: AppShell()));
        await tester.pumpAndSettle();
        expect(find.text('แจ้งเตือนกิจกรรมใหม่'), findsOneWidget);
        await tester.tap(find.text('ดูกิจกรรมนี้'));
        await tester.pumpAndSettle();
        final details = tester.widget<ManagementScreen>(
          find.byType(ManagementScreen),
        );
        expect(details.index, 2);
        expect(details.activityId, 42);
        expect(find.text('Campus workshop'), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        switch (request.url.path) {
          case '/api/qr/alerts':
            return response([alert]);
          case '/api/activities':
            return response([
              {
                'activity_id': 42,
                'title': 'Campus workshop',
                'status': 'published',
              },
            ]);
          case '/api/activities/42':
            return response({
              'activity_id': 42,
              'title': 'Campus workshop',
              'status': 'published',
            });
          case '/api/registrations/my':
            return response([]);
          default:
            fail('Unexpected request: ${request.url.path}');
        }
      }),
    );
  });
}
