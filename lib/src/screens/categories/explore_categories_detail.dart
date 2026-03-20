import 'package:flutter/material.dart';
import 'home_categories_geography.dart';

class ExploreCategoriesDetailScreen extends StatefulWidget {
  final String categoryName;
  const ExploreCategoriesDetailScreen({super.key, required this.categoryName});

  @override
  State<ExploreCategoriesDetailScreen> createState() =>
      _ExploreCategoriesDetailScreenState();
}

class _ExploreCategoriesDetailScreenState
    extends State<ExploreCategoriesDetailScreen> {
  String _selected = '';

  final List<String> _categories = [
    'Mathematics',
    'Geography',
    'Physics',
    'Entertainment',
    'Science'
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.categoryName;
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

          // list with selection
          ..._categories.map((c) {
            final bool sel = c == _selected;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () => setState(() => _selected = c),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                      color: sel ? Colors.lightBlue[100] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: Row(children: [
                    Icon(_iconFor(c),
                        color: sel ? Colors.white : Colors.black54),
                    const SizedBox(width: 12),
                    Text(c,
                        style: TextStyle(
                            fontSize: 16,
                            color: sel ? Colors.white : Colors.black))
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
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      HomeCategoriesGeographyScreen(category: _selected))),
              child: const Text('View', style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  IconData _iconFor(String c) {
    switch (c) {
      case 'Mathematics':
        return Icons.calculate;
      case 'Geography':
        return Icons.public;
      case 'Physics':
        return Icons.science;
      case 'Entertainment':
        return Icons.emoji_emotions;
      default:
        return Icons.category;
    }
  }
}
