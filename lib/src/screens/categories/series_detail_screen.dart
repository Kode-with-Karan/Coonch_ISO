import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../theme.dart';
import 'course_detail_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({
    super.key,
    required this.seriesId,
    this.initialTitle,
    this.accentColor = AppTheme.primary,
  });

  final String seriesId;
  final String? initialTitle;
  final Color accentColor;

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _series;
  List<dynamic> _items = [];
  List<String> _tabTypes = [];
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    // Load series data after the widget is built to allow immediate navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSeries();
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadSeries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.getSeriesById(widget.seriesId);
      if (!mounted) return;

      final items = (data['items'] as List<dynamic>?) ?? [];
      final tabTypes = _buildTabTypes(items);
      _tabController?.dispose();
      _tabController = TabController(length: tabTypes.length, vsync: this);

      setState(() {
        _series = data;
        _items = items;
        _tabTypes = tabTypes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load series';
      });
    }
  }

  List<String> _buildTabTypes(List<dynamic> items) {
    final hasVideo = items.any((item) => _itemType(item) == 'video');
    final hasText = items.any((item) {
      final t = _itemType(item);
      return t == 'text' || t == 'article';
    });
    final hasAudio = items.any((item) => _itemType(item) == 'audio');

    final order = <String>[];
    if (hasVideo) order.add('video');
    if (hasText) order.add('text');
    if (hasAudio) order.add('audio');
    return order.isEmpty ? ['all'] : order;
  }

  String _itemType(dynamic item) {
    final raw = (item is Map && item['type'] != null)
        ? item['type'].toString().toLowerCase()
        : '';
    return raw;
  }

  List<dynamic> _itemsForType(String type) {
    if (type == 'all') return _items;
    if (type == 'text') {
      return _items.where((item) {
        final t = _itemType(item);
        return t == 'text' || t == 'article';
      }).toList();
    }
    return _items
        .where((item) => _itemType(item) == type)
        .toList(growable: false);
  }

  String _itemTitle(dynamic item) {
    if (item is! Map) return '';
    return (item['caption'] ?? item['title'] ?? item['name'] ?? '').toString();
  }

  String _itemSubtitle(dynamic item) {
    if (item is! Map) return '';
    return (item['description'] ?? '').toString();
  }

  String? _itemThumbnail(dynamic item) {
    if (item is! Map) return null;
    final thumb =
        item['thumbnail_url'] ?? item['thumbnail'] ?? item['image_url'];
    if (thumb != null && thumb.toString().isNotEmpty) return thumb.toString();
    final file = item['file_url'] ?? item['file'] ?? item['video_url'];
    if (file != null && file.toString().isNotEmpty) return file.toString();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = (_series?['title'] ?? widget.initialTitle ?? '').toString();
    final description = (_series?['description'] ?? '').toString();
    final user = _series?['user'];
    final creatorName = (user is Map)
        ? (user['name'] ?? user['username'] ?? '').toString()
        : '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          title.isEmpty ? 'Series' : title,
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _series == null
                    ? const Center(child: Text('Series not found'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (creatorName.isNotEmpty) ...[
                                  Text(
                                    creatorName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                if (title.isNotEmpty)
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    description,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_tabTypes.isNotEmpty)
                            TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              labelColor: widget.accentColor,
                              unselectedLabelColor: Colors.black54,
                              indicatorColor: widget.accentColor,
                              tabs: _tabTypes
                                  .map((t) => Tab(
                                      text:
                                          t[0].toUpperCase() + t.substring(1)))
                                  .toList(),
                            ),
                          Expanded(
                            child: _tabTypes.isEmpty
                                ? const Center(child: Text('No items'))
                                : TabBarView(
                                    controller: _tabController,
                                    children: _tabTypes
                                        .map((type) => _buildItemsList(
                                            _itemsForType(type)))
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildItemsList(List<dynamic> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No items in this tab'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final type = _itemType(item);
        final title = _itemTitle(item);
        final subtitle = _itemSubtitle(item);
        final thumb = _itemThumbnail(item);
        final contentId =
            (item is Map && item['id'] != null) ? item['id'].toString() : '';

        return GestureDetector(
          onTap: () {
            if (contentId.isEmpty) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CourseDetailScreen(
                  courseId: contentId,
                  courseTitle: title,
                  duration:
                      item is Map ? (item['duration']?.toString() ?? '') : '',
                  price: '',
                  color: widget.accentColor,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 110,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16)),
                    child: thumb != null
                        ? Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _iconForType(type),
                          )
                        : _iconForType(type),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _chip(type.toUpperCase()),
                            const SizedBox(width: 8),
                            if (item is Map && item['duration'] != null)
                              _chip(item['duration'].toString()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: widget.accentColor,
        ),
      ),
    );
  }

  Widget _iconForType(String type) {
    IconData icon;
    switch (type) {
      case 'audio':
        icon = Icons.audiotrack;
        break;
      case 'text':
      case 'article':
        icon = Icons.notes;
        break;
      default:
        icon = Icons.play_circle_fill;
    }
    return Center(
      child: Icon(icon, size: 32, color: widget.accentColor.withOpacity(0.8)),
    );
  }
}
