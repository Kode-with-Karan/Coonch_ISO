import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/widgets.dart';
import '../profile/edit_profile_screen.dart';
import 'change_password_screen.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../services/usage_monitor.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool? _privateValue;
  bool _savingPrivacy = false;
  bool _restAlertsEnabled = true;
  bool _loadingRestToggle = true;

  Future<void> _togglePrivacy(bool value) async {
    if (_savingPrivacy) return;
    setState(() {
      _savingPrivacy = true;
      _privateValue = value;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    try {
      final res = await auth.updateProfile({'is_private': value});
      if (res['success'] == 1) {
        await auth.refreshProfile();
      } else {
        notifications.showError(NotificationService.formatMessage(
            res['message'] ?? 'Update failed'));
        setState(() => _privateValue = !value);
      }
    } catch (e) {
      notifications.showError(NotificationService.formatMessage(e));
      setState(() => _privateValue = !value);
    } finally {
      setState(() => _savingPrivacy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final usage = context.watch<UsageMonitor>();
    if (_loadingRestToggle) {
      _restAlertsEnabled = usage.enabled;
      _loadingRestToggle = false;
    }
    final bool isPrivate = _privateValue ?? (auth.user?['is_private'] == true);
    final bool disableToggle = _savingPrivacy || auth.loading;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.6,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Profile Card
            CardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsTile(
                      icon: Icons.person_outline,
                      title: 'Edit profile',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const EditProfileScreen()))),
                  const Divider(height: 1),
                  SettingsTile(
                      icon: Icons.lock_outline,
                      title: 'Change password',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen()))),
                  // const Divider(height: 1),
                  // Linked accounts temporarily disabled per request.
                  // SettingsTile(
                  //     icon: Icons.link,
                  //     title: 'Linked accounts',
                  //     onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  //         builder: (_) => const LinkedAccountsScreen()))),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Privacy Card
            CardContainer(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Privacy',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Private account'),
                    subtitle: Text(isPrivate
                        ? 'Only followers can see your content'
                        : 'Everyone can see your content'),
                    value: isPrivate,
                    onChanged:
                        disableToggle ? null : (value) => _togglePrivacy(value),
                    secondary: _savingPrivacy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.visibility_off),
                    activeThumbColor: Colors.lightBlue,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Rest reminder'),
                    subtitle:
                        const Text('Alert after 2 hours of continuous use'),
                    value: _restAlertsEnabled,
                    onChanged: (val) async {
                      setState(() => _restAlertsEnabled = val);
                      await usage.setEnabled(val);
                    },
                    secondary: _loadingRestToggle
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.alarm),
                    activeThumbColor: Colors.lightBlue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
