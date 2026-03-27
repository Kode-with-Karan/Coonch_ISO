import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class NotificationRealtimeListener extends StatefulWidget {
  final Widget child;

  const NotificationRealtimeListener({
    super.key,
    required this.child,
  });

  @override
  State<NotificationRealtimeListener> createState() =>
      _NotificationRealtimeListenerState();
}

class _NotificationRealtimeListenerState
    extends State<NotificationRealtimeListener> with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 20);

  Timer? _timer;
  bool _isSyncing = false;
  bool _sessionInitialized = false;
  bool _wasAuthenticated = false;
  final Set<String> _knownNotificationKeys = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_pollInterval, (_) => _sync(showPopup: true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sync(showPopup: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync(showPopup: true);
    }
    super.didChangeAppLifecycleState(state);
  }

  String _keyForNotification(Map<dynamic, dynamic> item) {
    final explicitId = item['id']?.toString().trim();
    if (explicitId != null && explicitId.isNotEmpty) return explicitId;

    final title =
        (item['title'] ?? item['message'] ?? item['verb'] ?? '').toString();
    final when = (item['created_at'] ?? item['timestamp'] ?? '').toString();
    final actor = item['actor'];
    final actorId = actor is Map
        ? (actor['id'] ?? actor['user_id'] ?? actor['pk'] ?? '').toString()
        : '';
    return '$title|$when|$actorId';
  }

  bool _isUnread(Map<dynamic, dynamic> item) {
    final read = item['read'];
    if (read is bool) return !read;
    if (read is num) return read == 0;

    // Follow requests can be actionable even without explicit read flags.
    final hasActions =
        (item['accept_endpoint'] != null || item['reject_endpoint'] != null);
    return hasActions;
  }

  String _popupTextFor(Map<dynamic, dynamic> item) {
    final title = (item['title'] ?? item['message'] ?? '').toString().trim();
    if (title.isNotEmpty) return title;
    return 'You have a new notification';
  }

  Future<void> _sync({required bool showPopup}) async {
    if (!mounted || _isSyncing) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      _sessionInitialized = false;
      _knownNotificationKeys.clear();
    }
    if (!auth.isAuthenticated && _wasAuthenticated) {
      _wasAuthenticated = false;
      _sessionInitialized = false;
      _knownNotificationKeys.clear();
      auth.setUnreadCount(0);
    }
    if (!auth.isAuthenticated) return;

    final api = Provider.of<ApiService>(context, listen: false);
    final overlays = Provider.of<NotificationService>(context, listen: false);

    _isSyncing = true;
    try {
      final list = await api.getNotifications();
      if (!mounted) return;

      final unread = list.where((e) {
        if (e is! Map) return false;
        return _isUnread(e);
      }).toList();
      auth.setUnreadCount(unread.length);

      if (!_sessionInitialized) {
        for (final raw in list) {
          if (raw is! Map) continue;
          _knownNotificationKeys.add(_keyForNotification(raw));
        }
        _sessionInitialized = true;
        return;
      }

      if (showPopup) {
        for (final raw in unread) {
          if (raw is! Map) continue;
          final key = _keyForNotification(raw);
          if (_knownNotificationKeys.contains(key)) continue;
          overlays.showInfo(_popupTextFor(raw));
          break;
        }
      }

      for (final raw in list) {
        if (raw is! Map) continue;
        _knownNotificationKeys.add(_keyForNotification(raw));
      }
    } catch (_) {
      // Keep polling; transient notification sync failures should be silent.
    } finally {
      _isSyncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
