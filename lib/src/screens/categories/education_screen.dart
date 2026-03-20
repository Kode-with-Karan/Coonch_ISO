import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_navbar.dart';
import '../../widgets/subscription_dialog.dart';
import '../../theme.dart';
import 'course_detail_screen.dart';
import 'category_results_screen.dart';
import '../teacher_profile_screen.dart';
import 'all_categories.dart';
import 'all_series_screen.dart';
import '../notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../../utils/content_access.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({Key? key}) : super(key: key);

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _thisWeekCourses = [];
  List<dynamic> _popularCourses = [];
  List<dynamic> _categories = [];
  List<dynamic> _series = [];
  List<dynamic> _searchResults = [];
  bool _loadingCourses = true;
  bool _loadingCategories = true;
  bool _searching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Delay API calls until after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      await Future.wait([
        _loadCourses(),
        _loadCategories(),
        _loadSeries(),
      ]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadSeries() async {
    if (!mounted) return;
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final seriesList =
          await api.getSeries(queryParams: {'topic': 'education'});
      if (!mounted) return;
      setState(() {
        _series = seriesList;
      });
    } catch (e) {
      print('Error loading series: $e');
    }
  }

  Future<void> _loadCourses() async {
    if (!mounted) return;
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      // Try education topic first; if none returned, fall back to all content
      List<dynamic> contents =
          await api.getContents(queryParams: {'topic': 'education'});
      if (contents.isEmpty) {
        contents = await api.getContents();
      }
      if (!mounted) return;
      setState(() {
        if (contents.isNotEmpty) {
          // Split courses: first 3 for "This week", rest for "Popular courses"
          _thisWeekCourses = contents.take(3).toList();
          _popularCourses = contents.skip(3).take(5).toList();
        }
        _loadingCourses = false;
      });
    } catch (e) {
      print('Error loading courses: $e');
      if (!mounted) return;
      setState(() {
        _loadingCourses = false;
        _thisWeekCourses = [];
        _popularCourses = [];
      });
    }
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final cats = await api.getCategories();
      if (!mounted) return;
      setState(() {
        if (cats.isNotEmpty) {
          _categories =
              cats.take(4).toList(); // Take first 4 for horizontal list
        }
        _loadingCategories = false;
      });
    } catch (e) {
      print('Error loading categories: $e');
      if (!mounted) return;
      setState(() {
        _loadingCategories = false;
        _categories = [];
      });
    }
  }

  Future<void> _handleSearch(String query) async {
    final text = query.trim();
    if (!mounted) return;
    if (text.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setState(() {
      _searchQuery = text;
      _searching = true;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final contents =
          await api.getContents(queryParams: {'topic': 'education'});
      if (!mounted) return;

      final lower = text.toLowerCase();
      final filtered = contents.where((c) {
        if (c is! Map) return false;
        final topic = (c['topic'] ?? '').toString().toLowerCase();
        if (topic.isNotEmpty && topic != 'education') return false;
        final caption = (c['caption'] ?? '').toString().toLowerCase();
        final title = (c['title'] ?? '').toString().toLowerCase();
        final name = (c['name'] ?? '').toString().toLowerCase();
        return caption.contains(lower) ||
            title.contains(lower) ||
            name.contains(lower);
      }).toList();

      setState(() {
        _searchResults = filtered;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _searching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getUserName() {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.user;
      if (user is Map) {
        // Normalize dynamic map to a safely-typed map for indexing
        final Map<dynamic, dynamic> map = user as Map<dynamic, dynamic>;
        final dynamic name = map['name'] ?? map['username'] ?? map['full_name'];
        if (name != null && name.toString().trim().isNotEmpty) {
          return name.toString().split(' ').first;
        }
      }
    } catch (e) {
      print('Error getting user name: $e');
    }
    return 'Student';
  }

  // Helper methods to extract data from backend objects
  String _getCourseId(dynamic course) {
    if (course is Map) {
      return (course['id'] ?? '').toString();
    }
    return '';
  }

  String _getCourseTitle(dynamic course) {
    if (course is Map) {
      return (course['title'] ?? course['caption'] ?? course['name'] ?? '')
          .toString();
    }
    return '';
  }

  String _getCourseInstructor(dynamic course) {
    if (course is Map) {
      // API sometimes uses `user` for the owner, sometimes `creator`.
      final owner = course['user'] ?? course['creator'];
      if (owner is Map) {
        final name = owner['name'] ?? owner['username'] ?? owner['first_name'];
        if (name != null) return name.toString();
      }
      return '';
    }
    return '';
  }

  String? _formatPaidPrice(dynamic price) {
    if (price == null) return null;
    final priceValue = double.tryParse(price.toString());
    if (priceValue == null || priceValue <= 0) return null;

    final formatted = priceValue == priceValue.truncateToDouble()
        ? priceValue.toStringAsFixed(0)
        : priceValue.toStringAsFixed(2);
    return '£$formatted';
  }

  String _getCoursePrice(dynamic course) {
    if (course is Map) {
      final price = course['price'];
      final free = course['free'];
      if (free == true || free == 'true') {
        return 'Free';
      }
      final paidPrice = _formatPaidPrice(price);
      if (paidPrice != null) {
        return paidPrice;
      }
    }
    return 'Free';
  }

  String _getCourseRating(dynamic course) {
    if (course is Map) {
      final rating = course['rating'];
      if (rating != null) {
        return rating.toString();
      }
    }
    return '4.5';
  }

  Map<String, dynamic>? _asContentMap(dynamic course) {
    if (course is Map<String, dynamic>) return course;
    if (course is Map) return Map<String, dynamic>.from(course);
    return null;
  }

  Future<void> _openLockedPaidContent(dynamic course) async {
    final content = _asContentMap(course);
    if (content == null || !isLockedContent(content) || !mounted) {
      return;
    }

    await showSubscriptionRequiredDialog(context, content: content);
  }

  String _getCourseDuration(dynamic course) {
    if (course is Map) {
      final type = course['type']?.toString().toLowerCase();

      // For text content, show word count
      if (type == 'text') {
        final wordCount = course['word_count'];
        if (wordCount != null) {
          return '$wordCount words';
        }
        // Try alternate field name
        final words = course['words'];
        if (words != null) {
          return '$words words';
        }
      }

      // For video/audio content, show duration
      // Check multiple possible field names
      final duration = course['duration_seconds'] ??
          course['duration'] ??
          course['duration_seconds'];
      if (duration != null) {
        final seconds = int.tryParse(duration.toString()) ?? 0;
        if (seconds > 0) {
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
      }
    }
    return 'N/A';
  }

  String? _getCourseImage(dynamic course) {
    if (course is Map) {
      final thumb = course['thumbnail_url'] ?? course['thumbnail'];
      if (thumb != null && thumb.toString().isNotEmpty) {
        return thumb.toString();
      }
      final file = course['file_url'] ?? course['file'];
      if (file != null && file.toString().isNotEmpty) {
        return file.toString();
      }
    }
    return null;
  }

  String _getCourseType(dynamic course) {
    if (course is Map) {
      final type = (course['type'] ?? '').toString().toLowerCase();
      return type;
    }
    return '';
  }

  Color _getCourseColor(int index) {
    final colors = [
      AppTheme.primary,
      AppTheme.primaryDark,
      AppTheme.primaryMuted,
      const Color(0xFF64A3FF),
      const Color(0xFF9BC8FF),
      const Color(0xFFCFE4FF),
    ];
    return colors[index % colors.length];
  }

  IconData _getCourseIcon(String title) {
    final titleLower = title.toLowerCase();
    if (titleLower.contains('ui') ||
        titleLower.contains('ux') ||
        titleLower.contains('design')) {
      return Icons.design_services;
    } else if (titleLower.contains('web') ||
        titleLower.contains('html') ||
        titleLower.contains('css')) {
      return Icons.web;
    } else if (titleLower.contains('development') ||
        titleLower.contains('code') ||
        titleLower.contains('programming')) {
      return Icons.code;
    } else if (titleLower.contains('graphic') || titleLower.contains('photo')) {
      return Icons.palette;
    } else if (titleLower.contains('market')) {
      return Icons.campaign;
    } else {
      return Icons.school;
    }
  }

  int _getCategoryId(dynamic category) {
    if (category is Map) {
      return category['id'] ?? 0;
    }
    return 0;
  }

  String? _getCategoryImage(dynamic category) {
    if (category is Map && category['image_url'] != null) {
      return category['image_url'].toString();
    }
    return null;
  }

  String _getCategoryName(dynamic category) {
    if (category is Map) {
      return (category['name'] ?? 'Category').toString();
    }
    return 'Category';
  }

  IconData _getCategoryIcon(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('it') ||
        nameLower.contains('computer') ||
        nameLower.contains('tech')) {
      return Icons.computer_outlined;
    } else if (nameLower.contains('astrology')) {
      return Icons.stars_outlined;
    } else if (nameLower.contains('architecture')) {
      return Icons.architecture_outlined;
    } else if (nameLower.contains('quiz')) {
      return Icons.quiz_outlined;
    } else if (nameLower.contains('motivational') ||
        nameLower.contains('motivation')) {
      return Icons.campaign_outlined;
    } else if (nameLower.contains("let's talk") || nameLower.contains('talk')) {
      return Icons.chat_outlined;
    } else if (nameLower.contains('sharing information') ||
        nameLower.contains('information')) {
      return Icons.info_outlined;
    } else if (nameLower.contains('psychology')) {
      return Icons.psychology_outlined;
    } else if (nameLower.contains('career') || nameLower.contains('job')) {
      return Icons.work_outlined;
    } else if (nameLower.contains('mental health')) {
      return Icons.health_and_safety_outlined;
    } else if (nameLower.contains('storytelling') ||
        nameLower.contains('story')) {
      return Icons.auto_stories_outlined;
    } else if (nameLower.contains('sketch')) {
      return Icons.draw_outlined;
    } else if (nameLower.contains('cartoon')) {
      return Icons.animation_outlined;
    } else if (nameLower.contains('animation')) {
      return Icons.movie_outlined;
    } else if (nameLower.contains('dance') || nameLower.contains('dancing')) {
      return Icons.music_note_outlined;
    } else if (nameLower.contains('music')) {
      return Icons.music_note_outlined;
    } else if (nameLower.contains('general')) {
      return Icons.topic_outlined;
    } else if (nameLower.contains('book')) {
      return Icons.menu_book_outlined;
    } else if (nameLower.contains('discussion')) {
      return Icons.forum_outlined;
    } else if (nameLower.contains('question') ||
        nameLower.contains('answer') ||
        nameLower.contains('q&a')) {
      return Icons.question_answer_outlined;
    } else if (nameLower.contains('episode') || nameLower.contains('life')) {
      return Icons.podcasts_outlined;
    } else if (nameLower.contains('incident')) {
      return Icons.warning_outlined;
    } else if (nameLower.contains('blog')) {
      return Icons.article_outlined;
    } else if (nameLower.contains('diary') || nameLower.contains('journal')) {
      return Icons.book_outlined;
    } else if (nameLower.contains('review')) {
      return Icons.rate_review_outlined;
    } else if (nameLower.contains('article')) {
      return Icons.description_outlined;
    } else if (nameLower.contains('historical') ||
        nameLower.contains('history')) {
      return Icons.history_edu_outlined;
    } else if (nameLower.contains('poetry') || nameLower.contains('poem')) {
      return Icons.edit_note_outlined;
    } else if (nameLower.contains('script')) {
      return Icons.code_outlined;
    } else if (nameLower.contains('comic')) {
      return Icons.auto_awesome_mosaic_outlined;
    } else if (nameLower.contains('short')) {
      return Icons.short_text_outlined;
    } else if (nameLower.contains('biography')) {
      return Icons.person_outlined;
    } else if (nameLower.contains('non fiction') ||
        nameLower.contains('non-fiction')) {
      return Icons.menu_book_outlined;
    } else if (nameLower.contains('fiction')) {
      return Icons.auto_stories_outlined;
    } else if (nameLower.contains('science')) {
      return Icons.science_outlined;
    } else if (nameLower.contains('entertainment')) {
      return Icons.movie_outlined;
    } else if (nameLower.contains('physics')) {
      return Icons.science_outlined;
    } else if (nameLower.contains('geography')) {
      return Icons.public_outlined;
    } else if (nameLower.contains('math')) {
      return Icons.calculate_outlined;
    } else if (nameLower.contains('design') ||
        nameLower.contains('ui') ||
        nameLower.contains('ux')) {
      return Icons.palette_outlined;
    } else if (nameLower.contains('illustr')) {
      return Icons.brush_outlined;
    } else if (nameLower.contains('web') ||
        nameLower.contains('coding') ||
        nameLower.contains('programming')) {
      return Icons.code_outlined;
    } else if (nameLower.contains('market')) {
      return Icons.campaign_outlined;
    } else if (nameLower.contains('photo') ||
        nameLower.contains('camera') ||
        nameLower.contains('image')) {
      return Icons.camera_alt_outlined;
    } else if (nameLower.contains('video') ||
        nameLower.contains('film') ||
        nameLower.contains('movie')) {
      return Icons.videocam_outlined;
    } else if (nameLower.contains('music') ||
        nameLower.contains('audio') ||
        nameLower.contains('sound')) {
      return Icons.music_note_outlined;
    } else if (nameLower.contains('business') ||
        nameLower.contains('entrepreneur')) {
      return Icons.business_center_outlined;
    } else if (nameLower.contains('language') ||
        nameLower.contains('english') ||
        nameLower.contains('spanish')) {
      return Icons.translate_outlined;
    } else if (nameLower.contains('health') ||
        nameLower.contains('fitness') ||
        nameLower.contains('yoga')) {
      return Icons.fitness_center_outlined;
    } else if (nameLower.contains('food') ||
        nameLower.contains('cook') ||
        nameLower.contains('recipe')) {
      return Icons.restaurant_outlined;
    } else if (nameLower.contains('travel') || nameLower.contains('tourism')) {
      return Icons.flight_outlined;
    } else if (nameLower.contains('fashion') || nameLower.contains('style')) {
      return Icons.checkroom_outlined;
    } else if (nameLower.contains('game') || nameLower.contains('gaming')) {
      return Icons.sports_esports_outlined;
    } else if (nameLower.contains('data') || nameLower.contains('analytics')) {
      return Icons.analytics_outlined;
    } else if (nameLower.contains('ai') ||
        nameLower.contains('machine learning') ||
        nameLower.contains('ml')) {
      return Icons.psychology_outlined;
    } else if (nameLower.contains('mobile') || nameLower.contains('app')) {
      return Icons.phone_android_outlined;
    } else if (nameLower.contains('social') || nameLower.contains('media')) {
      return Icons.share_outlined;
    } else if (nameLower.contains('money') ||
        nameLower.contains('finance') ||
        nameLower.contains('invest')) {
      return Icons.attach_money_outlined;
    } else {
      return Icons.category_outlined;
    }
  }

  Color _getCategoryColor(int index) {
    final colors = [
      AppTheme.primary,
      AppTheme.primaryDark,
      AppTheme.primaryMuted,
      const Color(0xFF64A3FF),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final userName = _getUserName();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Blue gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row with greeting and icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi $userName,',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Lets Start Learning',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Settings
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.settings_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Notification icon with badge
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(
                                      Icons.notifications_outlined,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    Positioned(
                                      right: -4,
                                      top: -4,
                                      child: Consumer<AuthProvider>(
                                        builder: (_, auth, __) {
                                          final count =
                                              auth.unreadNotifications;
                                          if (count <= 0) {
                                            return const SizedBox.shrink();
                                          }
                                          return Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: AppTheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 18,
                                              minHeight: 18,
                                            ),
                                            child: Center(
                                              child: Text(
                                                count > 99 ? '99+' : '$count',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Search bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey[400], size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onSubmitted: _handleSearch,
                              onChanged: (value) {
                                setState(
                                    () {}); // Rebuild to show/hide clear button
                              },
                              decoration: InputDecoration(
                                hintText: 'Search for Topics, Courses',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.grey[400], size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _searchResults = [];
                                  _searching = false;
                                });
                              },
                            )
                          else
                            IconButton(
                              icon: Icon(Icons.search,
                                  color: Colors.grey[400], size: 24),
                              onPressed: () =>
                                  _handleSearch(_searchController.text),
                            ),
                        ],
                      ),
                    ),
                    if (_searchQuery.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      if (_searching)
                        const Center(child: CircularProgressIndicator())
                      else if (_searchResults.isEmpty)
                        const Text(
                          'No educational content matches your search.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Results for "$_searchQuery"',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 260,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final course = _searchResults[index];
                              final color = _getCourseColor(index);
                              return _buildCourseCard(
                                courseData: course,
                                courseId: _getCourseId(course),
                                title: _getCourseTitle(course),
                                instructor: _getCourseInstructor(course),
                                price: _getCoursePrice(course),
                                rating: _getCourseRating(course),
                                duration: _getCourseDuration(course),
                                color: color,
                                imageUrl: _getCourseImage(course),
                                contentType: _getCourseType(course),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Series section
                  if (_series.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Series',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AllSeriesScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF8C42),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _series.length,
                        itemBuilder: (context, index) {
                          final seriesItem = _series[index];
                          return _buildSeriesCard(seriesItem);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // This week section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'This week',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CategoryResultsScreen(
                                categoryName: 'This Week',
                                categoryColor: AppTheme.primary,
                                isThisWeek: true,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF8C42),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Course cards
                  SizedBox(
                    height: 280,
                    child: _loadingCourses
                        ? const Center(child: CircularProgressIndicator())
                        : _thisWeekCourses.isEmpty
                            ? const SizedBox.shrink()
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _thisWeekCourses.length,
                                itemBuilder: (context, index) {
                                  final course = _thisWeekCourses[index];
                                  final courseId = _getCourseId(course);
                                  final title = _getCourseTitle(course);
                                  final instructor =
                                      _getCourseInstructor(course);
                                  final duration = _getCourseDuration(course);
                                  final price = _getCoursePrice(course);
                                  final rating = _getCourseRating(course);
                                  final color = _getCourseColor(index);
                                  final imageUrl = _getCourseImage(course);
                                  final contentType = _getCourseType(course);

                                  return _buildCourseCard(
                                    courseData: course,
                                    courseId: courseId,
                                    title: title,
                                    instructor: instructor,
                                    price: price,
                                    rating: rating,
                                    duration: duration,
                                    color: color,
                                    imageUrl: imageUrl,
                                    contentType: contentType,
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 32),
                  // Categories section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AllCategoriesScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF8C42),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Category cards
                  SizedBox(
                    height: 140,
                    child: _loadingCategories
                        ? const Center(child: CircularProgressIndicator())
                        : _categories.isEmpty
                            ? const SizedBox.shrink()
                            : ListView.builder(
                                padding: const EdgeInsets.only(right: 24),
                                scrollDirection: Axis.horizontal,
                                itemCount: _categories.length,
                                itemBuilder: (context, index) {
                                  final category = _categories[index];
                                  final categoryId = _getCategoryId(category);
                                  final name = _getCategoryName(category);
                                  final icon = _getCategoryIcon(name);
                                  final color = _getCategoryColor(index);

                                  return _buildCategoryCard(
                                    categoryId: categoryId,
                                    title: name,
                                    icon: icon,
                                    color: color,
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 32),
                  // Popular courses section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Popular courses',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CategoryResultsScreen(
                                categoryName: 'Popular',
                                categoryColor: Color(0xFFFF8C42),
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF8C42),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Popular course list
                  if (_loadingCourses)
                    const Center(child: CircularProgressIndicator())
                  else if (_popularCourses.isEmpty)
                    const SizedBox.shrink()
                  else
                    ..._popularCourses.map((course) {
                      final index = _popularCourses.indexOf(course);
                      final courseId = _getCourseId(course);
                      final title = _getCourseTitle(course);
                      final duration = _getCourseDuration(course);
                      final price = _getCoursePrice(course);
                      final color = _getCourseColor(index);
                      final icon = _getCourseIcon(title);
                      final imageUrl = _getCourseImage(course);
                      final contentType = _getCourseType(course);

                      return _buildPopularCourse(
                        courseData: course,
                        courseId: courseId,
                        title: title,
                        duration: duration,
                        price: price,
                        color: color,
                        icon: icon,
                        imageUrl: imageUrl,
                        contentType: contentType,
                      );
                    }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(activeIndex: 0),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: const AppFAB(onPressed: null),
    );
  }

  Widget _buildSeriesCard(dynamic series) {
    final seriesId = series['id']?.toString() ?? '';
    final title = series['title']?.toString() ?? 'Untitled Series';
    final itemsCount = series['items_count'] ?? 0;
    final thumbnailUrl = series['thumbnail_url'];
    final user = series['user'];
    final creatorName =
        user != null ? (user['name'] ?? user['username'] ?? '') : '';

    return GestureDetector(
      onTap: () async {
        if (seriesId.isEmpty) return;

        final api = Provider.of<ApiService>(context, listen: false);

        try {
          final seriesData = await api.getSeriesById(seriesId);
          if (!mounted) return;

          final items = seriesData['items'] as List<dynamic>? ?? [];
          if (items.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No items in this series')),
            );
            return;
          }

          // Open the first item directly
          final firstItem = items.first;
          final contentId = firstItem['id']?.toString() ?? '';
          if (contentId.isEmpty) return;

          final firstContent = _asContentMap(firstItem);
          if (firstContent != null && isLockedContent(firstContent)) {
            await _openLockedPaidContent(firstContent);
            return;
          }

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(
                courseId: contentId,
                courseTitle: firstItem['caption']?.toString() ?? title,
                duration: firstItem['duration']?.toString() ?? '',
                price: _getCoursePrice(firstItem),
                color: AppTheme.primary,
              ),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load series: $e')),
          );
        }
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                color: AppTheme.primary.withOpacity(0.2),
              ),
              child: Stack(
                children: [
                  if (thumbnailUrl != null)
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        thumbnailUrl.toString(),
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.play_circle_outline,
                              size: 40, color: AppTheme.primaryDark),
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.play_circle_outline,
                          size: 40, color: AppTheme.primaryDark),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.playlist_play,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '$itemsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (creatorName.isNotEmpty)
                    Text(
                      'by $creatorName',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '$itemsCount episodes',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard({
    required dynamic courseData,
    required String courseId,
    required String title,
    required String instructor,
    required String price,
    required String rating,
    required String duration,
    required Color color,
    String? imageUrl,
    required String contentType,
  }) {
    IconData contentIcon;
    switch (contentType) {
      case 'video':
        contentIcon = Icons.videocam;
        break;
      case 'audio':
        contentIcon = Icons.audiotrack;
        break;
      case 'text':
        contentIcon = Icons.article;
        break;
      default:
        contentIcon = Icons.play_circle_outline;
    }

    return GestureDetector(
      onTap: () async {
        final content = _asContentMap(courseData);
        if (content != null && isLockedContent(content)) {
          await _openLockedPaidContent(content);
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourseDetailScreen(
              courseId: courseId,
              courseTitle: title,
              duration: duration,
              price: price,
              color: color,
            ),
          ),
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course image/thumbnail
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: color.withOpacity(0.15),
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withOpacity(0.7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                  ),
                  Center(
                    child: Icon(
                      contentIcon,
                      size: 50,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            contentIcon,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            contentType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: AppTheme.primaryDark,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Course title
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Instructor (show only when provided by API)
            if (instructor.isNotEmpty)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TeacherProfileScreen(
                        teacherName: instructor,
                        teacherTitle: 'Associate Editor',
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      instructor,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // Price
            Text(
              price,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required int categoryId,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    final imageUrl = _getCategoryImage(_categories.firstWhere(
        (c) => _getCategoryId(c) == categoryId,
        orElse: () => null));
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryResultsScreen(
              categoryId: categoryId,
              categoryName: title,
              categoryColor: color,
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: imageUrl != null
                  ? ClipOval(
                      child: Image.network(
                        imageUrl,
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(icon, color: color, size: 32),
                      ),
                    )
                  : Icon(
                      icon,
                      color: color,
                      size: 32,
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularCourse({
    required dynamic courseData,
    required String courseId,
    required String title,
    required String duration,
    required String price,
    required Color color,
    required IconData icon,
    String? imageUrl,
    required String contentType,
  }) {
    IconData contentIcon;
    switch (contentType) {
      case 'video':
        contentIcon = Icons.videocam;
        break;
      case 'audio':
        contentIcon = Icons.audiotrack;
        break;
      case 'text':
        contentIcon = Icons.article;
        break;
      default:
        contentIcon = Icons.play_circle_outline;
    }

    return GestureDetector(
      onTap: () async {
        final content = _asContentMap(courseData);
        if (content != null && isLockedContent(content)) {
          await _openLockedPaidContent(content);
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourseDetailScreen(
              courseId: courseId,
              courseTitle: title,
              duration: duration,
              price: price,
              color: color,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Course thumbnail
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
                            errorBuilder: (_, __, ___) =>
                                Icon(icon, color: color, size: 30),
                          ),
                        )
                      : Center(
                          child: Icon(
                            contentIcon,
                            color: color,
                            size: 30,
                          ),
                        ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        contentIcon,
                        size: 14,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Course details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Color(0xFFFF8C42),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        duration,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Price
            Text(
              price,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
