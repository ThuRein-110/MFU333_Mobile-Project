import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // กำหนดค่า Mock สำหรับ SharedPreferences ก่อนเริ่มแต่ละ Test Case
    SharedPreferences.setMockInitialValues({});
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  group('ApiService Unit Tests', () {
    test('TC01: ทดสอบการบันทึกข้อมูลเข้า Session (saveSession) และการโหลดค่ากลับ (restore)', () async {
      const testToken = 'jwt_token_sample_12345';
      final testUser = {
        'id': 1,
        'email': 'teststudent@mfu.ac.th',
        'role': 'student',
      };

      // บันทึก Session
      await ApiService.saveSession(testToken, testUser);

      expect(ApiService.token, testToken);
      expect(ApiService.currentUser, testUser);

      // เคลียร์ RAM Memory แล้วลองดึงจาก SharedPreferences กลับมา
      ApiService.token = null;
      ApiService.currentUser = null;
      await ApiService.restore();

      expect(ApiService.token, testToken);
      expect(ApiService.currentUser?['email'], 'teststudent@mfu.ac.th');
    });

    test('TC02: ทดสอบการออกจากระบบ (logout)', () async {
      await ApiService.saveSession('token_abc', {'id': 99});

      // เรียกใช้ฟังก์ชันออกจากระบบ
      await ApiService.logout();

      expect(ApiService.token, isNull);
      expect(ApiService.currentUser, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('jwt'), isNull);
      expect(prefs.getString('user'), isNull);
    });

    test('TC03: ทดสอบฟังก์ชันแกะข้อมูล response (unwrap)', () {
      final responseWithData = {
        'status': 'success',
        'data': {'id': 101, 'name': 'MFU Activity'},
      };
      final responseWithoutData = ['Item A', 'Item B'];

      final unwrapped1 = ApiService.unwrap(responseWithData);
      final unwrapped2 = ApiService.unwrap(responseWithoutData);

      expect(unwrapped1, {'id': 101, 'name': 'MFU Activity'});
      expect(unwrapped2, equals(['Item A', 'Item B']));
    });

    test('TC04: ทดสอบเมื่อเรียก API แต่เชื่อมต่อ Server ไม่ได้ ต้องโยน ApiException', () async {
      await http.runWithClient(() async {
        await expectLater(
          ApiService.request('GET', '/api/test-connection'),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'statusCode',
              0,
            ),
          ),
        );
      }, () => MockClient((_) async => throw http.ClientException('offline')));
    });
  });
}
