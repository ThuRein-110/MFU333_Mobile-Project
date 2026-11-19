import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/l10n/app_language.dart';
import 'package:frontend/screens/app_shell.dart';
import 'package:frontend/screens/system_settings_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.token = 'settings-test-token';
    ApiService.currentUser = {'role': 'admin', 'user_id': 1};
  });
  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  for (final width in [1200.0, 390.0]) {
    testWidgets(
      'admin configures categories and network ranges at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final language = AppLanguage();
        addTearDown(language.dispose);
        await language.select('en');
        final categories = <Map<String, dynamic>>[];
        final addresses = <Map<String, dynamic>>[
          {'ip_id': 1, 'zone_id': 1, 'ip_range': '10.20.0.0/16'},
        ];
        var removed = 0;
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              AppLanguageScope(
                controller: language,
                child: const MaterialApp(home: AppShell()),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(
                ValueKey(width > 900 ? 'sidebar-settings' : 'bottom-settings'),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.text('Add a category so lecturers can create activities.'),
              findsOneWidget,
            );
            await tester.tap(find.byKey(const ValueKey('add-category')));
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const ValueKey('settings-name')),
              'Student services',
            );
            await tester.tap(find.widgetWithText(FilledButton, 'Save'));
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 400));
            expect(find.text('Student services'), findsOneWidget);
            await tester.tap(find.byKey(const ValueKey('category-active-5')));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<Switch>(
                    find.byKey(const ValueKey('category-active-5')),
                  )
                  .value,
              isFalse,
            );

            await tester.tap(find.text('Campus Wi-Fi'));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('add-ip-1')));
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const ValueKey('settings-name')),
              '999.0.1.2/24',
            );
            await tester.tap(find.widgetWithText(FilledButton, 'Save'));
            await tester.pumpAndSettle();
            expect(
              find.text('Enter a valid IPv4 address or CIDR prefix (1–32)'),
              findsOneWidget,
            );
            expect(addresses.length, 1);
            await tester.enterText(
              find.byKey(const ValueKey('settings-name')),
              '203.0.113.45/24',
            );
            await tester.tap(find.widgetWithText(FilledButton, 'Save'));
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 400));
            expect(find.text('203.0.113.0/24'), findsOneWidget);
            final remove = find.byKey(const ValueKey('remove-ip-2'));
            await tester.ensureVisible(remove);
            await tester.tap(remove);
            await tester.pumpAndSettle();
            await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
            await tester.pumpAndSettle();
            expect(removed, 0);
            expect(find.text('203.0.113.0/24'), findsOneWidget);
            await tester.tap(remove);
            await tester.pumpAndSettle();
            await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
            await tester.pumpAndSettle();
            expect(removed, 1);
            expect(find.text('203.0.113.0/24'), findsNothing);
            expect(find.text('10.20.0.0/16'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            dynamic data;
            switch ('${request.method} ${request.url.path}') {
              case 'GET /api/admin/dashboard':
                data = <String, dynamic>{};
              case 'GET /api/admin/settings':
                data = {
                  'categories': categories,
                  'zones': [
                    {'zone_id': 1, 'zone_name': 'Campus', 'is_active': 1},
                  ],
                  'allowed_ips': addresses,
                };
              case 'POST /api/admin/settings/categories':
                final body = jsonDecode(request.body) as Map;
                expect(body['category_name'], 'Student services');
                expect(body['is_active'], isTrue);
                categories.add({
                  'category_id': 5,
                  'category_name': body['category_name'],
                  'is_active': 1,
                });
                data = {'id': 5};
              case 'PATCH /api/admin/settings/categories/5':
                expect(jsonDecode(request.body), {'is_active': false});
                categories.first['is_active'] = 0;
                data = {'id': 5};
              case 'POST /api/admin/settings/ips':
                final body = jsonDecode(request.body) as Map;
                expect(body['zone_id'], 1);
                expect(body['ip_range'], '203.0.113.45/24');
                addresses.add({
                  'ip_id': 2,
                  'zone_id': 1,
                  'ip_range': '203.0.113.0/24',
                });
                data = {'id': 2};
              case 'DELETE /api/admin/settings/ips/2':
                removed++;
                addresses.removeWhere((item) => item['ip_id'] == 2);
                data = <String, dynamic>{};
              default:
                fail(
                  'Unexpected request: ${request.method} ${request.url.path}',
                );
            }
            return http.Response(
              jsonEncode({
                'data': data,
                'message': 'Settings saved successfully',
              }),
              200,
            );
          }),
        );
      },
    );
  }

  for (final role in ['student', 'lecturer', 'unknown']) {
    testWidgets('$role cannot load system settings directly', (tester) async {
      ApiService.currentUser = {'role': role};
      var requests = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SystemSettingsScreen())),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('หน้านี้ไม่พร้อมใช้งานสำหรับบัญชีของคุณ'),
            findsOneWidget,
          );
          expect(find.byType(TextFormField), findsNothing);
          expect(requests, 0);
        },
        () => MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
    });
  }
}
