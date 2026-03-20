import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/post_options.dart';
import '../../widgets/app_navbar.dart';
import '../../widgets/widgets.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/content_card.dart';
import '../settings/settings_screen.dart';
import '../categories/all_categories.dart';
import '../notifications_screen.dart';
import 'edit_profile_screen.dart';
import 'followers_screen.dart';
import '../playlists/create_playlist_screen.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'following_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login/login_screen.dart';
import '../../widgets/coonch_logo.dart';
import '../../services/notification_service.dart';
import '../categories/series_detail_screen.dart';
import '../categories/series_edit_screen.dart';
import '../../theme.dart';

class ProfileScreen extends StatefulWidget {
  final String name;

  /// Optional user id to view a public profile. If null, shows current user.
  final String? userId;
  const ProfileScreen({super.key, this.name = 'Sara Mathew', this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedFilter = 0;
  List<dynamic> _contents = [];
  bool _loadingContents = false;
  Map<String, dynamic>? _profileUser;
  bool _isFollowing = false;
  bool _isRequested = false;
  bool _isBlockedByMe = false;
  bool _hasBlockedMe = false;
  bool _followProcessing = false;
  int _unreadNotifications = 0;
  static const String _kPendingFollowsKey = 'pending_follow_requests';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadContents());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadProfile());
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadNotificationsCount());
  }

  Future<void> _loadNotificationsCount() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final count = await api.getUnreadNotificationsCount();
      if (mounted) setState(() => _unreadNotifications = count);
    } catch (e) {
      debugPrint('Failed to load notifications count: $e');
    }
  }

  // Local persistence helpers for pending follow requests. We store a list
  // of user ids that this client has requested to follow but which haven't
  // been accepted yet. This keeps the UI showing "Requested" until an
  // explicit accept is observed (for example via notifications).
  // Build a storage key that is namespaced to the currently authenticated
  // user so pending follow requests are stored per-account (not globally).
  Future<String> _pendingKeyForCurrentUser() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.user;
      final ownerId = user != null
          ? (user['id'] ?? user['user_id'] ?? user['pk'])?.toString()
          : null;
      if (ownerId != null && ownerId.isNotEmpty) {
        return '$_kPendingFollowsKey:$ownerId';
      }
    } catch (_) {}
    return _kPendingFollowsKey; // fallback to global key if unauthenticated
  }

  Future<void> _markPendingFollowLocal(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _pendingKeyForCurrentUser();
      final list = prefs.getStringList(key) ?? <String>[];
      if (!list.contains(id)) {
        list.add(id);
        await prefs.setStringList(key, list);
      }
    } catch (e) {
      debugPrint('Failed to mark pending follow locally: $e');
    }
  }

  Future<void> _clearPendingFollowLocal(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _pendingKeyForCurrentUser();
      final list = prefs.getStringList(key) ?? <String>[];
      if (list.contains(id)) {
        list.remove(id);
        await prefs.setStringList(key, list);
      }
      // Also try clearing the global key just in case older entries exist
      final glob = prefs.getStringList(_kPendingFollowsKey) ?? <String>[];
      if (glob.contains(id)) {
        glob.remove(id);
        await prefs.setStringList(_kPendingFollowsKey, glob);
      }
    } catch (e) {
      debugPrint('Failed to clear pending follow locally: $e');
    }
  }

  Future<bool> _isPendingFollowLocal(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _pendingKeyForCurrentUser();
      final list = prefs.getStringList(key) ?? <String>[];
      if (list.contains(id)) return true;
      // fallback to check global key (for older stored entries)
      final glob = prefs.getStringList(_kPendingFollowsKey) ?? <String>[];
      return glob.contains(id);
    } catch (e) {
      return false;
    }
  }

  Future<void> _maybeLoadContents() async {
    // If viewing someone else's profile, load their contents by their id.
    if (widget.userId != null) {
      await _loadContents(widget.userId!);
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    debugPrint('user: $user');
    if (user == null) return;
    final id = user['id'] ?? user['user_id'] ?? user['pk'];

    if (id != null) {
      await _loadContents(id.toString());
    }
  }

  Future<void> _showLinksSheet(List<String> links) async {
    if (links.isEmpty) return;
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    await showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Linked accounts',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close))
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...links.map((link) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.link, color: Colors.lightBlue),
                        title: Text(link,
                            style: const TextStyle(
                                color: Colors.lightBlue,
                                decoration: TextDecoration.underline)),
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: link));
                          notifications.showSuccess('Link copied');
                          Navigator.of(ctx).pop();
                        },
                      ))
                ],
              ),
            ),
          );
        });
  }

  Future<void> _maybeLoadProfile() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (widget.userId != null) {
        // Viewing someone else's profile
        final res = await api.getProfileById(widget.userId!);
        if (mounted) {
          setState(() => _profileUser = res['data'] != null
              ? Map<String, dynamic>.from(res['data'] as Map)
              : Map<String, dynamic>.from(res));
        }
      } else {
        // Current user's profile
        final res = await api.getProfile();
        if (mounted) {
          setState(() => _profileUser = res['data'] != null
              ? Map<String, dynamic>.from(res['data'] as Map)
              : Map<String, dynamic>.from(res));
        }
      }

      // determine following state if profile is for other user
      if (_profileUser != null) {
        final current = auth.user;
        if (current != null && widget.userId != null) {
          _isBlockedByMe = _profileUser!['is_blocked_by_me'] == true;
          _hasBlockedMe = _profileUser!['has_blocked_me'] == true;
          // backend may provide is_following flag
          final isFollowing = _profileUser!['is_following'] ??
              _profileUser!['following'] ??
              false;

          // Derive viewed id from server payload to normalize comparisons.
          final String? viewedIdFromProfile = _profileUser!['id']?.toString();
          final viewedId = viewedIdFromProfile ?? widget.userId;

          // If server reports we are already following, clear any local
          // pending flag and show Following.
          if (isFollowing == true) {
            try {
              if (viewedId != null) _clearPendingFollowLocal(viewedId);
            } catch (_) {}
            try {
              if (widget.userId != null) {
                _clearPendingFollowLocal(widget.userId!);
              }
            } catch (_) {}
            try {
              final pid = _profileUser!['id'];
              if (pid != null) {
                _clearPendingFollowLocal(pid.toString());
              }
            } catch (_) {}
            if (mounted) {
              setState(() {
                _isFollowing = true;
                _isRequested = false;
              });
            }
          } else {
            // No approval flow: ignore requested flags and always show Follow.
            try {
              if (viewedId != null) _clearPendingFollowLocal(viewedId);
            } catch (_) {}
            if (mounted) {
              setState(() {
                _isFollowing = false;
                _isRequested = false;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load profile: $e');
    } finally {
      // finished
    }
  }

  Future<void> _loadContents(String userId) async {
    setState(() => _loadingContents = true);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      // Build query params including user_id and optional type filter
      final Map<String, String> qp = {'user_id': userId};
      final label = ['All', 'Video', 'Audio', 'Text'][_selectedFilter];
      if (label.toLowerCase() != 'all') {
        qp['type'] = label.toLowerCase();
      }
      final list = await api.getContents(queryParams: qp);
      final deduped = _dedupeSeries(list);
      if (mounted) setState(() => _contents = deduped);
    } catch (e) {
      if (mounted) {
        String message = 'Failed to load contents';
        try {
          if (e is ApiException && e.code == 401) {
            message = 'You must be logged in to view contents';
            notifications.showWarning(message);
            return;
          }
        } catch (_) {}

        notifications
            .showError(NotificationService.formatMessage('$message: $e'));
      }
    } finally {
      if (mounted) setState(() => _loadingContents = false);
    }
  }

  // Keep only one entry per series so the profile shows each series once.
  List<dynamic> _dedupeSeries(List<dynamic> items) {
    final seenSeries = <String>{};
    final result = <dynamic>[];
    for (final item in items) {
      if (item is Map && item['series'] is Map) {
        final seriesId =
            (item['series']['id'] ?? item['series']['pk'])?.toString();
        if (seriesId != null && seriesId.isNotEmpty) {
          if (seenSeries.contains(seriesId)) continue;
          seenSeries.add(seriesId);
        }
      }
      result.add(item);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.user ?? {};
    // If viewing own profile prefer the AuthProvider's user so updates
    // (e.g., after editing) are reflected immediately. For other users
    // continue using the cached `_profileUser` when present.
    final user = (widget.userId == null)
        ? (auth.user ?? _profileUser ?? currentUser)
        : (_profileUser ?? currentUser);
    final socialLinks = (user['social_links'] as List?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        <String>[];
    final viewedId = (user['id'] ?? user['user_id'] ?? user['pk'])?.toString();
    final bool isPrivate = user['is_private'] == true;
    final bool viewingOther =
        widget.userId != null && widget.userId != currentUser['id']?.toString();
    final bool showPrivateBlock = viewingOther && isPrivate && !_isFollowing;
    final bool showBlockedByMe = viewingOther && _isBlockedByMe;
    final bool showHasBlockedMe = viewingOther && _hasBlockedMe;
    return Scaffold(
      appBar: AppBar(
        elevation: 0.6,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios),
        ),
        title: const CoonchLogo(
          direction: Axis.horizontal,
          iconDiameter: 44,
          ringStroke: 22, // keep ring thick to match source logo
          textSize: 18,
          fontWeight: FontWeight.w700,
          spacing: 8,
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AllCategoriesScreen())),
            icon: const Icon(Icons.filter_alt_outlined),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () async {
                  // capture before await navigation
                  final navigator = Navigator.of(context);
                  final auth =
                      Provider.of<AuthProvider>(context, listen: false);

                  // Open NotificationsScreen and wait for result
                  final result = await navigator.push(MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()));

                  // After returning, refresh global unread count so the
                  // app-bar badge (in HomeScreen) updates immediately.
                  try {
                    await auth.loadUnreadCount();
                  } catch (_) {}

                  // Also refresh this profile's local unread count display
                  _loadNotificationsCount();

                  // If the notifications screen returned an accepted_user_id
                  // that matches the profile we're viewing, clear the local
                  // pending flag (fire-and-forget). Regardless, re-fetch
                  // the authoritative profile so the UI matches server state.
                  try {
                    final String? acceptedId = (result is Map)
                        ? result['accepted_user_id']?.toString()
                        : null;
                    if (acceptedId != null) {
                      // clear the locally-tracked pending flag
                      _clearPendingFollowLocal(acceptedId);
                    }
                  } catch (_) {}

                  // Always re-fetch the profile to reconcile with server
                  // state (is_following / is_requested). This fixes cases
                  // where id formats differ or when the accept occurred
                  // on another device.
                  _maybeLoadProfile();
                },
                icon: const Icon(Icons.notifications_none),
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Center(
                      child: Text('$_unreadNotifications',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18.0, vertical: 8),
                    child: Row(
                      children: [
                        // Use NetworkAvatar which handles load errors gracefully
                        NetworkAvatar(
                          url: user['avatar'],
                          radius: 40,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  user['username'] ??
                                      user['name'] ??
                                      widget.name,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Row(children: [
                                // const Icon(Icons.location_on_outlined,
                                //     size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(user['bio'] ?? '',
                                    style: const TextStyle(color: Colors.grey))
                                // Text(user['timezone'] ?? '',
                                //     style: const TextStyle(color: Colors.grey))
                              ])
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  if (socialLinks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18.0, vertical: 4),
                      child: InkWell(
                        onTap: () => _showLinksSheet(socialLinks),
                        child: Row(
                          children: [
                            const Icon(Icons.link,
                                size: 18, color: Colors.lightBlue),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                socialLinks.first,
                                style: const TextStyle(
                                    color: Colors.lightBlue,
                                    decoration: TextDecoration.underline),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (socialLinks.length > 1)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                    color: Colors.lightBlue.shade50,
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(
                                  '+${socialLinks.length - 1}',
                                  style:
                                      const TextStyle(color: Colors.lightBlue),
                                ),
                              )
                          ],
                        ),
                      ),
                    ),

                  // stats row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          _statItem((user['contents_count'] ?? '0').toString(),
                              'Posts',
                              onTap: () {}),
                          _verticalDivider(),
                          _statItem(
                              (user['followers_count'] ??
                                      user['followers'] ??
                                      0)
                                  .toString(),
                              'Friends', onTap: () async {
                            if (viewedId != null) {
                              final changed = await Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) {
                                return FollowersScreen(
                                    userId: viewedId,
                                    onChanged: () async {
                                      try {
                                        await _maybeLoadProfile();
                                      } catch (_) {}
                                    });
                              }));
                              if (changed == true) {
                                try {
                                  await _maybeLoadProfile();
                                } catch (_) {}
                              }
                            }
                          }),
                          _verticalDivider(),
                          _statItem(
                              (user['following_count'] ??
                                      user['followings'] ??
                                      0)
                                  .toString(),
                              'Following', onTap: () async {
                            if (viewedId != null) {
                              final changed = await Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) {
                                return FollowingScreen(
                                    userId: viewedId,
                                    onChanged: () async {
                                      try {
                                        await _maybeLoadProfile();
                                      } catch (_) {}
                                    });
                              }));
                              if (changed == true) {
                                try {
                                  await _maybeLoadProfile();
                                } catch (_) {}
                              }
                            }
                          }),
                        ],
                      ),
                    ),
                  ),

                  // action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0),
                    child: Row(
                      children: [
                        // If viewing own profile -> Edit / Create buttons
                        if (widget.userId == null ||
                            widget.userId == currentUser['id']?.toString()) ...[
                          Expanded(
                            flex: 3,
                            child: AccentButton(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const EditProfileScreen())),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit, color: Colors.white),
                                  SizedBox(width: 7),
                                  Text('Edit Profile',
                                      style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const CreatePlaylistScreen())),
                              style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Text('+ Create Play List')),
                            ),
                          ),
                        ] else ...[
                          // Viewing someone else's profile -> Follow / Message / Block
                          Expanded(
                            flex: 3,
                            child: (_isBlockedByMe || _hasBlockedMe)
                                ? OutlinedButton(
                                    onPressed:
                                        _isBlockedByMe ? _confirmUnblock : null,
                                    style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12))),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      child: Text(
                                          _isBlockedByMe
                                              ? 'Blocked (unblock)'
                                              : 'Blocked',
                                          style: TextStyle(
                                              color: _isBlockedByMe
                                                  ? Colors.red
                                                  : Colors.grey)),
                                    ),
                                  )
                                : _isFollowing
                                    ? AccentButton(
                                        onPressed: _followProcessing
                                            ? null
                                            : _toggleFollow,
                                        child: _followProcessing
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.person_off,
                                                      color: Colors.white),
                                                  SizedBox(width: 7),
                                                  Text('Unfollow',
                                                      style: TextStyle(
                                                          color: Colors.white)),
                                                ],
                                              ),
                                      )
                                    : AccentButton(
                                        onPressed: _followProcessing
                                            ? null
                                            : _toggleFollow,
                                        child: _followProcessing
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.person_add,
                                                      color: Colors.white),
                                                  SizedBox(width: 7),
                                                  Text('Follow',
                                                      style: TextStyle(
                                                          color: Colors.white)),
                                                ],
                                              ),
                                      ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: OutlinedButton(
                              onPressed: _hasBlockedMe
                                  ? null
                                  : (_isBlockedByMe
                                      ? _confirmUnblock
                                      : _confirmBlock),
                              style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  child: Text(
                                      _isBlockedByMe
                                          ? 'Unblock user'
                                          : 'Block user',
                                      style: TextStyle(
                                          color: _isBlockedByMe
                                              ? Colors.red
                                              : Colors.black))),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (showBlockedByMe)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18.0, vertical: 12),
                      child: _blockedCard(
                          'You blocked this user. Unblock to interact.'),
                    ),

                  if (showHasBlockedMe)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18.0, vertical: 12),
                      child: _blockedCard(
                          'This user has blocked you. You cannot interact.'),
                    ),

                  // chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: SizedBox(
                      height: 54,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount:
                            const ['All', 'Video', 'Audio', 'Text'].length,
                        itemBuilder: (context, i) {
                          final label = ['All', 'Video', 'Audio', 'Text'][i];
                          final selected = i == _selectedFilter;
                          return Padding(
                            padding:
                                const EdgeInsets.only(left: 12.0, right: 6),
                            child: ChoiceChip(
                              selectedColor: Colors.lightBlue[100],
                              backgroundColor: Colors.grey[100],
                              labelPadding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              label: Text(label,
                                  style: TextStyle(
                                      color: selected
                                          ? Colors.lightBlue
                                          : Colors.black54)),
                              selected: selected,
                              onSelected: (_) {
                                setState(() => _selectedFilter = i);
                                // reload contents for this profile with the new filter
                                final viewedId = (user['id'] ??
                                        user['user_id'] ??
                                        user['pk'])
                                    ?.toString();
                                if (viewedId != null) {
                                  _loadContents(viewedId);
                                }
                              },
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (showPrivateBlock)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18.0, vertical: 12),
                      child: Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lock_outline, color: Colors.orange),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('This account is private',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700)),
                                    SizedBox(height: 6),
                                    Text('Follow to view their posts.',
                                        style:
                                            TextStyle(color: Colors.black54)),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // If viewing own profile and not authenticated, prompt to login.
            // If viewing another user's profile (widget.userId != null), allow
            // showing their profile even when the current client is unauthenticated.
            if (widget.userId == null && auth.user == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text('Please log in to view this profile'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen())),
                          child: const Text('Login')),
                    ],
                  ),
                ),
              )
            else if (showBlockedByMe || showHasBlockedMe)
              const SliverToBoxAdapter(
                child: SizedBox.shrink(),
              )
            else if (showPrivateBlock)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.0),
                  child: SizedBox.shrink(),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (_loadingContents) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator()));
                    }
                    if (_contents.isEmpty) return const SizedBox.shrink();
                    final content =
                        Map<String, dynamic>.from(_contents[i] as Map);

                    // If this content belongs to a series, show a series card once.
                    if (content['series'] is Map) {
                      final series =
                          Map<String, dynamic>.from(content['series'] as Map);
                      final seriesId =
                          (series['id'] ?? series['pk'])?.toString();
                      return _SeriesCard(
                        series: series,
                        canManage: !viewingOther,
                        onOpen: () {
                          final id = (series['id'] ?? series['pk'])?.toString();
                          if (id == null || id.isEmpty) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SeriesDetailScreen(
                                seriesId: id,
                                initialTitle: series['title']?.toString(),
                              ),
                            ),
                          );
                        },
                        onEdit: () {
                          final id = (series['id'] ?? series['pk'])?.toString();
                          if (id == null || id.isEmpty) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SeriesEditScreen(
                                seriesId: id,
                                initialTitle: series['title']?.toString(),
                              ),
                            ),
                          );
                        },
                        onDeleted: () {
                          if (seriesId == null) return;
                          setState(() {
                            _contents.removeWhere((item) {
                              if (item is Map && item['series'] is Map) {
                                final sid = (item['series']['id'] ??
                                        item['series']['pk'])
                                    ?.toString();
                                return sid == seriesId;
                              }
                              return false;
                            });
                          });
                        },
                      );
                    }

                    return ContentCard(
                      content: content,
                      onUpdated: (fresh) {
                        if (!mounted) return;
                        try {
                          if (fresh['deleted'] == true) {
                            setState(() => _contents.removeAt(i));
                          } else {
                            setState(() => _contents[i] = fresh);
                          }
                        } catch (_) {
                          // Fallback: replace item
                          setState(() => _contents[i] = fresh);
                        }
                      },
                    );
                  },
                  childCount: _loadingContents ? 1 : _contents.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: AppFAB(
        onPressed: () => PostOptions.show(
          context, 
          profileName: widget.name,
          onUploadSuccess: () {
            // Refresh content after successful upload
            _maybeLoadContents();
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const AppBottomNavBar(activeIndex: 3),
    );
  }

  Future<void> _toggleFollow() async {
    if (_followProcessing) return;
    final api = Provider.of<ApiService>(context, listen: false);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    final user = _profileUser;
    final viewedId =
        (user?['id'] ?? user?['user_id'] ?? user?['pk'])?.toString();
    if (viewedId == null) return;

    // Prevent re-entrancy and optimistically update UI while request runs.
    setState(() => _followProcessing = true);
    // optimistic
    final prev = _isFollowing;
    final prevCount =
        (user?['followers_count'] ?? user?['followers'] ?? 0) as dynamic;
    setState(() {
      _isFollowing = !_isFollowing;
      if (_profileUser != null) {
        final int cur = (prevCount is int)
            ? prevCount
            : int.tryParse(prevCount?.toString() ?? '0') ?? 0;
        _profileUser!['followers_count'] =
            _isFollowing ? cur + 1 : (cur > 0 ? cur - 1 : 0);
      }
    });

    try {
      if (_isFollowing) {
        await api.followUser(viewedId);
        notifications.showSuccess('Followed');
      } else {
        await api.unfollowUser(viewedId);
        notifications.showInfo('Unfollowed');
      }
      // Re-fetch authoritative profile state and reconcile local UI.
      try {
        await _maybeLoadProfile();
      } catch (_) {}

      // After changing follow state, refresh home stories so the follower
      // stops/starts seeing the target user's stories immediately.
      try {
        final homeState = context.findAncestorStateOfType<State>();
        (homeState as dynamic)?._loadFollowings();
        (homeState as dynamic)?._loadStories();
      } catch (_) {}
    } catch (e) {
      // revert
      if (mounted) {
        setState(() {
          _isFollowing = prev;
          if (_profileUser != null) {
            _profileUser!['followers_count'] = prevCount;
          }
          _followProcessing = false;
        });
      }
      notifications.showError(
          NotificationService.formatMessage('Failed to update follow: $e'));
      return;
    }
    if (mounted) setState(() => _followProcessing = false);
  }

  Future<void> _sendFollowRequest() async {
    // Deprecated path: we now follow immediately without request approval.
    final api = Provider.of<ApiService>(context, listen: false);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    final user = _profileUser;
    final viewedId =
        (user?['id'] ?? user?['user_id'] ?? user?['pk'])?.toString();
    if (viewedId == null) return;

    try {
      await api.followUser(viewedId);
      setState(() {
        _isFollowing = true;
        _isRequested = false;
      });
      await _maybeLoadProfile();
      notifications.showSuccess('Followed');
    } catch (e) {
      notifications
          .showError(NotificationService.formatMessage('Failed to follow: $e'));
    }
  }

  Future<void> _confirmBlock() async {
    final user = _profileUser;
    final viewedId =
        (user?['id'] ?? user?['user_id'] ?? user?['pk'])?.toString();
    if (viewedId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block user?'),
        content: const Text(
            'They will not be able to interact with you and you will unfollow each other.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Block')),
        ],
      ),
    );
    if (confirmed != true) return;

    final api = Provider.of<ApiService>(context, listen: false);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    try {
      await api.blockUser(viewedId);
      if (mounted) {
        setState(() {
          _isBlockedByMe = true;
          _isFollowing = false;
          _isRequested = false;
        });
      }
      notifications.showSuccess('User blocked');
      await _maybeLoadProfile();
    } catch (e) {
      notifications
          .showError(NotificationService.formatMessage('Failed to block: $e'));
    }
  }

  Future<void> _confirmUnblock() async {
    final user = _profileUser;
    final viewedId =
        (user?['id'] ?? user?['user_id'] ?? user?['pk'])?.toString();
    if (viewedId == null) return;

    final api = Provider.of<ApiService>(context, listen: false);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    try {
      await api.unblockUser(viewedId);
      if (mounted) {
        setState(() {
          _isBlockedByMe = false;
        });
      }
      notifications.showSuccess('User unblocked');
      await _maybeLoadProfile();
    } catch (e) {
      notifications.showError(
          NotificationService.formatMessage('Failed to unblock: $e'));
    }
  }

  Widget _blockedCard(String message) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.block, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String value, String label, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() => Container(
        width: 1,
        height: 40,
        color: Colors.grey.shade200,
      );
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({
    required this.series,
    required this.onOpen,
    required this.onEdit,
    required this.onDeleted,
    required this.canManage,
  });

  final Map<String, dynamic> series;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDeleted;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final title = (series['title'] ?? 'Series').toString();
    final description = (series['description'] ?? '').toString();
    final thumb = series['thumbnail_url'] ?? series['thumbnail'];
    final thumbUrl = thumb?.toString();
    final count =
        (series['items'] is List) ? (series['items'] as List).length : null;

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: thumbUrl != null && thumbUrl.isNotEmpty
                    ? Image.network(
                        thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Series',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: 8),
                        Text('$count items',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                      ],
                      const Spacer(),
                      if (canManage)
                        IconButton(
                          onPressed: () => _showActions(context),
                          icon:
                              const Icon(Icons.more_horiz, color: Colors.grey),
                          tooltip: 'More',
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final seriesId = (series['id'] ?? series['pk'])?.toString();
    if (seriesId == null || seriesId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete series?'),
        content: const Text(
            'This will delete the entire series and all of its items.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    final api = Provider.of<ApiService>(context, listen: false);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    try {
      await api.deleteSeries(seriesId);
      notifications.showSuccess('Series deleted');
      onDeleted();
    } catch (e) {
      final msg = e is ApiException
          ? 'Delete failed (${e.code}): ${e.body}'
          : 'Delete failed: ${e.toString()}';
      notifications.showError(NotificationService.formatMessage(msg));
    }
  }

  Future<void> _showActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.of(c).pop();
              onEdit();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.of(c).pop();
              _confirmDelete(context);
            },
          ),
        ]),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Icon(Icons.collections_bookmark,
          color: AppTheme.primaryDark.withOpacity(0.7), size: 32),
    );
  }
}
