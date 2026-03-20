import 'package:flutter/material.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/content_card.dart';
import '../playlists/playlists_screen.dart';
import '../../widgets/app_navbar.dart';
import '../../widgets/post_options.dart';

class ViewProfileScreen extends StatelessWidget {
  const ViewProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = List.generate(
      3,
      (i) => {
        'avatar': 'https://picsum.photos/seed/avatar$i/80',
        'name': i == 0
            ? 'Ryan Calzoni (Me)'
            : i == 1
                ? 'Jakob Geidt (Me)'
                : 'Ahmad Curtis',
        'role': 'Engineer',
        'image': 'https://picsum.photos/800/360?image=${1050 + i * 10}',
        'text':
            "Hello Gz.. Good morning 😎\ndon't forgot to follow and comment this post...",
      },
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const SizedBox.shrink(),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () {},
                ),
                Positioned(
                  right: 6,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: const Center(
                      child: Text(
                        '5',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.0),
                child: Row(
                  children: [
                    NetworkAvatar(
                        url: 'https://picsum.photos/seed/profile/140',
                        radius: 43),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Adriam Liyam',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 16, color: Colors.grey),
                              SizedBox(width: 6),
                              Text('USA', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Stats row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statItem('1,532', 'Posts'),
                    _verticalDivider(),
                    _statItem('4,310', 'Friends'),
                    _verticalDivider(),
                    _statItem('1,310', 'Following'),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Buttons row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9ED1FF),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('+ Follow',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const PlayListsScreen()));
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Play List',
                            style: TextStyle(color: Colors.black87)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.more_horiz),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // First post author label
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Replace static mock posts with interactive ContentCard widgets
                    ContentCard(
                      content: {
                        'id': 1001,
                        'user': {
                          'name': posts[0]['name'],
                          'avatar': posts[0]['avatar']
                        },
                        'file_url': posts[0]['image'],
                        'caption': posts[0]['text'],
                        'likes_count': 7500,
                        'comments_count': 425,
                        'is_liked_by_me': false,
                      },
                    ),
                    const SizedBox(height: 12),
                    ContentCard(
                      content: {
                        'id': 1002,
                        'user': {
                          'name': posts[1]['name'],
                          'avatar': posts[1]['avatar']
                        },
                        'file_url': posts[1]['image'],
                        'caption': posts[1]['text'],
                        'likes_count': 1200,
                        'comments_count': 88,
                        'is_liked_by_me': false,
                      },
                    ),
                    const SizedBox(height: 12),
                    ContentCard(
                      content: {
                        'id': 1003,
                        'user': {
                          'name': posts[2]['name'],
                          'avatar': posts[2]['avatar']
                        },
                        'file_url': posts[2]['image'],
                        'caption': posts[2]['text'],
                        'likes_count': 530,
                        'comments_count': 14,
                        'is_liked_by_me': false,
                      },
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: AppFAB(
        onPressed: () => PostOptions.show(context, profileName: 'Adriam Liyam'),
      ),
      bottomNavigationBar: const AppBottomNavBar(activeIndex: 3),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return SizedBox(
      width: 1,
      child: Container(color: Colors.grey.shade200, height: 48),
    );
  }

  // Old helper UI functions removed — replaced by reusable ContentCard widget above.
}
