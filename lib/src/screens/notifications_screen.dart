import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/network_avatar.dart';
import '../services/api_service.dart';
import 'profile/profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  static const Duration _refreshInterval = Duration(seconds: 15);

  bool _loading = true;
  List<dynamic> _items = [];
  Timer? _timer;
  int _selectedTab = 0;

  List<dynamic> get _filteredItems {
    if (_selectedTab == 1) {
      return _items.where((n) => n['read'] != true).toList();
    } else if (_selectedTab == 2) {
      return _items.where((n) => n['read'] == true).toList();
    }
    return _items;
  }

  int get _unreadCount => _items.where((n) => n['read'] != true).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _timer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) _load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _load();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.getNotifications();
      if (mounted) setState(() => _items = list);
      // Mark non-follow-request Notification rows as read when user opens
      // the notifications screen. We keep follow-request notifications
      // unread so Accept/Reject buttons remain available until the user acts.
      try {
        final idsToMark = <String>[];
        for (final n in _items) {
          try {
            final id = n['id']?.toString() ?? '';
            final hasActions =
                (n['accept_endpoint'] != null || n['reject_endpoint'] != null);
            // mark read only if it's a Notification row and it has no action endpoints
            if (id.startsWith('notif-') && !hasActions) idsToMark.add(id);
          } catch (_) {}
        }

        if (idsToMark.isNotEmpty) {
          await api.markNotificationsRead(ids: idsToMark);
          // locally mark those items as read to keep UI consistent
          if (mounted) {
            setState(() {
              for (final n in _items) {
                try {
                  final id = n['id']?.toString() ?? '';
                  if (idsToMark.contains(id)) n['read'] = true;
                } catch (_) {}
              }
            });
          }
        }

        // Refresh provider unread count from server so follow-request unread
        // notifications are still counted correctly.
        try {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.loadUnreadCount();
        } catch (_) {}
      } catch (_) {}
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load notifications: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _performAction(String endpoint,
      {String? actorId, bool isAccept = false}) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.postJson(endpoint, {});
      // If server returned accepted_user_id prefer that for accuracy.
      String? acceptedId;
      try {
        if (res['data'] is Map && res['data']['accepted_user_id'] != null) {
          acceptedId = res['data']['accepted_user_id']?.toString();
        } else if (res['accepted_user_id'] != null) {
          acceptedId = res['accepted_user_id']?.toString();
        }
      } catch (_) {}

      // Update local notification items that reference this endpoint so the
      // Accept/Reject buttons disappear immediately.
      try {
        if (mounted) {
          setState(() {
            for (final n in _items) {
              try {
                final aep = n['accept_endpoint']?.toString();
                final rep = n['reject_endpoint']?.toString();
                if (aep == endpoint || rep == endpoint) {
                  n['read'] = true;
                  n.remove('accept_endpoint');
                  n.remove('reject_endpoint');
                }
              } catch (_) {}
            }
          });
        }

        // If this was an accept action and we have an accepted id, return it to caller
        if (isAccept && (acceptedId != null || actorId != null)) {
          final String returned = acceptedId ?? actorId!;
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Accepted')));
            Navigator.of(context).pop({'accepted_user_id': returned});
          }
          return;
        }

        // Otherwise reload non-actionable notifications and refresh count.
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Action completed')));
        }
      } catch (e) {
        // fall back to reload if anything goes wrong
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Action completed')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    }
  }

  Future<void> _toggleRead(String id, bool currentlyRead) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      if (currentlyRead) {
        await api.markNotificationsUnread(ids: [id]);
      } else {
        await api.markNotificationsRead(ids: [id]);
      }
      if (mounted) {
        setState(() {
          for (final n in _items) {
            if (n['id']?.toString() == id) {
              n['read'] = !currentlyRead;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final api = Provider.of<ApiService>(context, listen: false);
        await api.clearAllNotifications();
        if (mounted) {
          setState(() => _items.clear());
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('All notifications cleared')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to clear: $e')));
        }
      }
    }
  }

  String _formatTimestamp(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      final local = parsed.toLocal();
      final localizations = MaterialLocalizations.of(context);
      final date = localizations.formatMediumDate(local);
      final time = localizations.formatTimeOfDay(
        TimeOfDay.fromDateTime(local),
        alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
      );
      return '$date  $time';
    }

    // Fall back to improving common ISO-like strings when parsing fails.
    return value.replaceAll('T', '  ').replaceFirst(RegExp(r'(\.\d+)?Z$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearAll,
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTab('All', 0),
                _buildTab('Unread', 1),
                _buildTab('Read', 2),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                    ? Center(
                        child: Text(
                          _selectedTab == 0
                              ? 'No notifications'
                              : (_selectedTab == 1
                                  ? 'No unread notifications'
                                  : 'No read notifications'),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        separatorBuilder: (_, __) => const Divider(),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, i) {
                          final n =
                              _filteredItems[i] as Map<dynamic, dynamic>;
                          final actor = n['actor'];
                          final String title = n['title']?.toString() ??
                              n['message']?.toString() ??
                              '';
                          final String when = n['created_at']?.toString() ??
                              n['timestamp']?.toString() ??
                              '';
                          final String formattedWhen = _formatTimestamp(when);
                          String? avatar;
                          if (actor is Map) {
                            avatar = (actor['avatar'] ?? actor['avatar_url'])
                                ?.toString();
                          }

                          final String? acceptEp =
                              n['accept_endpoint']?.toString() ??
                                  n['accept_url']?.toString();
                          final String? rejectEp =
                              n['reject_endpoint']?.toString() ??
                                  n['reject_url']?.toString();

                          String? actorId;
                          if (actor is Map) {
                            actorId = (actor['id'] ?? actor['user_id'] ?? actor['pk'])
                                ?.toString();
                          }

                          final String notificationId = n['id']?.toString() ?? '';
                          final bool isRead = n['read'] == true;

                          return Dismissible(
                            key: Key(notificationId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(Icons.delete,
                                  color: Colors.white),
                            ),
                            onDismissed: (_) => _clearItem(notificationId),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (avatar != null && avatar.isNotEmpty)
                                    GestureDetector(
                                        onTap: () {
                                          if (actorId != null) {
                                            Navigator.of(context).push(
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        ProfileScreen(
                                                            userId: actorId)));
                                          }
                                        },
                                        child: NetworkAvatar(
                                            url: avatar, radius: 22))
                                  else
                                    CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.blue[50],
                                        child: const Icon(
                                            Icons.notifications_none,
                                            color: Colors.lightBlue)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () {
                                                  if (actorId != null) {
                                                    Navigator.of(context).push(
                                                        MaterialPageRoute(
                                                            builder: (_) =>
                                                                ProfileScreen(
                                                                    userId:
                                                                        actorId)));
                                                  }
                                                },
                                                child: Text(title,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: isRead
                                                          ? FontWeight.normal
                                                          : FontWeight.w600,
                                                    )),
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                isRead
                                                    ? Icons.mark_email_unread
                                                    : Icons.mark_email_read,
                                                size: 20,
                                                color: Colors.grey[600],
                                              ),
                                              onPressed: () => _toggleRead(
                                                  notificationId, isRead),
                                              tooltip: isRead
                                                  ? 'Mark as unread'
                                                  : 'Mark as read',
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(formattedWhen,
                                            style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 12)),
                                        const SizedBox(height: 8),
                                        if (acceptEp != null || rejectEp != null)
                                          Row(
                                            children: [
                                              if (acceptEp != null)
                                                ElevatedButton(
                                                  onPressed: () => _performAction(
                                                      acceptEp,
                                                      actorId: actorId,
                                                      isAccept: true),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.lightBlue[
                                                                  100],
                                                          foregroundColor:
                                                              Colors.black,
                                                          elevation: 0),
                                                  child: const Text('Accept'),
                                                ),
                                              const SizedBox(width: 8),
                                              if (rejectEp != null)
                                                OutlinedButton(
                                                  onPressed: () => _performAction(
                                                      rejectEp,
                                                      actorId: actorId,
                                                      isAccept: false),
                                                  child: const Text('Reject'),
                                                ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    final count = index == 0
        ? _items.length
        : (index == 1 ? _unreadCount : (_items.length - _unreadCount));
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.lightBlue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.grey,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (count > 0)
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.lightBlue : Colors.grey[400],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearItem(String id) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.clearAllNotifications();
      if (mounted) {
        setState(() {
          _items.removeWhere((n) => n['id']?.toString() == id);
        });
      }
    } catch (_) {}
  }
}
