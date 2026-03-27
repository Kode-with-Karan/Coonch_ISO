import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/network_avatar.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  File? _file;
  bool _isVideo = false;
  VideoPlayerController? _videoController;
  bool _uploading = false;
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _setSelectedMedia(File file, {required bool isVideo}) async {
    final oldController = _videoController;
    _videoController = null;
    await oldController?.dispose();

    if (!mounted) return;
    setState(() {
      _file = file;
      _isVideo = isVideo;
    });

    if (!isVideo) return;

    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
      });
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        Provider.of<NotificationService>(context, listen: false).showWarning(
            'Could not preview this video, but you can still post it.');
      }
    }
  }

  Future<void> _clearSelectedMedia() async {
    final oldController = _videoController;
    _videoController = null;
    await oldController?.dispose();
    if (!mounted) return;
    setState(() {
      _file = null;
      _isVideo = false;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    await _setSelectedMedia(File(picked.path), isVideo: false);
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null || !mounted) return;
    await _setSelectedMedia(File(picked.path), isVideo: false);
  }

  Future<void> _pickVideoFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    await _setSelectedMedia(File(picked.path), isVideo: true);
  }

  Future<void> _recordVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.camera);
    if (picked == null || !mounted) return;
    await _setSelectedMedia(File(picked.path), isVideo: true);
  }

  Future<void> _upload() async {
    // Allow text-only stories when no file is selected, provided caption exists.
    final caption = _captionController.text.trim();
    if (_file == null && caption.isEmpty) {
      Provider.of<NotificationService>(context, listen: false)
          .showWarning('Please add an image/video or enter text for a story');
      return;
    }

    setState(() => _uploading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    try {
      final fields = {'caption': caption, 'type': 'story'};
      Map<String, dynamic> res;
      if (_file != null) {
        res = await api.createContent(fields, file: _file, fileField: 'file');
      } else {
        res = await api.createContent(fields);
      }
      notifications.showSuccess('Story posted');
      if (!mounted) return;

      // The create endpoint may return only metadata (content_id/status).
      // Fetch the created item so home/story UI gets file_url + user payload.
      try {
        final data = (res['data'] is Map) ? res['data'] as Map : res;
        final createdId =
            (data['content_id'] ?? data['id'] ?? data['pk'])?.toString();
        if (createdId != null && createdId.isNotEmpty) {
          final fresh = await api.getContentById(createdId);
          if (mounted) {
            Navigator.of(context).pop({'data': fresh});
            return;
          }
        }
      } catch (_) {
        // Fallback to original response shape below.
      }

      Navigator.of(context).pop(res);
    } catch (e) {
      notifications.showError(
          NotificationService.formatMessage('Failed to post story: $e'));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Create Story'),
        actions: [
          TextButton(
            onPressed: _uploading ? null : _upload,
            child: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _upload,
        icon: _uploading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send),
        label: Text(_uploading ? 'Posting...' : 'Post'),
        backgroundColor: Colors.lightBlue,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const NetworkAvatar(radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _captionController,
                        decoration: const InputDecoration(
                            hintText: 'Say something about your story...'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // When no media file is selected show an explicit post button
                if (_file == null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : _upload,
                      icon: const Icon(Icons.send),
                      label: const Text('Post text-only'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  height: math.min(420.0, constraints.maxHeight * 0.6),
                  child: Center(
                    child: _file == null
                        ? SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Choose from gallery'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _takePhoto,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Take a photo'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _pickVideoFromGallery,
                                  icon: const Icon(Icons.video_library),
                                  label:
                                      const Text('Choose video from gallery'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _recordVideo,
                                  icon: const Icon(Icons.videocam),
                                  label: const Text('Record video'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isVideo)
                                  Container(
                                    width: constraints.maxWidth * 0.9,
                                    constraints: BoxConstraints(
                                      maxHeight: math.min(
                                          320.0, constraints.maxHeight * 0.55),
                                    ),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: _videoController != null &&
                                            _videoController!
                                                .value.isInitialized
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: AspectRatio(
                                                    aspectRatio:
                                                        _videoController!
                                                            .value.aspectRatio,
                                                    child: VideoPlayer(
                                                        _videoController!),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  IconButton(
                                                    onPressed: () {
                                                      final controller =
                                                          _videoController;
                                                      if (controller == null) {
                                                        return;
                                                      }
                                                      if (controller
                                                          .value.isPlaying) {
                                                        controller.pause();
                                                      } else {
                                                        controller.play();
                                                      }
                                                      setState(() {});
                                                    },
                                                    icon: Icon(
                                                      _videoController!
                                                              .value.isPlaying
                                                          ? Icons.pause_circle
                                                          : Icons.play_circle,
                                                      size: 28,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      _file!.path
                                                          .split(Platform
                                                              .pathSeparator)
                                                          .last,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          )
                                        : const SizedBox(
                                            height: 140,
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          ),
                                  )
                                else
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                        maxWidth: constraints.maxWidth * 0.9,
                                        maxHeight: math.min(360.0,
                                            constraints.maxHeight * 0.5)),
                                    child: Image.file(
                                      _file!,
                                      width: double.infinity,
                                      height: null,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                            child: Icon(Icons.broken_image,
                                                color: Colors.grey)),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _clearSelectedMedia,
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Choose different'),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _uploading ? null : _upload,
                                  icon: _uploading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.upload),
                                  label:
                                      Text(_uploading ? 'Posting...' : 'Post'),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
