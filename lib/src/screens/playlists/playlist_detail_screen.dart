import 'package:flutter/material.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final Map<String, dynamic> playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final title = (playlist['title'] ?? '').toString();
    final posts = (playlist['posts'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: posts.isEmpty
          ? const Center(child: Text('No posts in this playlist yet'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final p = posts[i] as Map<String, dynamic>;
                final type = (p['type'] ?? '').toString();
                final image =
                    (p['thumbnail_url'] ?? p['file_url'] ?? p['image'] ?? '')
                        .toString();
                final caption = (p['caption'] ?? p['text'] ?? '').toString();
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (image.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              image,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 160,
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image,
                                    color: Colors.grey),
                              ),
                            ),
                          ),
                        if (type == 'audio')
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.audiotrack, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Audio'),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                              caption.isNotEmpty ? caption : 'No caption',
                              style: const TextStyle(fontSize: 15)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.favorite_border,
                                color: Colors.red),
                            const SizedBox(width: 6),
                            Text(
                                (p['likes_count'] ?? p['likes'] ?? '0')
                                    .toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            const Icon(Icons.chat_bubble_outline),
                            const SizedBox(width: 6),
                            Text(
                                (p['comments_count'] ?? p['comments'] ?? '0')
                                    .toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(type,
                                style: TextStyle(color: Colors.grey[600]))
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
