import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../home_screen.dart';

import '../../widgets/network_avatar.dart';
import '../settings/change_password_screen.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.requireComplete = false});

  /// If true, after a successful update the screen will navigate to
  /// `HomeScreen` instead of simply popping. Useful when forcing profile
  /// completion immediately after login.
  final bool requireComplete;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _firstName = TextEditingController();
  final _bio = TextEditingController();
  final _phone = TextEditingController();
  File? _avatarFile;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _bio.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user ?? {};
    final existingFirstRaw = (user['first_name'] ?? user['firstName'])
        ?.toString()
        .trim();
    final existingLastRaw = (user['last_name'] ?? user['lastName'])
        ?.toString()
        .trim();
    final firstLocked = existingFirstRaw != null && existingFirstRaw.isNotEmpty;
    final lastLocked = existingLastRaw != null && existingLastRaw.isNotEmpty;
    // populate controllers on first build
    if (_first.text.isEmpty && user['username'] != null) {
      _first.text = user['username'];
    }
    if (_phone.text.isEmpty && user['phone'] != null) {
      _phone.text = user['phone'].toString();
    }
    if (_bio.text.isEmpty && user['bio'] != null) _bio.text = user['bio'];
    // populate first/last name from server 'name' if available
    if (_firstName.text.isEmpty && existingFirstRaw != null) {
      _firstName.text = existingFirstRaw;
    }
    if (_last.text.isEmpty && existingLastRaw != null) {
      _last.text = existingLastRaw;
    }
    if (_firstName.text.isEmpty) {
      final full = user['name']?.toString() ?? '';
      if (full.isNotEmpty) {
        final parts = full.split(' ');
        _firstName.text = parts.first;
        if (_last.text.isEmpty && parts.length > 1) {
          _last.text = parts.sublist(1).join(' ');
        }
      }
    }
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
          'Edit Profile',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              // Profile avatar with safe network loading or selected local file
              if (_avatarFile != null)
                CircleAvatar(
                  radius: 48,
                  backgroundImage: FileImage(_avatarFile!),
                )
              else
                NetworkAvatar(url: user['avatar'] as String?, radius: 48),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  // Pick an image from gallery to set as profile photo
                  () async {
                    final picker = ImagePicker();
                    final XFile? file = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (file == null) return;
                    setState(() {
                      _avatarFile = File(file.path);
                    });
                  }();
                },
                child: const Text(
                  'Change profile photo',
                  style: TextStyle(color: Colors.lightBlue),
                ),
              ),
              const SizedBox(height: 14),
              // First name and last name fields
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstName,
                      readOnly: firstLocked,
                      enableInteractiveSelection: true,
                      decoration: InputDecoration(
                        hintText: 'First name',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _last,
                      readOnly: lastLocked,
                      enableInteractiveSelection: true,
                      decoration: InputDecoration(
                        hintText: 'Last name',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (firstLocked || lastLocked) ...[
                const SizedBox(height: 6),
                Text(
                  'First name and last name can only be set once.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              // Username field
              TextField(
                controller: _first,
                decoration: InputDecoration(
                  hintText: 'Username',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // last name removed in favor of bio
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: TextField(
                  controller: _bio,
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    hintText: 'Bio',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                  LengthLimitingTextInputFormatter(16),
                ],
                decoration: InputDecoration(
                  hintText:
                      'Mobile Number with country code (e.g. +919876543210)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                ),
                child: const Text(
                  'Change Password',
                  style: TextStyle(color: Colors.lightBlue),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final notifications = Provider.of<NotificationService>(
                      context,
                      listen: false,
                    );
                    final auth = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    final phone = _phone.text.trim();
                    final data = {
                      'username': _first.text.trim(),
                      'first_name': _firstName.text.trim(),
                      'last_name': _last.text.trim(),
                      'phone': phone,
                      'bio': _bio.text.trim(),
                    };

                    if (phone.isEmpty) {
                      notifications.showWarning(
                        'Please enter mobile number with country code',
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
                      final res = await auth.updateProfile(
                        data,
                        avatar: _avatarFile,
                      );
                      Navigator.of(context).pop();
                      if (res['success'] == 1) {
                        if (widget.requireComplete) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                          );
                        } else {
                          // Return a flag so caller can refresh their state
                          Navigator.of(context).pop({'updated': true});
                        }
                        return;
                      }
                      notifications.showError(
                        NotificationService.formatMessage(
                          res['message'] ?? 'Update failed',
                        ),
                      );
                    } catch (e) {
                      Navigator.of(context).pop();
                      notifications.showError(
                        NotificationService.formatMessage(e),
                      );
                    }
                  },
                  child: const Text('Done', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
