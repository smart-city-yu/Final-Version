import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/user_profile.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  UserProfile? _user;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _error;
  // Inline feedback after profile edit dialog.
  String? _updateSuccess;
  String? _updateError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await _userService.getProfile();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _user = UserProfile.fromJson(result['data'] as Map<String, dynamic>);
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message'] as String?;
        _isLoading = false;
      });
    }
  }

  void logout(BuildContext context) async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  // ── PUT /api/user/profile ─────────────────────────────────────────────────

  Future<void> _showEditProfileDialog() async {
    final nameCtrl = TextEditingController(text: _user!.fullName);
    final phoneCtrl = TextEditingController(text: _user!.phone);

    final inputDecoration = (String label, IconData icon) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textGrey, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
          filled: true,
          fillColor: AppColors.backgroundLight,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration:
                  inputDecoration('Full Name', Icons.person_outline),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration:
                  inputDecoration('Phone Number', Icons.phone_outlined),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final capturedName  = nameCtrl.text.trim();
    final capturedPhone = phoneCtrl.text.trim();

    if (confirmed != true || !mounted) return;

    setState(() => _isUpdating = true);

    final result = await _userService.updateProfile(
      fullName: capturedName,
      phoneNumber: capturedPhone,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _user = UserProfile.fromJson(result['data'] as Map<String, dynamic>);
        _isUpdating = false;
        _updateSuccess = 'Profile updated successfully.';
        _updateError = null;
      });
    } else {
      setState(() {
        _isUpdating = false;
        _updateError = result['message'] as String? ?? 'Update failed.';
        _updateSuccess = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_error != null || _user == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                _error ?? 'Failed to load profile.',
                style: const TextStyle(color: AppColors.textGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadProfile();
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final user = _user!;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Edit button row
              Align(
                alignment: Alignment.centerRight,
                child: _isUpdating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Edit Profile',
                        icon: const Icon(Icons.edit_outlined,
                            color: AppColors.primary),
                        onPressed: _showEditProfileDialog,
                      ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                user.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textGrey,
                ),
              ),
              // ── Profile update feedback banners ─────────────────────
              if (_updateSuccess != null) ...[
                const SizedBox(height: 16),
                AppSuccessBanner(
                  message: _updateSuccess!,
                  onDismiss: () => setState(() => _updateSuccess = null),
                ),
              ],
              if (_updateError != null) ...[
                const SizedBox(height: 16),
                AppErrorBanner(
                  message: _updateError!,
                  onDismiss: () => setState(() => _updateError = null),
                ),
              ],
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    buildInfoRow(
                      icon: Icons.person_outline,
                      label: 'Full Name',
                      value: user.fullName,
                    ),
                    buildInfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: user.email,
                    ),
                    buildInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: user.phone,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    buildTapRow(
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordScreen(),
                          ),
                        );
                      },
                    ),
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        leading: const Icon(
                          Icons.help_outline,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        title: const Text(
                          'Help & Support',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        iconColor: AppColors.textLight,
                        collapsedIconColor: AppColors.textLight,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        children: [
                          const Divider(
                            height: 1,
                            color: AppColors.borderLight,
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.borderLight,
                              ),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Contact Support',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'roadnacity@gmail.com',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'We are here to help you with reports, account issues, and app questions.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textGrey,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Frequently Asked Questions',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          buildFaqItem(
                            question: 'How do I create a report?',
                            answer:
                            'Open the map, choose the issue type, confirm the location, and submit your report. You can also add details if needed.',

                          ),

                          buildFaqItem(
                            question: 'What does voting mean?',
                            answer:
                            'Voting helps confirm whether a reported issue still exists, which improves report accuracy for other users.',
                          ),
                          buildFaqItem(
                            question: 'What happens after I submit a report?',
                            answer:
                            'Your report is added to the map and shared with the community. It is reviewed and forwarded to  municipalities, helping highlight issues and support better road conditions.',
                            ),
                          buildFaqItem(
                            question: 'What do report statuses mean?',
                            answer:
                            'Report statuses show the current state of an issue, such as under review, in progress, resolved, or still active.',
                          ),

                        ],
                      ),
                    ),
                    const Divider(
                      height: 1,
                      indent: 50,
                      color: AppColors.borderLight,
                    ),
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          14,
                        ),
                        leading: const Icon(
                          Icons.info_outline,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        title: const Text(
                          'About RoadNa',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        iconColor: AppColors.textLight,
                        collapsedIconColor: AppColors.textLight,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        children: const [
                          Divider(
                            height: 1,
                            color: AppColors.borderLight,
                          ),
                          SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'RoadNa',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'RoadNa is a smart road reporting app that helps users report road issues, track updates, and support safer roads through community interaction.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textGrey,
                                height: 1.5,
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Together, we make roads safer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Version 1.0.0',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                      height: 1,
                      indent: 50,
                      color: AppColors.borderLight,
                    ),
                    InkWell(
                      onTap: () => logout(context),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              size: 20,
                              color: AppColors.red,
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Sign Out',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 50,
            color: AppColors.borderLight,
          ),
      ],
    );
  }

  Widget buildTapRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textLight,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 50,
            color: AppColors.borderLight,
          ),
      ],
    );
  }

  Widget buildFaqItem({
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderLight,
        ),
      ),
      child: Theme(
        data: ThemeData().copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 2,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            14,
            0,
            14,
            14,
          ),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textLight,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            question,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}