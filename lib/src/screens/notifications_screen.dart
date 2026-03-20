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

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
        title: const Text('Notification',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No notifications'))
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  separatorBuilder: (_, __) => const Divider(),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final n = _items[i] as Map<dynamic, dynamic>;
                    final actor = n['actor'];
                    final String title = n['title']?.toString() ??
                        n['message']?.toString() ??
                        '';
                    final String when = n['created_at']?.toString() ??
                        n['timestamp']?.toString() ??
                        '';
                    String? avatar;
                    if (actor is Map) {
                      avatar =
                          (actor['avatar'] ?? actor['avatar_url'])?.toString();
                    }

                    // optional endpoints provided by backend in notification payload
                    final String? acceptEp = n['accept_endpoint']?.toString() ??
                        n['accept_url']?.toString();
                    final String? rejectEp = n['reject_endpoint']?.toString() ??
                        n['reject_url']?.toString();

                    // Try to get actor id for navigation
                    String? actorId;
                    if (actor is Map) {
                      actorId = (actor['id'] ?? actor['user_id'] ?? actor['pk'])
                          ?.toString();
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (avatar != null && avatar.isNotEmpty)
                            GestureDetector(
                                onTap: () {
                                  if (actorId != null) {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => ProfileScreen(
                                                userId: actorId)));
                                  }
                                },
                                child: NetworkAvatar(url: avatar, radius: 22))
                          else
                            CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.blue[50],
                                child: const Icon(Icons.notifications_none,
                                    color: Colors.lightBlue)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (actorId != null) {
                                      Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) => ProfileScreen(
                                                  userId: actorId)));
                                    }
                                  },
                                  child: GestureDetector(
                                    onTap: () async {
                                      // Mark this notification read (if it's a Notification row)
                                      try {
                                        final api = Provider.of<ApiService>(
                                            context,
                                            listen: false);
                                        final idStr = n['id']?.toString() ?? '';
                                        final hasActionsLocal =
                                            (n['accept_endpoint'] != null ||
                                                n['reject_endpoint'] != null);
                                        if (idStr.startsWith('notif-') &&
                                            !hasActionsLocal) {
                                          await api.markNotificationsRead(
                                              ids: [idStr]);
                                          // locally mark as read to avoid re-calling
                                          if (mounted) {
                                            setState(() {
                                              n['read'] = true;
                                            });
                                          }
                                        }
                                      } catch (_) {}
                                      if (actorId != null) {
                                        Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) => ProfileScreen(
                                                    userId: actorId)));
                                      }
                                    },
                                    child: Text(title,
                                        style: const TextStyle(fontSize: 15)),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(when,
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 12)),
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
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.lightBlue[100],
                                              foregroundColor: Colors.black,
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
                    );
                  },
                ),
    );
  }
}
