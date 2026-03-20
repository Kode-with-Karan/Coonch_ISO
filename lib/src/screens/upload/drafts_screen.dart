import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  List<dynamic> _drafts = [];
  bool _loading = true;
  bool _publishingAll = false;
  final Set<String> _publishingIds = {};

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final drafts = await api.getDraftContents();
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      Provider.of<NotificationService>(context, listen: false).showError(
        NotificationService.formatMessage('Failed to load drafts: $e'),
      );
    }
  }

  String _draftId(dynamic item) {
    if (item is Map && item['id'] != null) return item['id'].toString();
    return '';
  }

  String _draftTitle(dynamic item) {
    if (item is Map) {
      final caption = (item['caption'] ?? '').toString().trim();
      if (caption.isNotEmpty) return caption;
    }
    return 'Untitled draft';
  }

  String _draftType(dynamic item) {
    if (item is Map) return (item['type'] ?? 'content').toString();
    return 'content';
  }

  String? _draftImage(dynamic item) {
    if (item is! Map) return null;
    final type = (item['type'] ?? '').toString();
    final thumb = item['thumbnail_url']?.toString();
    if (thumb != null && thumb.isNotEmpty) return thumb;
    final file = item['file_url']?.toString();
    if ((type == 'image' || type == 'story') &&
        file != null &&
        file.isNotEmpty) {
      return file;
    }
    return null;
  }

  Future<void> _publishOne(dynamic item) async {
    final id = _draftId(item);
    if (id.isEmpty || _publishingIds.contains(id) || _publishingAll) return;

    setState(() => _publishingIds.add(id));
    final api = Provider.of<ApiService>(context, listen: false);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);

    try {
      final res = await api.publishDraft(id);
      final data = (res['data'] ?? const {}) as Map<String, dynamic>;
      final awarded = data['reward_points_awarded'];

      if (!mounted) return;
      setState(() {
        _drafts.removeWhere((d) => _draftId(d) == id);
      });

      if (awarded is int && awarded > 0) {
        notifications.showSuccess('Draft published (+$awarded pts)');
      } else {
        notifications.showSuccess('Draft published');
      }
    } catch (e) {
      notifications.showError(
          NotificationService.formatMessage('Failed to publish draft: $e'));
    } finally {
      if (mounted) {
        setState(() => _publishingIds.remove(id));
      }
    }
  }

  Future<void> _publishAll() async {
    if (_publishingAll || _drafts.isEmpty) return;

    setState(() => _publishingAll = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);

    try {
      final res = await api.publishAllDrafts();
      final data = (res['data'] ?? const {}) as Map<String, dynamic>;
      final publishedCount =
          int.tryParse((data['published_count'] ?? 0).toString()) ?? 0;
      final rewardTotal =
          int.tryParse((data['reward_points_awarded_total'] ?? 0).toString()) ??
              0;

      if (!mounted) return;
      setState(() {
        _drafts = [];
      });

      if (publishedCount == 0) {
        notifications.showInfo('No drafts to publish');
      } else if (rewardTotal > 0) {
        notifications.showSuccess(
            'Published $publishedCount drafts (+$rewardTotal pts)');
      } else {
        notifications.showSuccess('Published $publishedCount drafts');
      }
    } catch (e) {
      notifications.showError(NotificationService.formatMessage(
          'Failed to publish all drafts: $e'));
    } finally {
      if (mounted) {
        setState(() => _publishingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Drafts'),
        actions: [
          TextButton.icon(
            onPressed: _drafts.isEmpty || _loading || _publishingAll
                ? null
                : _publishAll,
            icon: _publishingAll
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish, color: Colors.white),
            label: const Text('Publish All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDrafts,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _drafts.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 140),
                      Center(
                        child: Text(
                          'No drafts found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _drafts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _drafts[index];
                      final id = _draftId(item);
                      final isPublishing =
                          _publishingIds.contains(id) || _publishingAll;
                      final image = _draftImage(item);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: image != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        image,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                                Icons.image_not_supported),
                                      ),
                                    )
                                  : const Icon(Icons.description_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _draftTitle(item),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _draftType(item).toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 36,
                                    child: ElevatedButton.icon(
                                      onPressed: isPublishing
                                          ? null
                                          : () => _publishOne(item),
                                      icon: isPublishing
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : const Icon(Icons.publish, size: 16),
                                      label: Text(isPublishing
                                          ? 'Publishing...'
                                          : 'Publish'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
