import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import 'category_content_screen.dart';

class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  List<dynamic> _categories = [];
  bool _loading = true;
  String? _error;

  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCategories();
      }
    });
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final cats = await api.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats ?? [];
        _loading = false;
      });
    } catch (e) {
      print('Error loading categories: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load categories';
        _categories = [];
      });
    }
  }

  IconData _getCategoryIcon(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('it') || nameLower.contains('computer') || nameLower.contains('tech')) {
      return Icons.computer;
    } else if (nameLower.contains('astrology')) {
      return Icons.stars;
    } else if (nameLower.contains('architecture')) {
      return Icons.architecture;
    } else if (nameLower.contains('quiz')) {
      return Icons.quiz;
    } else if (nameLower.contains('motivational') || nameLower.contains('motivation')) {
      return Icons.campaign;
    } else if (nameLower.contains("let's talk") || nameLower.contains('talk')) {
      return Icons.chat;
    } else if (nameLower.contains('sharing information') || nameLower.contains('information')) {
      return Icons.info;
    } else if (nameLower.contains('psychology')) {
      return Icons.psychology;
    } else if (nameLower.contains('career') || nameLower.contains('job')) {
      return Icons.work;
    } else if (nameLower.contains('mental health')) {
      return Icons.health_and_safety;
    } else if (nameLower.contains('storytelling') || nameLower.contains('story')) {
      return Icons.auto_stories;
    } else if (nameLower.contains('sketch')) {
      return Icons.draw;
    } else if (nameLower.contains('cartoon')) {
      return Icons.animation;
    } else if (nameLower.contains('animation')) {
      return Icons.movie;
    } else if (nameLower.contains('dance')) {
      return Icons.music_note;
    } else if (nameLower.contains('music')) {
      return Icons.music_note;
    } else if (nameLower.contains('general')) {
      return Icons.topic;
    } else if (nameLower.contains('book')) {
      return Icons.menu_book;
    } else if (nameLower.contains('discussion')) {
      return Icons.forum;
    } else if (nameLower.contains('question') || nameLower.contains('answer') || nameLower.contains('q&a')) {
      return Icons.question_answer;
    } else if (nameLower.contains('episode') || nameLower.contains('life')) {
      return Icons.podcasts;
    } else if (nameLower.contains('incident')) {
      return Icons.warning;
    } else if (nameLower.contains('blog')) {
      return Icons.article;
    } else if (nameLower.contains('diary') || nameLower.contains('journal')) {
      return Icons.book;
    } else if (nameLower.contains('review')) {
      return Icons.rate_review;
    } else if (nameLower.contains('article')) {
      return Icons.description;
    } else if (nameLower.contains('historical') || nameLower.contains('history')) {
      return Icons.history_edu;
    } else if (nameLower.contains('poetry') || nameLower.contains('poem')) {
      return Icons.edit_note;
    } else if (nameLower.contains('script')) {
      return Icons.code;
    } else if (nameLower.contains('comic')) {
      return Icons.auto_awesome_mosaic;
    } else if (nameLower.contains('short')) {
      return Icons.short_text;
    } else if (nameLower.contains('biography')) {
      return Icons.person;
    } else if (nameLower.contains('non fiction') || nameLower.contains('non-fiction')) {
      return Icons.menu_book;
    } else if (nameLower.contains('fiction')) {
      return Icons.auto_stories;
    } else if (nameLower.contains('science')) {
      return Icons.science;
    } else if (nameLower.contains('entertainment')) {
      return Icons.movie;
    } else if (nameLower.contains('physics')) {
      return Icons.science;
    } else if (nameLower.contains('geography')) {
      return Icons.public;
    } else if (nameLower.contains('math')) {
      return Icons.calculate;
    } else if (nameLower.contains('web') || nameLower.contains('design')) {
      return Icons.web;
    } else if (nameLower.contains('illustr')) {
      return Icons.brush;
    } else if (nameLower.contains('ui') || nameLower.contains('ux')) {
      return Icons.design_services;
    } else if (nameLower.contains('graphic')) {
      return Icons.auto_awesome;
    } else if (nameLower.contains('market')) {
      return Icons.campaign;
    } else if (nameLower.contains('writ')) {
      return Icons.article;
    } else if (nameLower.contains('video') || nameLower.contains('film')) {
      return Icons.videocam;
    } else if (nameLower.contains('photo')) {
      return Icons.camera_alt;
    } else {
      return Icons.category;
    }
  }

  Color _getCategoryColor(int index) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Choose Categories',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 32),
              // Grid of category cards
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!,
                                    style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _loadCategories,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _categories.isEmpty
                            ? const Center(
                                child: Text('No categories available'))
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 18,
                                  crossAxisSpacing: 18,
                                  childAspectRatio: 1.1,
                                ),
                                itemCount: _categories.length,
                                itemBuilder: (context, index) {
                                  final c = _categories[index];
                                  final id = (c is Map && c['id'] != null)
                                      ? (c['id'] as int)
                                      : null;
                                  final name = (c is Map && c['name'] != null)
                                      ? c['name'].toString()
                                      : 'Category';
                                  final selected = _selected.contains(name);
                                  final icon = _getCategoryIcon(name);
                                  final color = _getCategoryColor(index);

                                  return GestureDetector(
                                    onTap: () {
                                      if (id != null) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                CategoryContentScreen(
                                              categoryId: id,
                                              categoryName: name,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.primarySoft,
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: selected
                                              ? AppTheme.primary
                                              : AppTheme.primaryMuted,
                                          width: 2,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? AppTheme.primary
                                                      .withValues(alpha: 0.12)
                                                  : Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              icon,
                                              size: 40,
                                              color: selected
                                                  ? AppTheme.primaryDark
                                                  : AppTheme.primaryDark,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8.0),
                                            child: Text(
                                              name,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
