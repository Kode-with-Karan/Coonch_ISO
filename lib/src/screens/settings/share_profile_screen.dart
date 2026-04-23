import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/widgets.dart';
import '../../theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../config.dart';

class ShareProfileScreen extends StatelessWidget {
  const ShareProfileScreen({super.key});

  String _buildProfileLink(Map<String, dynamic>? user) {
    final username = user?['username']?.toString();
    if (username != null && username.isNotEmpty) {
      return 'coonch://profile/$username';
    }
    final id = user?['id'] ?? user?['user_id'] ?? user?['pk'];
    return 'coonch://profile/${id ?? ''}';
  }

  String _buildWebProfileLink(Map<String, dynamic>? user) {
    final username = user?['username']?.toString();
    const base = Config.baseUrl;
    if (username != null && username.isNotEmpty) {
      return '$base/u/$username';
    }
    final id = user?['id'] ?? user?['user_id'] ?? user?['pk'];
    return '$base/profile/$id';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user ?? {};
    final link = _buildProfileLink(user);
    final webLink = _buildWebProfileLink(user);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Share Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.6,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Share your profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
                'Share a link to your profile or copy QR code to let others follow you.'),
            const SizedBox(height: 18),

            CardContainer(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('App link',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      link,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Share link (open in browser)',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    webLink,
                    style: const TextStyle(fontSize: 13, color: Colors.blue),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Buttons in a white card
            CardContainer(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  AccentButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: webLink));
                        notifications.showSuccess('Profile link copied');
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.copy),
                          SizedBox(width: 8),
                          Text('Copy profile link')
                        ],
                      )),
                  const SizedBox(height: 12),
                  AccentButton(
                      onPressed: () async {
                        await SharePlus.instance.share(
                          ShareParams(text: 'Check out my profile on Coonch: $webLink'),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share),
                          SizedBox(width: 8),
                          Text('Share profile')
                        ],
                      )),
                ],
              ),
            ),

            const SizedBox(height: 18),
            Center(
              child: Container(
                width: 180,
                height: 180,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: QrImageView(
                  data: webLink,
                  version: QrVersions.auto,
                  size: 164,
                  gapless: true,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                  embeddedImageStyle:
                      const QrEmbeddedImageStyle(size: Size(32, 32)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
