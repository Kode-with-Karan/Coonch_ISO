import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';

class NotificationOverlay extends StatefulWidget {
  final Widget child;

  const NotificationOverlay({
    super.key,
    required this.child,
  });

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, -1),
      end: const Offset(0, 0),
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showNotification() {
    _animationController.forward();
  }

  void _hideNotification() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Consumer<NotificationService>(
          builder: (context, notificationService, _) {
            final notification = notificationService.currentNotification;

            if (notification != null) {
              // Trigger show animation
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_animationController.isDismissed) {
                  _showNotification();
                }
              });
            } else {
              // Trigger hide animation
              if (_animationController.isCompleted) {
                _hideNotification();
              }
            }

            return Positioned(
              top: 0,
              right: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 16, left: 12),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: notification != null
                            ? _NotificationCard(notification: notification)
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationMessage notification;

  const _NotificationCard({required this.notification});

  Color _getBackgroundColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return const Color(0xFF4CAF50);
      case NotificationType.error:
        return const Color(0xFFf44336);
      case NotificationType.warning:
        return const Color(0xFFff9800);
      case NotificationType.info:
        return const Color(0xFF2196F3);
    }
  }

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.warning:
        return Icons.warning_amber;
      case NotificationType.info:
        return Icons.info_outline;
    }
  }

  String _getTitle(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return 'Success';
      case NotificationType.error:
        return 'Error';
      case NotificationType.warning:
        return 'Warning';
      case NotificationType.info:
        return 'Info';
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor(notification.type);
    final icon = _getIcon(notification.type);
    final title = _getTitle(notification.type);

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withAlpha((0.3 * 255).toInt()),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Provider.of<NotificationService>(context, listen: false)
                      .dismiss();
                },
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
