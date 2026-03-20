import 'package:flutter/material.dart';
import '../theme.dart';
import 'network_avatar.dart';

/// Small reusable avatar that can show either an [icon] or an [image].
class AvatarIcon extends StatelessWidget {
  final IconData? icon;
  final ImageProvider? image;
  final Color? backgroundColor;
  final Color? iconColor;
  final double radius;

  const AvatarIcon({
    Key? key,
    this.icon,
    this.image,
    this.backgroundColor,
    this.iconColor,
    this.radius = 20,
  })  : assert(icon != null || image != null,
            'Either icon or image must be provided'),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    if (image != null) {
      // If image is a NetworkImage, use NetworkAvatar to get error handling
      if (image is NetworkImage) {
        return NetworkAvatar(url: (image as NetworkImage).url, radius: radius);
      }
      return CircleAvatar(radius: radius, backgroundImage: image);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppTheme.avatarBackground,
      child: Icon(icon, color: iconColor ?? AppTheme.primary),
    );
  }
}
