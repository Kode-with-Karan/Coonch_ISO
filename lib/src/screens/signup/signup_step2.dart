import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
// import '../home_screen.dart';

class SignUpStep2 extends StatefulWidget {
  const SignUpStep2({super.key, this.email = '', this.password = ''});

  final String email;
  final String password;

  @override
  State<SignUpStep2> createState() => _SignUpStep2State();
}

class _SignUpStep2State extends State<SignUpStep2> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _nameError;
  String? _phoneError;
  String? _otpError;
  File? _avatarFile;
  String? _selectedAvatarUrl;

  String _extractErrorText(dynamic value) {
    if (value == null) return '';

    if (value is List || value is Iterable) {
      final first = (value as Iterable).isNotEmpty ? value.first : null;
      return _extractErrorText(first);
    }

    final text = value.toString();
    final errorDetail = RegExp(
      r"ErrorDetail\(string='([^']+)'[,)]",
    ).firstMatch(text);
    if (errorDetail != null) {
      return errorDetail.group(1)?.trim() ?? text.trim();
    }

    return text.trim();
  }

  String? _extractFieldErrorFromPayload(dynamic payload, String fieldName) {
    if (payload == null) return null;

    if (payload is Map) {
      if (payload.containsKey(fieldName)) {
        final text = _extractErrorText(payload[fieldName]);
        if (text.isNotEmpty) return text;
      }

      // Nested Laravel-like wrappers: {message, data}
      final fromData = _extractFieldErrorFromPayload(
        payload['data'],
        fieldName,
      );
      if (fromData != null && fromData.isNotEmpty) return fromData;

      final fromMessage = _extractFieldErrorFromPayload(
        payload['message'],
        fieldName,
      );
      if (fromMessage != null && fromMessage.isNotEmpty) return fromMessage;

      return null;
    }

    if (payload is List || payload is Iterable) {
      for (final item in payload) {
        final found = _extractFieldErrorFromPayload(item, fieldName);
        if (found != null && found.isNotEmpty) return found;
      }
      return null;
    }

    final raw = payload.toString();

    final detailPattern = RegExp(
      "['\"]$fieldName['\"]\\s*:\\s*\\[ErrorDetail\\(string='([^']+)'",
      caseSensitive: false,
    );
    final detailMatch = detailPattern.firstMatch(raw);
    if (detailMatch != null) {
      return detailMatch.group(1)?.trim();
    }

    final listPattern = RegExp(
      "['\"]$fieldName['\"]\\s*:\\s*\\[['\"]([^'\"]+)['\"]",
      caseSensitive: false,
    );
    final listMatch = listPattern.firstMatch(raw);
    if (listMatch != null) {
      return listMatch.group(1)?.trim();
    }

    final plainPattern = RegExp(
      '$fieldName\\s*:\\s*([^\\n,]+)',
      caseSensitive: false,
    );
    final plainMatch = plainPattern.firstMatch(raw);
    if (plainMatch != null) {
      return plainMatch.group(1)?.trim();
    }

    return null;
  }

  bool _validateForm() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    String? nameError;
    String? phoneError;
    String? otpError;

    if (name.isEmpty) {
      nameError = 'Please enter your full name';
    }

    if (phone.isEmpty) {
      phoneError = 'Please enter mobile number including country code';
    } else if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(phone)) {
      phoneError = 'Please enter a valid mobile number';
    }

    if (otp.isEmpty) {
      otpError = 'Please enter the verification code';
    } else if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      otpError = 'Verification code must be 6 digits';
    }

    setState(() {
      _nameError = nameError;
      _phoneError = phoneError;
      _otpError = otpError;
    });

    return nameError == null && phoneError == null && otpError == null;
  }

  // Show options bottom sheet
  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from device'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFromDevice();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Pick avatar'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showAvatarPicker();
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromDevice() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() {
        _avatarFile = File(file.path);
        _selectedAvatarUrl = null;
      });
    } catch (e) {
      // ignore
    }
  }

  Future<File?> _downloadAvatarToFile(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;
      final bytes = res.bodyBytes;
      final tmpDir = Directory.systemTemp;
      final file = File(
        '${tmpDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      return null;
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SizedBox(
          height: 240,
          child: GridView.count(
            crossAxisCount: 4,
            padding: const EdgeInsets.all(12),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: List.generate(8, (i) {
              final idx = i + 1;
              final url = 'https://i.pravatar.cc/150?img=$idx';
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAvatarUrl = url;
                    _avatarFile = null;
                  });
                  Navigator.of(context).pop();
                },
                child: CircleAvatar(backgroundImage: NetworkImage(url)),
              );
            }),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            bottomInset > 0 ? bottomInset + 16 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: kIsWeb ? 560 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Almost There',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Let's add some additional details to complete your profile.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => _showPhotoOptions(),
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.grey.shade100,
                            backgroundImage: _avatarFile != null
                                ? FileImage(_avatarFile!) as ImageProvider
                                : (_selectedAvatarUrl != null
                                      ? NetworkImage(_selectedAvatarUrl!)
                                      : null),
                            child:
                                _avatarFile == null &&
                                    _selectedAvatarUrl == null
                                ? const Icon(
                                    Icons.camera_alt,
                                    color: Colors.lightBlue,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => _showPhotoOptions(),
                          child: const Text(
                            'Change profile photo',
                            style: TextStyle(color: Colors.lightBlue),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          children: List.generate(4, (i) {
                            final idx = i + 1;
                            final url = 'https://i.pravatar.cc/150?img=$idx';
                            final selected = _selectedAvatarUrl == url;
                            return GestureDetector(
                              onTap: () => setState(() {
                                _selectedAvatarUrl = url;
                                _avatarFile = null;
                              }),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: selected
                                    ? Colors.lightBlue.shade50
                                    : Colors.grey.shade100,
                                backgroundImage: NetworkImage(url),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Or Select Profile Photo',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  _buildInput(
                    label: 'Name',
                    hint: 'Enter your name',
                    controller: _nameController,
                    errorText: _nameError,
                    onChanged: (_) {
                      if (_nameError != null) {
                        setState(() => _nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildInput(
                    label: 'Ph. Number (e.g. +919876543210)',
                    hint: 'Ph. Number with country code ',
                    controller: _phoneController,
                    errorText: _phoneError,
                    hintMaxLines: 2,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) {
                      if (_phoneError != null) {
                        setState(() => _phoneError = null);
                      }
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                      LengthLimitingTextInputFormatter(16),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInput(
                    label: 'Verification Code',
                    hint: 'Enter the verification code sent to your email',
                    controller: _otpController,
                    errorText: _otpError,
                    hintMaxLines: 2,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      if (_otpError != null) {
                        setState(() => _otpError = null);
                      }
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        final notifications = Provider.of<NotificationService>(
                          context,
                          listen: false,
                        );
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) =>
                              const Center(child: CircularProgressIndicator()),
                        );
                        try {
                          final auth = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          final res = await auth.api.requestRegistrationOtp(
                            widget.email.trim(),
                          );
                          Navigator.of(context).pop();
                          if (res['success'] == 1) {
                            notifications.showSuccess(
                              'Verification code resent to ${widget.email.trim()}.',
                            );
                          } else {
                            notifications.showError(
                              NotificationService.formatMessage(
                                res['message'] ?? 'Could not resend code',
                              ),
                            );
                          }
                        } catch (e) {
                          Navigator.of(context).pop();
                          notifications.showError(
                            NotificationService.formatMessage(e),
                          );
                        }
                      },
                      child: const Text('Resend code'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue.shade200,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final name = _nameController.text.trim();
                        final phone = _phoneController.text.trim();
                        final otp = _otpController.text.trim();
                        final email = widget.email.trim();
                        final password = widget.password;
                        final notifications = Provider.of<NotificationService>(
                          context,
                          listen: false,
                        );

                        if (email.isEmpty || password.trim().isEmpty) {
                          notifications.showError(
                            'Signup session is incomplete. Please go back and enter email and password again.',
                          );
                          return;
                        }

                        if (!_validateForm()) {
                          notifications.showWarning(
                            'Please correct the highlighted fields',
                          );
                          return;
                        }

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) =>
                              const Center(child: CircularProgressIndicator()),
                        );

                        try {
                          final auth = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          final res = await auth.register(
                            username: name,
                            email: email,
                            password: password,
                            otp: otp,
                            phone: phone,
                          );

                          Navigator.of(context).pop();

                          if (res['success'] == 1) {
                            // Save phone -> username mapping locally so users can
                            // later login with their phone number.
                            try {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString(
                                'phone_to_username:$phone',
                                name,
                              );
                            } catch (_) {}

                            // If the user picked a file avatar, upload it now.
                            try {
                              if (_avatarFile != null) {
                                await auth.updateProfile({
                                  'phone': phone,
                                }, avatar: _avatarFile);
                              } else if (_selectedAvatarUrl != null) {
                                // Download the selected avatar URL and upload as file
                                final downloaded = await _downloadAvatarToFile(
                                  _selectedAvatarUrl!,
                                );
                                if (downloaded != null) {
                                  await auth.updateProfile({
                                    'phone': phone,
                                  }, avatar: downloaded);
                                  try {
                                    // delete temp file after upload
                                    await downloaded.delete();
                                  } catch (_) {}
                                } else {
                                  // Fallback: try setting avatar by URL field
                                  await auth.updateProfile({
                                    'avatar': _selectedAvatarUrl,
                                  });
                                }
                              }
                            } catch (_) {}

                            Navigator.of(
                              context,
                            ).pushReplacementNamed('/signup/3');
                            return;
                          }

                          final backendNameError =
                              _extractFieldErrorFromPayload(res, 'username') ??
                              _extractFieldErrorFromPayload(res, 'name') ??
                              _extractFieldErrorFromPayload(res, 'first_name');
                          final backendPhoneError =
                              _extractFieldErrorFromPayload(res, 'phone');
                          final backendOtpError =
                              _extractFieldErrorFromPayload(res, 'otp') ??
                              _extractFieldErrorFromPayload(
                                res,
                                'verification_code',
                              );
                          final backendEmailError =
                              _extractFieldErrorFromPayload(res, 'email');
                          final backendPasswordError =
                              _extractFieldErrorFromPayload(res, 'password');

                          var hasFieldErrors = false;
                          setState(() {
                            if (backendNameError != null &&
                                backendNameError.isNotEmpty) {
                              _nameError = backendNameError;
                              hasFieldErrors = true;
                            }
                            if (backendPhoneError != null &&
                                backendPhoneError.isNotEmpty) {
                              _phoneError = backendPhoneError;
                              hasFieldErrors = true;
                            }
                            if (backendOtpError != null &&
                                backendOtpError.isNotEmpty) {
                              _otpError = backendOtpError;
                              hasFieldErrors = true;
                            }
                          });

                          if ((backendEmailError != null &&
                                  backendEmailError.isNotEmpty) ||
                              (backendPasswordError != null &&
                                  backendPasswordError.isNotEmpty)) {
                            notifications.showError(
                              'Signup details from Step 1 are missing or invalid. Please go back and complete Step 1 again.',
                            );
                            return;
                          }

                          if (hasFieldErrors) {
                            notifications.showWarning(
                              'Please correct the highlighted fields',
                            );
                            return;
                          }

                          final fallbackText =
                              NotificationService.formatMessage(
                                res['message'] ??
                                    res['data'] ??
                                    'Registration failed',
                              );
                          notifications.showError(fallbackText);
                        } catch (e) {
                          Navigator.of(context).pop();
                          notifications.showError(
                            NotificationService.formatMessage(e),
                          );
                        }
                      },
                      child: const Text('Next'),
                    ),
                  ),
                  const SizedBox(height: 12),
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
    required String hint,
    required TextEditingController controller,
    String? errorText,
    ValueChanged<String>? onChanged,
    int hintMaxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) => Column(
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
                : Colors.red.shade400,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintMaxLines: hintMaxLines,
            hintStyle: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
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
