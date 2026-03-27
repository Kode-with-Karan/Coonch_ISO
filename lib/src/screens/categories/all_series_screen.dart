import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import 'series_detail_screen.dart';

class AllSeriesScreen extends StatefulWidget {
  const AllSeriesScreen({super.key});

  @override
  State<AllSeriesScreen> createState() => _AllSeriesScreenState();
}

class _AllSeriesScreenState extends State<AllSeriesScreen> {
  List<dynamic> _series = [];
  bool _loading = true;
  String? _error;

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
      _loadSeries();
    });
  }

  Future<void> _loadSeries() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final seriesList =
          await api.getSeries(queryParams: {'topic': 'education'});
      if (!mounted) return;
      setState(() {
        _series = seriesList;
        _loading = false;
      });
    } catch (e) {
      print('Error loading series: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load series';
      });
    }
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
        title: const Text(
          'All Series',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
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
                          onPressed: _loadSeries,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _series.isEmpty
                    ? const Center(child: Text('No series available'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _series.length,
                        itemBuilder: (context, index) {
                          final series = _series[index];
                          return _buildSeriesCard(series);
                        },
                      ),
      ),
    );
  }

  Widget _buildSeriesCard(dynamic series) {
    final seriesId = series['id']?.toString() ?? '';
    final title = series['title']?.toString() ?? 'Untitled Series';
    final description = series['description']?.toString() ?? '';
    final itemsCount = series['items_count'] ?? 0;
    final thumbnailUrl = series['thumbnail_url'];
    final user = series['user'];
    final creatorName =
        user != null ? (user['name'] ?? user['username'] ?? '') : '';

    return GestureDetector(
      onTap: () {
        if (seriesId.isEmpty) return;
        _pushPage(SeriesDetailScreen(
          seriesId: seriesId,
          initialTitle: title,
          accentColor: AppTheme.primary,
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
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
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            size: 48,
                            color: AppTheme.primary.withOpacity(0.6),
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 48,
                        color: AppTheme.primary.withOpacity(0.6),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$itemsCount items',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (creatorName.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.primary.withOpacity(0.2),
                          child: Text(
                            creatorName.isNotEmpty
                                ? creatorName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          creatorName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
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
}
