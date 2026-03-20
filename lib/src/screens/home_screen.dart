import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/app_navbar.dart';
import '../widgets/network_avatar.dart';
import '../widgets/content_card.dart';
import '../services/api_service.dart';
import 'settings/settings_screen.dart';
import 'settings/help_support_screen.dart';
import 'profile/view_profile_screen.dart';
import 'profile/profile_screen.dart';
import 'notifications_screen.dart';
import 'categories/education_screen.dart';
import '../providers/auth_provider.dart';
import 'stories/story_viewer.dart';
import 'stories/create_story_screen.dart';
import '../widgets/coonch_logo.dart';
import '../widgets/ios_sidebar.dart';
import 'login/login_screen.dart';

const _logoDefaultFill = Color.fromRGBO(169, 203, 245, 0.85);
const _logoDefaultRing = Color.fromRGBO(154, 188, 247, 0.88);
const _logoEducationFill = Color(0xFFB2DFDB);
const _logoEducationRing = Color(0xFF26A69A);
const _logoEntertainmentFill = Color(0xFFBBDEFB); // Light blue
const _logoEntertainmentRing = Color(0xFF1976D2); // Darker blue

/// Home screen with feeds and stories strip.
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedFilter = 0;
  String? _selectedTopic; // null == All topics
  List<dynamic> _contents = [];
  List<dynamic> _stories = [];
  bool _initialized = false;
  bool _loadingContents = false;
  bool _loadingStories = false;
  List<dynamic> _followings = [];
  // unread count moved to AuthProvider

  final List<String> _filters = ['All', 'Video', 'Audio', 'Text'];

  // Sidebar controller
  bool _sidebarOpen = false;
  late final AnimationController _sidebarCtrl;

  /// Insert a newly created story at the front (optimistic UI).
  void insertStory(Map<String, dynamic> story) {
    setState(() => _stories.insert(0, story));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadContents();
      _loadFollowings();
      _loadStories();
      // Load unread count into AuthProvider so badge updates globally
      final auth = Provider.of<AuthProvider>(context, listen: false);
      auth.loadUnreadCount();
    }
  }

  @override
  void initState() {
    super.initState();
    _sidebarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    super.dispose();
  }

  // unread count is managed by AuthProvider; no local loader required

  String? _extractUserId(dynamic userOrMap) {
    try {
      if (userOrMap == null) return null;
      if (userOrMap is Map) {
        final id = userOrMap['id'] ?? userOrMap['user_id'] ?? userOrMap['pk'];
        return id?.toString();
      }
      return userOrMap.toString();
    } catch (_) {
      return null;
    }
  }

  bool _topicMatches(dynamic item, List<String> allowedTopics) {
    try {
      if (item is Map) {
        final dynamic t = item['topic'];
        if (t is String) {
          final lower = t.toLowerCase();
          return allowedTopics.any((allowed) => lower == allowed.toLowerCase());
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  String _userDisplayName(dynamic user) {
    try {
      if (user is Map) {
        final map = user;
        final dynamic name = map['name'] ?? map['username'] ?? map['full_name'];
        if (name != null && name.toString().trim().isNotEmpty) {
          return name.toString();
        }
        final dynamic email = map['email'];
        if (email != null && email.toString().trim().isNotEmpty) {
          return email.toString();
        }
      }
    } catch (_) {
      // ignore and fallback
    }
    return 'Sara Mathew';
  }

  String? _userAvatar(dynamic user) {
    try {
      if (user is Map) {
        final map = user;
        final dynamic av = map['avatar'] ?? map['avatar_url'];
        if (av != null && av.toString().trim().isNotEmpty) {
          return av.toString();
        }
      }
    } catch (_) {
      // ignore and fallback to null
    }
    return null;
  }

  bool get _educationActive {
    final topic = _selectedTopic?.toLowerCase();
    return topic == 'education';
  }

  bool get _entertainmentActive {
    final topic = _selectedTopic?.toLowerCase();
    return topic == 'entertainment' || topic == 'infotainment';
  }

  Color get _logoFillColor {
    if (_educationActive) return _logoEducationFill;
    if (_entertainmentActive) return _logoEntertainmentFill;
    return _logoDefaultFill;
  }

  Color get _logoRingColor {
    if (_educationActive) return _logoEducationRing;
    if (_entertainmentActive) return _logoEntertainmentRing;
    return _logoDefaultRing;
  }

  Future<void> _loadStories() async {
    setState(() => _loadingStories = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.user;
      final myId = _extractUserId(user);
      // Ensure we have the followings list available before filtering stories.
      // _followings may be empty if it hasn't loaded yet; fetch it now
      // when we have an authenticated user.
      if ((myId != null) && _followings.isEmpty) {
        try {
          final listFollow = await api.getFollowingsFor(myId);
          if (mounted) setState(() => _followings = listFollow);
        } catch (_) {
          // ignore followings fetch errors and continue; we'll still include
          // the current user's stories.
        }
      }

      final list = await api.getStories();
      if (!mounted) return;

      final allowed = <String>{};
      for (final f in _followings) {
        final id = _extractUserId(f);
        if (id != null) allowed.add(id);
      }
      if (myId != null) allowed.add(myId);

      final filtered = <dynamic>[];
      for (final s in list) {
        final uid = _extractUserId((s is Map) ? s['user'] : s);
        if (uid == null) continue;
        // Only include stories from users we follow or ourselves.
        if (allowed.contains(uid)) filtered.add(s);
      }

      final ownerFirst = <dynamic>[];
      final others = <dynamic>[];
      for (final s in filtered) {
        final uid = _extractUserId((s is Map) ? s['user'] : s);
        if (uid != null && uid == myId) {
          ownerFirst.add(s);
        } else {
          others.add(s);
        }
      }

      if (mounted) setState(() => _stories = [...ownerFirst, ...others]);
    } catch (e) {
      debugPrint('Failed to load stories: $e');
    } finally {
      if (mounted) setState(() => _loadingStories = false);
    }
  }

  Future<void> _loadFollowings() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final api = Provider.of<ApiService>(context, listen: false);
      final user = auth.user;
      if (user == null) return;
      final id = _extractUserId(user);
      if (id == null) return;
      final list = await api.getFollowingsFor(id);
      if (!mounted) return;
      setState(() => _followings = list);
    } catch (e) {
      debugPrint('Failed to load followings: $e');
    }
  }

  Future<void> _loadContents() async {
    setState(() => _loadingContents = true);
    final api = Provider.of<ApiService>(context, listen: false);
    // capture messenger before any async gaps to avoid using BuildContext
    final messenger = ScaffoldMessenger.of(context);
    try {
      Map<String, String>? queryParams;
      final filter = _filters[_selectedFilter];
      if (filter.toLowerCase() != 'all') {
        queryParams = {'type': filter.toLowerCase()};
      }
      final manualTopic = _selectedTopic != null && _selectedTopic!.isNotEmpty
          ? _selectedTopic!.toLowerCase()
          : null;

      // Apply topic filter if selected (manual only)
      if (manualTopic != null) {
        queryParams = (queryParams ?? {})..addAll({'topic': manualTopic});
      }

      final list = await api.getContents(queryParams: queryParams);
      if (!mounted) return;

      // Topic enforcement post-fetch (manual only) with education exclusion
      List<dynamic> finalList = list;
      if (manualTopic != null) {
        finalList =
            list.where((it) => _topicMatches(it, [manualTopic])).toList();
      }
      // Always remove education content from home feed
      finalList =
          finalList.where((it) => !_topicMatches(it, ['education'])).toList();

      setState(() => _contents = finalList);
    } catch (e) {
      if (!mounted) return;
      setState(() => _contents = []);
      messenger
          .showSnackBar(SnackBar(content: Text('Failed to load contents: $e')));
    } finally {
      if (mounted) setState(() => _loadingContents = false);
    }
  }

  void _onFilterSelected(int i) {
    setState(() => _selectedFilter = i);
    // reload contents according to the newly selected filter
    _loadContents();
  }

  Future<void> _showTopicFilterSheet() async {
    final topics = <Map<String, dynamic>>[
      {'key': null, 'label': 'All', 'icon': Icons.format_list_bulleted},
      {'key': 'entertainment', 'label': 'Entertainment', 'icon': Icons.movie},
      {
        'key': 'infotainment',
        'label': 'Infotainment',
        'icon': Icons.auto_stories
      },
    ];

    final res = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Filter by topic',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...topics.map((t) {
              final key = t['key'] as String?;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[100],
                  child: Icon(t['icon'] as IconData, color: Colors.lightBlue),
                ),
                title: Text(t['label'] as String),
                trailing: _selectedTopic == key
                    ? const Icon(Icons.check, color: Colors.lightBlue)
                    : null,
                onTap: () => Navigator.of(c).pop(key),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                dense: false,
              );
            }).toList(),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'))
            ])
          ]),
        ),
      ),
    );

    if (!mounted) return;
    if (_selectedTopic != res) {
      setState(() => _selectedTopic = res);
      _loadContents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            elevation: 0.6,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            automaticallyImplyLeading: false,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: GestureDetector(
                onTap: () {
                  setState(() => _sidebarOpen = true);
                  _sidebarCtrl.forward();
                },
                child: SvgPicture.asset(
                  'assets/icons/menu_icon.svg',
                  width: 26,
                  height: 26,
                ),
              ),
            ),
            title: CoonchLogo(
              direction: Axis.horizontal,
              iconDiameter: 42,
              ringStroke: 21, // keep ring proportion thick like source logo
              textSize: 17,
              fontWeight: FontWeight.w700,
              spacing: 6,
              fillColor: _logoFillColor,
              ringColor: _logoRingColor,
              textColor: _logoRingColor,
            ),
            actions: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
                icon: const Icon(Icons.settings_outlined),
              ),
              // Topic filter (opens styled modal)
              IconButton(
                onPressed: _showTopicFilterSheet,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.filter_alt_outlined),
                    if (_selectedTopic != null)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.lightBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Notifications icon with unread badge
              Consumer<AuthProvider>(builder: (context, auth, _) {
                final count = auth.unreadNotifications;
                return IconButton(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()));
                    // After returning, refresh provider unread count
                    await auth.loadUnreadCount();
                  },
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none),
                      if (count > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                            constraints: const BoxConstraints(
                                minWidth: 18, minHeight: 18),
                            child: Center(
                              child: Text(
                                count > 99 ? '99+' : count.toString(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 160,
                        child: Builder(builder: (context) {
                          // Group stories by owner user id so each user has one story box
                          final Map<String, List<dynamic>> grouped = {};
                          final List<String> ordered = [];
                          for (final s in _stories) {
                            final uid =
                                _extractUserId((s is Map) ? s['user'] : s) ??
                                    '';
                            if (!grouped.containsKey(uid)) {
                              grouped[uid] = [];
                              ordered.add(uid);
                            }
                            grouped[uid]!.add(s);
                          }

                          // Ensure the owner's group (if any) appears first
                          final auth =
                              Provider.of<AuthProvider>(context, listen: false);
                          final myIdLocal = _extractUserId(auth.user);
                          if (myIdLocal != null &&
                              ordered.contains(myIdLocal)) {
                            ordered.remove(myIdLocal);
                            ordered.insert(0, myIdLocal);
                          }

                          // Build one card per user; include AddStory card at start
                          final int itemCount = ordered.length + 1;

                          if (_loadingStories) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            itemCount: itemCount,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, idx) {
                              if (idx == 0) return const _AddStoryCard();
                              final uidx = idx - 1;
                              if (uidx < 0 || uidx >= ordered.length) {
                                return const SizedBox.shrink();
                              }
                              final uid = ordered[uidx];
                              final userStories = grouped[uid] ?? [];
                              final s = userStories.isNotEmpty
                                  ? userStories[0]
                                  : null;
                              final user = s is Map && s['user'] is Map
                                  ? s['user'] as Map
                                  : null;
                              final name = (user != null &&
                                      (user['username'] ?? user['name']) !=
                                          null)
                                  ? (user['username'] ?? user['name'])
                                      .toString()
                                  : 'User';
                              final avatar = (user != null &&
                                      (user['avatar'] ?? user['avatar_url']) !=
                                          null)
                                  ? (user['avatar'] ?? user['avatar_url'])
                                      .toString()
                                  : null;
                              final thumb = (s is Map &&
                                      (s['thumbnail_url'] ??
                                              s['file_url'] ??
                                              s['file']) !=
                                          null)
                                  ? (s['thumbnail_url'] ??
                                          s['file_url'] ??
                                          s['file'])
                                      .toString()
                                  : avatar;
                              final thumbUrl = thumb ??
                                  'https://www.gravatar.com/avatar/?d=mp&s=400';

                              return GestureDetector(
                                onTap: () async {
                                  // capture navigator & messenger before any await
                                  final navigator = Navigator.of(context);
                                  final messenger =
                                      ScaffoldMessenger.of(context);

                                  final auth = Provider.of<AuthProvider>(
                                      context,
                                      listen: false);
                                  final myIdInner = _extractUserId(auth.user);

                                  // If tapped user's id equals my id -> show modal (watch/upload)
                                  if (uid == myIdInner) {
                                    final choice =
                                        await showModalBottomSheet<String>(
                                      context: context,
                                      builder: (_) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading:
                                                  const Icon(Icons.visibility),
                                              title: const Text('Watch story'),
                                              onTap: () =>
                                                  Navigator.of(_).pop('watch'),
                                            ),
                                            ListTile(
                                              leading:
                                                  const Icon(Icons.upload_file),
                                              title: const Text(
                                                  'Upload new story'),
                                              onTap: () =>
                                                  Navigator.of(_).pop('upload'),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      ),
                                    );

                                    if (!mounted) return;

                                    if (choice == 'watch') {
                                      if (userStories.isNotEmpty) {
                                        // Build groups (ordered by `ordered`) and open StoryViewer
                                        final groups = ordered
                                            .map((uid) => List<
                                                    Map<String, dynamic>>.from(
                                                (grouped[uid] ?? []).map((e) =>
                                                    Map<String, dynamic>.from(
                                                        e as Map))))
                                            .toList();
                                        navigator.push(MaterialPageRoute(
                                            builder: (_) => StoryViewer(
                                                  groups: groups,
                                                  initialGroupIndex: uidx,
                                                  initialStoryIndex: 0,
                                                )));
                                      } else {
                                        messenger.showSnackBar(const SnackBar(
                                            content:
                                                Text('No stories to watch')));
                                      }
                                    } else if (choice == 'upload') {
                                      final res = await navigator.push(
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const CreateStoryScreen()));
                                      if (!mounted) return;
                                      if (res == true) {
                                        await _loadStories();
                                      } else if (res is Map) {
                                        try {
                                          final data = res['data'] is Map
                                              ? res['data']
                                              : res;
                                          if (data is Map) {
                                            insertStory(
                                                Map<String, dynamic>.from(
                                                    data));
                                          } else {
                                            await _loadStories();
                                          }
                                        } catch (_) {
                                          await _loadStories();
                                        }
                                      }
                                    }
                                  } else {
                                    // Non-owner: open the first story of that user, but allow switching across users
                                    if (userStories.isNotEmpty) {
                                      final groups = ordered
                                          .map((uid) => List<
                                                  Map<String, dynamic>>.from(
                                              (grouped[uid] ?? []).map((e) =>
                                                  Map<String, dynamic>.from(
                                                      e as Map))))
                                          .toList();
                                      navigator.push(MaterialPageRoute(
                                          builder: (_) => StoryViewer(
                                                groups: groups,
                                                initialGroupIndex: uidx,
                                                initialStoryIndex: 0,
                                              )));
                                    }
                                  }
                                },
                                child: Container(
                                  width: 110,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        children: [
                                          SizedBox(
                                            width: 110,
                                            height: 100,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: Image.network(
                                                thumbUrl,
                                                fit: BoxFit.cover,
                                                width: 110,
                                                height: 100,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                        width: 110,
                                                        height: 100,
                                                        color: Colors.grey[200],
                                                        child: const Icon(
                                                            Icons.image,
                                                            color:
                                                                Colors.grey)),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                              left: 6,
                                              top: 6,
                                              child: GestureDetector(
                                                onTap: () {
                                                  // Open the user's profile
                                                  Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              ProfileScreen(
                                                                  userId:
                                                                      uid)));
                                                },
                                                child: CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor:
                                                        Colors.white,
                                                    child: NetworkAvatar(
                                                        url: avatar,
                                                        radius: 14)),
                                              )),
                                          // story-count badge removed — keep only avatar/thumbnail
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.of(context)
                                              .push(MaterialPageRoute(
                                                  builder: (_) => ProfileScreen(
                                                        userId: uid,
                                                      )));
                                        },
                                        child: Text(name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: SizedBox(
                          height: 46,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filters.length,
                            itemBuilder: (context, i) {
                              final selected = i == _selectedFilter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  selectedColor: Colors.lightBlue[100],
                                  backgroundColor: Colors.grey[100],
                                  labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  label: Text(_filters[i],
                                      style: TextStyle(
                                          color: selected
                                              ? Colors.lightBlue
                                              : Colors.black54,
                                          fontWeight: selected
                                              ? FontWeight.bold
                                              : FontWeight.w400)),
                                  selected: selected,
                                  onSelected: (_) => _onFilterSelected(i),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loadingContents)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_contents.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48.0),
                      child: Center(
                          child: Text('No content for the selected filter',
                              style: TextStyle(color: Colors.black54))),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => ContentCard(
                        content: Map<String, dynamic>.from(_contents[i] as Map),
                        onUpdated: (fresh) {
                          if (!mounted) return;
                          setState(() => _contents[i] = fresh);
                        },
                      ),
                      childCount: _contents.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
          bottomNavigationBar: const AppBottomNavBar(activeIndex: 0),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: const AppFAB(onPressed: null),
        ),

        // Sidebar overlay
        AnimatedBuilder(
          animation: _sidebarCtrl,
          builder: (context, child) {
            final t = _sidebarCtrl.value;
            final auth = Provider.of<AuthProvider>(context, listen: false);
            final user = auth.user;
            final name = _userDisplayName(user);
            final avatar = _userAvatar(user);
            final sidebarWidth = MediaQuery.of(context).size.width * 0.82;
            return Stack(
              children: [
                if (t > 0)
                  Opacity(
                    opacity: t * 0.38,
                    child: GestureDetector(
                        onTap: () {
                          _sidebarCtrl.reverse();
                          setState(() => _sidebarOpen = false);
                        },
                        child: Container(color: Colors.black)),
                  ),

                // Slide-in sidebar
                Transform.translate(
                  offset: Offset(-sidebarWidth * (1 - t), 0),
                  child: IOSSidebar(
                    userName: name,
                    avatarUrl: avatar,
                    onMenuTap: (key) {
                      _sidebarCtrl.reverse();
                      setState(() => _sidebarOpen = false);
                      if (key == 'education') {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const EducationScreen()));
                      } else if (key == 'infotainment') {
                        setState(() => _selectedTopic = 'infotainment');
                        _loadContents();
                      } else if (key == 'entertainment') {
                        setState(() => _selectedTopic = 'entertainment');
                        _loadContents();
                      } else if (key == 'settings') {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const SettingsScreen()));
                      } else if (key == 'help') {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const HelpSupportScreen()));
                      }
                    },
                    onLogout: () async {
                      _sidebarCtrl.reverse();
                      setState(() => _sidebarOpen = false);
                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);
                      await auth.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    onViewProfile: () {
                      _sidebarCtrl.reverse();
                      setState(() => _sidebarOpen = false);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ProfileScreen()));
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AddStoryCard extends StatelessWidget {
  const _AddStoryCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    String? avatar;
    if (user is Map) {
      final Map<dynamic, dynamic> userMap = user as Map<dynamic, dynamic>;
      final dynamic av = userMap['avatar'] ?? userMap['avatar_url'];
      avatar = av?.toString();
    } else {
      avatar = null;
    }

    return GestureDetector(
      onTap: () async {
        final homeState = context.findAncestorStateOfType<_HomeScreenState>();
        final res = await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const CreateStoryScreen()));
        if (res == true) {
          homeState?._loadStories();
        } else if (res is Map) {
          try {
            // Treat res as a Map (checked by the `is` above) to avoid
            // unchecked nullable-index access warnings
            final Map map = res;
            final dynamic data = map.containsKey('data') ? map['data'] : map;
            if (data is Map) {
              homeState?.insertStory(Map<String, dynamic>.from(data));
            } else {
              homeState?._loadStories();
            }
          } catch (_) {
            homeState?._loadStories();
          }
        }
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 8),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 110,
                  height: 100,
                  decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(14)),
                  child: const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 32, color: Colors.grey),
                    SizedBox(height: 6),
                    Text('Add Story',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500))
                  ])),
                ),
                const SizedBox(height: 15),
                const Text('You',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            Positioned(
              bottom: 20,
              child: GestureDetector(
                onTap: () {
                  final auth =
                      Provider.of<AuthProvider>(context, listen: false);
                  final user = auth.user;
                  String? id;
                  if (user is Map) {
                    final Map<dynamic, dynamic> userMap =
                        user as Map<dynamic, dynamic>;
                    id = (userMap['id'] ?? userMap['user_id'] ?? userMap['pk'])
                        ?.toString();
                  }
                  // If we have an id, open the full ProfileScreen; otherwise fallback to ViewProfileScreen
                  if (id != null) {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: id)));
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ViewProfileScreen()));
                  }
                },
                child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: NetworkAvatar(url: avatar, radius: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
