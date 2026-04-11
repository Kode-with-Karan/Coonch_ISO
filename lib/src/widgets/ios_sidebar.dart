import 'dart:ui';

import 'package:flutter/material.dart';

class IOSSidebar extends StatelessWidget {
  final void Function()? onLogout;
  final void Function()? onViewProfile;
  final void Function(String key)? onMenuTap;
  final String? userName;
  final String? avatarUrl;

  const IOSSidebar({
    Key? key,
    this.onLogout,
    this.onViewProfile,
    this.onMenuTap,
    this.userName,
    this.avatarUrl,
  }) : super(key: key);

  Widget _menuItem(
    IconData icon,
    String label,
    String key,
    TextStyle menuStyle,
  ) {
    return InkWell(
      onTap: onMenuTap != null ? () => onMenuTap!(key) : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.grey[800]),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: menuStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.82;
    final name =
        (userName == null || userName!.isEmpty) ? 'Sara Mathew' : userName!;
    final textTheme = Theme.of(context).textTheme;
    final nameStyle = textTheme.titleMedium?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
          letterSpacing: 0,
        ) ??
        const TextStyle(
            fontSize: 19, fontWeight: FontWeight.w700, color: Colors.black87);
    final menuStyle = textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
          letterSpacing: 0,
        ) ??
        const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87);
    final pillStyle = textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
          letterSpacing: 0,
        ) ??
        TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            letterSpacing: 0);

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: width,
              padding: const EdgeInsets.fromLTRB(24, 42, 20, 26),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.74),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SafeArea(
                left: false,
                right: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          padding: const EdgeInsets.all(3.2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.blue.shade400, width: 2.4),
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            backgroundImage:
                                const AssetImage('assets/icons/app_icon.png'),
                            foregroundImage: avatarUrl != null &&
                                    avatarUrl!.trim().isNotEmpty
                                ? NetworkImage(avatarUrl!.trim())
                                : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: nameStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: onViewProfile,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                        color: Colors.grey.withValues(alpha: 0.25)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_outlined,
                                          size: 14, color: Colors.grey[800]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'View Profile',
                                        style: pillStyle,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 34),

                    // Menu items
                    _menuItem(Icons.school_outlined, 'Education', 'education',
                        menuStyle),
                    _menuItem(Icons.lightbulb_outline, 'Infotainment',
                        'infotainment', menuStyle),
                    _menuItem(Icons.movie_creation_outlined, 'Entertainment',
                        'entertainment', menuStyle),
                    _menuItem(Icons.settings_outlined, 'Settings', 'settings',
                        menuStyle),
                    _menuItem(Icons.help_outline, 'Help & Support', 'help',
                        menuStyle),

                    const Spacer(),

                    // Optional logout to keep parity with app flows
                    if (onLogout != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onLogout,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F9AFF), Color(0xFF1D7CFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade200.withValues(alpha: 0.28),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout, color: Colors.white, size: 18),
                              SizedBox(width: 10),
                              Text(
                                'Log Out',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
