import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../theme.dart';
import 'course_detail_screen.dart';
import '../upload/upload_content_screen.dart';

class SeriesEditScreen extends StatefulWidget {
  const SeriesEditScreen({
    super.key,
    required this.seriesId,
    this.initialTitle,
  });

  final String seriesId;
  final String? initialTitle;

  @override
  State<SeriesEditScreen> createState() => _SeriesEditScreenState();
}

class _SeriesEditScreenState extends State<SeriesEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _externalIdController = TextEditingController();

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _series;
  List<dynamic> _items = [];
  final Map<String, Map<String, TextEditingController>> _itemControllers = {};
  bool _savingSeries = false;
  final Map<String, bool> _savingItem = {};

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _externalIdController.dispose();
    for (final entry in _itemControllers.values) {
      entry['title']?.dispose();
      entry['description']?.dispose();
    }
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

      final seriesData = data['data'] ?? data;
      _titleController.text =
          (seriesData['title'] ?? widget.initialTitle ?? '').toString();
      _descriptionController.text =
          (seriesData['description'] ?? '').toString();
      _externalIdController.text = (seriesData['external_id'] ?? '').toString();

      final items = (seriesData['items'] as List<dynamic>? ?? []);
      _syncItemControllers(items);

      setState(() {
        _series = seriesData;
        _items = items;
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

  void _syncItemControllers(List<dynamic> items) {
    for (final item in items) {
      if (item is! Map) continue;
      final id = item['id']?.toString();
      if (id == null) continue;
      _itemControllers.putIfAbsent(id, () {
        return {
          'title': TextEditingController(),
          'description': TextEditingController(),
        };
      });
      _itemControllers[id]!['title']!.text =
          (item['caption'] ?? item['title'] ?? '').toString();
      _itemControllers[id]!['description']!.text =
          (item['description'] ?? '').toString();
    }
  }

  Future<void> _saveSeries() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _savingSeries = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.updateSeries(widget.seriesId, {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'external_id': _externalIdController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Series updated')),
      );
      await _loadSeries();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update series: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingSeries = false);
    }
  }

  Future<void> _deleteSeries() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete series?'),
        content: const Text(
            'This will delete the entire series and all its content items.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.deleteSeries(widget.seriesId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Series deleted')),
      );
      Navigator.of(context)
          .pop({'deleted': true, 'series_id': widget.seriesId});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete series: $e')),
      );
    }
  }

  Future<void> _saveItem(String itemId) async {
    final controllers = _itemControllers[itemId];
    if (controllers == null) return;
    setState(() => _savingItem[itemId] = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.updateContent(itemId, {
        'caption': controllers['title']!.text.trim(),
        'title': controllers['title']!.text.trim(),
        'description': controllers['description']!.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item updated')),
      );
      await _loadSeries();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update item: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingItem[itemId] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Series'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadSeries,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Series Info',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Title required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _externalIdController,
            decoration: const InputDecoration(
              labelText: 'External ID (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _savingSeries ? null : _saveSeries,
            icon: _savingSeries
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            label: Text(_savingSeries ? 'Saving...' : 'Save Series'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _deleteSeries,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text(
              'Delete series',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Items (${_items.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.video_library, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('No items added yet',
                        style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text('Tap "Add content" below to add items to your series',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ..._items.map((item) => _buildItemCard(item)).toList(),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UploadContentScreen(
                    type: 'video',
                    profileName: 'Series',
                    seriesId: widget.seriesId,
                    initialSeriesTitle: _titleController.text,
                    initialSeriesDescription: _descriptionController.text,
                  ),
                ),
              );
              if (!mounted) return;
              // If upload succeeded, refresh the series items list
              if (result is Map && (result['success'] == true)) {
                _loadSeries();
              }
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add content'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(dynamic item) {
    if (item is! Map) return const SizedBox.shrink();
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return const SizedBox.shrink();
    final type = (item['type'] ?? '').toString().toLowerCase();
    final order = item['series_order']?.toString();
    final controllers = _itemControllers[id]!;
    final saving = _savingItem[id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(_iconForType(type), color: AppTheme.primaryDark),
                  const SizedBox(width: 8),
                  Text(
                    order != null ? 'Item $order' : 'Item $id',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      type.isEmpty ? 'Unknown' : type.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: saving
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CourseDetailScreen(
                              courseId: id,
                              courseTitle: controllers['title']!.text,
                              duration: item['duration']?.toString() ?? '',
                              price: '',
                              color: AppTheme.primary,
                            ),
                          ),
                        );
                      },
                child: const Text('Open'),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete item',
                onPressed: saving ? null : () => _deleteItem(id),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controllers['title'],
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controllers['description'],
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: saving ? null : () => _saveItem(id),
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(saving ? 'Saving...' : 'Save Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: saving
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CourseDetailScreen(
                              courseId: id,
                              courseTitle: controllers['title']!.text,
                              duration: item['duration']?.toString() ?? '',
                              price: '',
                              color: AppTheme.primary,
                            ),
                          ),
                        );
                      },
                child: const Text('Preview'),
              ),
              TextButton(
                onPressed: saving ? null : () => _deleteItem(id),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text('This will remove the content from the series.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.deleteContent(itemId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted')),
      );
      await _loadSeries();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete item: $e')),
      );
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'audio':
        return Icons.audiotrack;
      case 'text':
      case 'article':
        return Icons.notes;
      default:
        return Icons.play_circle_fill;
    }
  }
}
