import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/screens/password_screen.dart';
import 'package:frontend/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.token = 'mock_jwt_token';
    ApiService.currentUser = null;
  });

  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  group('Password Screen Tests', () {
    testWidgets('TC01: ตรวจสอบการแสดงผล Element หลักบนหน้าเปลี่ยนรหัสผ่าน', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PasswordScreen())),
      );

      expect(find.text('เปลี่ยนรหัสผ่าน'), findsOneWidget);
      expect(find.text('รหัสผ่านปัจจุบัน'), findsOneWidget);
      expect(find.text('รหัสผ่านใหม่ (อย่างน้อย 8 ตัวอักษร)'), findsOneWidget);
      expect(find.text('ยืนยันรหัสผ่านใหม่'), findsOneWidget);
      expect(find.text('บันทึกรหัสผ่าน'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('TC02: ทดสอบการกรอกข้อมูลในช่องรหัสผ่านทั้ง 3 ช่อง', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PasswordScreen())),
      );

      final currentPassField = find.byType(TextField).at(0);
      final newPassField = find.byType(TextField).at(1);
      final confirmPassField = find.byType(TextField).at(2);

      await tester.enterText(currentPassField, 'OldPassword123');
      await tester.enterText(newPassField, 'NewPassword123');
      await tester.enterText(confirmPassField, 'NewPassword123');
      await tester.pump();

      expect(find.text('OldPassword123'), findsOneWidget);
      expect(find.text('NewPassword123'), findsNWidgets(2));
    });

    testWidgets(
      'TC03: กดปุ่มบันทึกรหัสผ่านเมื่อเกิดข้อผิดพลาดในการเชื่อมต่อ Server',
      (WidgetTester tester) => http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: PasswordScreen())),
          );

          final currentPassField = find.byType(TextField).at(0);
          final newPassField = find.byType(TextField).at(1);
          final confirmPassField = find.byType(TextField).at(2);
          final saveButton = find.text('บันทึกรหัสผ่าน');

          await tester.enterText(currentPassField, '12345678');
          await tester.enterText(newPassField, '87654321');
          await tester.enterText(confirmPassField, '87654321');

          await tester.tap(saveButton);
          await tester.pumpAndSettle();

          expect(find.byType(SnackBar), findsOneWidget);
          expect(
            find.text('เชื่อมต่อ Backend ไม่สำเร็จ ตรวจสอบ IP และสถานะ Server'),
            findsOneWidget,
          );
          expect(ApiService.token, 'mock_jwt_token');
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNotNull,
          );
        },
        () => MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/auth/change-password');
          expect(request.headers['Authorization'], 'Bearer mock_jwt_token');
          expect(jsonDecode(request.body), {
            'current_password': '12345678',
            'new_password': '87654321',
            'confirm_password': '87654321',
          });
          throw http.ClientException('offline');
        }),
      ),
    );
  });
}
