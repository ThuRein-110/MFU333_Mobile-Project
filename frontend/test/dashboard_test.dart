import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/services/api_service.dart';

const adminResponse = {
  'success': true,
  'data': {
    'users': {
      'total_users': '5',
      'total_students': 1,
      'total_lecturers': 3,
      'total_admins': 1,
      'active_users': 5,
    },
    'activities': {
      'total_activities': 2,
      'draft_activities': 0,
      'published_activities': 2,
      'ongoing_activities': 0,
      'completed_activities': 0,
      'cancelled_activities': 0,
    },
    'checkins': {
      'total_checkins': 1,
      'successful_checkins': 1,
      'rejected_checkins': 0,
    },
    'points': {'total_points_awarded': 100},
  },
};

void main() {
  tearDown(() => ApiService.currentUser = null);

  for (final width in [1200.0, 390.0]) {
    testWidgets('admin summary shows readable values at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ApiService.currentUser = {'role': 'admin'};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardScreen(
              loadDashboard: (path) async {
                expect(path, '/api/admin/dashboard');
                return adminResponse;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ผู้ใช้ทั้งหมด'), findsOneWidget);
      expect(find.text('กิจกรรมทั้งหมด'), findsOneWidget);
      for (final entry in {
        'users': '5',
        'activities': '2',
        'checkins': '1',
        'points': '100',
      }.entries) {
        final value = find.byKey(ValueKey('dashboard-value-${entry.key}'));
        await tester.ensureVisible(value);
        expect(tester.widget<Text>(value).data, entry.value);
      }
      expect(find.textContaining('total_users'), findsNothing);
      expect(find.textContaining('total_points_awarded'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('lecturer dashboard uses flat stats and a useful empty state', (
    tester,
  ) async {
    ApiService.currentUser = {'role': 'lecturer'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            loadDashboard: (path) async {
              expect(path, '/api/lecturer/dashboard');
              return {
                'data': {
                  'stats': {
                    'total_activities': 2,
                    'published_activities': 1,
                    'ongoing_activities': 0,
                    'completed_activities': 1,
                    'cancelled_activities': 0,
                  },
                  'activities': [],
                },
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('dashboard-value-activities')),
          )
          .data,
      '2',
    );
    await tester.scrollUntilVisible(
      find.text('ยังไม่มีกิจกรรมที่รับผิดชอบ'),
      120,
    );
    expect(find.text('ยังไม่มีกิจกรรมที่รับผิดชอบ'), findsOneWidget);
    expect(find.textContaining('total_activities'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student dashboard keeps the activity list', (tester) async {
    ApiService.currentUser = {'role': 'student'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            loadDashboard: (path) async {
              expect(path, '/api/activities');
              return {
                'data': [
                  {
                    'title': 'Workshop',
                    'location': 'E4',
                    'status': 'published',
                    'points': 100,
                  },
                ],
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Workshop'), findsOneWidget);
    expect(find.text('100 แต้ม'), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-metric-users')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
