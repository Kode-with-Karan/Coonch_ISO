import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum LegalDocumentType { terms, privacy }

class LegalDocuments {
  static const String _termsPath = 'assets/docs/terms_and_conditions.txt';
  static const String _privacyPath = 'assets/docs/privacy_policy.txt';

  static String title(LegalDocumentType type) {
    switch (type) {
      case LegalDocumentType.terms:
        return 'Terms and Conditions';
      case LegalDocumentType.privacy:
        return 'Privacy Policy';
    }
  }

  static String _assetPath(LegalDocumentType type) {
    switch (type) {
      case LegalDocumentType.terms:
        return _termsPath;
      case LegalDocumentType.privacy:
        return _privacyPath;
    }
  }

  static Future<String> load(LegalDocumentType type) async {
    final path = _assetPath(type);
    try {
      final content = await rootBundle.loadString(path);
      if (content.trim().isEmpty) {
        return 'No content available for ${title(type)}.';
      }
      return content;
    } catch (_) {
      return '${title(type)} is not available right now.';
    }
  }
}

Future<void> showLegalDocumentPopup(
  BuildContext context,
  LegalDocumentType type,
) async {
  final documentText = await LegalDocuments.load(type);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(LegalDocuments.title(type)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: SelectableText(
            documentText,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
