import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme.dart';

class MonetizationScreen extends StatelessWidget {
  const MonetizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Monetization'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.6,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monetization Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Enable monetization to earn from your content.'),
            const SizedBox(height: 18),
            // Card for monetization toggle
            CardContainer(
              padding: const EdgeInsets.all(8),
              child: SwitchListTile(
                title: const Text('Enable monetization'),
                value: false,
                onChanged: (_) {},
                secondary:
                    const AvatarIcon(icon: Icons.monetization_on_outlined),
                activeThumbColor: AppTheme.primary,
              ),
            ),

            const SizedBox(height: 12),

            // Payout & Earnings
            CardContainer(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  SettingsTile(
                    icon: Icons.payment_outlined,
                    title: 'Payout settings',
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  SettingsTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Earnings history',
                    onTap: () {},
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
