import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  group('Login Screen Tests', () {
    testWidgets('TC01: ตรวจสอบการแสดงผล Element หลักบนหน้า Login', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      expect(find.text('เข้าสู่ระบบ MFU333'), findsOneWidget);
      expect(find.text('ใช้บัญชีที่ได้รับจากมหาวิทยาลัย'), findsOneWidget);
      expect(find.text('อีเมล'), findsOneWidget);
      expect(find.text('รหัสผ่าน'), findsOneWidget);
      expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('TC02: ทดสอบการสลับซ่อน/แสดงรหัสผ่าน (Obscure Toggle)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      final toggleIcon = find.byIcon(Icons.visibility);
      expect(toggleIcon, findsOneWidget);

      await tester.tap(toggleIcon);
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('TC03: ทดสอบการพิมพ์ข้อมูลในช่องอีเมลและรหัสผ่าน', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      final emailField = find.byType(TextField).at(0);
      final passwordField = find.byType(TextField).at(1);

      await tester.enterText(emailField, 'student@mfu.ac.th');
      await tester.enterText(passwordField, '12345678');
      await tester.pump();

      expect(find.text('student@mfu.ac.th'), findsOneWidget);
      expect(find.text('12345678'), findsOneWidget);
    });

    testWidgets(
      'TC04: แสดงผลการทำงานเมื่อกดปุ่มเข้าสู่ระบบ',
      (WidgetTester tester) => http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

          final emailField = find.byType(TextField).at(0);
          final passwordField = find.byType(TextField).at(1);
          final loginBtn = find.text('เข้าสู่ระบบ');

          await tester.enterText(emailField, 'test@mfu.ac.th');
          await tester.enterText(passwordField, 'password123');
          await tester.tap(loginBtn);
          await tester.pumpAndSettle();

          expect(find.byType(LoginScreen), findsOneWidget);
          expect(find.text('Test login rejected'), findsOneWidget);
          expect(ApiService.token, isNull);
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNotNull,
          );
        },
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/auth/login');
          expect(jsonDecode(request.body), {
            'email': 'test@mfu.ac.th',
            'password': 'password123',
          });
          return http.Response(
            jsonEncode({'message': 'Test login rejected'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
  });
}
