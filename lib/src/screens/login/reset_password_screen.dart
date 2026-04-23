import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../utils/legal_documents.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure = true;
  bool _requesting = false;
  bool _submitting = false;

  final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static const List<String> _commonPasswords = [
    'password',
    '123456',
    '123456789',
    '12345678',
    'qwerty',
    'abc123',
    '111111',
    '123123',
    'password1',
  ];

  @override
  void dispose() {
    _identifierController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    final notifications = Provider.of<NotificationService>(
      context,
      listen: false,
    );
    final api = Provider.of<ApiService>(context, listen: false);
    final email = _identifierController.text.trim();

    if (email.isEmpty) {
      notifications.showWarning('Please enter your registered email address');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      notifications.showWarning('Please enter a valid email address');
      return;
    }
    if (_requesting) return;

    setState(() => _requesting = true);
    try {
      final res = await api.requestPasswordReset(email);
      final data = res['data'] as Map<String, dynamic>?;
      final otp = data != null ? data['otp']?.toString() : null;
      if (otp != null) {
        _otpController.text = otp;
      }
      notifications.showSuccess(res['message'] ?? 'Reset code sent');
    } catch (e) {
      notifications.showError(NotificationService.formatMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _submit() async {
    final notifications = Provider.of<NotificationService>(
      context,
      listen: false,
    );
    final api = Provider.of<ApiService>(context, listen: false);

    final otp = _otpController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    final email = _identifierController.text.trim();

    if (_identifierController.text.trim().isEmpty ||
        otp.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty) {
      notifications.showWarning('Please fill all fields');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      notifications.showError('Please enter a valid registered email address');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      notifications.showWarning('Reset code must be exactly 6 digits');
      return;
    }
    if (password != confirm) {
      notifications.showError('Passwords do not match');
      return;
    }
    final unmet = _unmetRules(password);
    if (unmet.isNotEmpty) {
      notifications.showWarning('Please meet all password requirements');
      return;
    }
    if (_submitting) return;

    setState(() => _submitting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await api.confirmPasswordReset(
        email: email,
        otp: otp,
        password: password,
      );
      Navigator.of(context).pop();
      if (res['success'] == 1) {
        notifications.showSuccess('Password reset successfully');
        Navigator.of(context).maybePop();
      } else {
        notifications.showError(
          NotificationService.formatMessage(
            res['message'] ?? 'Failed to reset password',
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      notifications.showError(NotificationService.formatMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Request a reset code, then set a new password.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _identifierController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Registered Email',
                        hintText: 'name@example.com',
                        labelStyle: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
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
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _requesting ? null : _requestReset,
                        child: _requesting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Request reset code'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Reset code',
                        hintText: '6-digit code',
                        counterText: '',
                        labelStyle: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
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
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        hintText: 'Enter new password',
                        labelStyle: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        hintStyle: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    _buildPasswordRules(),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Re-enter password',
                        labelStyle: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        hintStyle: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
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
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom + 12,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPasswordRules() {
    final password = _passwordController.text;
    final pwdLower = password.toLowerCase();

    final rules = <String, bool>{
      'Your password must contain at least 8 characters.': password.length >= 8,
      'Your password can’t be a commonly used password.':
          password.isNotEmpty && !_commonPasswords.contains(pwdLower),
      'Your password can’t be entirely numeric.':
          password.isNotEmpty && !RegExp(r'^\d+$').hasMatch(password),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rules.entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Icon(
                    e.value ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: e.value ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.key, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  List<String> _unmetRules(String password) {
    final pwdLower = password.toLowerCase();
    final unmet = <String>[];

    if (password.length < 8) unmet.add('at least 8 characters');
    if (password.isEmpty || RegExp(r'^\d+$').hasMatch(password)) {
      unmet.add('not entirely numeric');
    }
    if (password.isEmpty || _commonPasswords.contains(pwdLower)) {
      unmet.add('not a common password');
    }

    return unmet;
  }
}
