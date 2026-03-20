import 'package:flutter/material.dart';

enum NotificationType { success, error, info, warning }

class NotificationMessage {
  final String message;
  final NotificationType type;
  final Duration duration;

  NotificationMessage({
    required this.message,
    required this.type,
    this.duration = const Duration(seconds: 6),
  });
}

class NotificationService extends ChangeNotifier {
  NotificationMessage? _currentNotification;
  late BuildContext _context;

  NotificationMessage? get currentNotification => _currentNotification;
  bool get hasNotification => _currentNotification != null;

  void setContext(BuildContext context) {
    _context = context;
  }

  void show(
    String message, {
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 6),
  }) {
    _currentNotification = NotificationMessage(
      message: message,
      type: type,
      duration: duration,
    );
    notifyListeners();

    // Auto-dismiss after duration
    Future.delayed(duration, () {
      if (_currentNotification?.message == message) {
        _currentNotification = null;
        notifyListeners();
      }
    });
  }

  void showSuccess(String message,
      {Duration duration = const Duration(seconds: 6)}) {
    show(message, type: NotificationType.success, duration: duration);
  }

  void showError(String message,
      {Duration duration = const Duration(seconds: 6)}) {
    show(message, type: NotificationType.error, duration: duration);
  }

  void showInfo(String message,
      {Duration duration = const Duration(seconds: 6)}) {
    show(message, type: NotificationType.info, duration: duration);
  }

  void showWarning(String message,
      {Duration duration = const Duration(seconds: 6)}) {
    show(message, type: NotificationType.warning, duration: duration);
  }

  void dismiss() {
    _currentNotification = null;
    notifyListeners();
  }

  /// Formats heterogeneous error/info payloads (strings, maps, lists) into a
  /// concise, human-friendly string suitable for a toast.
  static String formatMessage(
    dynamic msg, {
    int maxEntries = 3,
    int maxItemsPerEntry = 2,
  }) {
    if (msg == null) return 'Unexpected error. Please try again.';
    if (msg is String) return _cleanValue(msg);

    if (msg is Map) {
      final entries = msg.entries.take(maxEntries).map((entry) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is List || value is Iterable) {
          final values = (value as Iterable)
              .take(maxItemsPerEntry)
              .map((v) => _cleanValue(v.toString()))
              .join(', ');
          return '$key: $values';
        }
        return '$key: ${_cleanValue(value.toString())}';
      }).toList();
      if (entries.isNotEmpty) return entries.join('\n');
    }

    if (msg is Iterable) {
      final items =
          msg.take(maxEntries).map((e) => _cleanValue(e.toString())).toList();
      if (items.isNotEmpty) return items.join('\n');
    }

    return _cleanValue(msg.toString());
  }

  static String _cleanValue(String text) {
    // Strip common Django/DRF ErrorDetail wrappers: ErrorDetail(string='msg', code='err')
    final errorDetailMatch =
        RegExp(r"ErrorDetail\(string='([^']+)'[,)]").firstMatch(text);
    if (errorDetailMatch != null) {
      return errorDetailMatch.group(1) ?? text;
    }

    // Remove surrounding braces/quotes noise
    final cleaned =
        text.replaceAll('{', '').replaceAll('}', '').replaceAll('"', '').trim();

    return cleaned.isEmpty ? text : cleaned;
  }
}
