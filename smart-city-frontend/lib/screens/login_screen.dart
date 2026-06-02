// Flutter's UI library — gives us Scaffold, TextFormField, ElevatedButton, etc.
import 'package:flutter/material.dart';

// Our custom color constants (green, white, border colors, etc.)
import '../core/app_colors.dart';

// Reusable widgets: AppLogo (the logo image) and AppErrorBanner (red error box)
import '../widgets/app_widgets.dart';

// The forgot password screen — navigated to when user taps "Forgot Password?"
import 'forgot_password_screen.dart';

// The service that handles login API call and token storage
import '../services/auth_service.dart';

// ── Widget Declaration ────────────────────────────────────────────────────────

// StatefulWidget because this screen has state that changes:
// loading spinner, error messages, password visibility toggle
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  // Required by Flutter — creates the mutable state object for this widget
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// ── State Class ───────────────────────────────────────────────────────────────

// The actual logic and UI live here, not in LoginScreen above
class _LoginScreenState extends State<LoginScreen> {

  // A unique key that links to the Form widget below —
  // used to trigger all field validators at once via _formKey.currentState!.validate()
  final _formKey = GlobalKey<FormState>();

  // Controllers let us READ what the user typed at any time via .text
  // and are attached to each TextFormField
  final _emailController = TextEditingController();
  final _passController = TextEditingController();

  // One instance of AuthService — reused every time login is called
  final _authService = AuthService();

  // true = show spinner on button + disable it, false = show "Sign In" text
  bool _isLoading = false;

  // true = password shows as dots (hidden), false = shows as plain text
  // starts as true so password is hidden by default
  bool _hidePassword = true;

  // Holds the error message from the server (e.g. "Wrong password")
  // null = no error banner shown, any string = banner appears with that text
  String? _errorMessage;

  // ── Cleanup ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    // TextEditingControllers must be manually released when the screen is destroyed
    // to avoid memory leaks — they hold references to their text fields
    _emailController.dispose();
    _passController.dispose();

