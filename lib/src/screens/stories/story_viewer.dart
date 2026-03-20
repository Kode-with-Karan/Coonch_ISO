import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../profile/profile_screen.dart';
import '../../services/api_service.dart';
import '../../widgets/network_avatar.dart';
import '../../services/notification_service.dart';

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
    _controller =
        AnimationController(vsync: this, duration: _getDurationForCurrent());
    
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
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
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
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    final story = widget.groups[_groupIndex][_index];
    final id = story['id']?.toString();
    if (id == null) return;
    setState(() => _isLiked = !_isLiked);
    try {
      await api.likeUnlikeContent(id);
    } catch (e) {
      setState(() => _isLiked = !_isLiked);
      notifications
          .showError(NotificationService.formatMessage('Failed to react: $e'));
    }
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

  @override
  Widget build(BuildContext context) {
    final data = widget.groups[_groupIndex][_index];
    final user =
        data['user'] is Map ? data['user'] as Map<String, dynamic> : null;
    final avatar = user != null
        ? (user['avatar'] ?? user['avatar_url'])?.toString()
        : null;
    final name = user != null
        ? (user['username'] ?? user['name'])?.toString()
        : (data['user']?.toString());
    final uid = user != null
        ? (user['id'] ?? user['user_id'] ?? user['pk'])?.toString()
        : null;
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Row(
                children: List.generate(widget.groups[_groupIndex].length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: _isLoading
                          ? const LinearProgressIndicator(
                              value: null,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : LinearProgressIndicator(
                              value: i < _index
                                  ? 1
                                  : (i == _index ? _controller.value : 0),
                              backgroundColor: Colors.white24,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(Colors.white),
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
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: uid)));
                      }
                    },
                    child: NetworkAvatar(url: avatar, radius: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (uid != null) {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: uid)));
                        }
                      },
                      child: Text(name ?? 'Unknown',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if ((data['views_count'] ?? data['views']) != null)
                    Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Text(
                            '${(data['views_count'] ?? data['views']).toString()} views',
                            style: const TextStyle(color: Colors.white70))),
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            // content + gesture area
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
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
                              child: Image.network(image.toString(),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image,
                                          color: Colors.white))),
                            )
                          else
                            // Text-only story background
                            Container(
                              color: Colors.black,
                            ),

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
                                    horizontal: 12, vertical: 10),
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
                                      color: Colors.white, fontSize: 16),
                                  maxLines: 6,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),

                          // Fallback icon when no media and no caption
                          if (image == null &&
                              (data['caption'] == null ||
                                  data['caption'].toString().trim().isEmpty))
                            const Icon(Icons.image,
                                size: 80, color: Colors.white24),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            // footer actions
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                      onPressed: _toggleLike,
                      icon: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: Colors.red)),
                  const SizedBox(width: 8),
                  Text(
                      data['likes_count']?.toString() ??
                          data['likes']?.toString() ??
                          '0',
                      style: const TextStyle(color: Colors.white)),
                  const Spacer(),
                  TextButton(
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                              content: Text(
                                  'Viewers/reactions are not implemented yet'))),
                      child: const Text('More',
                          style: TextStyle(color: Colors.white))),
                ],
              ),
            ),
          ],
        ),
        // Loading overlay
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
      ],
        ),
      ),
    );
  }
}
