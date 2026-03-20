import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../widgets/network_avatar.dart';
import '../profile/profile_screen.dart';
import '../settings/subscription_screen.dart';
import '../../widgets/audio_player_widget.dart';
import '../../widgets/video_player_view.dart';
import '../../services/api_service.dart';
import '../../utils/content_access.dart';

class ContentDetailScreen extends StatefulWidget {
  final String? contentId;
  final Map<String, dynamic>? initialContent;

  const ContentDetailScreen({super.key, this.contentId, this.initialContent});

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _content;
  bool _isLiked = false;
  String _likes = '0';
  List<dynamic> _comments = [];
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Always load fresh data from API when possible. Do not rely on
    // `initialContent` fallback so the screen only displays API-provided data.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      if (widget.contentId != null) {
        final fresh = await api.getContentById(widget.contentId!);
        _content = fresh;

        // Track view and award points
        if (canAccessContent(_content)) {
          try {
            final viewRes = await api.viewContent(widget.contentId!);
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
      }
      if (_content == null) {
        setState(() => _loading = false);
        return;
      }

      setState(() {
        _isLiked = _content!['is_liked_by_me'] == true;
        _likes =
            (_content!['likes_count'] ?? _content!['likes'] ?? '0').toString();
        _comments = (_content!['comments'] is List)
            ? _content!['comments'] as List<dynamic>
            : <dynamic>[];
      });
    } catch (e) {
      debugPrint('Failed to load content detail: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load content: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_content == null) return;
    if (isLockedContent(_content)) {
      await _openSubscriptionPlans();
      return;
    }
    final api = Provider.of<ApiService>(context, listen: false);
    final id = _content!['id']?.toString();
    if (id == null) return;

    setState(() {
      _isLiked = !_isLiked;
      final num = int.tryParse(_likes) ?? 0;
      _likes = (_isLiked ? num + 1 : (num > 0 ? num - 1 : 0)).toString();
    });

    try {
      await api.likeUnlikeContent(id);
      final fresh = await api.getContentById(id);
      if (!mounted) return;
      setState(() {
        _isLiked = fresh['is_liked_by_me'] == true;
        _likes = (fresh['likes_count'] ?? fresh['likes'] ?? '0').toString();
        _comments = (fresh['comments'] is List)
            ? fresh['comments'] as List<dynamic>
            : <dynamic>[];
        _content = fresh;
      });
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
      });
      final msg = e is ApiException ? 'Like failed (${e.code})' : 'Like failed';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _content == null) return;
    if (isLockedContent(_content)) {
      await _openSubscriptionPlans();
      return;
    }

    final api = Provider.of<ApiService>(context, listen: false);
    final id = _content!['id']?.toString();
    if (id == null) return;

