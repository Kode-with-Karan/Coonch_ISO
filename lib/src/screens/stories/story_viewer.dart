import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../profile/profile_screen.dart';
import '../../services/api_service.dart';
import '../../widgets/network_avatar.dart';
import '../../services/notification_service.dart';
import '../../providers/auth_provider.dart';

/// StoryViewer now supports a list of stories and auto-advancing progress bars.
class StoryViewer extends StatefulWidget {
  /// Stories grouped by owner. Each inner list contains the stories for one user.
  final List<List<Map<String, dynamic>>> groups;
  final int initialGroupIndex;
  final int initialStoryIndex;

  const StoryViewer({
    super.key,
    required this.groups,
    this.initialGroupIndex = 0,
    this.initialStoryIndex = 0,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late int _groupIndex;
  late int _index; // index within current group
  late AnimationController _controller;
  bool _isLiked = false;
  bool _isPaused = false;
  bool _isLoading = true;

  static const Duration _defaultDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroupIndex.clamp(0, widget.groups.length - 1);
    final currentGroup = widget.groups[_groupIndex];
    _index = widget.initialStoryIndex.clamp(0, currentGroup.length - 1);
    _controller = AnimationController(
      vsync: this,
      duration: _getDurationForCurrent(),
    );

    // Don't start animation yet - wait for content to load
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goNext();
      }
    });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    // register view for the initial story after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentStory();
    });
  }

  void _loadCurrentStory() async {
    setState(() => _isLoading = true);
    _controller.reset();

    // Wait for widget to build and content to be ready
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      final story = widget.groups[_groupIndex][_index];
      setState(() {
        _isLiked = story['is_liked_by_me'] == true;
      });

      // Register view
      _registerViewForIndex(_groupIndex, _index);

      // Start animation after content is loaded
      setState(() => _isLoading = false);
      _controller.duration = _getDurationForCurrent();
      _controller.forward();
    }
  }

  Duration _getDurationForCurrent() {
    final s = widget.groups[_groupIndex][_index];
    final d = s['duration_seconds'];
    if (d is int && d > 0) return Duration(seconds: d);
    return _defaultDuration;
  }

  Future<void> _registerViewForIndex(int gidx, int idx) async {
    final story = widget.groups[gidx][idx];
    final id = story['id']?.toString();
    if (id == null) return;
    final api = Provider.of<ApiService>(context, listen: false);
    final notifications = Provider.of<NotificationService>(
      context,
      listen: false,
    );
    try {
      final res = await api.viewContent(id);
      final awarded =
          ((res['data'] ?? const {})['reward_points_awarded']) as int?;
      if (awarded != null && awarded > 0) {
        notifications.showInfo('+$awarded pts for watching');
      }
    } catch (_) {}
  }

  void _goNext() {
    final currentGroup = widget.groups[_groupIndex];
    if (_index < currentGroup.length - 1) {
      setState(() {
        _index += 1;
        _isLiked = widget.groups[_groupIndex][_index]['is_liked_by_me'] == true;
        _controller.duration = _getDurationForCurrent();
        _controller.forward(from: 0);
      });
      _registerViewForIndex(_groupIndex, _index);
      return;
    }

    // move to next group's first story if available
    if (_groupIndex < widget.groups.length - 1) {
      setState(() {
        _groupIndex += 1;
        _index = 0;
        _isLiked = widget.groups[_groupIndex][_index]['is_liked_by_me'] == true;
        _controller.duration = _getDurationForCurrent();
        _controller.forward(from: 0);
      });
      _registerViewForIndex(_groupIndex, _index);
      return;
    }

    // no more groups -> close
    _controller.stop();
    Navigator.of(context).pop();
  }

  void _goPrevious() {
    if (_controller.value > 0.2) {
      // if more than 20% into the story, restart it
      _controller.forward(from: 0);
      return;
    }

    if (_index > 0) {
      setState(() {
        _index -= 1;
        _isLiked = widget.groups[_groupIndex][_index]['is_liked_by_me'] == true;
        _controller.duration = _getDurationForCurrent();
        _controller.forward(from: 0);
      });
      _registerViewForIndex(_groupIndex, _index);
      return;
    }

    // go to previous group's last story if available
    if (_groupIndex > 0) {
      setState(() {
        _groupIndex -= 1;
        final prevGroup = widget.groups[_groupIndex];
        _index = prevGroup.length - 1;
        _isLiked = widget.groups[_groupIndex][_index]['is_liked_by_me'] == true;
        _controller.duration = _getDurationForCurrent();
        _controller.forward(from: 0);
      });
      _registerViewForIndex(_groupIndex, _index);
      return;
    }

    // At first group's first story: restart
    _controller.forward(from: 0);
  }

  Future<void> _toggleLike() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final notifications = Provider.of<NotificationService>(
      context,
      listen: false,
    );
    final story = widget.groups[_groupIndex][_index];
    final id = story['id']?.toString();
    if (id == null) return;
    final bool previousLiked = _isLiked;
    final int previousCount = _readLikesCount(story);
    final bool nextLiked = !previousLiked;

    // Optimistic local update so the footer count reacts immediately.
    setState(() {
      _isLiked = nextLiked;
      story['is_liked_by_me'] = nextLiked;
      final int nextCount = nextLiked
          ? previousCount + 1
          : (previousCount > 0 ? previousCount - 1 : 0);
      story['likes_count'] = nextCount;
      story['likes'] = nextCount;
    });

    try {
      await api.likeUnlikeContent(id);
    } catch (e) {
      // Roll back optimistic update on failure.
      setState(() {
        _isLiked = previousLiked;
        story['is_liked_by_me'] = previousLiked;
        story['likes_count'] = previousCount;
        story['likes'] = previousCount;
      });
      notifications.showError(
        NotificationService.formatMessage('Failed to react: $e'),
      );
    }
  }

  Future<void> _showCommentsBottomSheet() async {
    final story = widget.groups[_groupIndex][_index];
    final contentId = story['id']?.toString();
    if (contentId == null) return;

    // Pause story so it doesn't auto-advance while they comment
    if (_controller.isAnimating) {
      _controller.stop();
    }

    final api = Provider.of<ApiService>(context, listen: false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (c) {
        final TextEditingController commentCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top > 0 ? MediaQuery.of(context).padding.top - 8 : 0,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: (MediaQuery.of(context).size.height * 0.65) - MediaQuery.of(context).padding.top,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Reactions & Comments',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: api.getContentById(contentId),
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snap.hasError) {
                            return Center(
                              child: Text(
                                'Failed to load comments: ${snap.error}',
                              ),
                            );
                          }
                          final data = snap.data ?? {};
                          final comments = data['comments'] is List
                              ? data['comments'] as List<dynamic>
                              : <dynamic>[];

                          if (comments.isEmpty) {
                            return const Center(child: Text('No comments yet'));
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            itemBuilder: (context, i) {
                              final cmt = comments[i] as Map<dynamic, dynamic>;
                              final user = cmt['user'];
                              final uname =
                                  (user is Map &&
                                      (user['username'] != null ||
                                          user['name'] != null))
                                  ? (user['username'] ?? user['name'])
                                        .toString()
                                  : 'Unknown';
                              final text =
                                  cmt['comment_text']?.toString() ?? '';
                              return ListTile(
                                title: Text(
                                  uname,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(text),
                              );
                            },
                            separatorBuilder: (_, __) => const Divider(),
                            itemCount: comments.length,
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Add a comment...',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send, color: Colors.blue),
                            onPressed: () async {
                              final text = commentCtrl.text.trim();
                              if (text.isEmpty) return;

                              try {
                                await api.commentContent(contentId, text);
                                commentCtrl.clear();
                                setModalState(() {});
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to post: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Resume playing if closed
      _controller.forward();
    });
  }

  int _readLikesCount(Map<String, dynamic> story) {
    final dynamic raw = story['likes_count'] ?? story['likes'] ?? 0;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString()) ?? 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details, BoxConstraints constraints) {
    final dx = details.localPosition.dx;
    final w = constraints.maxWidth;
    if (dx < w * 0.4) {
      _goPrevious();
    } else if (dx > w * 0.6) {
      _goNext();
    } else {
      // center tap toggles pause
      if (_isPaused) {
        _isPaused = false;
        _controller.forward();
      } else {
        _isPaused = true;
        _controller.stop();
      }
    }
  }

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

  Future<void> _deleteCurrentStory() async {
    final story = widget.groups[_groupIndex][_index];
    final id = story['id']?.toString();
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete story'),
        content: const Text('Are you sure you want to delete this story?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final api = Provider.of<ApiService>(context, listen: false);
    final notifications = Provider.of<NotificationService>(
      context,
      listen: false,
    );

    try {
      await api.deleteContent(id);

      setState(() {
        widget.groups[_groupIndex].removeAt(_index);

        if (widget.groups[_groupIndex].isEmpty) {
          widget.groups.removeAt(_groupIndex);
          if (widget.groups.isNotEmpty) {
            if (_groupIndex >= widget.groups.length) {
              _groupIndex = widget.groups.length - 1;
            }
            _index = 0;
          }
        } else if (_index >= widget.groups[_groupIndex].length) {
          _index = widget.groups[_groupIndex].length - 1;
        }
      });

      if (widget.groups.isEmpty) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      notifications.showSuccess('Story deleted successfully');
      _loadCurrentStory();
    } catch (e) {
      notifications.showError(
        NotificationService.formatMessage('Failed to delete story: $e'),
      );
    }
  }

  String _resolveStoryOwnerName(
    Map<String, dynamic> data,
    Map<String, dynamic>? user,
  ) {
    try {
      if (user != null) {
        final firstName = (user['first_name'] ?? user['firstName'] ?? '')
            .toString()
            .trim();
        final lastName = (user['last_name'] ?? user['lastName'] ?? '')
            .toString()
            .trim();
        final fullFromParts = '$firstName $lastName'.trim();

        final candidates = [
          user['username'],
          user['name'],
          user['full_name'],
          fullFromParts.isNotEmpty ? fullFromParts : null,
          user['email'],
        ];
        for (final value in candidates) {
          final text = value?.toString().trim() ?? '';
          if (text.isNotEmpty) return text;
        }
      }

      final rootCandidates = [
        data['username'],
        data['name'],
        data['full_name'],
        data['user_name'],
      ];
      for (final value in rootCandidates) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
    } catch (_) {
      // ignore and fallback
    }
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.groups[_groupIndex][_index];
    final user = data['user'] is Map
        ? data['user'] as Map<String, dynamic>
        : null;
    final avatar = user != null
        ? (user['avatar'] ?? user['avatar_url'])?.toString()
        : null;
    final name = _resolveStoryOwnerName(data, user);
    final uid = user != null
        ? (user['id'] ?? user['user_id'] ?? user['pk'])?.toString()
        : null;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final myId = _extractUserId(auth.user);
    final isOwner = myId != null && uid != null && myId == uid;
    final image = data['thumbnail_url'] ?? data['file_url'] ?? data['file'];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // progress bars
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 6.0,
                  ),
                  child: Row(
                    children: List.generate(widget.groups[_groupIndex].length, (
                      i,
                    ) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: _isLoading
                              ? const LinearProgressIndicator(
                                  value: null,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                )
                              : LinearProgressIndicator(
                                  value: i < _index
                                      ? 1
                                      : (i == _index ? _controller.value : 0),
                                  backgroundColor: Colors.white24,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                ),
                        ),
                      );
                    }),
                  ),
                ),
                // header row
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (uid != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(userId: uid),
                              ),
                            );
                          }
                        },
                        child: NetworkAvatar(url: avatar, radius: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (uid != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(userId: uid),
                                ),
                              );
                            }
                          },
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if ((data['views_count'] ?? data['views']) != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Text(
                            '${(data['views_count'] ?? data['views']).toString()} views',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      if (isOwner)
                        IconButton(
                          onPressed: _deleteCurrentStory,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // content + gesture area
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => _onTapDown(d, constraints),
                        onLongPressStart: (_) {
                          _isPaused = true;
                          _controller.stop();
                        },
                        onLongPressEnd: (_) {
                          _isPaused = false;
                          _controller.forward();
                        },
                        child: Center(
                          child: SizedBox.expand(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Media (image/video thumbnail) if available
                                if (image != null)
                                  Positioned.fill(
                                    child: Image.network(
                                      image.toString(),
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const Center(
                                            child: Icon(
                                              Icons.broken_image,
                                              color: Colors.white,
                                            ),
                                          ),
                                    ),
                                  )
                                else
                                  // Text-only story background
                                  Container(color: Colors.black),

                                // Caption overlay: for media show at bottom, for text-only show centered
                                if ((data['caption'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty)
                                  Positioned(
                                    left: 16,
                                    right: 16,
                                    bottom: image != null ? 24 : null,
                                    top: image == null ? 120 : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        data['caption']?.toString() ?? '',
                                        textAlign: image != null
                                            ? TextAlign.left
                                            : TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                        maxLines: 6,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),

                                // Fallback icon when no media and no caption
                                if (image == null &&
                                    (data['caption'] == null ||
                                        data['caption']
                                            .toString()
                                            .trim()
                                            .isEmpty))
                                  const Icon(
                                    Icons.image,
                                    size: 80,
                                    color: Colors.white24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // footer actions
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _toggleLike,
                        icon: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        data['likes_count']?.toString() ??
                            data['likes']?.toString() ??
                            '0',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _showCommentsBottomSheet,
                        child: const Text(
                          'More',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Loading overlay
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
