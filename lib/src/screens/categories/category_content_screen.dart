import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../widgets/content_card.dart';

class CategoryContentScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  const CategoryContentScreen(
      {super.key, required this.categoryId, required this.categoryName});

  @override
  State<CategoryContentScreen> createState() => _CategoryContentScreenState();
}

class _CategoryContentScreenState extends State<CategoryContentScreen> {
  List<dynamic> _contents = [];
  bool _loading = true;
  String? _error;
  String? _selectedTopic; // null == All

  @override
  void initState() {
    super.initState();
    _loadContents();
  }

  Future<void> _loadContents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final q = <String, String>{'category': widget.categoryId.toString()};
      
      // Apply topic filter if user selected one
      if (_selectedTopic != null && _selectedTopic!.isNotEmpty) {
        q['topic'] = _selectedTopic!;
      }
      
      final list = await api.getContents(queryParams: q);

      // Filter content to ensure it matches the category exactly
      List<dynamic> filtered = [];
      if (list.isNotEmpty) {
        filtered = list.where((item) {
          if (item is Map) {
            final cat = item['category'];
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
            
            final cid = item['category_id'];
            if (cid is int) return cid == widget.categoryId;
            if (cid is String) return int.tryParse(cid) == widget.categoryId;
          }
          return false;
        }).toList();
      }

      if (!mounted) return;
      setState(() {
        // Use filtered list if we found matching content, otherwise show empty
        _contents = filtered.isNotEmpty ? filtered : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load contents for this category';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(widget.categoryName,
            style: const TextStyle(color: Colors.black)),
        actions: [
          // Topic filter popup: All / Entertainment / Education / Infotainment
          PopupMenuButton<String?>(
            tooltip: 'Filter by topic',
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onSelected: (val) {
              // val is null for 'All', otherwise one of the topic keys
              setState(() {
                _selectedTopic = val;
              });
              // reload contents for the selected topic
              _loadContents();
            },
            itemBuilder: (ctx) => <PopupMenuEntry<String?>>[
              const PopupMenuItem<String?>(value: null, child: Text('All')),
              const PopupMenuDivider(),
              const PopupMenuItem<String?>(
                  value: 'entertainment', child: Text('Entertainment')),
              const PopupMenuItem<String?>(
                  value: 'education', child: Text('Education')),
              const PopupMenuItem<String?>(
                  value: 'infotainment', child: Text('Infotainment')),
            ],
          ),
        ],
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: _loadContents, child: const Text('Retry'))
                ]))
              : _contents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
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
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _contents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final item =
                            Map<String, dynamic>.from(_contents[i] as Map);
                        return ContentCard(
                          content: item,
                          onUpdated: (fresh) {
                            if (!mounted) return;
                            setState(() => _contents[i] = fresh);
                          },
                        );
                      },
                    ),
    );
  }
}
