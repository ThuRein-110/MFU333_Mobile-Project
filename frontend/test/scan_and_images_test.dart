import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/app_shell.dart';
import 'package:frontend/screens/management_screen.dart';
import 'package:frontend/services/activity_qr.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/activity_date_time_field.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

final imageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAACXBIWXMAAAPoAAAD6AG1e1JrAAAAEUlEQVQImWOQTr2CFTEMLQkACHdVAcbmtPkAAAAASUVORK5CYII=',
);

class TestImagePicker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(
    Uint8List.fromList(imageBytes),
    mimeType: 'image/png',
    name: 'activity.png',
  );
}

http.Response response(dynamic data) => http.Response.bytes(
  utf8.encode(jsonEncode({'data': data})),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.token = 'test-session';
    ApiService.currentUser = {'user_id': 3, 'role': 'student'};
    ActivityQr.pendingCheckIn = null;
  });
  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
    ActivityQr.pendingCheckIn = null;
  });

  test('phone-camera links preserve QR context without sending the token to the web server URL', () {
    final qr = const ActivityQr(activityId: 42, token: 'shared-token');
    final link = Uri.parse(
      qr.toLink(origin: Uri.parse('https://campus.invalid')),
    );
    expect(link.scheme, 'https');
    expect(link.query, isEmpty);
    expect(link.fragment, contains('/check-in?'));
    expect(ActivityQr.parse(link.toString()).activityId, 42);
    expect(ActivityQr.parse(link.toString()).token, qr.token);
    ActivityQr.captureLink(link);
    expect(ActivityQr.pendingCheckIn!.token, qr.token);
    expect(ActivityQr.parse(qr.encode()).token, qr.token);
    expect(
      () => ActivityQr.parse('https://campus.invalid/other'),
      throwsFormatException,
    );
  });

  for (final viaPhoto in [false, true]) {
    testWidgets(
      viaPhoto
          ? 'a QR photo supplies the matching activity and can be checked in'
          : 'opening a phone-camera link opens check-in with the token ready',
      (tester) async {
        final picker = ImagePickerPlatform.instance;
        ImagePickerPlatform.instance = TestImagePicker();
        addTearDown(() => ImagePickerPlatform.instance = picker);
        final link = const ActivityQr(
          activityId: 42,
          token: 'scan-token',
        ).toLink(origin: Uri.parse('https://campus.invalid'));
        if (!viaPhoto) ActivityQr.captureLink(Uri.parse(link));
        var checkedIn = false;
        await http.runWithClient(
          () async {
            await tester.pumpWidget(const MaterialApp(home: AppShell()));
            await tester.pumpAndSettle();
            if (viaPhoto) {
              await tester.tap(find.byKey(const ValueKey('bottom-checkIn')));
              await tester.pumpAndSettle();
              await tester.tap(find.text('อัปโหลดรูป QR'));
              await tester.pumpAndSettle();
            }
            expect(
              find.text('อ่าน QR แล้ว กรุณายืนยันเช็คอิน'),
              findsOneWidget,
            );
            expect(checkedIn, isFalse);
            await tester.tap(find.text('ยืนยัน Check-in'));
            await tester.pumpAndSettle();
            expect(checkedIn, isTrue);
            expect(find.text('เช็คอินสำเร็จ ได้รับ 25 คะแนน'), findsOneWidget);
            await tester.pumpWidget(const SizedBox.shrink());
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            switch (request.url.path) {
              case '/api/qr/alerts':
                return response([]);
              case '/api/activities':
                return response([]);
              case '/api/registrations/my':
                return response(
                  checkedIn
                      ? []
                      : [
                          {
                            'activity_id': 42,
                            'title': 'QR workshop',
                            'registration_status': 'registered',
                            'activity_status': 'ongoing',
                          },
                        ],
                );
              case '/api/checkins/read-qr':
                expect(
                  base64Decode(jsonDecode(request.body)['image']),
                  imageBytes,
                );
                return response({'payload': link});
              case '/api/checkins':
                expect(jsonDecode(request.body), {
                  'activity_id': 42,
                  'token': 'scan-token',
                });
                checkedIn = true;
                return response({'points': 25});
              default:
                fail('Unexpected request: ${request.url.path}');
            }
          }),
        );
      },
    );
  }

  testWidgets('a linked ongoing activity offers registration before check-in', (
    tester,
  ) async {
    ActivityQr.captureLink(
      Uri.parse(
        const ActivityQr(
          activityId: 42,
          token: 'scan-token',
        ).toLink(origin: Uri.parse('https://campus.invalid')),
      ),
    );
    var registered = false;
    const activity = {
      'activity_id': 42,
      'title': 'Ongoing workshop',
      'status': 'ongoing',
    };
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: AppShell()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ดูกิจกรรมนี้'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('เข้าร่วมกิจกรรม'));
        await tester.pumpAndSettle();
        expect(registered, isTrue);
        await tester.tap(find.widgetWithText(TextButton, 'เช็คอิน QR'));
        await tester.pumpAndSettle();
        expect(find.text('อ่าน QR แล้ว กรุณายืนยันเช็คอิน'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        switch (request.url.path) {
          case '/api/qr/alerts':
            return response([]);
          case '/api/activities':
            return response([activity]);
          case '/api/activities/42':
            return response(activity);
          case '/api/registrations/my':
            return response(
              registered
                  ? [
                      {
                        ...activity,
                        'registration_status': 'registered',
                        'activity_status': 'ongoing',
                      },
                    ]
                  : [],
            );
          case '/api/registrations/42':
            registered = true;
            return response({});
          default:
            fail('Unexpected request: ${request.url.path}');
        }
      }),
    );
  });

  testWidgets(
    'activity image upload retries without losing form fields, then persists its URL on creation',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ApiService.currentUser = {'role': 'lecturer', 'user_id': 7};
      final picker = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = TestImagePicker();
      addTearDown(() => ImagePickerPlatform.instance = picker);
      var failUpload = true;
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
          await tester.tap(find.text('เพิ่มกิจกรรม'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('activity-field-title')),
            'Photo workshop',
          );
          await tester.enterText(
            find.byKey(const ValueKey('activity-field-location')),
            'E4',
          );
          await tester.tap(find.byType(DropdownButtonFormField<int>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Campus').last);
          await tester.pumpAndSettle();
          final dates = tester
              .widgetList<ActivityDateTimeField>(
                find.byType(ActivityDateTimeField),
              )
              .toList();
          dates[0].controller.text = '2099-01-01T10:00:00Z';
          dates[1].controller.text = '2099-01-01T12:00:00Z';
          await tester.tap(find.byKey(const ValueKey('pick-activity-image')));
          await tester.pumpAndSettle();
          expect(find.byType(Image), findsOneWidget);
          await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
          await tester.pumpAndSettle();
          expect(saved, isNull);
          expect(find.text('Photo workshop'), findsOneWidget);
          expect(find.byType(AlertDialog), findsOneWidget);
          failUpload = false;
          await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
          await tester.pumpAndSettle();
          expect(
            saved!['cover_image'],
            'https://fixture.public.blob.vercel-storage.com/activity.jpg',
          );
          expect(saved!['title'], 'Photo workshop');
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          switch (request.url.path) {
            case '/api/activities/options':
              return response({
                'categories': [
                  {'category_id': 1, 'category_name': 'Campus'},
                ],
                'zones': [],
              });
            case '/api/activities/image':
              expect(
                base64Decode(jsonDecode(request.body)['image']),
                imageBytes,
              );
              if (failUpload) {
                return http.Response(
                  jsonEncode({'message': 'Upload failed'}),
                  502,
                );
              }
              return response({
                'url': 'https://fixture.public.blob.vercel-storage.com/activity.jpg',
              });
            case '/api/activities':
              if (request.method == 'POST') {
                saved = Map<String, dynamic>.from(jsonDecode(request.body));
              }
              return response([]);
            default:
              fail('Unexpected request: ${request.url.path}');
          }
        }),
      );
    },
  );
}
