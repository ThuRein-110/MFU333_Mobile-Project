import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.token = 'mock_jwt_token';
    ApiService.currentUser = {'role': 'student'};
  });

  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  group('Dashboard Screen Tests', () {
    testWidgets(
      'TC01: ตรวจสอบการแสดงผลหัวข้อสำหรับสิทธิ์ นิสิต/นักศึกษา (Student)',
      (WidgetTester tester) async {
        ApiService.currentUser = {'role': 'student'};

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DashboardScreen(
                loadDashboard: (path) async {
                  expect(path, '/api/activities');
                  return {'data': []};
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('กิจกรรมที่เปิดให้เข้าร่วม'), findsOneWidget);
        expect(
          find.text('สรุปกิจกรรม การเข้าร่วม และคะแนนสะสม'),
          findsOneWidget,
        );
        expect(find.text('ลองอีกครั้ง'), findsNothing);
      },
    );

    testWidgets(
      'TC02: ตรวจสอบการแสดงผลหัวข้อสำหรับสิทธิ์ ผู้ดูแลระบบ (Admin)',
      (WidgetTester tester) async {
        ApiService.currentUser = {'role': 'admin'};

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DashboardScreen(
                loadDashboard: (path) async {
                  expect(path, '/api/admin/dashboard');
                  return {'data': {}};
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('ภาพรวมระบบ'), findsOneWidget);
      },
    );

    testWidgets('TC03: ตรวจสอบการแสดงผลหัวข้อสำหรับสิทธิ์ อาจารย์ (Lecturer)', (
      WidgetTester tester,
    ) async {
      ApiService.currentUser = {'role': 'lecturer'};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardScreen(
              loadDashboard: (path) async {
                expect(path, '/api/lecturer/dashboard');
                return {
                  'data': {'stats': {}, 'activities': []},
                };
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ภาพรวมอาจารย์'), findsOneWidget);
    });

    testWidgets(
      'TC04: แสดงผล Card แจ้งเตือนข้อผิดพลาด และปุ่ม "ลองอีกครั้ง" เมื่อเชื่อมต่อ Server ไม่สำเร็จ',
      (WidgetTester tester) async {
        ApiService.currentUser = {'role': 'student'};
        var attempts = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DashboardScreen(
                loadDashboard: (path) async {
                  attempts++;
                  if (attempts == 1) {
                    throw ApiException(503, 'Test API unavailable');
                  }
                  return {'data': []};
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // ตรวจสอบว่าแสดงปุ่มลองอีกครั้งเมื่อเกิด Error จาก API
        expect(find.text('ลองอีกครั้ง'), findsOneWidget);
        expect(find.text('Test API unavailable'), findsOneWidget);
        await tester.tap(find.text('ลองอีกครั้ง'));
        await tester.pumpAndSettle();
        expect(attempts, 2);
        expect(find.text('ลองอีกครั้ง'), findsNothing);
        expect(find.text('Test API unavailable'), findsNothing);
        expect(find.text('รายการกิจกรรม'), findsOneWidget);
      },
    );
  });
}
