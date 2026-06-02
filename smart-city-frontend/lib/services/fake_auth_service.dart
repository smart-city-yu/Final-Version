class FakeAuthService {
  static String currentEmail = 'leen@test.com';
  static String currentPassword = '123456L';

  static const String takenEmail = 'used@test.com';
  static const String usedNationalId = '1234567890';
  static const String usedPhone = '0791234567';
  static const String resetCode = '123456';

  Future<Map<String, dynamic>> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 2));

    String cleanEmail = email.trim().toLowerCase();

    if (cleanEmail == currentEmail && password == currentPassword) {
      return {
        'success': true,
        'message': 'Logged in successfully.',
        'data': {'email': cleanEmail},
      };
    }

    return {
      'success': false,
      'message': 'Incorrect email or password.',
      'data': null,
    };
  }

  Future<Map<String, dynamic>> register(
    String name,
    String nationalId,
    String phone,
    String email,
    String password,
  ) async {
    await Future.delayed(const Duration(seconds: 2));

    String cleanName = name.trim();
    String cleanNationalId = nationalId.trim();
    String cleanPhone = phone.trim();
    String cleanEmail = email.trim().toLowerCase();

    if (cleanName.isEmpty) return _fail('Name is required.');
    if (cleanNationalId.isEmpty) return _fail('National ID is required.');
    if (!RegExp(r'^[0-9]{10}$').hasMatch(cleanNationalId)) return _fail('National ID must be 10 digits.');
    if (cleanNationalId == usedNationalId) return _fail('National ID already used.');
    if (cleanPhone.isEmpty) return _fail('Phone number is required.');
    if (!RegExp(r'^07[789][0-9]{7}$').hasMatch(cleanPhone)) return _fail('Phone number must be a valid Jordanian number.');
    if (cleanPhone == usedPhone) return _fail('Phone number already used.');
    if (cleanEmail.isEmpty) return _fail('Email is required.');
    if (!cleanEmail.contains('@')) return _fail('Enter a valid email.');
    if (cleanEmail == takenEmail) return _fail('This email is already registered.');
    if (password.isEmpty) return _fail('Password is required.');
    if (password.length < 7) return _fail('At least 7 characters');
    if (!RegExp(r'[A-Z]').hasMatch(password)) return _fail('Must contain uppercase letter');

    currentEmail = cleanEmail;
    currentPassword = password;

    return {
      'success': true,
      'message': 'Account created! Please sign in.',
      'data': {'name': cleanName, 'nationalId': cleanNationalId, 'phone': cleanPhone, 'email': cleanEmail},
    };
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    if (currentPassword != FakeAuthService.currentPassword) return _fail('Current password is incorrect');
    if (newPassword.length < 7) return _fail('At least 7 characters');
    if (!RegExp(r'[A-Z]').hasMatch(newPassword)) return _fail('Must contain uppercase letter');
    FakeAuthService.currentPassword = newPassword;
    return {'success': true, 'message': 'Password changed successfully', 'data': null};
  }

  Future<Map<String, dynamic>> sendResetCode({required String email}) async {
    await Future.delayed(const Duration(seconds: 2));
    String cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return _fail('Please enter your email');
    if (!cleanEmail.contains('@')) return _fail('Enter a valid email');
    if (cleanEmail != currentEmail) return _fail('Email not found');
    return {'success': true, 'message': 'Verification code sent successfully', 'data': {'email': cleanEmail, 'code': resetCode}};
  }

  Future<Map<String, dynamic>> verifyResetCode({required String email, required String code}) async {
    await Future.delayed(const Duration(seconds: 1));
    if (email.trim().toLowerCase() != currentEmail) return _fail('Email not found');
    if (code.trim().isEmpty) return _fail('Enter verification code');
    if (code.trim() != resetCode) return _fail('Invalid verification code');
    return {'success': true, 'message': 'Code verified successfully', 'data': null};
  }

  Future<Map<String, dynamic>> resetPassword({required String email, required String newPassword}) async {
    await Future.delayed(const Duration(seconds: 2));
    if (email.trim().toLowerCase() != currentEmail) return _fail('Email not found');
    if (newPassword.isEmpty) return _fail('Enter new password');
    if (newPassword.length < 7) return _fail('At least 7 characters');
    if (!RegExp(r'[A-Z]').hasMatch(newPassword)) return _fail('Must contain uppercase letter');
    currentPassword = newPassword;
    return {'success': true, 'message': 'Password updated successfully', 'data': null};
  }

  static Map<String, dynamic> _fail(String message) =>
      {'success': false, 'message': message, 'data': null};
}
