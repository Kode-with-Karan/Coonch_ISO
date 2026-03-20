import 'package:flutter/material.dart';

import '../screens/categories/all_categories.dart';
import '../screens/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/search_screen.dart';
import '../widgets/post_options.dart';

/// Reusable bottom navigation bar used across screens.
///
/// Usage: place `bottomNavigationBar: AppBottomNavBar(activeIndex: X)` in a
/// `Scaffold` and `floatingActionButton: AppFAB(onPressed: ...)` if needed.
class AppBottomNavBar extends StatelessWidget {
  final int activeIndex;
  const AppBottomNavBar({super.key, this.activeIndex = 0});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: SizedBox(
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
              icon: Icon(Icons.home,
                  color: activeIndex == 0 ? Colors.lightBlue : Colors.grey),
            ),
            IconButton(
              onPressed: () {
                if (activeIndex != 1) {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()));
                }
              },
              icon: Icon(Icons.search,
                  color: activeIndex == 1 ? Colors.lightBlue : Colors.grey),
            ),
            const SizedBox(width: 48), // FAB space
            IconButton(
              onPressed: () {
                if (activeIndex != 2) {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AllCategoriesScreen()));
                }
              },
              icon: Icon(Icons.grid_view_rounded,
                  color: activeIndex == 2 ? Colors.lightBlue : Colors.grey),
            ),
            IconButton(
              onPressed: () {
                if (activeIndex != 3) {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()));
                }
              },
              icon: Icon(Icons.person_outline,
                  color: activeIndex == 3 ? Colors.lightBlue : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class AppFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color backgroundColor;
  const AppFAB(
      {super.key, this.onPressed, this.backgroundColor = Colors.lightBlue});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed ?? () => PostOptions.show(context, profileName: ''),
      backgroundColor: backgroundColor,
      child: const Icon(Icons.add),
    );
  }
}
