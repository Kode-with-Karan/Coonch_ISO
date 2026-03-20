import 'package:flutter/material.dart';
import '../../widgets/network_avatar.dart';

class HomeCategoriesGeographyScreen extends StatelessWidget {
  final String category;
  const HomeCategoriesGeographyScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> posts = [
      {
        'name': 'Ryan Calzoni',
        'role': 'Engineer',
        'image': 'https://picsum.photos/800/480?image=1050',
        'likes': '7.5K',
        'comments': 425,
        'text':
            "Hello Gz.. Good morning 😎\ndon't forgot to follow and comment this post...",
      },
      {
        'name': 'Jakob Geidt',
        'role': 'Engineer',
        'audioDuration': '0:05',
        'likes': '7.5K',
        'comments': 425,
        'text': '',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(category),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: posts.length,
        itemBuilder: (context, i) {
          final p = posts[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      NetworkAvatar(
                          url: 'https://i.pravatar.cc/150?u=${p['name']}',
                          radius: 20),
                      const SizedBox(width: 10),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['name'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(p['role'],
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey))
                          ]),
                    ]),
                    const SizedBox(height: 8),
                    if (p.containsKey('image'))
                      Image.network(
                        p['image'],
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 180,
                          width: double.infinity,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey),
                        ),
                      ),
                    if ((p['text'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(p['text']),
                    ],
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.favorite_border, color: Colors.red),
                      const SizedBox(width: 6),
                      Text(p['likes'])
                    ]),
                  ]),
            ),
          );
        },
      ),
    );
  }
}
