import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../categories/course_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Map<String, dynamic>> _wishlistItems = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.getJson('api/v1/content/wishlist/');

      if (res['success'] == 1 && res['data'] != null) {
        setState(() {
          _wishlistItems = List<Map<String, dynamic>>.from(res['data']);
          _loading = false;
        });
      } else {
        setState(() {
          _wishlistItems = [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load wishlist';
      });
    }
  }

  Future<void> _removeFromWishlist(String contentId) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.postJson('api/v1/content/$contentId/wishlist/remove/', {});

      setState(() {
        _wishlistItems
            .removeWhere((item) => item['id'].toString() == contentId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from wishlist')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove from wishlist')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('My Wishlist', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadWishlist,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _wishlistItems.isEmpty
                  ? _buildEmptyState()
                  : _buildWishlistList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No items in wishlist',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Save content to watch later',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistList() {
    return RefreshIndicator(
      onRefresh: _loadWishlist,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _wishlistItems.length,
        itemBuilder: (context, index) {
          final item = _wishlistItems[index];
          return _buildWishlistCard(item);
        },
      ),
    );
  }

  Widget _buildWishlistCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final title = item['title'] ?? item['caption'] ?? 'Untitled';
    final thumbnail = item['thumbnail_url'] ?? item['thumbnail'];
    final type = item['type'] ?? 'video';
    final price = item['price'];
    final user = item['user'];
    final creatorName =
        user != null ? (user['name'] ?? user['username'] ?? '') : '';

    IconData typeIcon;
    switch (type.toString().toLowerCase()) {
      case 'video':
        typeIcon = Icons.videocam;
        break;
      case 'audio':
        typeIcon = Icons.audiotrack;
        break;
      case 'text':
        typeIcon = Icons.article;
        break;
      case 'short':
        typeIcon = Icons.shortcut;
        break;
      default:
        typeIcon = Icons.play_circle;
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourseDetailScreen(
              courseId: id,
              courseTitle: title,
              duration: '',
              price: price?.toString() ?? '',
              color: AppTheme.primary,
            ),
          ),
        );
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
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 120,
              height: 100,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(16)),
                color: AppTheme.primary.withValues(alpha: 0.1),
              ),
              child: Stack(
                children: [
                  if (thumbnail != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(16)),
                      child: Image.network(
                        thumbnail.toString(),
                        width: 120,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(typeIcon,
                              size: 40,
                              color: AppTheme.primary.withValues(alpha: 0.5)),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Icon(typeIcon,
                          size: 40, color: AppTheme.primary.withValues(alpha: 0.5)),
                    ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(typeIcon, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            // Content info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
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
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (price != null && price != '0' && price != 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '£$price',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Free',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Remove button
            IconButton(
              icon: const Icon(Icons.bookmark, color: AppTheme.primary),
              onPressed: () => _removeFromWishlist(id),
            ),
          ],
        ),
      ),
    );
  }
}
