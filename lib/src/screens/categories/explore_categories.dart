import 'package:flutter/material.dart';
import 'explore_categories_detail.dart';

class ExploreCategoriesScreen extends StatelessWidget {
  const ExploreCategoriesScreen({super.key});

  final List<Map<String, dynamic>> _categories = const [
    {'name': 'Mathematics', 'icon': Icons.calculate},
    {'name': 'Geography', 'icon': Icons.public},
    {'name': 'Physics', 'icon': Icons.science},
    {'name': 'Entertainment', 'icon': Icons.emoji_emotions},
    {'name': 'Science', 'icon': Icons.biotech},
  ];

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
        title: const Text('Categories', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Explore Categories',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              'Discover a wide range of content across different categories to suit your interests and preferences.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 18),

          // categories list
          ..._categories.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ExploreCategoriesDetailScreen(
                        categoryName: c['name'] as String))),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: Row(children: [
                    Icon(c['icon'] as IconData, color: Colors.black54),
                    const SizedBox(width: 12),
                    Text(c['name'] as String,
                        style: const TextStyle(fontSize: 16))
                  ]),
                ),
              ),
            );
          }).toList(),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () {},
              child: const Text('View', style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}
