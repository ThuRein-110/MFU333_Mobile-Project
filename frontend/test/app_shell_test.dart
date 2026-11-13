import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/screens/app_shell.dart';
import 'package:frontend/screens/management_screen.dart';
import 'package:frontend/screens/password_screen.dart';
import 'package:frontend/services/api_service.dart';

import 'support/mock_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.token = 'mock_jwt_token';
    ApiService.currentUser = {'full_name': 'Test Student', 'role': 'student'};
  });

  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  group('AppShell Screen Tests', () {
    testWidgets(
      'TC01: ตรวจสอบการแสดงผล Header และชื่อผู้ใช้งาน',
      (WidgetTester tester) => withEmptyListsApi(() async {
        await tester.pumpWidget(const MaterialApp(home: AppShell()));

        await tester.pumpAndSettle();

        expect(find.text('MFU333'), findsWidgets);
        expect(find.text('Test Student'), findsOneWidget);
        expect(find.text('ลองอีกครั้ง'), findsNothing);
      }),
    );

    testWidgets(
      'TC02: ตรวจสอบการเข้าสู่หน้าเปลี่ยนรหัสผ่านทันทีเมื่อ forcePassword = true',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: AppShell(forcePassword: true)),
        );

        await tester.pumpAndSettle();

        expect(find.text('เปลี่ยนรหัสผ่าน'), findsWidgets);
        expect(find.byType(PasswordScreen), findsOneWidget);
      },
    );

    testWidgets(
      'TC03: ทดสอบการสลับหน้าเมื่อกดเลือกเมนูกิจกรรมบน NavigationBar (Mobile View)',
      (WidgetTester tester) => withEmptyListsApi(() async {
        tester.view.physicalSize = const Size(600, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const MaterialApp(home: AppShell()));

        await tester.pumpAndSettle();

        final navBarItem = find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('กิจกรรม'),
        );
        await tester.tap(navBarItem);
        await tester.pumpAndSettle();

        expect(find.text('กิจกรรม'), findsWidgets);
        expect(
          tester.widget<ManagementScreen>(find.byType(ManagementScreen)).index,
          1,
        );
        expect(find.text('ลองอีกครั้ง'), findsNothing);
      }),
    );

    testWidgets(
      'TC04: ทดสอบเปิด PopupMenu Header และเลือกรายการเปลี่ยนรหัสผ่าน',
      (WidgetTester tester) => withEmptyListsApi(() async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const MaterialApp(home: AppShell()));

        await tester.pumpAndSettle();

        // เปิด Popup Menu บน Header
        final popupBtn = find.byWidgetPredicate(
          (widget) =>
              widget is PopupMenuButton<String> &&
              widget.key != const ValueKey('language-switcher'),
        );
        await tester.tap(popupBtn);
        await tester.pumpAndSettle();

        // กดเลือกเมนูเปลี่ยนรหัสผ่านใน PopupMenu
        final passwordMenuItem = find.widgetWithText(
          PopupMenuItem<String>,
          'เปลี่ยนรหัสผ่าน',
        );
        await tester.tap(passwordMenuItem);
        await tester.pumpAndSettle();

        expect(find.text('เปลี่ยนรหัสผ่าน'), findsWidgets);
        expect(find.byType(PasswordScreen), findsOneWidget);
      }),
    );
  });
}
