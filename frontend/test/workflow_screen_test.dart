import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/activity_tool_screen.dart';
import 'package:frontend/screens/app_shell.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/management_screen.dart';
import 'package:frontend/screens/password_screen.dart';
import 'package:frontend/services/activity_qr.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response response(dynamic data) => http.Response.bytes(
  utf8.encode(jsonEncode({'data': data})),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() {
    ActivityQr.pendingCheckIn = null;
    SharedPreferences.setMockInitialValues({});
    ApiService.token = 'workflow-token';
  });
  tearDown(() {
    ActivityQr.pendingCheckIn = null;
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  test('activity QR preserves the activity context and supports existing token-only codes', () {
    final encoded = const ActivityQr(
      activityId: 42,
      token: 'token-42',
    ).encode();
    expect(ActivityQr.parse(encoded).activityId, 42);
    expect(ActivityQr.parse(encoded).token, 'token-42');
    expect(ActivityQr.parse('legacy-token').activityId, isNull);
    expect(ActivityQr.parse('legacy-token').token, 'legacy-token');
    for (final invalid in [
      '',
      '{}',
      '{"activity_id":0,"token":"value"}',
      '{"activity_id":42,"token":1}',
    ]) {
      expect(() => ActivityQr.parse(invalid), throwsFormatException);
    }
  });

  testWidgets(
    'student opens an activity from overview, checks in and sees points from the same activity',
    (tester) async {
      ApiService.currentUser = {'role': 'student', 'user_id': 3};
      var attended = false;
      const activity = {
        'activity_id': 42,
        'title': 'Shared workshop',
        'status': 'published',
        'points': 75,
      };
      await http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: AppShell()));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Shared workshop'));
          await tester.pumpAndSettle();
          final detail = tester.widget<ManagementScreen>(
            find.byType(ManagementScreen),
          );
          expect(detail.index, 2);
          expect(detail.activityId, 42);
          await tester.tap(find.widgetWithText(TextButton, 'เช็คอิน QR'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ActivityToolScreen>(find.byType(ActivityToolScreen))
                .activityId,
            42,
          );
          expect(
            tester
                .widget<DropdownButtonFormField<int>>(
                  find.byType(DropdownButtonFormField<int>),
                )
                .initialValue,
            42,
          );
          await tester.enterText(
            find.byType(TextField),
            const ActivityQr(activityId: 42, token: 'valid-qr').encode(),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('ยืนยัน Check-in'));
          await tester.pumpAndSettle();
          expect(attended, isTrue);
          expect(find.text('เช็คอินสำเร็จ ได้รับ 75 คะแนน'), findsOneWidget);
          await tester.tap(find.text('ดูคะแนนสะสม'));
          await tester.pumpAndSettle();
          expect(find.text('คะแนนรวม: 75'), findsOneWidget);
          expect(find.text('Shared workshop'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          switch (request.url.path) {
            case '/api/qr/alerts':
              return response([]);
            case '/api/activities':
              return response([activity]);
            case '/api/activities/42':
              return response(activity);
            case '/api/registrations/my':
              return response([
                {
                  ...activity,
                  'activity_status': 'published',
                  'registration_status': attended ? 'attended' : 'registered',
                },
              ]);
            case '/api/checkins':
              expect(request.method, 'POST');
              expect(jsonDecode(request.body), {
                'activity_id': 42,
                'token': 'valid-qr',
              });
              attended = true;
              return response({'activity_id': 42, 'points': 75});
            case '/api/points/my':
              return response({'total_points': attended ? 75 : 0});
            case '/api/points/history':
              return response([
                {'activity_title': 'Shared workshop', 'points': 75},
              ]);
            default:
              fail('Unexpected request: ${request.url.path}');
          }
        }),
      );
    },
  );

  testWidgets(
    'lecturer row actions carry one activity through participants and QR creation',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ApiService.currentUser = {'role': 'lecturer', 'user_id': 7};
      final savedCodes = <Map<String, dynamic>>[];
      String? copiedLink;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedLink = (call.arguments as Map)['text'];
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: AppShell()));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('sidebar-activities')));
          await tester.pumpAndSettle();
          final participants = find.byTooltip('ผู้เข้าร่วม');
          expect(participants, findsNWidgets(2));
          await tester.ensureVisible(participants.last);
          await tester.tap(participants.last);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<DropdownButtonFormField<int>>(
                  find.byType(DropdownButtonFormField<int>),
                )
                .initialValue,
            42,
          );
          expect(find.text('Registered Student'), findsOneWidget);
          expect(find.text('student@example.invalid'), findsOneWidget);
          expect(find.text('75'), findsOneWidget);
          await tester.tap(find.byType(DropdownButtonFormField<int>));
          await tester.pumpAndSettle();
          expect(find.text('Other lecturer workshop'), findsNothing);
          await tester.tap(find.text('First workshop').last);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('activity-tab-qrCodes')));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<DropdownButtonFormField<int>>(
                  find.byType(DropdownButtonFormField<int>),
                )
                .initialValue,
            41,
          );
          await tester.tap(find.text('สร้าง QR Code'));
          await tester.pumpAndSettle();
          expect(find.byType(TextFormField), findsNWidgets(2));
          await tester.tap(find.widgetWithText(FilledButton, 'สร้าง'));
          await tester.pumpAndSettle();
          expect(find.byType(QrImageView), findsOneWidget);
          expect(find.byType(SelectableText), findsNothing);
          expect(
            tester
                .widget<QrImageView>(find.byType(QrImageView))
                .backgroundColor,
            Colors.white,
          );
          await tester.tap(find.text('คัดลอกลิงก์เช็คอิน'));
          await tester.pumpAndSettle();
          final payload = ActivityQr.parse(copiedLink!);
          expect(payload.activityId, 41);
          expect(payload.token, 'generated-token');
          await tester.tap(find.text('ปิด'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('รีเฟรช'));
          await tester.pumpAndSettle();
          expect(find.textContaining('QR #9'), findsOneWidget);
          await tester.ensureVisible(find.byKey(const ValueKey('show-qr-9')));
          await tester.tap(find.byKey(const ValueKey('show-qr-9')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('คัดลอกลิงก์เช็คอิน'));
          await tester.pumpAndSettle();
          expect(ActivityQr.parse(copiedLink!).token, payload.token);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          switch (request.url.path) {
            case '/api/lecturer/dashboard':
              return response({'stats': {}, 'activities': []});
            case '/api/activities':
              return response([
                {
                  'activity_id': 41,
                  'organizer_id': 7,
                  'title': 'First workshop',
                  'status': 'published',
                },
                {
                  'activity_id': 42,
                  'organizer_id': 7,
                  'title': 'Selected workshop',
                  'status': 'published',
                },
                {
                  'activity_id': 43,
                  'organizer_id': 8,
                  'title': 'Other lecturer workshop',
                  'status': 'published',
                },
              ]);
            case '/api/lecturer/activities/41/participants':
            case '/api/lecturer/activities/42/participants':
              return response([
                {
                  'full_name': 'Registered Student',
                  'student_code': 'S-1',
                  'email': 'student@example.invalid',
                  'total_points': 75,
                  'registration_status': 'registered',
                },
              ]);
            case '/api/qr/41':
              if (request.method == 'GET') return response(savedCodes);
              expect(request.method, 'POST');
              final dates = jsonDecode(request.body) as Map;
              expect(
                DateTime.parse(dates['expires_at'])
                    .isAfter(DateTime.parse(dates['starts_at'])),
                isTrue,
              );
              final saved = {
                'qr_id': 9,
                'activity_id': 41,
                'token': 'generated-token',
                ...dates,
              };
              savedCodes.insert(0, Map<String, dynamic>.from(saved));
              return response(saved);
            default:
              fail('Unexpected request: ${request.url.path}');
          }
        }),
      );
    },
  );

  testWidgets(
    'admin creates a lecturer using the existing account endpoint and reloads accounts',
    (tester) async {
      ApiService.currentUser = {'role': 'admin', 'user_id': 1};
      var created = false;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: ManagementScreen(index: 14, title: 'Accounts'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('สร้างบัญชีอาจารย์'));
          await tester.pumpAndSettle();
          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(0), 'New Lecturer');
          await tester.enterText(fields.at(1), 'lecturer@example.invalid');
          await tester.enterText(fields.at(2), 'Temporary-password-27');
          await tester.tap(find.widgetWithText(FilledButton, 'สร้าง'));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 400));
          expect(created, isTrue);
          expect(find.text('New Lecturer'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            expect(request.url.path, '/api/admin/lecturers');
            expect(
              (jsonDecode(request.body) as Map)['email'],
              'lecturer@example.invalid',
            );
            created = true;
            return response({'user_id': 12});
          }
          expect(request.url.path, '/api/admin/users');
          return response(
            created
                ? [
                    {
                      'user_id': 12,
                      'full_name': 'New Lecturer',
                      'email': 'lecturer@example.invalid',
                      'role': 'lecturer',
                      'is_active': 1,
                    },
                  ]
                : [],
          );
        }),
      );
    },
  );

  testWidgets(
    'restoring a first-login lecturer session stays on password change',
    (tester) async {
      ApiService.currentUser = {
        'role': 'lecturer',
        'must_change_password': true,
      };
      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();
      expect(find.byType(PasswordScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-activities')), findsNothing);
      expect(find.byKey(const ValueKey('sidebar-activities')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an inactive or expired session clears saved credentials and returns to login',
    (tester) async {
      await ApiService.saveSession('expired-token', {'role': 'student'});
      await http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: AppShell()));
          await tester.pumpAndSettle();
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(ApiService.token, isNull);
          expect(ApiService.currentUser, isNull);
          expect(
            (await SharedPreferences.getInstance()).getString('jwt'),
            isNull,
          );
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (_) async => http.Response('{"message":"Account is inactive"}', 401),
        ),
      );
    },
  );
}
