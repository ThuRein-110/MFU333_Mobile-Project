import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/l10n/app_language.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/app_shell.dart';
import 'package:frontend/screens/management_screen.dart';
import 'package:frontend/screens/password_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget localizedApp(AppLanguage language, Widget home) => AnimatedBuilder(
  animation: language,
  builder: (_, _) => AppLanguageScope(
    controller: language,
    child: MaterialApp(
      locale: language.locale,
      supportedLocales: const [Locale('th'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    ),
  ),
);

Future<void> selectLanguage(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('language-switcher')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.token = null;
    ApiService.currentUser = null;
  });
  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  testWidgets('login language switch preserves input and survives a restart', (
    tester,
  ) async {
    final language = AppLanguage();
    addTearDown(language.dispose);
    await tester.pumpWidget(Mfu333App(language: language));
    await tester.pumpAndSettle();
    expect(find.text('เข้าสู่ระบบ MFU333'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'fixture@example.invalid',
    );
    await tester.enterText(find.byType(TextField).last, 'fixture-password');

    await selectLanguage(tester, 'English');
    expect(find.text('Sign in to MFU333'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'fixture@example.invalid',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'fixture-password',
    );

    final restored = AppLanguage();
    addTearDown(restored.dispose);
    await restored.restore();
    await tester.pumpWidget(Mfu333App(key: UniqueKey(), language: restored));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to MFU333'), findsOneWidget);
    await selectLanguage(tester, 'ไทย');
    expect(find.text('เข้าสู่ระบบ MFU333'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(AppLanguage.preferenceKey), 'th');
    expect(tester.takeException(), isNull);
  });

  testWidgets('language updates an open route without losing password input', (
    tester,
  ) async {
    final language = AppLanguage();
    addTearDown(language.dispose);
    await tester.pumpWidget(Mfu333App(language: language));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('เข้าสู่ระบบ MFU333'));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: PasswordScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'fixture-current');
    await language.select('en');
    await tester.pumpAndSettle();
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Current password'), findsOneWidget);
    expect(find.text('Save password'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'fixture-current',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('participant activity ID survives language changes', (
    tester,
  ) async {
    final language = AppLanguage();
    addTearDown(language.dispose);
    ApiService.currentUser = {'role': 'lecturer'};
    await tester.pumpWidget(
      localizedApp(
        language,
        const Scaffold(
          body: ManagementScreen(index: 3, title: 'Registrations'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '42');
    await language.select('en');
    await tester.pumpAndSettle();
    expect(find.text('View participants'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '42',
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [1200.0, 390.0]) {
    testWidgets('English shell, dashboard and forms at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final language = AppLanguage();
      addTearDown(language.dispose);
      await language.select('en');
      ApiService.currentUser = {'role': 'admin', 'full_name': 'Test Admin'};
      var dashboardLoads = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(localizedApp(language, const AppShell()));
          await tester.pumpAndSettle();
          expect(find.text('Total users'), findsOneWidget);
          expect(find.text('Total activities'), findsOneWidget);
          expect(find.text('Points awarded'), findsOneWidget);
          await selectLanguage(tester, 'ไทย');
          expect(find.text('ผู้ใช้ทั้งหมด'), findsOneWidget);
          await selectLanguage(tester, 'English');
          expect(
            dashboardLoads,
            1,
            reason: 'Language changes must not reload data',
          );

          // Desktop sidebar and mobile navigation open the same activity screen.
          await tester.tap(find.text('Activities').first);
          await tester.pumpAndSettle();
          expect(find.text('กิจกรรมตัวอย่าง'), findsOneWidget);
          expect(find.text('Published'), findsOneWidget);
          expect(find.text('Location'), findsOneWidget);
          await tester.tap(find.text('Add activity'));
          await tester.pumpAndSettle();
          expect(find.text('Activity status'), findsOneWidget);
          expect(find.text('Activity title'), findsWidgets);
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
          expect(find.text('This field is required'), findsWidgets);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          if (request.url.path == '/api/admin/dashboard') {
            dashboardLoads++;
            return http.Response(
              jsonEncode({
                'data': {
                  'users': {'total_users': 5},
                  'activities': {'total_activities': 2},
                  'checkins': {'total_checkins': 1},
                  'points': {'total_points_awarded': 100},
                },
              }),
              200,
            );
          }
          expect(request.method, 'GET');
          expect(request.url.path, '/api/activities');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'data': [
                  {
                    'activity_id': 1,
                    'title': 'กิจกรรมตัวอย่าง',
                    'location': 'E4',
                    'status': 'published',
                    'points': 100,
                  },
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
    });
  }

  testWidgets('login API errors follow the selected language', (tester) async {
    final language = AppLanguage();
    addTearDown(language.dispose);
    await http.runWithClient(
      () async {
        await tester.pumpWidget(Mfu333App(language: language));
        await tester.pumpAndSettle();
        await tester.tap(find.text('เข้าสู่ระบบ'));
        await tester.pumpAndSettle();
        expect(find.text('อีเมลหรือรหัสผ่านไม่ถูกต้อง'), findsOneWidget);
        await selectLanguage(tester, 'English');
        expect(find.text('Invalid email or password'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Invalid email or password'}),
          401,
        ),
      ),
    );
  });

  test('unsupported saved language falls back to Thai', () async {
    SharedPreferences.setMockInitialValues({AppLanguage.preferenceKey: 'fr'});
    final language = AppLanguage();
    addTearDown(language.dispose);
    await language.restore();
    expect(language.locale, const Locale('th'));
  });
}
