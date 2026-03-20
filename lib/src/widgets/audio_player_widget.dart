import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// A simple audio player widget that uses `audioplayers` for real playback.
///
/// - Supports loading from a URL (`url`) or local file path.
/// - Shows play/pause, seek slider, elapsed/total time, and mute toggle.
class AudioPlayerWidget extends StatefulWidget {
  final String? url;
  final double? height;
  final VoidCallback? onComplete;
  final bool autoPlay;

  const AudioPlayerWidget({
    super.key, 
    required this.url, 
    this.height, 
    this.onComplete,
    this.autoPlay = false,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _ready = false;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;
  bool _muted = false;
  // waveform animation
  final Random _rand = Random();
  late List<double> _barHeights;
  Timer? _barTimer;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    // Stop after completion; we manually restart when user taps play again.
    _player.setReleaseMode(ReleaseMode.stop);

    _positionSub = _player.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });
    _durationSub = _player.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      setState(() => _playerState = s);
      // Start/stop waveform animation depending on play state
      if (s == PlayerState.playing) {
        _startBarTimer();
      } else {
        _stopBarTimer();
      }
      // When playback completes, reset position to start so user can replay.
      if (s == PlayerState.completed) {
        // Attempt to seek to start; ignore errors so UI stays stable.
        _player.seek(Duration.zero).catchError((_) {});
        setState(() {
          _position = Duration.zero;
          _playerState = PlayerState.stopped;
        });
        widget.onComplete?.call();
      }
    });

    // Attempt to set source if URL is provided
    if (widget.url != null && widget.url!.isNotEmpty) {
      _setSource(widget.url!);
    }

    // initialize waveform bars
    _barHeights = List.generate(24, (_) => 0.2 + _rand.nextDouble() * 0.8);
  }

  Future<void> _setSource(String url) async {
    try {
      // `setSourceUrl` handles http(s) and file URIs
      await _player.setSourceUrl(url);
      // mark ready after successfully setting source
      setState(() => _ready = true);
      
      // Auto-play if enabled
      if (widget.autoPlay && url.isNotEmpty) {
        try {
          await _player.play(UrlSource(url));
        } catch (_) {
          // ignore auto-play errors
        }
      }
    } catch (e) {
      // ignore errors; UI remains functional
    }
  }

  @override
  void didUpdateWidget(covariant AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url && widget.url != null) {
      _setSource(widget.url!);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _barTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _startBarTimer() {
    _barTimer?.cancel();
    _barTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      setState(() {
        for (var i = 0; i < _barHeights.length; i++) {
          final target = 0.15 + _rand.nextDouble() * 0.85;
          _barHeights[i] = (_barHeights[i] * 0.7) + (target * 0.3);
        }
      });
    });
  }

  void _stopBarTimer() {
    _barTimer?.cancel();
    _barTimer = null;
  }

  String _formatTime(Duration d) {
    final int s = d.inSeconds;
    final int mins = s ~/ 60;
    final int secs = s % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
      return;
    }
    final hasUrl = widget.url != null && widget.url!.isNotEmpty;
    // Ensure source is ready before attempting resume/play. If not ready,
    // try to set the source with a short timeout so the UI remains responsive.
    if (!_ready && hasUrl) {
      try {
        await _setSource(widget.url!).timeout(const Duration(seconds: 8));
      } catch (_) {
        // ignore timeout or setSource errors — we'll still try to resume/play
      }
    }

    // If playback finished (or we're at the end), restart from the beginning
    // and call play() directly to avoid resume getting stuck.
    final bool atEnd = _duration > Duration.zero &&
        _position >= _duration - const Duration(milliseconds: 300);
    if (_playerState == PlayerState.completed || atEnd) {
      await _restartFromBeginning();
      return;
    }

    // Try to resume; some platform/plugin versions implement `resume`, others
    // expect `play` to start playback. Catch MissingPluginException and
    // fallback to `play(url)` so the app remains compatible.
    try {
      if (_playerState == PlayerState.paused && !atEnd) {
        await _player.resume();
        return;
      }
      if (hasUrl) {
        await _player.play(UrlSource(widget.url!));
      }
    } catch (e) {
      // If resume isn't implemented, attempt to play from the provided URL.
      if (hasUrl) {
        try {
          // Use UrlSource for the newer audioplayers API.
          await _player.play(UrlSource(widget.url!));
        } catch (_) {
          // swallows any error — playback will remain silent but app won't crash.
        }
      }
    }
  }

  Future<void> _restartFromBeginning() async {
    final hasUrl = widget.url != null && widget.url!.isNotEmpty;
    if (!hasUrl) return;
    final src = widget.url!;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _player.seek(Duration.zero);
    } catch (_) {}
    // Reapply source to avoid platform edge-cases after completion.
    try {
      if (!_ready) {
        await _player.setSourceUrl(src);
        setState(() => _ready = true);
      }
      await _player.play(UrlSource(src));
    } catch (_) {}
    setState(() {
      _position = Duration.zero;
      _playerState = PlayerState.playing;
    });
  }

  Future<void> _seek(double seconds) async {
    final pos = Duration(milliseconds: (seconds * 1000).round());
    try {
      // Guard seek with a timeout so it can't hang indefinitely.
      await _player.seek(pos).timeout(const Duration(seconds: 8));
    } catch (_) {
      // ignore seek errors/timeouts — keep UI stable
    }
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _player.setVolume(_muted ? 0.0 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final height =
        widget.height ?? 78.0; // keep compact to avoid overflow in cards
    return SizedBox(
      height: height,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.02), blurRadius: 4)
          ],
        ),
        child: Row(children: [
          // Play / pause
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: Colors.blue, shape: BoxShape.circle),
              child: Icon(
                _playerState == PlayerState.playing
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  // waveform bars
                  Expanded(
                    child: SizedBox(
                      height: 22,
                      child: CustomPaint(
                        painter: _WaveformPainter(_barHeights,
                            color: Colors.grey.shade300,
                            activeColor: Colors.blue.shade300),
                        child: Container(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_formatTime(_position),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(width: 6),
                  const Text('/',
                      style: TextStyle(fontSize: 12, color: Colors.black26)),
                  const SizedBox(width: 6),
                  Text(_formatTime(_duration),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
                const SizedBox(height: 4),
                // Compact seek slider below waveform
                SizedBox(
                  height: 26,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.2,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6)),
                    child: Slider(
                      min: 0.0,
                      max: _duration.inMilliseconds > 0
                          ? _duration.inMilliseconds.toDouble() / 1000.0
                          : 0.0,
                      value: (_position.inMilliseconds.toDouble() / 1000.0)
                          .clamp(
                              0.0,
                              _duration.inMilliseconds > 0
                                  ? _duration.inMilliseconds.toDouble() / 1000.0
                                  : 0.0),
                      onChanged: (v) {
                        setState(() {
                          _position =
                              Duration(milliseconds: (v * 1000).round());
                        });
                        _seek(v);
                      },
                      activeColor: Colors.blue,
                      inactiveColor: Colors.grey.shade300,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              iconSize: 20,
              onPressed: _toggleMute,
              icon: Icon(_muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.black54),
            )
          ])
        ]),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> bars; // values 0..1
  final Color color;
  final Color activeColor;
  _WaveformPainter(this.bars, {required this.color, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final active = Paint()..color = activeColor;
    final barWidth = size.width / (bars.length * 1.6);
    final gap = barWidth * 0.6;
    double x = 0;
    for (var i = 0; i < bars.length; i++) {
      final h = (bars[i].clamp(0.05, 1.0)) * size.height;
      final r = Rect.fromLTWH(x, (size.height - h) / 2, barWidth, h);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)),
          i.isEven ? active : paint);
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.bars != bars;
}
