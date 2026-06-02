import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static const String _baseUrl = '$kApiHost/api/auth';
  static const String _tokenKey = 'auth_token';

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveToken(data['token'] as String);

        // Separate try/catch — login still succeeds even if Firebase fails
        try {
          final firebaseToken = data['fireBaseToken'];
          if (firebaseToken != null) {
            await FirebaseAuth.instance.signInWithCustomToken(firebaseToken);
            print('✅ Firebase UID: ${FirebaseAuth.instance.currentUser?.uid}');
          }
        } catch (e) {
          print('⚠️ Firebase sign-in failed: $e');
        }

        return {'success': true, 'message': 'Logged in successfully.', 'data': data};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Incorrect email or password.',
        'data': null,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to server. Please try again.',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> register(
    String name,
    String nationalId,
    String email,
    String phoneNumber,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': name.trim(),
          'nationalId': nationalId.trim(),
          'email': email.trim().toLowerCase(),
          'phoneNumber': phoneNumber.trim(),
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Account created! Please sign in.', 'data': data};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed.',
        'data': null,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to server. Please try again.',
        'data': null,
      };
    }
  }

  // ── Forgot / Reset password ─────────────────────────────────────────────

  /// Step 1 — Ask the backend to email a 6-digit reset code.
  Future<Map<String, dynamic>> sendResetCode({required String email}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'A reset code has been sent to your email.',
          'data': data,
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Could not send reset code. Check your email and try again.',
        'data': null,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to server. Please try again.',
        'data': null,
      };
    }
  }

  /// Step 2 — Verify the 6-digit code.
  Future<Map<String, dynamic>> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/verify-reset-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Code verified.', 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Invalid or expired code.',
        'data': null,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to server. Please try again.',
        'data': null,
      };
    }
  }

  /// Step 3 — Set the new password (code is re-sent for server-side validation).
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
          'newPassword': newPassword,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Password reset successfully. You can now sign in.',
          'data': data,
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Could not reset password.',
        'data': null,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to server. Please try again.',
        'data': null,
      };
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }
}
