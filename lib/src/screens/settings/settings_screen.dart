import 'package:flutter/material.dart';
import '../playlists/playlists_screen.dart';
import 'subscription_screen.dart';
import 'rewards_screen.dart';
import 'account_screen.dart';
import 'monetization_screen.dart';
import 'share_profile_screen.dart';
import 'help_support_screen.dart';
import 'wishlist_screen.dart';
import '../login/login_screen.dart';
import '../../widgets/widgets.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _popup = true;

  Future<void> _confirmDeleteAccount() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);

    final otpController = TextEditingController();
    bool sending = false;
    bool deleting = false;

    final navigator = Navigator.of(context);
    final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16),
            child: StatefulBuilder(builder: (ctx, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delete account',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                      "If you delete the account then all your data will be deleted and can't be retrieved.",
                      style: TextStyle(color: Colors.red, height: 1.3)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Enter OTP', hintText: '6-digit code'),
                    maxLength: 6,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: sending
                              ? null
                              : () async {
                                  setState(() => sending = true);
                                  try {
                                    final res =
                                        await auth.requestDeleteAccountOtp();
                                    if (res['success'] == 1) {
                                      notifications.showSuccess(
                                          'OTP sent to your email');
                                    } else {
                                      notifications.showError(
                                          NotificationService.formatMessage(
                                              res['message'] ??
                                                  res['detail'] ??
                                                  'Failed to send OTP'));
                                    }
                                  } catch (e) {
                                    notifications.showError(
                                        NotificationService.formatMessage(e));
                                  } finally {
                                    setState(() => sending = false);
                                  }
                                },
                          child: sending
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Send OTP'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent),
                          onPressed: deleting
                              ? null
                              : () async {
                                  final otp = otpController.text.trim();
                                  if (otp.isEmpty) {
                                    notifications
                                        .showError('Please enter the OTP');
                                    return;
                                  }
                                  setState(() => deleting = true);
                                  try {
                                    final res = await auth.deleteAccount(otp);
                                    if (res['success'] == 1) {
                                      notifications
                                          .showSuccess('Account deleted');
                                      navigator.pop(true);
                                    } else {
                                      notifications.showError(
                                          NotificationService.formatMessage(
                                              res['message'] ??
                                                  res['detail'] ??
                                                  'Delete failed'));
                                    }
                                  } catch (e) {
                                    notifications.showError(
                                        NotificationService.formatMessage(e));
                                  } finally {
                                    setState(() => deleting = false);
                                  }
                                },
                          child: deleting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                      onPressed:
                          deleting || sending ? null : () => navigator.pop(),
                      child: const Text('Cancel')),
                  const SizedBox(height: 8),
                ],
              );
            }),
          );
        });

    if (result == true) {
      navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false);
    }
  }

  Widget _sectionCard({required Widget child}) => CardContainer(child: child);

  Widget _listRow(IconData icon, String title, {VoidCallback? onTap}) {
    return SettingsTile(icon: icon, title: title, onTap: onTap);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios)),
        title: const Text('Settings', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _sectionCard(
              child: Column(
                children: [
                  _listRow(Icons.person_outline, 'Account',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const AccountScreen()))),
                  const Divider(height: 1),
                  _listRow(Icons.credit_card, 'Subscription',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen()))),
                  const Divider(height: 1),
                  _listRow(Icons.pie_chart_outline, 'Monetization',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const MonetizationScreen()))),
                  const Divider(height: 1),
                  _listRow(Icons.insert_chart_outlined, 'Share Profile',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ShareProfileScreen()))),
                  const Divider(height: 1),
                  _listRow(Icons.tv, 'Play Lists',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const PlayListsScreen()))),
                  const Divider(height: 1),
                  _listRow(Icons.support_agent_outlined, 'Help & Support',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const HelpSupportScreen()))),
                ],
              ),
            ),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                      padding: EdgeInsets.only(left: 8.0, bottom: 8),
                      child: Text('Notification',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16))),
                  ListTile(
                    leading: CircleAvatar(
                        backgroundColor: Colors.lightBlue[50],
                        child: const Icon(Icons.notifications_none,
                            color: Colors.lightBlue, size: 20)),
                    title: const Text('Pop-up Notification',
                        style: TextStyle(fontSize: 16)),
                    trailing: Switch(
                        value: _popup,
                        onChanged: (v) => setState(() => _popup = v),
                        activeThumbColor: Colors.lightBlue),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
              ),
            ),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                      padding: EdgeInsets.only(left: 8.0, bottom: 8),
                      child: Text('My Content',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16))),
                  ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF0F7FF),
                        child: Icon(Icons.bookmark,
                            color: Colors.lightBlue, size: 20)),
                    title: const Text('My Wishlist',
                        style: TextStyle(fontSize: 16)),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const WishlistScreen())),
                  ),
                ],
              ),
            ),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                      padding: EdgeInsets.only(left: 8.0, bottom: 8),
                      child: Text('Rewards',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16))),
                  ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF0F7FF),
                        child: Icon(Icons.card_giftcard,
                            color: Colors.lightBlue, size: 20)),
                    title: const Text('Reward Points and Coupons',
                        style: TextStyle(fontSize: 16)),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const RewardsScreen())),
                  ),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    // Perform logout: clear token and user state, then navigate to login
                    final navigator = Navigator.of(context);
                    final auth =
                        Provider.of<AuthProvider>(context, listen: false);

                    // show progress dialog
                    showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) =>
                            const Center(child: CircularProgressIndicator()));

                    try {
                      await auth.logout();
                    } catch (e) {
                      // ignore errors but ensure dialog is dismissed
                    }

                    // remove progress
                    navigator.pop();

                    // Navigate to LoginScreen and clear history so user can't go back
                    navigator.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false);
                  },
                  icon: const Icon(Icons.logout, color: Colors.black),
                  label: const Text('Log out',
                      style: TextStyle(color: Colors.black, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmDeleteAccount,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text('Delete account',
                      style: TextStyle(color: Colors.red, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
