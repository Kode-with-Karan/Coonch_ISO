import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/audio_player_widget.dart';

class SelectExistingPostsScreen extends StatefulWidget {
  const SelectExistingPostsScreen({super.key});

  @override
  State<SelectExistingPostsScreen> createState() =>
      _SelectExistingPostsScreenState();
}

class _SelectExistingPostsScreenState extends State<SelectExistingPostsScreen> {
  String _filter = 'All';
  bool _loading = false;
  String? _error;
  final List<Map<String, dynamic>> _posts = [];

  List<Map<String, dynamic>> get _filteredPosts => _posts
      .where((p) =>
          _filter == 'All' ||
          (p['type'] ?? '').toString().toLowerCase() == _filter.toLowerCase())
      .toList();

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final data = await api.getContents();
      _posts
        ..clear()
        ..addAll(data.map<Map<String, dynamic>>((c) {
          return {
            'id': c['id'] ?? UniqueKey().toString(),
            'type': (c['type'] ?? '').toString(),
            'name': ((c['user'] ?? const {})['name'] ??
                    (c['user'] ?? const {})['username'] ??
                    'Unknown')
                .toString(),
            'role': 'Creator',
            'image': c['thumbnail_url'] ?? c['file_url'] ?? '',
            'file_url': c['file_url'],
            'thumbnail_url': c['thumbnail_url'],
            'user': c['user'] ?? const {},
            'likes': (c['likes_count'] ?? '0').toString(),
            'comments':
                int.tryParse((c['comments_count'] ?? '0').toString()) ?? 0,
            'text': (c['caption'] ?? '').toString(),
            'raw': c,
            'selected': false,
          };
        }));
    } catch (e) {
      _error = 'Failed to load posts. Please try again.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _toggleSelected(dynamic id) {
    setState(() {
      final idx = _posts.indexWhere((p) => p['id'] == id);
      if (idx != -1) _posts[idx]['selected'] = !_posts[idx]['selected'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios)),
        centerTitle: true,
        title:
            const Text('Posts', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _typeChip('All'),
                  const SizedBox(width: 12),
                  _typeChip('Video'),
                  const SizedBox(width: 12),
                  _typeChip('Audio'),
                  const SizedBox(width: 12),
                  _typeChip('Text'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                            ElevatedButton(
                                onPressed: _fetchPosts,
                                child: const Text('Retry'))
                          ],
                        ),
                      )
                    : _filteredPosts.isEmpty
                        ? const Center(child: Text('No posts found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: _filteredPosts.length,
                            itemBuilder: (context, i) {
                              final post = _filteredPosts[i];
                              final type = (post['type'] ?? '').toString();
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 4),
                                      leading: NetworkAvatar(
                                          url: (post['user'] ??
                                                  const {})['avatar'] ??
                                              'https://i.pravatar.cc/150?img=${12 + (i % 10)}',
                                          radius: 22),
                                      title: Text(post['name'],
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                      subtitle: Text(post['role'],
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13)),
                                      trailing: GestureDetector(
                                        onTap: () =>
                                            _toggleSelected(post['id']),
                                        child: _selectionCircle(
                                            post['selected'] as bool),
                                      ),
                                    ),
                                    if (type == 'video' || type == 'short')
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0, vertical: 6),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: Image.network(
                                                (post['thumbnail_url'] ??
                                                        post['image'] ??
                                                        '')
                                                    .toString(),
                                                height: 180,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  height: 180,
                                                  width: double.infinity,
                                                  color: Colors.grey[200],
                                                  child: const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 64,
                                              height: 64,
                                              decoration: const BoxDecoration(
                                                color: Color.fromRGBO(
                                                    0, 0, 0, 0.35),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                  Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 36),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (type == 'audio')
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0, vertical: 8),
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.all(
                                              Radius.circular(12)),
                                          child: AudioPlayerWidget(
                                            url: (post['file_url'] ??
                                                    post['audio_url'] ??
                                                    post['thumbnail_url'] ??
                                                    post['image'] ??
                                                    '')
                                                .toString(),
                                            height: 86,
                                          ),
                                        ),
                                      ),
                                    // Images for plain image posts (type image/photo) or when file is image
                                    if (type == 'image' || type == 'photo')
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0, vertical: 6),
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.all(
                                              Radius.circular(12)),
                                          child: Image.network(
                                            (post['image'] ??
                                                    post['thumbnail_url'] ??
                                                    '')
                                                .toString(),
                                            height: 200,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              height: 200,
                                              width: double.infinity,
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (type == 'text')
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18.0),
                                        child: Text(post['text'],
                                            style:
                                                const TextStyle(fontSize: 15)),
                                      ),
                                    if ((post['type'] ?? '') == 'text')
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 18.0, top: 6),
                                        child: Text('view more',
                                            style: TextStyle(
                                                color: Colors.grey[400])),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0, vertical: 8),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.favorite_border,
                                              color: Colors.red),
                                          const SizedBox(width: 6),
                                          Text(post['likes'],
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.chat_bubble_outline),
                                          const SizedBox(width: 6),
                                          Text('${post['comments']}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          const Spacer(),
                                          Text('likes',
                                              style: TextStyle(
                                                  color: Colors.grey[600]))
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(height: 1),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final selected =
                        _posts.where((e) => e['selected'] == true).toList();
                    Navigator.of(context).pop(selected);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _typeChip(String label) {
    final selected = _filter == label;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _filter = label),
      label: Text(label,
          style: TextStyle(color: selected ? Colors.white : Colors.grey[700])),
      selectedColor: Colors.lightBlue,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
              color: selected ? Colors.transparent : Colors.grey.shade200)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    );
  }

  Widget _selectionCircle(bool selected) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: selected ? Colors.lightBlue : Colors.grey.shade300,
            width: 2.5),
      ),
      child: selected
          ? Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Colors.lightBlue,
                shape: BoxShape.circle,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
