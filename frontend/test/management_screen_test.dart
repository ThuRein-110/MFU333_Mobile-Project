import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/screens/management_screen.dart';
import 'package:frontend/services/api_service.dart';

import 'support/mock_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.token = 'mock_jwt_token';
    ApiService.currentUser = {'role': 'admin'};
  });

  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  group('Management Screen Tests', () {
    testWidgets(
      'TC01: ตรวจสอบการแสดงผลหน้าจัดการกิจกรรม (Index 1)',
      (WidgetTester tester) => withEmptyListsApi(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManagementScreen(index: 1, title: 'รายการกิจกรรม'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('รายการกิจกรรม'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget); // ช่องค้นหา
        expect(find.text('ลองอีกครั้ง'), findsNothing);
      }),
    );

    testWidgets('TC02: retired placeholder pages do not expose controls', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManagementScreen(index: 7, title: 'หมวดหมู่กิจกรรม'),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('หมวดหมู่กิจกรรม'), findsOneWidget);
      expect(
        find.text('หน้านี้ไม่พร้อมใช้งานสำหรับบัญชีของคุณ'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets(
      'TC03: ทดสอบการพิมพ์คำค้นหาในช่องค้นหากิจกรรม',
      (WidgetTester tester) => withEmptyListsApi(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManagementScreen(index: 1, title: 'รายการกิจกรรม'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, 'สัมมนา');
        await tester.pump();

        expect(find.text('สัมมนา'), findsOneWidget);
      }),
    );

    testWidgets(
      'TC04: ตรวจสอบการแสดงผลหน้าจัดการผู้ใช้งาน (Index 14) สำหรับ Admin',
      (WidgetTester tester) => withEmptyListsApi(() async {
        ApiService.currentUser = {'role': 'admin'};

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ManagementScreen(index: 14, title: 'จัดการผู้ใช้งาน'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('จัดการผู้ใช้งาน'), findsOneWidget);
        expect(find.text('ไม่มีข้อมูลผู้ใช้'), findsOneWidget);
        expect(find.text('ลองอีกครั้ง'), findsNothing);
      }),
    );

    testWidgets('admin users table shows student contact and points', (
      WidgetTester tester,
    ) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: ManagementScreen(index: 14, title: 'จัดการผู้ใช้งาน'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('S-1'), findsOneWidget);
          expect(find.text('Student Example'), findsOneWidget);
          expect(find.text('student@example.invalid'), findsOneWidget);
          expect(find.text('75'), findsOneWidget);
        },
        () => MockClient((request) async {
          expect(request.url.path, '/api/admin/users');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'user_id': 3,
                  'student_code': 'S-1',
                  'full_name': 'Student Example',
                  'email': 'student@example.invalid',
                  'role': 'student',
                  'total_points': 75,
                  'is_active': 1,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
    });
  });
}
