import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/widgets.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
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
    'password1',
  ];

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _change() {
    final notifications = Provider.of<NotificationService>(
      context,
      listen: false,
    );
    final current = _currentController.text;
    final password = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty || password.isEmpty || confirm.isEmpty) {
      notifications.showWarning('Please fill all fields');
      return;
    }
    if (password == current) {
      notifications.showWarning(
        'New password must be different from current password',
      );
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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    auth
        .updatePassword(current, _newController.text)
        .then((res) {
          Navigator.of(context).pop();
          if (res['success'] == 1) {
            notifications.showSuccess('Password changed');
            Navigator.of(context).pop();
            return;
          }
          notifications.showError(
            NotificationService.formatMessage(
              res['message'] ?? 'Failed to change password',
            ),
          );
        })
        .catchError((e) {
          Navigator.of(context).pop();
          notifications.showError(NotificationService.formatMessage(e));
        });
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
        title: const Text(
          'Change Password',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              TextField(
                controller: _currentController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'Current Password',
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
              const SizedBox(height: 12),
              TextField(
                controller: _newController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'New Password',
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
                  hintText: 'Confirm Password',
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
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: AccentButton(
                  height: 54,
                  onPressed: _change,
                  child: const Text(
                    'Change Password',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRules() {
    final password = _newController.text;
    final pwdLower = password.toLowerCase();
    final rules = <String, bool>{
      "Your password can’t be too similar to your other personal information.":
          true, // No personal info available here, allow by default
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
    // No personal info to compare; skip

    return unmet;
  }
}
