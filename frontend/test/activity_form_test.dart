import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/management_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'activity forms show five essentials and preserve collapsed edit settings',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      ApiService.token = 'form-test-token';
      ApiService.currentUser = {'role': 'lecturer', 'user_id': 7};
      addTearDown(() {
        ApiService.token = null;
        ApiService.currentUser = null;
      });
      final activity = {
        'activity_id': 42,
        'organizer_id': 7,
        'category_id': 1,
        'title': 'Original workshop',
        'location': 'E4',
        'start_at': '2099-01-01T10:00:00Z',
        'end_at': '2099-01-01T12:00:00Z',
        'description': 'Keep this description',
        'points': 75,
        'zone_id': 2,
        'max_participants': 50,
        'status': 'ongoing',
      };
      Map<String, dynamic>? saved;
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
          final edit = find.byTooltip('แก้ไข');
          await tester.ensureVisible(edit);
          await tester.tap(edit);
          await tester.pumpAndSettle();
          final dialog = find.byType(AlertDialog);
          final visibleFields = find.descendant(
            of: dialog,
            matching: find.byWidgetPredicate((widget) => widget is FormField),
          );
          expect(visibleFields, findsNWidgets(5));
          expect(
            find.byKey(const ValueKey('activity-field-status')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('activity-field-points')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('activity-field-zone_id')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('activity-field-max_participants')),
            findsNothing,
          );
          await tester.enterText(
            find.byKey(const ValueKey('activity-field-title')),
            'Updated workshop',
          );
          await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
          await tester.pumpAndSettle();
          expect(saved, {
            'category_id': 1,
            'title': 'Updated workshop',
            'location': 'E4',
            'start_at': activity['start_at'],
            'end_at': activity['end_at'],
            'description': 'Keep this description',
            'points': 75,
            'zone_id': 2,
            'max_participants': 50,
            'status': 'ongoing',
            'cover_image': null,
          });
          await tester.tap(find.text('เพิ่มกิจกรรม'));
          await tester.pumpAndSettle();
          expect(visibleFields, findsNWidgets(5));
          expect(
            find.byKey(const ValueKey('activity-field-status')),
            findsNothing,
          );
          final moreSettings = find.byKey(
            const ValueKey('activity-more-settings'),
          );
          await tester.ensureVisible(moreSettings);
          await tester.tap(moreSettings);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('activity-field-status')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('activity-field-description')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('activity-field-points')),
            findsOneWidget,
          );
          await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          dynamic data;
          if (request.url.path == '/api/activities/options') {
            data = {
              'categories': [
                {'category_id': 1, 'category_name': 'Workshop'},
              ],
              'zones': [
                {'zone_id': 2, 'zone_name': 'Campus'},
              ],
            };
          } else if (request.method == 'PUT') {
            expect(request.url.path, '/api/activities/42');
            saved = Map<String, dynamic>.from(jsonDecode(request.body));
            data = {};
          } else {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/activities');
            data = [activity];
          }
          return http.Response(
            jsonEncode({
              'data': data,
              'message': 'Activity updated successfully',
            }),
            200,
          );
        }),
      );
    },
  );
}
