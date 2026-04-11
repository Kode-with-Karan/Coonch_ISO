import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../utils/content_access.dart';
import '../../widgets/audio_player_widget.dart';
import '../../widgets/subscription_dialog.dart';
import '../teacher_profile_screen.dart';

class _ContentTypeMeta {
  const _ContentTypeMeta({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

const Map<String, _ContentTypeMeta> _typeMeta = {
  'video': _ContentTypeMeta(
    label: 'Video',
    icon: Icons.videocam,
    color: AppTheme.primary,
  ),
  'audio': _ContentTypeMeta(
    label: 'Audio',
    icon: Icons.audiotrack,
    color: AppTheme.primary,
  ),
  'text': _ContentTypeMeta(
    label: 'Text',
    icon: Icons.article,
    color: AppTheme.primary,
  ),
};

_ContentTypeMeta _metaForType(String type) {
  final key = type.toLowerCase();
  if (_typeMeta.containsKey(key)) return _typeMeta[key]!;
  final label = key.isEmpty
      ? 'Other'
      : '${key[0].toUpperCase()}${key.substring(1)}';
  return _ContentTypeMeta(
    label: label,
    icon: Icons.play_circle_outline,
    color: Colors.grey,
  );
}

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({
    Key? key,
    this.courseId,
    this.courseTitle,
    this.duration,
    this.price,
    this.color,
  }) : super(key: key);

  final String? courseId;
  final String? courseTitle;
  final String? duration;
  final String? price;
  final Color? color;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _courseDetails;
  bool _loading = false;
  bool _hasTriedLoadingDetails = false;
  List<dynamic> _seriesItems = [];
  bool _loadingSeriesItems = false;
  bool _isWishlisted = false;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoInitializing = false;
  bool _hasAwardedPoints = false;

  Future<T?> _pushPageDeferred<T>(
    Widget page, {
    bool replace = false,
    bool fullscreenDialog = false,
  }) {
    return Future<T?>.microtask(() {
      if (!mounted) return null;
      final route = MaterialPageRoute<T>(
        builder: (_) => page,
        fullscreenDialog: fullscreenDialog,
      );
      if (replace) {
        return Navigator.of(context).pushReplacement<T, T>(route);
      }
      return Navigator.of(context).push<T>(route);
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    debugPrint(
      '[course_detail_screen.dart][COURSE_DETAIL] Opened: courseId=${widget.courseId} title=${widget.courseTitle}',
    );
  }

  void _openContentItem({
    required String itemId,
    required String title,
    required String duration,
    required String price,
  }) {
    if (itemId.isEmpty) return;
    _pushPageDeferred<void>(
      CourseDetailScreen(
        courseId: itemId,
        courseTitle: title,
        duration: duration,
        price: price,
        color: AppTheme.primary,
      ),
      replace: true,
    );
  }

  Future<void> _loadCourseDetails() async {
    if (!mounted) return;
    debugPrint(
      '[course_detail_screen.dart][COURSE_DETAIL] Loading details for courseId=${widget.courseId}',
    );
    setState(() {
      _loading = true;
      _hasTriedLoadingDetails = true;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final details = await api.getContentById(widget.courseId!);
      if (!mounted) return;

      final contentData = details['data'] ?? details;

      // Debug: Print access-related fields
      print('[course_detail_screen.dart][COURSE_DETAIL] Loaded content:');
      print(
        '[course_detail_screen.dart][COURSE_DETAIL]   id: ${contentData['id']}',
      );
      print(
        '[course_detail_screen.dart][COURSE_DETAIL]   is_premium: ${contentData['is_premium']}',
      );
      print(
        '[course_detail_screen.dart][COURSE_DETAIL]   can_access: ${contentData['can_access']}',
      );
      print(
        '[course_detail_screen.dart][COURSE_DETAIL]   access_reason: ${contentData['access_reason']}',
      );
      print(
        '[course_detail_screen.dart][COURSE_DETAIL]   free: ${contentData['free']}',
      );
      print(
        '[course_detail_screen.dart][COURSE_DETAIL]   price: ${contentData['price']}',
      );
      print(
        '[course_detail_screen.dart][COURSE_DETAIL]   active_subscription: ${contentData['active_subscription']}',
      );

      setState(() {
        _courseDetails = contentData;
        _loading = false;
      });
      debugPrint(
        '[course_detail_screen.dart][COURSE_DETAIL] Details loaded successfully',
      );

      if (canAccessContent(contentData)) {
        try {
          final viewRes = await api.viewContent(widget.courseId!);
          if (viewRes['success'] == 1) {
            final awarded = viewRes['data']?['reward_points_awarded'] as int?;
            if (awarded != null && awarded > 0 && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('+$awarded points earned! 🎉'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } catch (e) {
          // View tracking is best-effort, ignore errors
        }
      }

      // Check if content is part of a series and load series items
      final series = contentData['series'];
      if (series != null && series is Map) {
        final seriesId = series['id']?.toString();
        if (seriesId != null) {
          _loadSeriesItems(seriesId);
        }
      }
    } catch (e) {
      debugPrint(
        '[course_detail_screen.dart][COURSE_DETAIL] Error loading course details: $e',
      );
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<bool> _ensureCourseDetailsLoaded() async {
    if (_courseDetails != null) return true;
    if (_loading) return false;

    final courseId = widget.courseId;
    if (courseId == null || courseId.isEmpty) return false;

    debugPrint(
      '[course_detail_screen.dart][COURSE_DETAIL] Triggered lazy load from Play button',
    );
    await _loadCourseDetails();
    return _courseDetails != null;
  }

  Future<void> _loadSeriesItems(String seriesId) async {
    debugPrint(
      '[course_detail_screen.dart][COURSE_DETAIL] Loading sibling series items: seriesId=$seriesId',
    );
    setState(() => _loadingSeriesItems = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final seriesData = await api.getSeriesById(seriesId);
      if (!mounted) return;

      final items = seriesData['items'] as List<dynamic>? ?? [];
      setState(() {
        _seriesItems = items;
        _loadingSeriesItems = false;
      });
    } catch (e) {
      debugPrint(
        '[course_detail_screen.dart][COURSE_DETAIL] Error loading series items: $e',
      );
      if (!mounted) return;
      setState(() => _loadingSeriesItems = false);
    }
  }

  Future<void> _openFullScreenVideo() async {
    debugPrint(
      '[course_detail_screen.dart][COURSE_DETAIL] Play tapped for video',
    );
    if (isLockedContent(_courseDetails)) {
      _openSubscriptionPlans();
      return;
    }

    final fileUrl =
        (_courseDetails?['file_url'] ??
                _courseDetails?['file'] ??
                _courseDetails?['video_url'])
            ?.toString();
    if (fileUrl == null || fileUrl.isEmpty) return;

    if (_videoController == null || !_isVideoInitialized) {
      setState(() => _isVideoInitializing = true);

      try {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(fileUrl));
        await _videoController!.initialize();
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
            _isVideoInitializing = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isVideoInitializing = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to load video: $e')));
        }
        return;
      }
    }

    if (!mounted || _videoController == null || !_isVideoInitialized) return;

    await _pushPageDeferred<void>(
      _FullScreenVideoPage(
        controller: _videoController!,
        contentId: widget.courseId ?? '',
        onComplete: () => _awardViewPoints(),
      ),
      fullscreenDialog: true,
    );
  }

  Future<void> _awardViewPoints() async {
    if (_hasAwardedPoints || widget.courseId == null) return;
    if (isLockedContent(_courseDetails)) {
      _openSubscriptionPlans();
      return;
    }

    _hasAwardedPoints = true;

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final viewRes = await api.viewContent(widget.courseId!);
      if (viewRes['success'] == 1 && mounted) {
        final awarded = viewRes['data']?['reward_points_awarded'] as int?;
        if (awarded != null && awarded > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('+$awarded points earned for completing! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Already watched, reset flag
          _hasAwardedPoints = false;
        }
      } else {
        // Failed, reset flag
        _hasAwardedPoints = false;
      }
    } catch (e) {
      // Best effort, ignore errors
      _hasAwardedPoints = false;
    }
  }

  void _toggleWishlist() {
    setState(() {
      _isWishlisted = !_isWishlisted;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isWishlisted ? 'Added to wishlist' : 'Removed from wishlist',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _shareContent() {
    final title =
        _courseDetails?['title'] ??
        _courseDetails?['caption'] ??
        'Check out this content';
    final contentId = widget.courseId ?? '';
    final shareText =
        '$title\n\nWatch on Coonch: https://coonch.app/content/$contentId';

    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openSubscriptionPlans() async {
    if (!mounted) return;
    await showSubscriptionRequiredDialog(context, content: _courseDetails);
  }

  // Preferred order: video, audio, text, then any others.
  List<String> get _availableTypes {
    final types = <String>{};
    for (final item in _seriesItems) {
      final type = (item['type'] ?? '').toString().toLowerCase();
      if (type.isNotEmpty) types.add(type);
    }
    const preferred = ['video', 'audio', 'text'];
    final ordered = <String>[];
    for (final p in preferred) {
      if (types.contains(p)) ordered.add(p);
    }
    final remaining = types.difference(preferred.toSet()).toList()..sort();
    ordered.addAll(remaining);
    return ordered;
  }

  int _selectedTabIndex = 0;

  List<dynamic> get _filteredItems {
    final available = _availableTypes;
    if (available.isEmpty) return _seriesItems;
    final index = _selectedTabIndex.clamp(0, available.length - 1);
    final selectedType = available[index];
    return _seriesItems
        .where(
          (item) =>
              (item['type'] ?? '').toString().toLowerCase() == selectedType,
        )
        .toList();
  }

  Widget _buildSeriesItemsSection() {
    if (_seriesItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final availableTypes = _availableTypes;
    final selectedIndex = availableTypes.isEmpty
        ? 0
        : _selectedTabIndex.clamp(0, availableTypes.length - 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Content',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Text(
                '${_seriesItems.length} items',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (availableTypes.length > 1) ...[
            // Show tabs for multiple content types
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: availableTypes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final type = entry.value;
                  final meta = _metaForType(type);
                  final isSelected = index == selectedIndex;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (index != _selectedTabIndex) {
                          setState(() {
                            _selectedTabIndex = index;
                          });
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? meta.color.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? meta.color.withValues(alpha: 0.5)
                                : Colors.transparent,
                          ),
                        ),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              meta.icon,
                              size: 18,
                              color: isSelected ? meta.color : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              meta.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? meta.color
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_loadingSeriesItems)
            const Center(child: CircularProgressIndicator())
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final originalIndex = _seriesItems.indexOf(item);
                return _buildSeriesItemTile(item, originalIndex);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSeriesItemTile(dynamic item, int index) {
    final itemId = item['id']?.toString() ?? '';
    final title = item['caption'] ?? item['title'] ?? 'Episode ${index + 1}';
    final type = (item['type'] ?? '').toString().toLowerCase();
    final thumbnailUrl = item['thumbnail_url'] ?? item['thumbnail'];
    final currentItemId = _courseDetails?['id']?.toString();
    final isCurrentItem = itemId == currentItemId;
    final meta = _metaForType(type);
    final hasThumbnail =
        thumbnailUrl != null && thumbnailUrl.toString().isNotEmpty;

    return GestureDetector(
      onTap: () => _openContentItem(
        itemId: itemId,
        title: title.toString(),
        duration: _formatDuration(item['duration'] ?? item['duration_seconds']),
        price: _contentPriceLabel(item),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentItem
              ? AppTheme.primary.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentItem ? AppTheme.primary : Colors.grey.shade200,
            width: isCurrentItem ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail or icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: hasThumbnail
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        thumbnailUrl.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(meta.icon, color: meta.color),
                      ),
                    )
                  : Icon(meta.icon, color: meta.color),
            ),
            const SizedBox(width: 12),
            // Title and type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Episode ${index + 1}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isCurrentItem ? AppTheme.primary : Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(meta.icon, size: 14, color: meta.color),
                      const SizedBox(width: 4),
                      Text(
                        meta.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: meta.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Playing indicator
            if (isCurrentItem)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                ),
              )
            else
              Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isWishlisted ? Icons.bookmark : Icons.bookmark_border,
              color: _isWishlisted ? AppTheme.primary : Colors.black,
            ),
            onPressed: () => _toggleWishlist(),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black),
            onPressed: () => _shareContent(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ((_courseDetails == null && _hasTriedLoadingDetails)
                ? const Center(child: Text('Content not found'))
                : Column(
                    children: [
                      // Debug: Access state indicator (remove in production)
                      _buildDebugAccessInfo(),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMediaSection(),
                              if (_courseDetails == null) ...[
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Text(
                                    'Tap Play below to load this content.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              _buildTitleSection(),
                              const SizedBox(height: 12),
                              _buildMetadataSection(),
                              if (isLockedContent(_courseDetails)) ...[
                                const SizedBox(height: 20),
                                _buildLockedAccessNotice(),
                              ],
                              const SizedBox(height: 24),
                              _buildAboutSection(),
                              if (_seriesItems.length > 1) ...[
                                const SizedBox(height: 32),
                                _buildSeriesItemsSection(),
                              ],
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// Debug widget showing access state (TODO: remove in production)
  Widget _buildDebugAccessInfo() {
    final isPremium = _courseDetails?['is_premium'];
    final canAccess = _courseDetails?['can_access'];
    final accessReason = _courseDetails?['access_reason'];
    final activeSub = _courseDetails?['active_subscription'];
    final isLocked = isLockedContent(_courseDetails);

    Color bgColor = isLocked ? Colors.red.shade100 : Colors.green.shade100;
    Color textColor = isLocked ? Colors.red.shade900 : Colors.green.shade900;
    String status = isLocked ? 'LOCKED' : 'UNLOCKED';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: bgColor,
      child: Text(
        'DEBUG: $status | premium=$isPremium, can_access=$canAccess, reason=$accessReason, sub=${activeSub != null ? "yes" : "no"}',
        style: TextStyle(fontSize: 10, color: textColor),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMediaSection() {
    if (isLockedContent(_courseDetails)) {
      return _buildLockedMediaSection();
    }

    final type = (_courseDetails?['type'] ?? '').toString().toLowerCase();
    final fileUrl =
        (_courseDetails?['file_url'] ??
                _courseDetails?['file'] ??
                _courseDetails?['video_url'])
            ?.toString();
    final audioUrl = (_courseDetails?['audio_url'] ?? fileUrl)?.toString();
    final thumb =
        (_courseDetails?['thumbnail_url'] ??
                _courseDetails?['thumbnail'] ??
                _courseDetails?['image_url'])
            ?.toString();

    if (type == 'video' && fileUrl != null && fileUrl.isNotEmpty) {
      return _buildVideoContent(fileUrl, thumb);
    }

    if (type == 'audio' && audioUrl != null && audioUrl.isNotEmpty) {
      return _buildAudioContent(audioUrl);
    }

    if (type == 'text') {
      return _buildTextContent();
    }

    if (type == 'image' && thumb != null && thumb.isNotEmpty) {
      return _buildImageContent(thumb);
    }

    return _buildDefaultContent();
  }

  Widget _buildVideoContent(String videoUrl, String? thumbnail) {
    final meta = _metaForType('video');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Video',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
        if (thumbnail != null && thumbnail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: meta.color.withValues(alpha: 0.08),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      thumbnail,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: meta.color.withValues(alpha: 0.08),
                        child: Icon(meta.icon, color: meta.color, size: 64),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  _buildPlayButton(),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: GestureDetector(
              onTap: _openFullScreenVideo,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _isVideoInitializing
                      ? const CircularProgressIndicator(color: AppTheme.primary)
                      : Icon(meta.icon, size: 80, color: AppTheme.primary),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Tap to watch video',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _openFullScreenVideo,
      child: Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
        ),
        child: _isVideoInitializing
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Icon(Icons.play_arrow, size: 50, color: Colors.white),
      ),
    );
  }

  Widget _buildAudioContent(String audioUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Audio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.audiotrack,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _courseDetails?['caption'] ??
                                _courseDetails?['title'] ??
                                'Audio Content',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _courseDetails?['duration']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AudioPlayerWidget(
                  url: audioUrl,
                  height: 60,
                  onComplete: _awardViewPoints,
                  autoPlay: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextContent() {
    final caption =
        _courseDetails?['caption'] ?? _courseDetails?['title'] ?? '';
    final description =
        _courseDetails?['description'] ?? _courseDetails?['content'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Text Content',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption.toString().isNotEmpty) ...[
                  Text(
                    caption.toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (description.toString().isNotEmpty)
                  Text(
                    description.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[800],
                      height: 1.6,
                    ),
                  ),
                if (caption.toString().isEmpty &&
                    description.toString().isEmpty)
                  Text(
                    'No text content available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _awardViewPoints,
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark as Read'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageContent(String imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Image',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 200,
      decoration: BoxDecoration(
        color: widget.color ?? Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, size: 60, color: Colors.grey[500]),
            const SizedBox(height: 8),
            Text(
              'No preview available',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedMediaSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, size: 56, color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(
              '${requiredPlanTopicLabel(_courseDetails)} content is locked',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              contentAccessMessage(_courseDetails),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    final title =
        _courseDetails?['caption'] ??
        _courseDetails?['title'] ??
        widget.courseTitle ??
        '';
    if (title.toString().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title.toString(),
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '';
    final seconds = int.tryParse(duration.toString()) ?? 0;
    if (seconds <= 0) return '';
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final mins = seconds ~/ 60;
      final secs = seconds % 60;
      return secs > 0 ? '${mins}m ${secs}s' : '${mins}m';
    } else {
      final hours = seconds ~/ 3600;
      final mins = (seconds % 3600) ~/ 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
  }

  String? _formatPaidPrice(dynamic rawPrice) {
    if (rawPrice == null) return null;
    final priceValue = double.tryParse(rawPrice.toString());
    if (priceValue == null || priceValue <= 0) return null;
    return priceValue == priceValue.truncateToDouble()
        ? '£${priceValue.toStringAsFixed(0)}'
        : '£${priceValue.toStringAsFixed(2)}';
  }

  String _contentPriceLabel(Map<String, dynamic>? content, {String? fallback}) {
    final freeValue = content?['free'];
    if (freeValue == true || freeValue == 'true') {
      return 'Free';
    }

    final paidPrice = _formatPaidPrice(content?['price']);
    if (paidPrice != null) {
      return paidPrice;
    }

    final fallbackPrice = _formatPaidPrice(fallback);
    if (fallbackPrice != null) {
      return fallbackPrice;
    }

    if ((fallback ?? '').trim().toLowerCase() == 'free') {
      return 'Free';
    }

    return 'Free';
  }

  Widget _buildMetadataSection() {
    // Check multiple possible field names for duration
    final durationRaw =
        _courseDetails?['duration'] ??
        _courseDetails?['duration_seconds'] ??
        widget.duration ??
        '';
    final duration = _formatDuration(durationRaw);
    final owner = _courseDetails?['user'] ?? _courseDetails?['creator'];
    final priceLabel = _contentPriceLabel(
      _courseDetails,
      fallback: widget.price,
    );
    final hasPaidPrice = priceLabel != 'Free';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (duration.isNotEmpty) ...[
            const Icon(Icons.access_time, color: Color(0xFFFF8C42), size: 20),
            const SizedBox(width: 8),
            Text(
              duration,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFFFF8C42),
              ),
            ),
            const SizedBox(width: 24),
          ],
          if (owner != null)
            GestureDetector(
              onTap: () {
                final id = (owner is Map) ? (owner['id']?.toString()) : null;
                if (id != null) {
                  final name = (owner is Map)
                      ? (owner['name'] ?? owner['username'])?.toString() ?? ''
                      : '';
                  _pushPageDeferred<void>(
                    TeacherProfileScreen(teacherName: name, teacherTitle: ''),
                  );
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.person, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    owner is Map
                        ? (owner['name'] ?? owner['username'] ?? '').toString()
                        : '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          if (hasPaidPrice) ...[
            if (duration.isNotEmpty || owner != null) const SizedBox(width: 24),
            const Icon(
              Icons.local_offer_outlined,
              color: AppTheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              priceLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    final description =
        _courseDetails?['description'] ?? _courseDetails?['caption'];
    if (description == null || description.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About this content',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description.toString(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedAccessNotice() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                contentAccessMessage(_courseDetails),
                style: TextStyle(color: Colors.orange.shade900, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final locked = isLockedContent(_courseDetails);
    final premium = isPremiumContent(_courseDetails);
    final type = (_courseDetails?['type'] ?? '').toString().toLowerCase();
    final priceLabel = _contentPriceLabel(
      _courseDetails,
      fallback: widget.price,
    );
    final hasPaidPrice = priceLabel != 'Free';
    final buttonLabel = _courseDetails == null
        ? 'Play'
        : (locked
              ? lockedActionLabel(_courseDetails)
              : premium
              ? hasPaidPrice
                    ? 'Included in your plan • $priceLabel'
                    : 'Included in your plan'
              : hasPaidPrice
              ? 'Watch for $priceLabel'
              : 'Free Watch');
    final buttonColor = locked ? Colors.orange : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              if (_courseDetails == null) {
                final loaded = await _ensureCourseDetailsLoaded();
                if (!loaded) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to load content')),
                  );
                  return;
                }
              }

              if (!mounted) return;

              final loadedLocked = isLockedContent(_courseDetails);
              final loadedPremium = isPremiumContent(_courseDetails);
              final loadedType = (_courseDetails?['type'] ?? '')
                  .toString()
                  .toLowerCase();

              if (loadedLocked) {
                _openSubscriptionPlans();
              } else if (loadedType == 'video') {
                _openFullScreenVideo();
              } else if (loadedType == 'text') {
                _awardViewPoints();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      loadedPremium
                          ? 'Content unlocked with your subscription.'
                          : 'Starting playback...',
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final String contentId;
  final VoidCallback? onComplete;

  const _FullScreenVideoPage({
    required this.controller,
    required this.contentId,
    this.onComplete,
  });

  @override
  State<_FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<_FullScreenVideoPage> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  bool _hasAwardedPoints = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.setLooping(false);
    _controller.play();

    _controller.addListener(_onVideoComplete);
  }

  void _onVideoComplete() {
    if (_hasAwardedPoints) return;

    final position = _controller.value.position;
    final duration = _controller.value.duration;

    if (duration.inSeconds > 0) {
      final progress = position.inSeconds / duration.inSeconds;
      if (progress >= 0.9) {
        _hasAwardedPoints = true;
        widget.onComplete?.call();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoComplete);
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _controller.value.aspectRatio == 0
        ? 16 / 9
        : _controller.value.aspectRatio;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: aspect,
                child: VideoPlayer(_controller),
              ),
            ),
            if (_showControls)
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            if (_showControls)
              Center(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 40,
              left: 16,
              right: 16,
              child: _showControls
                  ? VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: AppTheme.primary,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white12,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
