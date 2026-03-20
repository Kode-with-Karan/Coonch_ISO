import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/content_access.dart';
import '../screens/settings/subscription_screen.dart';

/// Shows a modal dialog prompting the user to subscribe to unlock content.
///
/// Returns `true` if the user chose to navigate to the subscription screen,
/// `false` if they dismissed the dialog.
Future<bool> showSubscriptionRequiredDialog(
  BuildContext context, {
  Map<String, dynamic>? content,
  String? customTitle,
  String? customMessage,
}) async {
  final title =
      customTitle ?? '${requiredPlanTopicLabel(content)} Content Locked';
  final message = customMessage ?? contentAccessMessage(content);
  final actionLabel = lockedActionLabel(content);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _SubscriptionRequiredDialog(
      title: title,
      message: message,
      actionLabel: actionLabel,
    ),
  );

  if (result == true && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
    return true;
  }

  return false;
}

class _SubscriptionRequiredDialog extends StatelessWidget {
  const _SubscriptionRequiredDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  final String title;
  final String message;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Subscribe button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
