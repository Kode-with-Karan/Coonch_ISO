import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

/// Simple Circle avatar that loads a network image and falls back to an icon
/// if the host is not reachable or the image fails to load.
class NetworkAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final String? initials;

  static const String _defaultAvatarUrl =
      'https://www.gravatar.com/avatar/?d=mp&s=200';

  const NetworkAvatar({super.key, this.url, this.radius = 20, this.initials});

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiService?>(context, listen: false);
    String resolvedUrl;
    if (url == null || url!.isEmpty) {
      resolvedUrl = _defaultAvatarUrl;
    } else if (url!.startsWith('http://') || url!.startsWith('https://')) {
      resolvedUrl = url!;
    } else {
      // Relative path returned by some backends — prefix with API baseUrl
      final base = api?.baseUrl ?? '';
      if (base.isEmpty) {
        resolvedUrl = url!;
      } else {
        // Ensure single slash between base and path
        if (base.endsWith('/') && url!.startsWith('/')) {
          resolvedUrl = base + url!.substring(1);
        } else if (!base.endsWith('/') && !url!.startsWith('/')) {
          resolvedUrl = '$base/${url!}';
        } else {
          resolvedUrl = base + url!;
        }
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.network(
          resolvedUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: radius * 2,
            height: radius * 2,
            color: Colors.lightBlue[50],
            child: initials != null && initials!.isNotEmpty
                ? Center(
                    child: Text(initials![0].toUpperCase(),
                        style: const TextStyle(color: Colors.lightBlue)))
                : Icon(Icons.category, size: radius, color: Colors.lightBlue),
          ),
        ),
      ),
    );
  }
}
