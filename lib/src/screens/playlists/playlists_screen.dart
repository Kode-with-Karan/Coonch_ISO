import 'package:flutter/material.dart';

import 'uploaded_playlists_screen.dart';

/// Wrapper to keep existing navigation routes working.
class PlayListsScreen extends StatelessWidget {
  const PlayListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaylistsScreen();
  }
}
