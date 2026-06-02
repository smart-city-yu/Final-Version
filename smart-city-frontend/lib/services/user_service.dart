import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../core/api_constants.dart';

/// Connects to:
///   GET   /api/user/profile          — fetch authenticated user's profile
///   PUT   /api/user/profile          — update fullName and/or phoneNumber
///   POST  /api/user/change-password  — change password (current + new + confirm)
class UserService {
  static const String _baseUrl = '$kApiHost/api/user';
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // -------------------------------------------------------------------------
  // GET /api/user/profile
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profile'),
        headers: await _authHeaders(),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to load profile.',
        'data': null,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to server.',
        'data': null,
      };
    }
  }

  // -------------------------------------------------------------------------
  // PUT /api/user/profile
  //
  // Body: { fullName (required, min 3 chars), phoneNumber (optional) }
  // Response: ProfileResponse
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    String? phoneNumber,
  }) async {
    try {
      final body = <String, dynamic>{'fullName': fullName.trim()};
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        body['phoneNumber'] = phoneNumber.trim();
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/profile'),
        headers: await _authHeaders(),
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update profile.',
        'data': null,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to server.',
        'data': null,
      };
    }
  }

  // -------------------------------------------------------------------------
  // POST /api/user/change-password
  //
  // Body: { currentPassword, newPassword (min 8), confirmPassword }
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/change-password'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        }),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Password changed successfully.'};
      }
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to change password.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to server.'};
    }
  }
}
