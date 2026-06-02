import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _codeController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isVerified = false;
  bool _isVerifying = false;
  bool _isSaving = false;
  String? _verifyError;
  String? _resetError;

  // Keeps the verified code so we can send it again with the new password.
  String _verifiedCode = '';

  @override
  void dispose() {
    _codeController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _verifyError = 'Enter the verification code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _verifyError = null;
    });

    final result = await _authService.verifyResetCode(
      email: widget.email,
      code: code,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (result['success'] == true) {
      setState(() {
        _isVerified = true;
        _verifiedCode = code;
      });
    } else {
      setState(() => _verifyError = result['message'] as String?);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isVerified) return;

    setState(() {
      _isSaving = true;
      _resetError = null;
    });

    final result = await _authService.resetPassword(
      email: widget.email,
      code: _verifiedCode,
      newPassword: _newController.text,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } else {
      setState(() => _resetError = result['message'] as String?);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textGrey, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.textLight),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: const Text(
          'Reset Password',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Step 1 — Code verification ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isVerified
                      ? const Color(0xFFF0FFF4)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isVerified
                        ? const Color(0xFFA8D5A2)
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isVerified
                              ? Icons.check_circle
                              : Icons.mail_outline,
                          color: _isVerified
                              ? const Color(0xFF2E7D32)
                              : AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isVerified
                              ? 'Code verified ✓'
                              : 'Step 1 — Enter verification code',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _isVerified
                                ? const Color(0xFF2E7D32)
                                : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    if (!_isVerified) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Sent to ${widget.email}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) =>
                            setState(() => _verifyError = null),
                        decoration:
                            _inputDecoration('Verification Code', Icons.verified_outlined),
                      ),
                      if (_verifyError != null) ...[
                        const SizedBox(height: 12),
                        AppErrorBanner(
                          message: _verifyError!,
                          onDismiss: () =>
                              setState(() => _verifyError = null),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isVerifying ? null : _verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isVerifying
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                )
                              : const Text(
                                  'Verify Code',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Step 2 — New password (visible only after code verified) ─
              if (_isVerified) ...[
                const SizedBox(height: 24),
                const Text(
                  'Step 2 — Set your new password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newController,
                  obscureText: true,
                  onChanged: (_) => setState(() => _resetError = null),
                  decoration: _inputDecoration('New Password', Icons.lock_outline),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter new password';
                    if (v.length < 8) return 'At least 8 characters';
                    if (!RegExp(r'[A-Z]').hasMatch(v)) {
                      return 'Must contain an uppercase letter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  onChanged: (_) => setState(() => _resetError = null),
                  decoration:
                      _inputDecoration('Confirm Password', Icons.lock_outline),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != _newController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                // ── Inline error banner ──────────────────────────────────
                if (_resetError != null) ...[
                  const SizedBox(height: 14),
                  AppErrorBanner(
                    message: _resetError!,
                    onDismiss: () => setState(() => _resetError = null),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          )
                        : const Text(
                            'Save New Password',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
