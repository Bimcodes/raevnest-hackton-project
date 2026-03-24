import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized API client for the QR Fare backend.
/// Used by both Student and Driver apps.
class ApiService {
  // For real device use your PC's local IP on the network
  static const String _baseUrl = 'https://qr-fare-backend.onrender.com';
  static String get baseUrl => _baseUrl;

  static String? _token;
  static String? _role;

  // ── Logging ─────────────────────────────────────────────────────────────

  static void _log(String msg) {
    // ignore: avoid_print
    print('[API_DEBUG] $msg');
  }

  static void _logReq(
    String method,
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) {
    _log('--> $method $path');
    if (headers != null) _log('Headers: $headers');
    if (body != null) {
      final bodyStr = body is String ? body : jsonEncode(body);
      _log(
        'Body: ${bodyStr.length > 500 ? "${bodyStr.substring(0, 500)}..." : bodyStr}',
      );
    }
  }

  static void _logRes(http.Response res) {
    final status = res.statusCode;
    final emoji = (status >= 200 && status < 300) ? '✅' : '❌';
    _log('<-- $emoji $status ${res.request?.url.path}');
    _log(
      'Response: ${res.body.length > 500 ? "${res.body.substring(0, 500)}..." : res.body}',
    );
  }

  // ── Token Management ────────────────────────────────────────────────────

