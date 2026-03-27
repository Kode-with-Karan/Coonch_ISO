import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config.dart';

/// Lightweight network video player with tap-to-play/pause controls.
class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({super.key, required this.url, this.controller});

  final String url;
  final VideoPlayerController? controller;

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  VideoPlayerController? _controller;
  Future<void>? _initFuture;
  bool _hasError = false;
  bool _isExternalController = false;

  @override
  void initState() {
    super.initState();
    // Use external controller if provided, otherwise create our own.
    if (widget.controller != null) {
      _controller = widget.controller;
      _isExternalController = true;
      if (_controller!.value.isInitialized) {
        _initFuture = Future.value();
      } else {
        _initFuture = _controller!
            .initialize()
            .catchError((_) => setState(() => _hasError = true));
      }
      _controller!.addListener(_onControllerUpdate);
    } else {
      _initFuture = _initializeInternalController();
    }
  }

  Uri? _toAbsoluteUri(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return null;
    url = url.replaceAll('\\', '/');

    if (url.startsWith('//')) {
      url = 'https:$url';
    }

    final base = Config.baseApiUrl.endsWith('/')
        ? Config.baseApiUrl
        : '${Config.baseApiUrl}/';

    if (url.startsWith('/')) {
      url = '${base.substring(0, base.length - 1)}$url';
    } else if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = '$base$url';
    }

    return Uri.tryParse(url);
  }

  List<Uri> _candidateUris(String raw) {
    final Set<String> seen = {};
    final List<Uri> out = [];

    void addUri(Uri? uri) {
      if (uri == null) return;
      final key = uri.toString();
      if (seen.add(key)) out.add(uri);
    }

    final primary = _toAbsoluteUri(raw);
    addUri(primary);

    if (primary != null) {
      final encoded = Uri.tryParse(Uri.encodeFull(primary.toString()));
      addUri(encoded);

      if (primary.scheme == 'http' &&
          primary.host.toLowerCase().contains('pythonanywhere.com')) {
        addUri(primary.replace(scheme: 'https'));
      }
    }

    return out;
  }

  Future<void> _initializeInternalController() async {
    final candidates = _candidateUris(widget.url);
    Object? lastError;

    for (final uri in candidates) {
      final c = VideoPlayerController.networkUrl(uri);
      try {
        await c.initialize();
        await c.setLooping(true);

        if (!mounted) {
          await c.dispose();
          return;
        }

        _controller = c;
        _controller!.addListener(_onControllerUpdate);
        return;
      } catch (e) {
        lastError = e;
        await c.dispose();
      }
    }

    if (mounted) {
      setState(() => _hasError = true);
    }

    // ignore: avoid_print
    print('VideoPlayerView: failed to load URL "${widget.url}"; '
        'candidates=${candidates.map((u) => u.toString()).toList()} '
        'error=$lastError');
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    if (!_isExternalController) {
      _controller?.removeListener(_onControllerUpdate);
      _controller?.dispose();
    } else {
      _controller?.removeListener(_onControllerUpdate);
    }
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty || _hasError) {
      return Container(
        height: 220,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Text('Unable to load video'),
      );
    }

    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            height: 220,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        }
        if (_hasError ||
            _controller == null ||
            !_controller!.value.isInitialized) {
          return Container(
            height: 220,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Text('Unable to load video'),
          );
        }

        final aspect = _controller!.value.aspectRatio == 0
            ? 16 / 9
            : _controller!.value.aspectRatio;

        return GestureDetector(
          onTap: _togglePlay,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: aspect,
                child: VideoPlayer(_controller!),
              ),
              Container(
                color: Colors.black26,
              ),
              Icon(
                _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 64,
                color: Colors.white,
              ),
            ],
          ),
        );
      },
    );
  }
}
