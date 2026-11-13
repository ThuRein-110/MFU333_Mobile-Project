import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    testWidgets('TC02: ตรวจสอบการแสดงผลหน้าฟีเจอร์ที่ไม่รองรับ (Index 7)', (
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
      expect(find.text('ยังเชื่อมต่อ หมวดหมู่กิจกรรม ไม่ได้'), findsOneWidget);
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
  });
}
