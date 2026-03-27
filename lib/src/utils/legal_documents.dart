import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

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
    final remote = await _loadFromBackend(type);
    if (remote != null && remote.trim().isNotEmpty) {
      return _normalizeDocumentText(remote);
    }

    final path = _assetPath(type);
    try {
      final content = await rootBundle.loadString(path);
      if (content.trim().isEmpty) {
        return 'No content available for ${title(type)}.';
      }
      return _normalizeDocumentText(content);
    } catch (_) {
      return '${title(type)} is not available right now.';
    }
  }

  static String _typeParam(LegalDocumentType type) {
    switch (type) {
      case LegalDocumentType.terms:
        return 'terms';
      case LegalDocumentType.privacy:
        return 'privacy';
    }
  }

  static Future<String?> _loadFromBackend(LegalDocumentType type) async {
    final base = Config.baseApiUrl.endsWith('/')
        ? Config.baseApiUrl
        : '${Config.baseApiUrl}/';
    final uri = Uri.parse(
        '${base}api/v1/user/legal-document/?type=${_typeParam(type)}');

    try {
      final res = await http.get(uri, headers: const {
        'Accept': 'application/json',
      });

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }

      final body = res.body;
      if (body.trim().isEmpty) return null;

      final decoded = _tryDecodeJson(body);
      if (decoded == null) return null;

      final data = decoded['data'];
      if (data is! Map) return null;
      final content = data['content']?.toString() ?? '';
      return content;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _tryDecodeJson(String source) {
    try {
      final dynamic decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _normalizeDocumentText(String source) {
    var text = source;

    // Attempt to recover common UTF-8/Latin1 mojibake.
    try {
      final repaired = utf8.decode(latin1.encode(text), allowMalformed: true);
      if (repaired.contains('"') ||
          repaired.contains('’') ||
          repaired.contains('“')) {
        text = repaired;
      }
    } catch (_) {}

    // Replace frequently seen broken quote/dash symbols with clean variants.
    const replacements = <String, String>{
      'â€œ': '"',
      'â€': '"',
      'â€˜': "'",
      'â€™': "'",
      'â€“': '-',
      'â€”': '-',
      'Â': '',
      'Ã¢â‚¬Å“': '"',
      'Ã¢â‚¬': '"',
      'Ã¢â‚¬Ëœ': "'",
      'Ã¢â‚¬â„¢': "'",
    };

    replacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });

    return text;
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
