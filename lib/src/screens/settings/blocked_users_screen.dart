import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/network_avatar.dart';
import '../profile/profile_screen.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<dynamic> _blocked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      _blocked = await api.getBlockedUsers();
    } catch (e) {
      debugPrint('Failed to load blocked users: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(String userId, String userName) async {
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text('Unblock $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.unblockUser(userId);
      Navigator.of(context).pop();
      if (mounted) {
        setState(() {
          _blocked.removeWhere(
            (u) => (u['id'] ?? u['user_id'] ?? u['pk'])?.toString() == userId,
          );
        });
        notifications.showSuccess('User unblocked');
      }
    } catch (e) {
      Navigator.of(context).pop();
      notifications.showError('Failed to unblock: ${NotificationService.formatMessage(e)}');
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
        title: const Text('Blocked Users',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blocked.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No blocked users',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: _blocked.length,
                    itemBuilder: (context, i) {
                      final u = _blocked[i] as Map<String, dynamic>;
                      final id = (u['id'] ?? u['user_id'] ?? u['pk'])?.toString();
                      final name = (u['username'] ?? u['name'] ?? 'User').toString();
                      final avatar = (u['avatar'] ?? u['avatar_url'])?.toString();
                      return ListTile(
                        leading: NetworkAvatar(url: avatar ?? '', radius: 20),
                        title: Text(name),
                        trailing: TextButton(
                          onPressed: () => _unblock(id ?? '', name),
                          child: const Text('Unblock'),
                        ),
                        onTap: () {
                          if (id != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(userId: id),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }
}