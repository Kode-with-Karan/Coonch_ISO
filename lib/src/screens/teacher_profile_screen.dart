import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'categories/course_detail_screen.dart';

class TeacherProfileScreen extends StatefulWidget {
  final String teacherName;
  final String teacherTitle;
  final String? teacherAvatar;
  final int followers;
  final int reviews;
  final int totalStudents;

  const TeacherProfileScreen({
    Key? key,
    required this.teacherName,
    required this.teacherTitle,
    this.teacherAvatar,
    this.followers = 21200,
    this.reviews = 4100,
    this.totalStudents = 90000,
  }) : super(key: key);

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  bool _isFollowing = false;

  // Mock courses data
  final List<Map<String, dynamic>> _courses = [
    {
      'title': 'UI UX Course',
      'duration': '30h 15min',
      'price': '£75.00',
      'color': const Color(0xFFFF9B9B),
      'icon': Icons.design_services,
    },
    {
      'title': 'UI UX Course',
      'duration': '30h 15min',
      'price': '£75.00',
      'color': const Color(0xFFB5A1FF),
      'icon': Icons.design_services,
    },
    {
      'title': 'UI UX Course',
      'duration': '30h 15min',
      'price': '£75.00',
      'color': const Color(0xFFFF9B9B),
      'icon': Icons.design_services,
    },
  ];

  // Mock reviews data
  final List<Map<String, dynamic>> _reviews = [
    {
      'name': 'Jane Cooper',
      'avatar': null,
      'time': '2 days ago',
      'comment':
          'This is so amazing! I really enjoyed this film, I hope the next chapters will be released...',
    },
    {
      'name': 'Ralph Edwards',
      'avatar': null,
      'time': '3 days ago',
      'comment':
          'This is so amazing! I really enjoyed this film, I hope the next chapters will be released...',
    },
    {
      'name': 'Kathryn Murphy',
      'avatar': null,
      'time': '4 days ago',
      'comment':
          'This is so amazing! I really enjoyed this film, I hope the next chapters will be released...',
    },
  ];

  String _formatNumber(int number) {
    if (number >= 1000) {
      double value = number / 1000;
      return '${value.toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // Purple Gradient Header with Profile Card
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Purple Background
                Container(
                  height: 300,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7B5FFF), Color(0xFF9D7FFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(40),
                    ),
                  ),
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
                // Profile Card
                Positioned(
                  top: 80,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Profile Picture and Name Row
                        Row(
                          children: [
                            // Profile Picture with rounded corners
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                image: widget.teacherAvatar != null
                                    ? DecorationImage(
                                        image:
                                            NetworkImage(widget.teacherAvatar!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: const Color(0xFFE8E4FF),
                              ),
                              child: widget.teacherAvatar == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Color(0xFF7B5FFF),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            // Name and Title
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.teacherName,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.teacherTitle,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Stats Row with light purple background
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStat(
                                _formatNumber(widget.followers),
                                'Followers',
                                const Color(0xFF7B5FFF),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey[300],
                              ),
                              _buildStat(
                                _formatNumber(widget.reviews),
                                'Reviews',
                                const Color(0xFF7B5FFF),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey[300],
                              ),
                              _buildStat(
                                _formatNumber(widget.totalStudents),
                                'Total Students',
                                const Color(0xFF7B5FFF),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Buttons Row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  // Handle chat
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFF7B5FFF),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Chat',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7B5FFF),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isFollowing = !_isFollowing;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7B5FFF),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  _isFollowing ? 'Following' : 'Follow',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Spacer for the overlapping card
          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // All Courses Section
                Transform.translate(
                  offset: const Offset(0, -10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'All courses',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                // Handle see all
                              },
                              child: const Text(
                                'See all',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF8C42),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Course List
                        ..._courses.map((course) => _buildCourseItem(
                              course['title'] as String,
                              course['duration'] as String,
                              course['price'] as String,
                              course['color'] as Color,
                              course['icon'] as IconData,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Student Rating Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Student rating',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // Handle see all
                            },
                            child: const Text(
                              'See all',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF8C42),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Rating Cards
                      SizedBox(
                        height: 150,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildRatingCard(587, 'Satisfied',
                                const Color(0xFFFFB800), 0.75),
                            _buildRatingCard(
                                321, 'Neutral', const Color(0xFF7B5FFF), 0.5),
                            _buildRatingCard(
                                44, 'Poor', const Color(0xFFFF9B9B), 0.25),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Student Review Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Student Review',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // Handle see all
                            },
                            child: const Text(
                              'See all',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF8C42),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Review List
                      ..._reviews.map((review) => _buildReviewItem(
                            review['name'] as String,
                            review['avatar'] as String?,
                            review['time'] as String,
                            review['comment'] as String,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCourseItem(
    String title,
    String duration,
    String price,
    Color color,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourseDetailScreen(
              courseTitle: title,
              duration: duration,
              price: price,
              color: color,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            // Course thumbnail
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            // Course details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Color(0xFFFF8C42),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        duration,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Price
            Text(
              price,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7B5FFF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCard(
      int count, String label, Color color, double progress) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular Progress
          SizedBox(
            width: 60,
            height: 60,
            child: CustomPaint(
              painter: _CircularProgressPainter(
                progress: progress,
                color: color,
              ),
              child: Center(
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(
    String name,
    String? avatar,
    String time,
    String comment,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey[200]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8E4FF),
              image: avatar != null
                  ? DecorationImage(
                      image: NetworkImage(avatar),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatar == null
                ? const Icon(
                    Icons.person,
                    size: 24,
                    color: Color(0xFF7B5FFF),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Review content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  comment,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for circular progress indicator
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
