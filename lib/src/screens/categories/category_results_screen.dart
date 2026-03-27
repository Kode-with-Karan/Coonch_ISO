import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/subscription_dialog.dart';
import 'course_detail_screen.dart';
import '../../theme.dart';
import '../../utils/content_access.dart';

class CategoryResultsScreen extends StatefulWidget {
  final int? categoryId;
  final String categoryName;
  final Color categoryColor;
  final bool isThisWeek;

  const CategoryResultsScreen({
    Key? key,
    this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    this.isThisWeek = false,
  }) : super(key: key);

  @override
  State<CategoryResultsScreen> createState() => _CategoryResultsScreenState();
}

class _CategoryResultsScreenState extends State<CategoryResultsScreen> {
  List<dynamic> _courses = [];
  List<dynamic> _filteredCourses = [];
  bool _loading = true;
  String _selectedFilter = 'all';
  String _selectedSort = 'newest';

  final List<String> _filters = ['all', 'free', 'paid'];
  final List<String> _sortOptions = [
    'newest',
    'oldest',
    'price_low',
    'price_high'
  ];

  void _pushPage(Widget page) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCourses();
      }
    });
  }

  Future<void> _loadCourses() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final queryParams = <String, String>{};

      // Filter by category if provided
      if (widget.categoryId != null && widget.categoryId! > 0) {
        queryParams['category'] = widget.categoryId.toString();
      }

      // Only add topic filter if not filtering by specific category
      if (widget.categoryId == null || widget.categoryId! <= 0) {
        queryParams['topic'] = 'education';
      }

      if (widget.isThisWeek) {
        final now = DateTime.now();
        final weekAgo = now.subtract(const Duration(days: 7));
        queryParams['created_after'] = weekAgo.toIso8601String().split('T')[0];
      }

      final contents = await api.getContents(queryParams: queryParams);
      if (!mounted) return;

      // Filter content to ensure it matches the category exactly
      List<dynamic> filteredContents = [];
      bool hasCategoryField = false;

      if (contents.isNotEmpty) {
        // First check if any content has category metadata
        hasCategoryField = contents.any((content) {
          if (content is Map) {
            return content.containsKey('category') ||
                content.containsKey('category_id');
          }
          return false;
        });

        if (hasCategoryField) {
          filteredContents = contents.where((content) {
            if (content is Map) {
              final cat = content['category'];
              if (cat is int) return cat == widget.categoryId;
              if (cat is String) {
                final parsed = int.tryParse(cat);
                if (parsed != null) return parsed == widget.categoryId;
              }
              if (cat is Map && cat['id'] != null) {
                final id = cat['id'];
                if (id is int) return id == widget.categoryId;
                if (id is String) return int.tryParse(id) == widget.categoryId;
              }

              final cid = content['category_id'];
              if (cid is int) return cid == widget.categoryId;
              if (cid is String) return int.tryParse(cid) == widget.categoryId;
            }
            return false;
          }).toList();
        }
      }

      setState(() {
        // If we found content with category metadata, use filtered results
        // Otherwise use all content returned from API
        if (hasCategoryField) {
          _courses = filteredContents;
        } else {
          _courses = contents;
        }
        _applyFiltersAndSort();
        _loading = false;
      });
    } catch (e) {
      print('Error loading category courses: $e');
      if (!mounted) return;
      setState(() {
        _courses = [];
        _filteredCourses = [];
        _loading = false;
      });
    }
  }

  void _applyFiltersAndSort() {
    List<dynamic> result = List.from(_courses);

    // Apply filter
    if (_selectedFilter == 'free') {
      result = result.where((course) {
        final free = course['free'];
        final price = course['price'];
        return free == true ||
            free == 'true' ||
            price == 0 ||
            price == '0' ||
            price == null;
      }).toList();
    } else if (_selectedFilter == 'paid') {
      result = result.where((course) {
        final free = course['free'];
        final price = course['price'];
        return (free != true && free != 'true') &&
            (price != null && price != 0 && price != '0');
      }).toList();
    }

    // Apply sort
    if (_selectedSort == 'newest') {
      result.sort((a, b) {
        final dateA = a['created_at'] ?? a['createdAt'] ?? '';
        final dateB = b['created_at'] ?? b['createdAt'] ?? '';
        return dateB.toString().compareTo(dateA.toString());
      });
    } else if (_selectedSort == 'oldest') {
      result.sort((a, b) {
        final dateA = a['created_at'] ?? a['createdAt'] ?? '';
        final dateB = b['created_at'] ?? b['createdAt'] ?? '';
        return dateA.toString().compareTo(dateB.toString());
      });
    } else if (_selectedSort == 'price_low') {
      result.sort((a, b) {
        final priceA = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
        final priceB = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
        return priceA.compareTo(priceB);
      });
    } else if (_selectedSort == 'price_high') {
      result.sort((a, b) {
        final priceA = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
        final priceB = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
        return priceB.compareTo(priceA);
      });
    }

    setState(() {
      _filteredCourses = result;
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter & Sort',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Filter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return ChoiceChip(
                        label: Text(filter == 'all'
                            ? 'All'
                            : filter == 'free'
                                ? 'Free'
                                : 'Paid'),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedFilter = filter;
                          });
                          setState(() {});
                        },
                        selectedColor: widget.categoryColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? widget.categoryColor
                              : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    children: _sortOptions.map((sort) {
                      final isSelected = _selectedSort == sort;
                      String label;
                      switch (sort) {
                        case 'newest':
                          label = 'Newest';
                          break;
                        case 'oldest':
                          label = 'Oldest';
                          break;
                        case 'price_low':
                          label = 'Price: Low to High';
                          break;
                        case 'price_high':
                          label = 'Price: High to Low';
                          break;
                        default:
                          label = sort;
                      }
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedSort = sort;
                          });
                          setState(() {});
                        },
                        selectedColor: widget.categoryColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? widget.categoryColor
                              : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFiltersAndSort();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.categoryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

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

  String _getCourseDuration(dynamic course) {
    if (course is Map) {
      final duration = course['duration'];
      if (duration != null) {
        return duration.toString();
      }
    }
    return '30h 15min';
  }

  String _getCoursePrice(dynamic course) {
    if (course is Map) {
      final price = course['price'];
      final free = course['free'];
      if (free == true || free == 'true') {
        return 'Free';
      }
      if (price != null) {
        final priceStr = price.toString();
        final priceValue = double.tryParse(priceStr);
        if (priceValue != null && priceValue > 0) {
          return '£$priceValue';
        }
      }
    }
    return 'Free';
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

  Color _getCourseColor(int index) {
    final colors = [
      widget.categoryColor,
      widget.categoryColor.withOpacity(0.8),
      widget.categoryColor.withOpacity(0.6),
      const Color(0xFFFFD89C),
      const Color(0xFF7B8FFF),
      const Color(0xFFFF9B9B),
    ];
    return colors[index % colors.length];
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('it') ||
        name.contains('computer') ||
        name.contains('tech')) {
      return Icons.computer;
    } else if (name.contains('astrology')) {
      return Icons.stars;
    } else if (name.contains('architecture')) {
      return Icons.architecture;
    } else if (name.contains('quiz')) {
      return Icons.quiz;
    } else if (name.contains('motivational') || name.contains('motivation')) {
      return Icons.campaign;
    } else if (name.contains("let's talk") || name.contains('talk')) {
      return Icons.chat;
    } else if (name.contains('sharing information') ||
        name.contains('information')) {
      return Icons.info;
    } else if (name.contains('psychology')) {
      return Icons.psychology;
    } else if (name.contains('career') || name.contains('job')) {
      return Icons.work;
    } else if (name.contains('mental health')) {
      return Icons.health_and_safety;
    } else if (name.contains('storytelling') || name.contains('story')) {
      return Icons.auto_stories;
    } else if (name.contains('sketch')) {
      return Icons.draw;
    } else if (name.contains('cartoon')) {
      return Icons.animation;
    } else if (name.contains('animation')) {
      return Icons.movie;
    } else if (name.contains('dance')) {
      return Icons.music_note;
    } else if (name.contains('music')) {
      return Icons.music_note;
    } else if (name.contains('general')) {
      return Icons.topic;
    } else if (name.contains('book')) {
      return Icons.menu_book;
    } else if (name.contains('discussion')) {
      return Icons.forum;
    } else if (name.contains('question') ||
        name.contains('answer') ||
        name.contains('q&a')) {
      return Icons.question_answer;
    } else if (name.contains('episode') || name.contains('life')) {
      return Icons.podcasts;
    } else if (name.contains('incident')) {
      return Icons.warning;
    } else if (name.contains('blog')) {
      return Icons.article;
    } else if (name.contains('diary') || name.contains('journal')) {
      return Icons.book;
    } else if (name.contains('review')) {
      return Icons.rate_review;
    } else if (name.contains('article')) {
      return Icons.description;
    } else if (name.contains('historical') || name.contains('history')) {
      return Icons.history_edu;
    } else if (name.contains('poetry') || name.contains('poem')) {
      return Icons.edit_note;
    } else if (name.contains('script')) {
      return Icons.code;
    } else if (name.contains('comic')) {
      return Icons.auto_awesome_mosaic;
    } else if (name.contains('short')) {
      return Icons.short_text;
    } else if (name.contains('biography')) {
      return Icons.person;
    } else if (name.contains('non fiction') || name.contains('non-fiction')) {
      return Icons.menu_book;
    } else if (name.contains('fiction')) {
      return Icons.auto_stories;
    } else if (name.contains('science')) {
      return Icons.science;
    } else if (name.contains('entertainment')) {
      return Icons.movie;
    } else if (name.contains('physics')) {
      return Icons.science;
    } else if (name.contains('geography')) {
      return Icons.public;
    } else if (name.contains('math')) {
      return Icons.calculate;
    } else {
      return Icons.school;
    }
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
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category illustration/header
                  Container(
                    margin: const EdgeInsets.all(24),
                    height: 220,
                    decoration: BoxDecoration(
                      color: widget.categoryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [
                          widget.categoryColor.withOpacity(0.2),
                          widget.categoryColor.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _getCategoryIcon(widget.categoryName),
                        size: 100,
                        color: widget.categoryColor,
                      ),
                    ),
                  ),
                  // Category title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      widget.categoryName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Results count and filter
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_filteredCourses.length} Results',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[600],
                          ),
                        ),
                        GestureDetector(
                          onTap: _showFilterSheet,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE0F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.tune,
                              color: Color(0xFFFF8C42),
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Course list
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _loading
                        ? const Center(
                            heightFactor: 5, child: CircularProgressIndicator())
                        : _filteredCourses.isEmpty
                            ? Center(
                                heightFactor: 5,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _getCategoryIcon(widget.categoryName),
                                      size: 64,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No content yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Check back later for new content',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ))
                            : Column(
                                children: _filteredCourses
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final index = entry.key;
                                  final course = entry.value;
                                  final courseId = _getCourseId(course);
                                  final title = _getCourseTitle(course);
                                  final duration = _getCourseDuration(course);
                                  final price = _getCoursePrice(course);
                                  final color = _getCourseColor(index);
                                  final icon = _getCourseIcon(title);

                                  return _buildCourseItem(
                                    courseData: course,
                                    courseId: courseId,
                                    title: title,
                                    duration: duration,
                                    price: price,
                                    color: color,
                                    icon: icon,
                                  );
                                }).toList(),
                              ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseItem({
    required dynamic courseData,
    required String courseId,
    required String title,
    required String duration,
    required String price,
    required Color color,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () async {
        final content = _asContentMap(courseData);
        if (content != null && isLockedContent(content)) {
          await _openLockedPaidContent(content);
          return;
        }
        _pushPage(CourseDetailScreen(
          courseId: courseId,
          courseTitle: title,
          duration: duration,
          price: price,
          color: color,
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            // Course thumbnail
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: 36,
              ),
            ),
            const SizedBox(width: 16),
            // Course details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: AppTheme.primaryDark,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        duration,
                        style: TextStyle(
                          fontSize: 14,
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
                fontSize: 20,
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
