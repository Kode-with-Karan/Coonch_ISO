import 'package:flutter/material.dart';

/// Centralized theme values used by the app and shared widgets.
/// Keep this file minimal — it provides color constants that widgets can
/// reference without changing visual behavior.
class AppTheme {
  // Primary accent used across the app (matches light blue in provided mocks)
  static const Color primary = Color(0xFF7DB7FF);

  // Darker blue accent for text/icons when contrast is needed
  static const Color primaryDark = Color(0xFF3E8CEB);

  // Soft blue fill for chips, backgrounds, and selection states
  static const Color primarySoft = Color(0xFFE6F1FF);

  // Muted mid-tone blue for borders/hover-ish states
  static const Color primaryMuted = Color(0xFFAACCFD);

  // Pale background used for small avatar circles
  static const Color avatarBackground = Color(0xFFF0F7FF);

  // Card background (usually white)
  static const Color cardBackground = Colors.white;

  // App scaffold background (approximation of Colors.grey[50])
  static const Color scaffoldBackground = Color(0xFFFAFBFC);
}
