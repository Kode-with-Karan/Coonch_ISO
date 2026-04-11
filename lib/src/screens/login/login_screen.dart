import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import 'reset_password_screen.dart';
import '../home_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../../services/notification_service.dart';
import '../../utils/legal_documents.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // final _emailController = TextEditingController(text: 'josh@gmail.com');
  // final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // final _emailController = TextEditingController(text: 'newuser');
  // final _passwordController = TextEditingController(text: 'P@ssw0rd@1221');
  bool _keepSigned = true;
  bool _obscure = true;

  String _resolveLoginMessage(Map<String, dynamic> res) {
    final directCandidates = [
      res['message'],
      res['detail'],
      res['error'],
      res['non_field_errors'],
      res['errors'],
      res['data'],
    ];

    for (final candidate in directCandidates) {
      if (candidate == null) continue;
      final formatted = NotificationService.formatMessage(candidate).trim();
      if (formatted.isNotEmpty &&
          formatted.toLowerCase() != 'null' &&
          formatted.toLowerCase() != 'login failed') {
        return formatted;
      }
    }

    return 'Login failed. Please verify your username/email and password.';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: kIsWeb ? 560 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Column(
                      children: [
                        SizedBox(height: 4),
                        Image(
                          image: AssetImage('assets/icons/app_icon.png'),
                          height: 96,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                  const Text(
                    'Log in',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your details and Log in',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  _buildInput(
                    label: 'Username or Email',
                    controller: _emailController,
                    hint: 'Username or email',
                  ),
                  const SizedBox(height: 12),
                  _buildInput(
                    label: 'Password',
                    controller: _passwordController,
                    hint: 'Password',
                    obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _keepSigned = !_keepSigned),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _keepSigned
                                ? Colors.lightBlue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: _keepSigned
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Keep me signed in',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ResetPasswordScreen(),
                          ),
                        ),
                        child: const Text('Forgot your password?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.lightBlue,
                      ),
                      onPressed: () async {
                        final auth = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        final notifications = Provider.of<NotificationService>(
                          context,
                          listen: false,
                        );
                        final input = _emailController.text.trim();
                        final password = _passwordController.text;

                        if (input.isEmpty || password.isEmpty) {
                          notifications.showWarning(
                            'Please enter email/username and password',
                          );
                          return;
                        }

                        // Resolve phone -> username mapping if user entered a phone
                        String identifierToSend = input;
                        try {
                          final phoneOnly = input.replaceAll(RegExp(r'\D'), '');
                          final looksLikeNumber =
                              RegExp(r'^\+?\d{6,}$').hasMatch(input) ||
                              (phoneOnly.isNotEmpty && phoneOnly.length >= 6);
                          if (looksLikeNumber) {
                            final prefs = await SharedPreferences.getInstance();
                            // Try exact input first, then digits-only
                            final mapped =
                                prefs.getString('phone_to_username:$input') ??
                                prefs.getString('phone_to_username:$phoneOnly');
                            if (mapped != null && mapped.isNotEmpty) {
                              identifierToSend = mapped;
                            }
                          }
                        } catch (_) {}

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) =>
                              const Center(child: CircularProgressIndicator()),
                        );

                        try {
                          final res = await auth.login(
                            identifierToSend,
                            password,
                          );
                          Navigator.of(context).pop(); // remove progress dialog

                          if (res['success'] == 1) {
                            // Check whether profile appears complete; if not,
                            // send user to EditProfileScreen to collect username/phone.
                            final user = auth.user ?? {};
                            final username = (user['username'] ?? '')
                                .toString();
                            final phone = (user['phone'] ?? '').toString();
                            final needsProfile =
                                username.isEmpty || phone.isEmpty;

                            if (needsProfile) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen(
                                    requireComplete: true,
                                  ),
                                ),
                              );
                            } else {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const HomeScreen(),
                                ),
                              );
                            }

                            return;
                          }

                          notifications.showError(_resolveLoginMessage(res));
                        } catch (e) {
                          Navigator.of(context).pop();
                          notifications.showError(
                            NotificationService.formatMessage(e),
                          );
                        }
                      },
                      child: const Text(
                        'Log in',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(context).pushNamed('/signup/1'),
                              child: const Text(
                                'Sign up',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => showLegalDocumentPopup(
                                context,
                                LegalDocumentType.terms,
                              ),
                              child: const Text(
                                'Terms of Services',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => showLegalDocumentPopup(
                                context,
                                LegalDocumentType.privacy,
                              ),
                              child: const Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }

  Widget _socialButton({required IconData icon}) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: IconButton(
        onPressed: () {},
        icon: Icon(icon, size: 30, color: Colors.grey),
      ),
    );
  }
}
