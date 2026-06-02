import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scale = Tween<double>(begin: 0.8, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;
      final token = await AuthService().getToken();
      if (!mounted) return;

      bool goHome = false;
      if (token != null) {
        goHome = _isTokenValid(token);
        if (!goHome) {
          // Token exists but expired — clear it so login screen starts clean
          await AuthService().logout();
        }
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, goHome ? '/home' : '/login');
    });
  }

  /// Returns true if the JWT token is present and has not yet expired.
  /// Decodes the `exp` claim from the payload — no server round-trip needed.
  bool _isTokenValid(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = base64Url.normalize(parts[1]); // payload is second part of token and here we convert it to bytes
      final decoded = utf8.decode(base64Url.decode(payload)); // convert bytes to string
      final data = jsonDecode(decoded) as Map<String, dynamic>; // parse string to json
      final exp = (data['exp'] as num?)?.toInt();
      if (exp == null) return true; // no exp claim → assume valid
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 < exp;
    } catch (_) {
      return true; // on parse error let the server decide
    }
  }

  @override
  void dispose() {    // STOP the animation to prevent memory leaks (it called automatically)
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Image.asset(
              'assets/images/logo.png',
              width: 160,
            ),
          ),
        ),
      ),
    );
  }
}
