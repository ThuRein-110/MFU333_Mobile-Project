import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class ApiService {
  static String? token;
  static Map<String, dynamic>? currentUser;

  static Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('jwt');
    final raw = p.getString('user');
    if (raw != null) currentUser = Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> saveSession(String jwt, Map<String, dynamic> user) async {
    token = jwt;
    currentUser = user;
    final p = await SharedPreferences.getInstance();
    await p.setString('jwt', jwt);
    await p.setString('user', jsonEncode(user));
  }

  static Future<void> logout() async {
    token = null;
    currentUser = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('jwt');
    await p.remove('user');
  }

  static Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (auth && token != null) headers['Authorization'] = 'Bearer $token';
    late http.Response response;
    try {
      switch (method) {
        case 'POST':
          response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: jsonEncode(body ?? {}));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          response = await http.get(uri, headers: headers);
      }
    } catch (_) {
      throw ApiException(0, 'เชื่อมต่อ Backend ไม่สำเร็จ ตรวจสอบ IP และสถานะ Server');
    }
    dynamic decoded;
    try { decoded = response.body.isEmpty ? {} : jsonDecode(response.body); }
    catch (_) { decoded = {'message': response.body}; }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = decoded is Map ? (decoded['message'] ?? decoded['error'] ?? 'Request failed') : 'Request failed';
      throw ApiException(response.statusCode, msg.toString());
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await request('POST', '/api/auth/login',
        auth: false, body: {'email': email, 'password': password});
    final data = Map<String, dynamic>.from(r['data'] ?? {});
    await saveSession(data['token'].toString(), Map<String, dynamic>.from(data['user'] ?? {}));
    return data;
  }

  static dynamic unwrap(dynamic response) {
    if (response is Map && response.containsKey('data')) return response['data'];
    return response;
  }
}
