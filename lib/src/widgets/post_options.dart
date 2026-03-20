import 'package:flutter/material.dart';
import '../screens/upload/upload_content_screen.dart';
import '../screens/stories/create_story_screen.dart';

class PostOptions {
  /// Show the post options bottom sheet.
  static Future<void> show(BuildContext context,
      {required String profileName, VoidCallback? onUploadSuccess}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) {
        return DraggableScrollableSheet(
          initialChildSize: 0.32,
          maxChildSize: 0.6,
          builder: (ctx, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.video_call_outlined),
                    title: const Text('Upload Video'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => UploadContentScreen(
                            type: 'Video', 
                            profileName: profileName,
                            onUploadSuccess: onUploadSuccess),
                      ));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.audiotrack_outlined),
                    title: const Text('Upload Audio'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => UploadContentScreen(
                            type: 'Audio', 
                            profileName: profileName,
                            onUploadSuccess: onUploadSuccess),
                      ));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.note_add_outlined),
                    title: const Text('Create Text Post'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => UploadContentScreen(
                            type: 'Text', 
                            profileName: profileName,
                            onUploadSuccess: onUploadSuccess),
                      ));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.text_fields_outlined),
                    title: const Text('Create Text Story'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const CreateStoryScreen(),
                      ));
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