  static Future<void> _saveToken(String token, String role) async {
    _token = token;
    _role = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('jwt_role', role);
  }

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    _role = prefs.getString('jwt_role');
    return _token;
  }

  static Future<bool> isLoggedIn() async {
    return (await getToken()) != null;
  }

  static Future<void> logout() async {
    _token = null;
    _role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('jwt_role');
  }

  static Map<String, String> _authHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> registerStudent({
    required String studentId,
    required String name,
    required String password,
    required String publicKeyPem,
  }) async {
    final url = '$_baseUrl/auth/register/student';
    final body = {
      'student_id': studentId,
      'name': name,
      'password': password,
      'public_key_pem': publicKeyPem,
    };
    _logReq('POST', url, body: body);

    final res = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    _logRes(res);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> registerDriver({
    required String driverId,
    required String name,
    required String password,
  }) async {
    final url = '$_baseUrl/auth/register/driver';
    final body = {'driver_id': driverId, 'name': name, 'password': password};
    _logReq('POST', url, body: body);

    final res = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    _logRes(res);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> login({
    required String userId,
    required String password,
    required String role,
  }) async {
    final url = '$_baseUrl/auth/login';
    final body = {'user_id': userId, 'password': password, 'role': role};
    _logReq('POST', url, body: body);

    final res = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    _logRes(res);
    final data = _handleResponse(res);
    await _saveToken(data['access_token'], data['role']);
    return data;
  }

  // ── Wallet (Student) ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fundWallet(int amountNaira) async {
    final url = '$_baseUrl/v1/student/me/fund';
    final body = {'amount_naira': amountNaira};
    _logReq('POST', url, body: body, headers: _authHeaders());

    final res = await http
        .post(Uri.parse(url), headers: _authHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));

    _logRes(res);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> deposit(int amountNaira) =>
      fundWallet(amountNaira);

  static Future<Map<String, dynamic>> getBalance() async {
    final url = '$_baseUrl/wallet/balance';
    _logReq('GET', url, headers: _authHeaders());

    final res = await http
        .get(Uri.parse(url), headers: _authHeaders())
        .timeout(const Duration(seconds: 15));

    _logRes(res);
    return _handleResponse(res);
  }

  // ── Student Profile ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getStudentProfile() async {
    final url = '$_baseUrl/v1/student/me';
    _logReq('GET', url, headers: _authHeaders());

    final res = await http
        .get(Uri.parse(url), headers: _authHeaders())
        .timeout(const Duration(seconds: 15));

    _logRes(res);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateStudentProfile({
    String? name,
    String? password,
  }) async {
    final url = '$_baseUrl/v1/student/me';
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (password != null) body['password'] = password;
    _logReq('PUT', url, body: body, headers: _authHeaders());

    final res = await http
        .put(Uri.parse(url), headers: _authHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));

    _logRes(res);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> uploadStudentAvatar(
    String filePath,
  ) async {
    final url = '$_baseUrl/v1/student/me/avatar';
    final token = await getToken();
    _logReq(
      'POST (Multipart)',
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    _log('File Path: $filePath');

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    // Increase timeout to 60s for images
    final streamedRes = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final res = await http.Response.fromStream(streamedRes);

    _logRes(res);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> uploadDriverAvatar(
    String filePath,
  ) async {
    final url = '$_baseUrl/v1/driver/me/avatar';
    final token = await getToken();
    _logReq(
      'POST (Multipart)',
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    _log('File Path: $filePath');

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    // Increase timeout to 60s for images
    final streamedRes = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final res = await http.Response.fromStream(streamedRes);

    _logRes(res);
    return _handleResponse(res);
  }

  static Future<void> deleteStudentAccount() async {
    final url = '$_baseUrl/v1/student/me';
    _logReq('DELETE', url, headers: _authHeaders());

    final res = await http
        .delete(Uri.parse(url), headers: _authHeaders())
        .timeout(const Duration(seconds: 15));

    _logRes(res);
    _handleResponse(res);
  }

  // ── Sync (Student) ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> studentSyncUpload(
    List<Map<String, dynamic>> refundClaims,
  ) async {
    final url = '$_baseUrl/sync/student/upload';
    final requestBody = {'refund_claims': refundClaims};
    _logReq('POST', url, body: requestBody, headers: _authHeaders());

    final res = await http
        .post(
          Uri.parse(url),
          headers: _authHeaders(),
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 20));

    _logRes(res);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> studentSyncDownload() async {
    final url = '$_baseUrl/sync/student/download';
    _logReq('GET', url, headers: _authHeaders());

    final res = await http
        .get(Uri.parse(url), headers: _authHeaders())
        .timeout(const Duration(seconds: 20));

    _logRes(res);
    return _handleResponse(res);
  }

  // ── Sync (Driver) ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> withdrawFunds({
    required double amountNaira,
    String? bankAccount,
    String? bankCode,
  }) async {
    final url = '$_baseUrl/v1/driver/me/withdraw';
    final body = {
      'amount_naira': amountNaira,
      if (bankAccount != null) 'bank_account_number': bankAccount,
      if (bankCode != null) 'bank_code': bankCode,
    };
    _logReq('POST', url, body: body, headers: _authHeaders());

    final res = await http
        .post(Uri.parse(url), headers: _authHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));

    _logRes(res);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> driverSyncUpload(
    List<Map<String, dynamic>> promiseNotes,
  ) async {
    final url = '$_baseUrl/sync/driver/upload';
    final requestBody = {'promise_notes': promiseNotes};
    _logReq('POST', url, body: requestBody, headers: _authHeaders());

    final res = await http
        .post(
          Uri.parse(url),
          headers: _authHeaders(),
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 20));

    _logRes(res);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> driverSyncDownload() async {
    final url = '$_baseUrl/sync/driver/download';
    _logReq('GET', url, headers: _authHeaders());

    final res = await http
        .get(Uri.parse(url), headers: _authHeaders())
        .timeout(const Duration(seconds: 20));

    _logRes(res);
    return _handleResponse(res);
  }

  // ── Routes (Public) ─────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchRoutes() async {
    final url = '$_baseUrl/v1/routes';
    _logReq('GET', url);

    final res = await http
        .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));

    _logRes(res);
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return List<Map<String, dynamic>>.from(body);
    }
    throw ApiException(res.statusCode, 'Failed to fetch routes');
  }

  // ── Notifications ──────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final url = '$_baseUrl/v1/notifications';
    _logReq('GET', url, headers: _authHeaders());

    final res = await http
        .get(Uri.parse(url), headers: _authHeaders())
        .timeout(const Duration(seconds: 15));

    _logRes(res);
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return List<Map<String, dynamic>>.from(body);
    }
    throw ApiException(res.statusCode, 'Failed to fetch notifications');
  }

  static Future<void> markNotificationRead(int notificationId) async {
    final url = '$_baseUrl/v1/notifications/$notificationId/read';
    _logReq('PATCH', url, headers: _authHeaders());

    final res = await http
        .patch(Uri.parse(url), headers: _authHeaders())
        .timeout(const Duration(seconds: 10));

    _logRes(res);
  }

  // ── Response Handler ────────────────────────────────────────────────────

  static Map<String, dynamic> _handleResponse(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'data': body};
    } else {
      final detail =
          body is Map ? body['detail'] ?? 'Unknown error' : body.toString();
      throw ApiException(res.statusCode, detail.toString());
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'API Error $statusCode: $message';
}