    // Always call super.dispose() last
    super.dispose();
  }

  // ── Sign In Logic ────────────────────────────────────────────────────────────

  Future<void> _signIn() async {

    // Step 1: Run all field validators before touching the network
    // If any field fails (empty, bad format), stop here and show field errors
    if (!_formKey.currentState!.validate()) return;

    // Step 2: Enter loading state
    // Show spinner on button, clear any previous error banner
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Step 3: Call the login API — sends email + password to the backend
    // 'await' pauses here until the server responds, UI stays responsive
    final result = await _authService.login(
      _emailController.text,
      _passController.text,
    );

    // Step 4: Safety check — after any await, the screen might have been
    // closed by the user. 'mounted' = false means the widget no longer exists,
    // so we stop to avoid crashing
    if (!mounted) return;

    // Step 5: Always stop the loading spinner regardless of success or failure
    setState(() => _isLoading = false);

    // Step 6: Handle the result
    if (result['success'] == true) {
      // Login worked — token was already saved inside AuthService.login()
      // Replace this screen with Home (user can't press Back to return to Login)
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Login failed — store the server's error message
      // This triggers a rebuild and makes the red error banner appear
      setState(() => _errorMessage = result['message'] as String?);
    }
  }

  // ── Input Field Styling ───────────────────────────────────────────────────────

  // Reusable helper that returns the same decoration for every input field
  // 'hint' = placeholder text, 'icon' = left icon, 'suffix' = optional right widget
  InputDecoration _buildInput(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,                                          // placeholder text inside the field
      prefixIcon: Icon(icon, color: AppColors.textLight),     // icon on the left side
      suffixIcon: suffix,                                      // optional widget on the right (e.g. eye button)
      filled: true,                                           // enables the fillColor below
      fillColor: AppColors.white,                             // field background color

      // Default border (fallback — usually overridden by the two below)
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),              // rounded corners
      ),

      // Border when field is visible but NOT focused (user hasn't tapped it)
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border), // grey border
      ),

      // Border when user taps INTO the field (active/focused state)
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.green, width: 1.5), // green border
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,         // white screen background

      // true = Scaffold shrinks when keyboard appears so nothing gets hidden behind it
      resizeToAvoidBottomInset: true,

      body: SafeArea(
        // SafeArea pushes content below the status bar and above the home indicator
        // so nothing gets hidden under the phone's notch or system UI
        child: SingleChildScrollView(
          // Allows the page to scroll when the keyboard pushes content up
          padding: const EdgeInsets.all(24),    // 24px padding on all sides

          child: Form(
            // Form groups all TextFormFields together
            // _formKey links this Form so we can validate all fields at once
            key: _formKey,

            child: Column(
              // Stacks all children vertically from top to bottom
              children: [

                // ── Top spacing ──────────────────────────────────────────
                const SizedBox(height: 60), // empty space at the top

                // ── Logo ─────────────────────────────────────────────────
                // AppLogo widget → shows assets/images/logo.png at 250px wide
                const AppLogo(),

                const SizedBox(height: 30), // gap between logo and first field

                // ── Email Field ───────────────────────────────────────────
                TextFormField(
                  controller: _emailController,              // connects to our controller to read the typed text
                  keyboardType: TextInputType.emailAddress,  // shows email keyboard (with @ key)
                  decoration: _buildInput('Email', Icons.email_outlined), // applies our shared style

                  // validator runs when _formKey.currentState!.validate() is called
                  // returning a String = show that as an error under the field
                  // returning null = field is valid, no error shown
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter your email';          // error: field is empty
                    }
                    if (!value.contains('@')) {
                      return 'Enter a valid email';       // error: missing @ symbol
                    }
                    return null;                           // valid — no error
                  },
                ),

                const SizedBox(height: 15), // gap between email and password fields

                // ── Password Field ────────────────────────────────────────
                TextFormField(
                  controller: _passController,  // connects to our controller
                  obscureText: _hidePassword,   // true = shows dots, false = shows text

                  decoration: _buildInput(
                    'Password',
                    Icons.lock_outline,

                    // The eye icon button passed as the right-side suffix
                    suffix: IconButton(
                      // Switch icon based on current visibility state
                      icon: Icon(
                        _hidePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textLight,
                      ),
                      // Flip the boolean every tap → triggers rebuild → field updates
                      onPressed: () {
                        setState(() {
                          _hidePassword = !_hidePassword;
                        });
                      },
                    ),
                  ),

                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter your password'; // error: field is empty
                    }
                    return null; // valid — no error
                  },
                ),

                const SizedBox(height: 8),

                // ── Forgot Password Link ──────────────────────────────────
                Align(
                  alignment: Alignment.centerRight, // pushes the button to the right side
                  child: TextButton(
                    onPressed: () {
                      // Push ForgotPasswordScreen on top (user can press Back to return)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Forgot Password?',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),

                // ── Error Banner (only shown when _errorMessage is not null) ──
                // The 'if' here is Flutter's way of conditionally adding widgets to a list
                // When _errorMessage = null → these widgets don't exist in the tree at all
                // When _errorMessage has a value → banner appears automatically
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  AppErrorBanner(
                    message: _errorMessage!,   // the error text from the server
                    // When user taps X → set _errorMessage to null → banner disappears
                    onDismiss: () => setState(() => _errorMessage = null),
                  ),
                ],

                const SizedBox(height: 12),

                // ── Sign In Button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity, // stretches button to full screen width
                  height: 50,             // fixed button height

                  child: ElevatedButton(
                    // null = button is disabled (Flutter greys it out automatically)
                    // _signIn = button is active and calls our login function
                    onPressed: _isLoading ? null : _signIn,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,  // green button background
                      foregroundColor: Colors.white,      // white text/icon color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14), // rounded corners
                      ),
                    ),

                    // Switch button content based on loading state:
                    // loading = white spinner, not loading = "Sign In" text
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,    // spinner line thickness
                          )
                        : const Text('Sign In'),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Register Link ─────────────────────────────────────────
                TextButton(
                  // Navigate to Register screen using the named route defined in main.dart
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text(
                    "Don't have an account? Create an account",
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 13,
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
