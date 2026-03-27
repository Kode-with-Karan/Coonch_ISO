import 'package:flutter/material.dart';
import 'avatar_icon.dart';

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const SettingsTile(
      {super.key, required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: AvatarIcon(icon: icon, radius: 20),
      title: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Text(title,
            style: const TextStyle(fontSize: 16, color: Colors.black87)),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
