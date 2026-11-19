import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/l10n/app_language.dart';
import 'package:frontend/screens/app_shell.dart';
import 'package:frontend/screens/management_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.token = 'test-token';
  });
  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  const menus = {
    'admin': ['overview', 'activities', 'studentDetails', 'users', 'settings'],
    'lecturer': ['overview', 'activities', 'studentDetails'],
    'student': ['overview', 'activities', 'checkIn', 'points'],
  };
  const tabs = {
    'admin': ['activities', 'activityDetails', 'qrCodes'],
    'lecturer': ['activities', 'activityDetails', 'registrations', 'qrCodes'],
    'student': ['activities', 'activityDetails', 'registrations'],
  };

  for (final role in menus.keys) {
    for (final width in [1200.0, 390.0]) {
      for (final locale in ['en', 'th']) {
        testWidgets('$role navigation at $width in $locale', (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          ApiService.currentUser = {
            'role': role,
            'full_name': 'Test User',
            'user_id': 7,
          };
          final language = AppLanguage();
          addTearDown(language.dispose);
          await language.select(locale);
          final requests = <String>[];

          await http.runWithClient(
            () async {
              await tester.pumpWidget(
                AppLanguageScope(
                  controller: language,
                  child: MaterialApp(
                    locale: language.locale,
                    supportedLocales: const [Locale('th'), Locale('en')],
                    localizationsDelegates:
                        GlobalMaterialLocalizations.delegates,
                    home: const AppShell(),
                  ),
                ),
              );
              await tester.pumpAndSettle();

              if (width < 900) {
                expect(
                  find.byType(NavigationDestination),
                  findsNWidgets(menus[role]!.length),
                );
                for (final page in menus[role]!) {
                  expect(find.byKey(ValueKey('bottom-$page')), findsOneWidget);
                }
                await tester.tap(find.byKey(const ValueKey('open-navigation')));
                await tester.pumpAndSettle();
              }
              expect(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is ListTile &&
                      widget.key is ValueKey<String> &&
                      (widget.key as ValueKey<String>).value.startsWith(
                        'sidebar-',
                      ),
                ),
                findsNWidgets(menus[role]!.length),
              );
              for (final page in menus[role]!) {
                expect(find.byKey(ValueKey('sidebar-$page')), findsOneWidget);
              }
              await tester.tap(
                find.byKey(const ValueKey('sidebar-activities')),
              );
              await tester.pumpAndSettle();
              expect(find.byType(Tab), findsNWidgets(tabs[role]!.length));
              expect(
                tester
                    .widget<ManagementScreen>(find.byType(ManagementScreen))
                    .index,
                1,
              );
              expect(
                find.text(locale == 'en' ? 'Add activity' : 'เพิ่มกิจกรรม'),
                role == 'student' ? findsNothing : findsOneWidget,
              );

              if (role != 'student') {
                if (width < 900) {
                  await tester.tap(
                    find.byKey(const ValueKey('open-navigation')),
                  );
                  await tester.pumpAndSettle();
                }
                await tester.tap(
                  find.byKey(const ValueKey('sidebar-studentDetails')),
                );
                await tester.pumpAndSettle();
                expect(
                  find.text(
                    locale == 'en' ? 'Student details' : 'รายละเอียดนักศึกษา',
                  ),
                  findsWidgets,
                );
                expect(find.text('student@example.invalid'), findsOneWidget);
                if (width < 900) {
                  await tester.tap(
                    find.byKey(const ValueKey('open-navigation')),
                  );
                  await tester.pumpAndSettle();
                }
                await tester.tap(
                  find.byKey(const ValueKey('sidebar-activities')),
                );
                await tester.pumpAndSettle();
              }

              await tester.tap(
                find.byKey(const ValueKey('activity-tab-activityDetails')),
              );
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<ManagementScreen>(find.byType(ManagementScreen))
                    .index,
                2,
              );

              final lastTab = find.byKey(
                ValueKey('activity-tab-${tabs[role]!.last}'),
              );
              await tester.ensureVisible(lastTab);
              await tester.tap(lastTab);
              await tester.pumpAndSettle();
              if (role == 'student') {
                expect(
                  find.text(
                    locale == 'en'
                        ? 'No registrations yet'
                        : 'ยังไม่มีรายการลงทะเบียน',
                  ),
                  findsOneWidget,
                );
              } else {
                await tester.tap(
                  find.text(
                    locale == 'en' ? 'Create QR code' : 'สร้าง QR Code',
                  ),
                );
                await tester.pumpAndSettle();
                expect(find.byType(AlertDialog), findsOneWidget);
                await tester.tap(
                  find.text(locale == 'en' ? 'Cancel' : 'ยกเลิก'),
                );
                await tester.pumpAndSettle();
              }

              // A resize retains the current tab and access to every primary page.
              tester.view.physicalSize = Size(width < 900 ? 1200 : 390, 900);
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<ManagementScreen>(find.byType(ManagementScreen))
                    .index,
                role == 'student' ? 3 : 5,
              );
              expect(tester.takeException(), isNull);
              expect(
                requests.where((path) => path == '/api/admin/users'),
                role == 'admin' ? hasLength(1) : isEmpty,
              );
              expect(
                requests.where((path) => path == '/api/lecturer/students'),
                role == 'lecturer' ? hasLength(1) : isEmpty,
              );
              expect(
                requests.where((path) => path == '/api/points/history'),
                isEmpty,
              );
            },
            () => MockClient((request) async {
              requests.add(request.url.path);
              expect(request.method, 'GET');
              final dynamic data = request.url.path.endsWith('/dashboard')
                  ? <String, dynamic>{}
                  : request.url.path == '/api/activities'
                  ? [
                      {
                        'activity_id': 1,
                        'organizer_id': 7,
                        'title': 'Workshop',
                        'status': 'published',
                      },
                    ]
                  : request.url.path == '/api/admin/users' ||
                        request.url.path == '/api/lecturer/students'
                  ? [
                      {
                        'user_id': 9,
                        'student_code': 'S-9',
                        'full_name': 'Student Example',
                        'email': 'student@example.invalid',
                        'total_points': 75,
                        'is_active': 1,
                      },
                    ]
                  : <dynamic>[];
              return http.Response(jsonEncode({'data': data}), 200);
            }),
          );
        });
      }
    }
  }

  const denied = {
    'admin': [3, 4, 13, 7, 9, 11],
    'lecturer': [4, 13, 14, 7, 9, 11, 16],
    'student': [5, 6, 14, 17, 7, 9, 11, 16],
    'unknown': [1, 2, 3, 4, 5, 6, 13, 14, 16, 17],
  };
  for (final entry in denied.entries) {
    testWidgets(
      '${entry.key} cannot open restricted pages or request their data',
      (tester) async {
        ApiService.currentUser = {'role': entry.key};
        final requests = <String>[];
        await http.runWithClient(
          () async {
            for (final index in entry.value) {
              await tester.pumpWidget(
                MaterialApp(
                  home: Scaffold(
                    body: ManagementScreen(
                      key: ValueKey(index),
                      index: index,
                      title: 'Restricted',
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(
                find.text('หน้านี้ไม่พร้อมใช้งานสำหรับบัญชีของคุณ'),
                findsOneWidget,
              );
              expect(find.byType(TextField), findsNothing);
              expect(find.byType(DataTable), findsNothing);
            }
            expect(requests, isEmpty);
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            requests.add(request.url.path);
            return http.Response(jsonEncode({'data': []}), 200);
          }),
        );
      },
    );
  }

  testWidgets('students can cancel their registrations and view points', (
    tester,
  ) async {
    ApiService.currentUser = {'role': 'student'};
    var cancelled = false;
    var registrationLoads = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: AppShell()));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('bottom-activities')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('activity-tab-registrations')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Workshop registration'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(cancelled, isFalse);
        await tester.tap(find.text('ยืนยันยกเลิก'));
        await tester.pumpAndSettle();
        expect(cancelled, isTrue);
        expect(find.text('ยกเลิกแล้ว'), findsOneWidget);
        expect(registrationLoads, 3);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'ยกเลิก'))
              .onPressed,
          isNull,
        );
        await tester.tap(find.byKey(const ValueKey('bottom-points')));
        await tester.pumpAndSettle();
        expect(find.text('Awarded workshop'), findsOneWidget);
        expect(find.text('75'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        dynamic data = <dynamic>[];
        switch (request.url.path) {
          case '/api/qr/alerts':
            data = [];
          case '/api/activities':
            expect(request.method, 'GET');
          case '/api/registrations/my':
            expect(request.method, 'GET');
            registrationLoads++;
            data = [
              {
                'activity_id': 42,
                'title': 'Workshop registration',
                'status': cancelled ? 'cancelled' : 'registered',
              },
            ];
          case '/api/registrations/42':
            expect(request.method, 'DELETE');
            cancelled = true;
          case '/api/points/history':
            expect(request.method, 'GET');
            data = [
              {
                'activity_title': 'Awarded workshop',
                'points': 75,
                'created_at': '2026-11-16',
              },
            ];
          case '/api/points/my':
            data = {'total_points': 75};
          default:
            fail('Unexpected request: ${request.url.path}');
        }
        return http.Response(jsonEncode({'data': data}), 200);
      }),
    );
  });

  testWidgets('lecturers can edit only activities they own', (tester) async {
    ApiService.currentUser = {'role': 'lecturer', 'user_id': 7};
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManagementScreen(index: 1, title: 'Activities'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('My workshop'), findsOneWidget);
        expect(find.text('Other workshop'), findsOneWidget);
        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
        expect(find.text('เพิ่มกิจกรรม'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        expect(request.url.path, '/api/activities');
        return http.Response(
          jsonEncode({
            'data': [
              {'activity_id': 1, 'organizer_id': '7', 'title': 'My workshop'},
              {'activity_id': 2, 'organizer_id': 8, 'title': 'Other workshop'},
            ],
          }),
          200,
        );
      }),
    );
  });

  testWidgets('changing from admin to lecturer removes a stale accounts page', (
    tester,
  ) async {
    final refresh = ValueNotifier(0);
    addTearDown(refresh.dispose);
    ApiService.currentUser = {'role': 'admin'};
    var requests = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<int>(
                valueListenable: refresh,
                builder: (_, _, _) => ManagementScreen(
                  index: 14,
                  title: 'Accounts ${ApiService.currentUser?["role"]}',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('ไม่มีข้อมูลผู้ใช้'), findsOneWidget);
        expect(requests, 1);
        ApiService.currentUser = {'role': 'lecturer'};
        refresh.value++;
        await tester.pumpAndSettle();
        expect(
          find.text('หน้านี้ไม่พร้อมใช้งานสำหรับบัญชีของคุณ'),
          findsOneWidget,
        );
        expect(find.text('ไม่มีข้อมูลผู้ใช้'), findsNothing);
        expect(requests, 1);
      },
      () => MockClient((request) async {
        requests++;
        return http.Response(jsonEncode({'data': []}), 200);
      }),
    );
  });
}
