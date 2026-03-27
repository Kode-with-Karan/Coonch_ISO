import 'package:flutter/material.dart';
import '../upload/upload_content_screen.dart';
import '../../services/playlist_service.dart';
import 'select_existing_posts_screen.dart';
import 'uploaded_playlists_screen.dart';

class CreatePlaylistScreen extends StatefulWidget {
  const CreatePlaylistScreen({super.key});

  @override
  State<CreatePlaylistScreen> createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  String _selectedType = 'Video';
  List<dynamic> _selectedPosts = [];
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _showMediaOptions() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) {
        return DraggableScrollableSheet(
          initialChildSize: 0.28,
          maxChildSize: 0.6,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text('Upload files from device'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => UploadContentScreen(
                                type: _selectedType,
                                profileName: 'Me',
                              )));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.collections),
                    title: const Text('Select existing post'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final res = await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SelectExistingPostsScreen()),
                      );
                      if (res != null && mounted) {
                        setState(() {
                          _selectedPosts = List.from(res);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Playlist'),
        centerTitle: true,
      ),
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              items: const [
                DropdownMenuItem(value: 'Video', child: Text('Video')),
                DropdownMenuItem(value: 'Audio', child: Text('Audio')),
                DropdownMenuItem(value: 'Text', child: Text('Text')),
              ],
              onChanged: (v) => setState(() => _selectedType = v ?? 'Video'),
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsCtrl,
              decoration:
                  const InputDecoration(labelText: 'Tags (comma separated)'),
            ),
            const SizedBox(height: 18),
            const Text('Media', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showMediaOptions,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _selectedPosts.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 36, color: Colors.black54),
                            SizedBox(height: 8),
                            Text('Select Posts',
                                style: TextStyle(color: Colors.black54)),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (ctx, i) {
                            final p = _selectedPosts[i];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                p['image'] ??
                                    'https://picsum.photos/200/120?random=$i',
                                width: 180,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 180,
                                  height: 120,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.grey),
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemCount: _selectedPosts.length,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _handleCreate,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14.0),
                  child: Text('Create Playlist'),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(Map payload) {
    final title = (payload['title'] as String?) ?? '';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                const Text(
                  'Playlist Created Successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Congratulations! Your playlist titled "$title" has been successfully created.',
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // close dialog
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop(true);
                    } else {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const PlaylistsScreen()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCreate() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }
    if (_selectedPosts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one post')));
      return;
    }
    setState(() => _saving = true);
    try {
      final tags = _tagsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final cover = _selectedPosts.firstWhere(
          (p) =>
              (p['thumbnail_url'] ?? p['file_url'] ?? '').toString().isNotEmpty,
          orElse: () => _selectedPosts.first);
      final payload = {
        'id': null,
        'title': _titleCtrl.text.trim(),
        'type': _selectedType,
        'description': _descCtrl.text.trim(),
        'tags': tags,
        'posts': _selectedPosts,
        'cover': (cover['thumbnail_url'] ??
                cover['file_url'] ??
                cover['image'] ??
                '')
            .toString(),
        'createdAt': DateTime.now().toIso8601String(),
      };
      await PlaylistService.addPlaylist(payload);
      if (!mounted) return;
      _showSuccessDialog(payload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create playlist')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
