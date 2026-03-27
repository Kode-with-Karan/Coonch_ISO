import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/network_avatar.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import 'profile_screen.dart';

class FollowersScreen extends StatefulWidget {
  final String? userId;
  final VoidCallback? onChanged;
  const FollowersScreen({super.key, this.userId, this.onChanged});

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  List<dynamic> _items = [];
  bool _loading = false;
  bool _mutated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFollowers());
  }

  Future<void> _loadFollowers() async {
    setState(() => _loading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      if (widget.userId != null) {
        final list = await api.getFollowersFor(widget.userId!);
        if (mounted) setState(() => _items = list);
        return;
      }
      final res = await api.getFollowers();
      if (res.containsKey('data') && res['data'] is List) {
        if (mounted) setState(() => _items = res['data'] as List<dynamic>);
        return;
      }
    } catch (e) {
      // ignore and fall back to mock
      debugPrint('Failed to load followers: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.userId != null ? 'Followers' : 'My Followers';
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_mutated);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
              onPressed: () => Navigator.of(context).pop(_mutated),
              icon: const Icon(Icons.arrow_back_ios)),
          title: Text(title, style: const TextStyle(color: Colors.black)),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(
                    child: Text(
                      'No followers found.',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 18),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final it = _items[i];
                      // support various shapes: either map with name/avatar or simple map from mock
                      final name =
                          (it is Map && (it['username'] ?? it['name']) != null)
                              ? (it['username'] ?? it['name']).toString()
                              : 'User';
                      // Prefer explicit avatar if provided; otherwise pass null to
                      // NetworkAvatar to render the default. Also send initials.
                      final img =
                          (it is Map && (it['avatar'] ?? it['img']) != null)
                              ? (it['avatar'] ?? it['img']).toString()
                              : null;
                      final initials = name.isNotEmpty ? name[0] : null;

                      return InkWell(
                        onTap: () {
                          String? id;
                          if (it is Map) {
                            id = (it['id'] ?? it['user_id'] ?? it['pk'])
                                ?.toString();
                          }
                          if (id != null) {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ProfileScreen(userId: id)));
                            return;
                          }
                        },
                        child: Row(
                          children: [
                            NetworkAvatar(
                                url: img, radius: 22, initials: initials),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Text(name,
                                    style: const TextStyle(fontSize: 18))),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                String? id;
                                if (it is Map) {
                                  id = (it['id'] ?? it['user_id'] ?? it['pk'])
                                      ?.toString();
                                }
                                if (id == null) return;
                                final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                          title: const Text('Remove follower'),
                                          content: const Text(
                                              'Remove this follower from your account?'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx)
                                                        .pop(false),
                                                child: const Text('Cancel')),
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: const Text('Remove')),
                                          ],
                                        ));
                                if (confirmed != true) return;
                                try {
                                  final api = Provider.of<ApiService>(context,
                                      listen: false);
                                  await api.unfollowUser(id);
                                  if (!mounted) return;
                                  setState(() => _items.removeAt(i));
                                  _mutated = true;
                                  final notif =
                                      Provider.of<NotificationService>(context,
                                          listen: false);
                                  notif.showInfo('Removed follower');
                                  try {
                                    widget.onChanged?.call();
                                  } catch (_) {}
                                } catch (e) {
                                  final notif =
                                      Provider.of<NotificationService>(context,
                                          listen: false);
                                  notif.showError('Failed to remove: $e');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16))),
                              child: const Row(
                                children: [
                                  Icon(Icons.remove_circle,
                                      color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Remove')
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
