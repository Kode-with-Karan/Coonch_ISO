import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'signup_step2.dart';
import '../home_screen.dart';
import '../../services/notification_service.dart';

class SignUpStep1 extends StatefulWidget {
  const SignUpStep1({super.key});

  @override
  State<SignUpStep1> createState() => _SignUpStep1State();
}

class _SignUpStep1State extends State<SignUpStep1> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  bool _obscure = true;

  static const List<String> _commonPasswords = [
    'password',
    '123456',
    '123456789',
    '12345678',
    'qwerty',
    'abc123',
    '111111',
    '123123',
    'password1'
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_refreshRules);
    _passwordController.addListener(_refreshRules);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    });
  }

  bool _hasVisiblePasswordChars(String password) => password.trim().isNotEmpty;

  bool _validateStep1() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    String? emailError;
    String? passwordError;
    String? confirmError;

    if (email.isEmpty) {
      emailError = 'Please enter your email';
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      emailError = 'Please enter a valid email address';
    }

    if (!_hasVisiblePasswordChars(password)) {
      passwordError = 'Please enter your password';
    }

    if (confirm.isEmpty) {
      confirmError = 'Please confirm your password';
    }

    if (passwordError == null && confirmError == null && password != confirm) {
      confirmError = 'Passwords do not match';
    }

    if (passwordError == null) {
      final unmet = _unmetRules(password, email);
      if (unmet.isNotEmpty) {
        passwordError = 'Please meet all password requirements';
      }
    }

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmError = confirmError;
    });

    return emailError == null && passwordError == null && confirmError == null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.black)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Center(
                  child: Column(children: [
                SizedBox(height: 4),
                Image(
                    image: AssetImage('assets/icons/app_icon.png'),
                    height: 100,
                    fit: BoxFit.contain),
                SizedBox(height: 22),
              ])),
              const Text('Sign Up',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Enter your details and sign In',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              _buildInput(
                  label: 'Email',
                  controller: _emailController,
                  hint: 'josh@gmail.com',
                  errorText: _emailError,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    if (_emailError != null) {
                      setState(() => _emailError = null);
                    }
                  }),
              const SizedBox(height: 12),
              _buildInput(
                  label: 'Password',
                  controller: _passwordController,
                  hint: 'Password',
                  errorText: _passwordError,
                  obscure: _obscure,
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                  suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off))),
              const SizedBox(height: 8),
              _buildPasswordRules(),
              const SizedBox(height: 12),
              _buildInput(
                  label: 'Confirm Password',
                  controller: _confirmController,
                  hint: 'Confirm Password',
                  errorText: _confirmError,
                  obscure: _obscure,
                  onChanged: (_) {
                    if (_confirmError != null) {
                      setState(() => _confirmError = null);
                    }
                  },
                  suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue.shade300,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    final email = _emailController.text.trim();
                    final password = _passwordController.text;
                    final notifications = Provider.of<NotificationService>(
                        context,
                        listen: false);

                    if (!_validateStep1()) {
                      notifications
                          .showWarning('Please correct the highlighted fields');
                      return;
                    }

                    showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) =>
                            const Center(child: CircularProgressIndicator()));

                    try {
                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);
                      final res = await auth.api.requestRegistrationOtp(email);

                      Navigator.of(context).pop();

                      if (res['success'] == 1) {
                        notifications
                            .showSuccess('Verification code sent to $email.');
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SignUpStep2(
                                  email: email,
                                  password: password,
                                )));
                        return;
                      }

                      notifications.showError(NotificationService.formatMessage(
                          res['message'] ??
                              'Failed to send verification code'));
                    } catch (e) {
                      Navigator.of(context).pop();
                      notifications
                          .showError(NotificationService.formatMessage(e));
                    }
                  },
                  child: const Text('Sign up',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text.rich(TextSpan(children: [
                    TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(color: Colors.grey)),
                    TextSpan(
                        text: 'Log in', style: TextStyle(color: Colors.black))
                  ])),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
      {required String label,
      required TextEditingController controller,
      String? hint,
      String? errorText,
      TextInputType? keyboardType,
      ValueChanged<String>? onChanged,
      bool obscure = false,
      Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: errorText == null
                      ? Colors.grey.shade200
                      : Colors.red.shade400)),
          child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              onChanged: onChanged,
              obscureText: obscure,
              decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  suffixIcon: suffix)),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: TextStyle(color: Colors.red.shade600, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordRules() {
    final password = _passwordController.text;
    final hasVisibleChars = _hasVisiblePasswordChars(password);
    final emailLocal = _emailController.text.split('@').first.toLowerCase();
    final pwdLower = password.trim().toLowerCase();
    final tooSimilar = emailLocal.length >= 3 && pwdLower.contains(emailLocal);

    final rules = <String, bool>{
      "Your password can’t be too similar to your other personal information.":
          hasVisibleChars && !tooSimilar,
      'Your password must contain at least 8 characters.':
          hasVisibleChars && password.length >= 8,
      'Your password can’t be a commonly used password.':
          hasVisibleChars && !_commonPasswords.contains(pwdLower),
      'Your password can’t be entirely numeric.':
          hasVisibleChars && !RegExp(r'^\d+$').hasMatch(password),
    };

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rules.entries
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(children: [
                    Icon(
                      e.value
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: e.value ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            Text(e.key, style: const TextStyle(fontSize: 12)))
                  ]),
                ))
            .toList());
  }

  List<String> _unmetRules(String password, String email) {
    final hasVisibleChars = _hasVisiblePasswordChars(password);
    final emailLocal = email.split('@').first.toLowerCase();
    final pwdLower = password.trim().toLowerCase();
    final tooSimilar = emailLocal.length >= 3 && pwdLower.contains(emailLocal);
    final unmet = <String>[];

    if (!hasVisibleChars || password.length < 8) {
      unmet.add('at least 8 characters');
    }
    if (!hasVisibleChars || RegExp(r'^\d+$').hasMatch(password)) {
      unmet.add('not entirely numeric');
    }
    if (!hasVisibleChars || _commonPasswords.contains(pwdLower)) {
      unmet.add('not a common password');
    }
    if (!hasVisibleChars || tooSimilar) {
      unmet.add('not similar to your personal info');
    }

    return unmet;
  }

  void _refreshRules() => setState(() {});
}