    try {
      await api.commentContent(id, text);
      _commentController.clear();
      final fresh = await api.getContentById(id);
      if (!mounted) return;
      setState(() {
        _comments = (fresh['comments'] is List)
            ? fresh['comments'] as List<dynamic>
            : <dynamic>[];
        _likes = (fresh['likes_count'] ?? fresh['likes'] ?? '0').toString();
        _content = fresh;
      });
    } catch (e) {
      final msg =
          e is ApiException ? 'Comment failed (${e.code})' : 'Comment failed';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebWideLayout = kIsWeb && screenWidth >= 1100;
    final type = (_content?['type'] ?? '').toString();
    final fileUrl =
        (_content?['file_url'] ?? _content?['file'] ?? _content?['video_url'])
            ?.toString();
    final lockedContent = isLockedContent(_content);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _content == null
              ? const Center(child: Text('Content not found'))
              : Container(
                  color:
                      isWebWideLayout ? const Color(0xFFF4F6F8) : Colors.white,
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: isWebWideLayout ? 1200 : double.infinity),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWebWideLayout ? 20 : 0,
                            vertical: isWebWideLayout ? 20 : 0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAuthorHeader(
                                  asWebsiteBlock: isWebWideLayout),
                              if (lockedContent)
                                _buildLockedContent()
                              else if (isWebWideLayout)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 7,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 10,
                                              offset: Offset(0, 3),
                                            )
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildMedia(type, fileUrl,
                                                isWideLayout: true),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: _buildCaptionAndActions(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 5,
                                      child: _buildCommentsPanel(),
                                    ),
                                  ],
                                )
                              else ...[
                                _buildMedia(type, fileUrl),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildCaptionAndActions(),
                                      const SizedBox(height: 12),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      const Text('Comments',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      ..._commentTiles(),
                                      const SizedBox(height: 12),
                                      Padding(
                                        padding: EdgeInsets.only(
                                            bottom: MediaQuery.of(context)
                                                    .viewInsets
                                                    .bottom +
                                                8),
                                        child: SafeArea(
                                          child: _buildCommentComposer(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildAuthorHeader({bool asWebsiteBlock = false}) {
    final u = _content!['user'];
    final name = (u is Map) ? (u['name'] ?? u['username']) : (u?.toString());
    final avatar =
        (u is Map) ? (u['avatar'] ?? u['avatar_url'])?.toString() : null;

    final row = Row(
      children: [
        NetworkAvatar(url: avatar, radius: 22),
        const SizedBox(width: 10),
        Expanded(
          child: name == null
              ? const SizedBox.shrink()
              : Text(name.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );

    if (!asWebsiteBlock) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: row,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: row,
    );
  }

  Widget _buildCaptionAndActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_content!['caption']?.toString() ?? '',
            style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
                onPressed: _toggleLike,
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                    color: Colors.red)),
            Text(_likes, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 18),
            const Icon(Icons.chat_bubble_outline),
            const SizedBox(width: 6),
            Text((_comments.length).toString(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comments',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No comments yet'),
            )
          else
            SizedBox(
              height: 420,
              child: ListView.separated(
                itemCount: _comments.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) => _buildCommentTile(_comments[i]),
              ),
            ),
          const SizedBox(height: 12),
          _buildCommentComposer(),
        ],
      ),
    );
  }

  List<Widget> _commentTiles() =>
      _comments.map((c) => _buildCommentTile(c)).toList();

  Widget _buildCommentTile(dynamic c) {
    final cm = c as Map<dynamic, dynamic>;
    final user = cm['user'];
    final text = cm['comment_text']?.toString() ?? '';
    final name =
        (user is Map) ? (user['name'] ?? user['username']) : (user?.toString());
    final avatar = (user is Map)
        ? (user['avatar'] ?? user['avatar_url'])?.toString()
        : null;

    String? commentUserId;
    if (user is Map) {
      commentUserId = (user['id'] ?? user['user_id'] ?? user['pk'])?.toString();
    }

    return ListTile(
      leading: avatar != null
          ? GestureDetector(
              onTap: () {
                if (commentUserId != null) {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: commentUserId)));
                }
              },
              child: NetworkAvatar(url: avatar, radius: 18))
          : const CircleAvatar(child: Icon(Icons.person)),
      title: GestureDetector(
        onTap: () {
          if (commentUserId != null) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: commentUserId)));
          }
        },
        child: name == null
            ? const SizedBox.shrink()
            : Text(name.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      subtitle: Text(text),
    );
  }

  Widget _buildCommentComposer() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
                hintText: 'Write a comment...',
                border: OutlineInputBorder(),
                isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: _postComment, child: const Text('Post'))
      ],
    );
  }

  Future<void> _openSubscriptionPlans() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
  }

  Widget _buildLockedContent() {
    final content = _content;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 52,
                  color: Color(0xFF1565C0),
                ),
                const SizedBox(height: 16),
                Text(
                  contentAccessMessage(content),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade800,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openSubscriptionPlans,
                    icon: const Icon(Icons.workspace_premium),
                    label: Text(lockedActionLabel(content)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(String type, String? fileUrl,
      {bool isWideLayout = false}) {
    final mediaHeight = isWideLayout ? 440.0 : 240.0;

    // Audio content
    if (type == 'audio') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: AudioPlayerWidget(
            url: (_content?['file_url'] ?? _content?['audio_url'])?.toString(),
            height: 84),
      );
    }

    // Video / short / story
    if (type == 'video' || type == 'short' || type == 'story') {
      if (fileUrl != null && fileUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(isWideLayout ? 16 : 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: mediaHeight),
            child: VideoPlayerView(url: fileUrl),
          ),
        );
      }
      if (_content?['thumbnail_url'] != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(isWideLayout ? 16 : 0),
          child: Image.network(
            _content!['thumbnail_url'].toString(),
            width: double.infinity,
            height: mediaHeight,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: mediaHeight,
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      }
      return Container(
        height: mediaHeight,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Text('No video available'),
      );
    }

    // Image fallback
    if (_content?['thumbnail_url'] != null || _content?['file_url'] != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(isWideLayout ? 16 : 0),
        child: Image.network(
          (_content?['thumbnail_url'] ?? _content?['file_url']).toString(),
          width: double.infinity,
          height: mediaHeight,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: mediaHeight,
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
