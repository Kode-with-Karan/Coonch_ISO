import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/legal_documents.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const String supportEmail = 'info@coonch.com';

  Future<void> _copySupportEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Support email copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Help & Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDCEBFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Need help?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'For support or account-related issues, contact our team at:',
                    style: TextStyle(color: Colors.black87, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  const SelectableText(
                    supportEmail,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.lightBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _copySupportEmail(context),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy support email'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Legal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms and Conditions'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showLegalDocumentPopup(
                      context,
                      LegalDocumentType.terms,
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showLegalDocumentPopup(
                      context,
                      LegalDocumentType.privacy,
                    ),
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
