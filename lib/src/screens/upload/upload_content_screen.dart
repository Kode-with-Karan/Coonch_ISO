import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:record/record.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';
import 'drafts_screen.dart';

class UploadContentScreen extends StatefulWidget {
  final String type;
  final String profileName;
  final String? seriesId;
  final String? initialSeriesTitle;
  final String? initialSeriesDescription;
  final VoidCallback? onUploadSuccess;

  const UploadContentScreen({
    super.key,
    required this.type,
    required this.profileName,
    this.seriesId,
    this.initialSeriesTitle,
    this.initialSeriesDescription,
    this.onUploadSuccess,
  });

  @override
  State<UploadContentScreen> createState() => _UploadContentScreenState();
}

class SeriesItem {
  String? _id;
  String get id => _id ??= UniqueKey().toString();

  String type;
  File? file;
  String? fileName;
  File? thumbnail;
  String? thumbnailFile;
  String caption;
  int? order;

  SeriesItem({
    String? id,
    this.type = 'video',
    this.file,
    this.fileName,
    this.thumbnail,
    this.thumbnailFile,
    this.caption = '',
    this.order,
  }) {
    _id = id;
  }
}

class _UploadContentScreenState extends State<UploadContentScreen> {
  String? _pickedFileName;
  File? _pickedFile;
  File? _thumbnailFile;
  final _captionController = TextEditingController();
  File? thumbnail;
  List<dynamic> _categories = [];
  int? _selectedCategoryId;
  String? _otherCategoryName;
  bool _loadingCategories = false;
  String? _categoriesError;
  String? _selectedTopic;
  String _selectedType = 'image';
  bool _uploading = false;
  double _uploadProgress = -1.0;
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isSeriesAudioRecording = false;
  int? _recordingSeriesItemIndex;
  final Map<String, VideoPlayerController> _seriesVideoControllers = {};

  bool _isSeriesMode = false;
  final List<SeriesItem> _seriesItems = [];
  final _seriesTitleController = TextEditingController();
  final _seriesDescriptionController = TextEditingController();
  String? _prefilledSeriesId;

  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  double? _computedPrice = 0.0;
  bool _canSetCustomPrice = false;
  bool _isCalculatingDuration = false;
  bool _publishSingleNow = true;
  bool _publishSeriesNow = true;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.type.toLowerCase();
    _prefilledSeriesId = widget.seriesId;
    if (widget.initialSeriesTitle != null) {
      _seriesTitleController.text = widget.initialSeriesTitle!;
    }
    if (widget.initialSeriesDescription != null) {
      _seriesDescriptionController.text = widget.initialSeriesDescription!;
    }
    if (widget.seriesId != null) {
      _isSeriesMode = true;
    }
    _loadCategories();
    _checkInstituteStatus();
  }

  Future<void> _checkInstituteStatus() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final profile = await api.getProfile();
      if (profile['data'] != null && profile['data']['is_institute'] == true) {
        setState(() {
          _canSetCustomPrice = true;
        });
      }
    } catch (e) {
      // ignore errors, default to false
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return '${minutes}m ${secs}s';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }

  Future<int?> _getVideoDuration(File videoFile) async {
    try {
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      final duration = controller.value.duration.inSeconds;
      await controller.dispose();
      return duration;
    } catch (e) {
      return null;
    }
  }

  Future<int?> _getAudioDuration(File audioFile) async {
    try {
      final player = AudioPlayer();
      await player.setSourceDeviceFile(audioFile.path);
      final duration = await player.getDuration();
      await player.dispose();
      if (duration != null) {
        return duration.inSeconds;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _calculateDurationForFile(File file) async {
    if (!mounted) return;

    setState(() {
      _isCalculatingDuration = true;
    });

    if (_selectedType == 'video' ||
        _selectedType == 'short' ||
        _selectedType == 'story') {
      final duration = await _getVideoDuration(file);
      if (duration != null && mounted) {
        setState(() {
          _durationController.text = duration.toString();
          _isCalculatingDuration = false;
        });
        _computePricePreview();
      } else if (mounted) {
        setState(() {
          _isCalculatingDuration = false;
        });
      }
    } else if (_selectedType == 'audio') {
      final duration = await _getAudioDuration(file);
      if (duration != null && mounted) {
        setState(() {
          _durationController.text = duration.toString();
          _isCalculatingDuration = false;
        });
        _computePricePreview();
      } else if (mounted) {
        setState(() {
          _isCalculatingDuration = false;
        });
      }
    }
  }

  void _computePricePreview() {
    if (_selectedTopic != 'education' && _selectedTopic != 'entertainment') {
      setState(() {
        _computedPrice = 0.0;
      });
      return;
    }

    final duration = int.tryParse(_durationController.text) ?? 0;
    final wordCount = _captionController.text.trim().isEmpty
        ? 0
        : _captionController.text.trim().split(RegExp(r'\s+')).length;
    double price = 0.0;

    if (_selectedTopic == 'entertainment') {
      if (_selectedType == 'video' ||
          _selectedType == 'short' ||
          _selectedType == 'story' ||
          _selectedType == 'audio') {
        if (duration <= 120) {
          price = 1.0;
        } else if (duration <= 300) {
          price = 2.0;
        } else if (duration <= 480) {
          price = 3.0;
        } else if (duration <= 720) {
          price = 4.0;
        } else {
          price = 5.0;
        }
      } else if (_selectedType == 'text') {
        if (wordCount < 1000) {
          price = 0.0;
        } else if (wordCount < 5000) {
          price = 1.0;
        } else if (wordCount < 10000) {
          price = 2.0;
        } else if (wordCount < 20000) {
          price = 3.0;
        } else {
          price = 5.0;
        }
      }
    } else if (_selectedTopic == 'education') {
      if (_selectedType == 'video' ||
          _selectedType == 'short' ||
          _selectedType == 'story') {
        if (duration < 120) {
          price = 0.0;
        } else if (duration < 900) {
          price = 1.0;
        } else if (duration < 1800) {
          price = 2.0;
        } else if (duration < 3600) {
          price = 3.0;
        } else if (duration < 10800) {
          price = 4.0;
        } else {
          price = 5.0;
        }
      } else if (_selectedType == 'audio') {
        if (duration < 180) {
          price = 0.0;
        } else if (duration < 900) {
          price = 1.0;
        } else if (duration < 1800) {
          price = 2.0;
        } else if (duration < 3600) {
          price = 3.0;
        } else if (duration < 14400) {
          price = 4.0;
        } else {
          price = 5.0;
        }
      } else if (_selectedType == 'text') {
        if (wordCount < 1000) {
          price = 0.0;
        } else if (wordCount < 5000) {
          price = 1.0;
        } else if (wordCount < 10000) {
          price = 2.0;
        } else if (wordCount < 20000) {
          price = 3.0;
        } else if (wordCount < 25000) {
          price = 4.0;
        } else {
          price = 5.0;
        }
      }
    }

    setState(() {
      _computedPrice = price;
    });
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    return trimmed.split(RegExp(r'\s+')).length;
  }

  bool _usesDurationPricing(String contentType) {
    return contentType == 'video' ||
        contentType == 'short' ||
        contentType == 'story' ||
        contentType == 'audio';
  }

  String? _validatedCustomPrice() {
    final raw = _priceController.text.trim();
    if (raw.isEmpty) {
      return null;
    }

    final parsed = double.tryParse(raw);
    if (parsed == null || parsed < 1 || parsed > 5) {
      throw const FormatException('Custom price must be between £1 and £5');
    }

    return parsed.toStringAsFixed(2);
  }

  Future<int?> _resolveDurationForUpload({
    required String contentType,
    required File? file,
    String? durationText,
  }) async {
    if (!_usesDurationPricing(contentType)) {
      return null;
    }

    final parsedDuration = int.tryParse((durationText ?? '').trim());
    if (parsedDuration != null && parsedDuration > 0) {
      return parsedDuration;
    }

    if (file == null) {
      return null;
    }

    if (contentType == 'audio') {
      return await _getAudioDuration(file);
    }

    return await _getVideoDuration(file);
  }

  Future<Map<String, String>> _buildPricingFieldsForUpload({
    required String contentType,
    required String caption,
    required File? file,
    String? durationText,
    bool allowCustomPrice = false,
  }) async {
    final pricingFields = <String, String>{};

    final duration = await _resolveDurationForUpload(
      contentType: contentType,
      file: file,
      durationText: durationText,
    );
    if (duration != null) {
      pricingFields['duration_seconds'] = duration.toString();
    }

    if (contentType == 'text') {
      pricingFields['word_count'] = _countWords(caption).toString();
    }

    if (allowCustomPrice) {
      final customPrice = _validatedCustomPrice();
      if (customPrice != null) {
        pricingFields['price'] = customPrice;
      }
    }

    return pricingFields;
  }

  String _getEntertainmentPricingTier() {
    final duration = int.tryParse(_durationController.text) ?? 0;
    if (duration <= 120) {
      return 'Short clip (≤2 min): £1';
    } else if (duration <= 300) {
      return '2-5 min: £2';
    } else if (duration <= 480) {
      return '5-8 min: £3';
    } else if (duration <= 720) {
      return '8-12 min: £4';
    } else {
      return '12+ min: £5';
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _seriesTitleController.dispose();
    _seriesDescriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _stopRecordingIfActive();
    _stopSeriesAudioRecordingIfActive();
    for (final controller in _seriesVideoControllers.values) {
      controller.dispose();
    }
    _seriesVideoControllers.clear();
    _recorder.dispose();
    super.dispose();
  }

  void _disposeSeriesVideoController(String itemId) {
    final controller = _seriesVideoControllers.remove(itemId);
    controller?.dispose();
  }

  Future<void> _initializeSeriesVideoPreview(int index, File file) async {
    if (index < 0 || index >= _seriesItems.length) return;
    final itemId = _seriesItems[index].id;

    _disposeSeriesVideoController(itemId);

    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      await controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final stillExists = _seriesItems.any((item) => item.id == itemId);
      if (!stillExists) {
        await controller.dispose();
        return;
      }

      setState(() {
        _seriesVideoControllers[itemId] = controller;
      });
    } catch (_) {
      await controller.dispose();
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoriesError = null;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final cats = await api.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCategories = false;
        _categoriesError = 'Failed to load categories';
      });
    }
  }

  void _applyPickedPath(String path, String? name) {
    final fileName = (name != null && name.isNotEmpty)
        ? name
        : path.split(Platform.pathSeparator).last;
    setState(() {
      _pickedFile = File(path);
      _pickedFileName = fileName;
      _thumbnailFile = null;
    });
    if (_pickedFile != null &&
        (_selectedType == 'video' ||
            _selectedType == 'short' ||
            _selectedType == 'story' ||
            _selectedType == 'audio')) {
      _calculateDurationForFile(_pickedFile!);
    }
  }

  void _clearPickedFiles() {
    setState(() {
      _pickedFile = null;
      _pickedFileName = null;
      _thumbnailFile = null;
    });
  }

  Future<void> _pickAudioFromDevice() async {
    _clearPickedFiles();
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
      );
      if (res != null && res.files.isNotEmpty) {
        final p = res.files.first;
        if (p.path != null) _applyPickedPath(p.path!, p.name);
      }
    } catch (e) {
      Provider.of<NotificationService>(context, listen: false).showError(
        NotificationService.formatMessage('Failed to pick audio: $e'),
      );
    }
  }

  Future<void> _stopRecordingIfActive({bool applyFile = false}) async {
    if (!_isRecording) return;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      // ignore stop errors
    }
    setState(() {
      _isRecording = false;
    });
    if (applyFile && path != null) {
      _applyPickedPath(path, path.split(Platform.pathSeparator).last);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingIfActive(applyFile: true);
      return;
    }
    if (_isSeriesAudioRecording) {
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showWarning('Stop series audio recording first');
      return;
    }
    _clearPickedFiles();
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        Provider.of<NotificationService>(
          context,
          listen: false,
        ).showWarning('Microphone permission is required to record audio');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      setState(() {
        _isRecording = true;
      });
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showInfo('Recording started...');
    } catch (e) {
      setState(() => _isRecording = false);
      Provider.of<NotificationService>(context, listen: false).showError(
        NotificationService.formatMessage('Failed to start recording: $e'),
      );
    }
  }

  Future<void> _stopSeriesAudioRecordingIfActive({
    bool applyFile = false,
  }) async {
    if (!_isSeriesAudioRecording) return;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}

    final recordingIndex = _recordingSeriesItemIndex;
    setState(() {
      _isSeriesAudioRecording = false;
      _recordingSeriesItemIndex = null;
    });

    if (applyFile &&
        path != null &&
        recordingIndex != null &&
        recordingIndex < _seriesItems.length) {
      setState(() {
        _seriesItems[recordingIndex].file = File(path!);
        _seriesItems[recordingIndex].fileName = path
            .split(Platform.pathSeparator)
            .last;
      });
    }
  }

  Future<void> _toggleSeriesAudioRecording(int index) async {
    if (_isRecording) {
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showWarning('Stop single audio recording first');
      return;
    }

    if (_isSeriesAudioRecording && _recordingSeriesItemIndex == index) {
      await _stopSeriesAudioRecordingIfActive(applyFile: true);
      return;
    }

    if (_isSeriesAudioRecording && _recordingSeriesItemIndex != index) {
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showWarning('Another series item is currently recording');
      return;
    }

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        Provider.of<NotificationService>(
          context,
          listen: false,
        ).showWarning('Microphone permission is required to record audio');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/series_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      setState(() {
        _isSeriesAudioRecording = true;
        _recordingSeriesItemIndex = index;
      });
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showInfo('Recording started for item ${index + 1}');
    } catch (e) {
      setState(() {
        _isSeriesAudioRecording = false;
        _recordingSeriesItemIndex = null;
      });
      Provider.of<NotificationService>(context, listen: false).showError(
        NotificationService.formatMessage('Failed to start recording: $e'),
      );
    }
  }

  Future<void> _recordSingleVideo() async {
    _clearPickedFiles();
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.camera);
      if (picked != null) {
        _applyPickedPath(picked.path, picked.name);
      }
    } catch (e) {
      Provider.of<NotificationService>(context, listen: false).showError(
        NotificationService.formatMessage('Failed to record video: $e'),
      );
    }
  }

  // Try to read a backend-provided series id from a createContent response.
  String? _extractSeriesIdFromResponse(Map<String, dynamic>? res) {
    if (res == null) return null;
    // Common patterns: direct field, nested in data, or nested series object.
    if (res['series_id'] != null) return res['series_id'].toString();
    if (res['seriesId'] != null) return res['seriesId'].toString();
    final data = res['data'];
    if (data is Map) {
      if (data['series_id'] != null) return data['series_id'].toString();
      if (data['seriesId'] != null) return data['seriesId'].toString();
      final series = data['series'];
      if (series is Map && series['id'] != null) return series['id'].toString();
    }
    final series = res['series'];
    if (series is Map && series['id'] != null) return series['id'].toString();
    return null;
  }

  Future<void> _pickTextFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      String? contents;
      if (picked.bytes != null) {
        contents = utf8.decode(picked.bytes!);
      } else if (picked.path != null) {
        contents = await File(picked.path!).readAsString();
      }
      if (contents == null || contents.trim().isEmpty) {
        Provider.of<NotificationService>(
          context,
          listen: false,
        ).showWarning('Selected file is empty');
        return;
      }
      final sanitized = contents.trim();
      setState(() {
        _captionController.text = sanitized;
        _pickedFileName = picked.name;
      });
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showSuccess('Text loaded from file');
    } catch (e) {
      Provider.of<NotificationService>(context, listen: false).showError(
        NotificationService.formatMessage('Failed to read text file: $e'),
      );
    }
  }

  void _chooseFile() async {
    _clearPickedFiles();
    try {
      final picker = ImagePicker();
      if (_selectedType == 'image') {
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked != null) _applyPickedPath(picked.path, picked.name);
        return;
      }
      if (_selectedType == 'audio') {
        await _pickAudioFromDevice();
        return;
      }
      if (_selectedType == 'story') {
        final choice = await showDialog<String?>(
          context: context,
          builder: (c) => SimpleDialog(
            title: const Text('Create story from'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.of(c).pop('image'),
                child: const Text('Image'),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.of(c).pop('video'),
                child: const Text('Video'),
              ),
            ],
          ),
        );
        if (choice == 'image') {
          final picked = await picker.pickImage(source: ImageSource.gallery);
          if (picked != null) _applyPickedPath(picked.path, picked.name);
          return;
        }
        if (choice == 'video') {
          final picked = await picker.pickVideo(source: ImageSource.gallery);
          if (picked != null) _applyPickedPath(picked.path, picked.name);
          return;
        }
      }
      if (_selectedType == 'video' || _selectedType == 'short') {
        final picked = await picker.pickVideo(source: ImageSource.gallery);
        if (picked != null) _applyPickedPath(picked.path, picked.name);
        return;
      }
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showWarning('Only image/video pick is supported in this build.');
    } catch (e) {
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showError(NotificationService.formatMessage('Failed to pick file: $e'));
    }
  }

  Future<void> _generateThumbnail() async {
    if (_pickedFile == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: _pickedFile!.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 75,
      );
      if (thumbPath != null) {
        final f = File(thumbPath);
        final sanitized = await _sanitizeImageFile(f);
        if (sanitized != null) setState(() => _thumbnailFile = sanitized);
      }
    } catch (_) {}
  }

  Future<File?> _sanitizeImageFile(File f) async {
    try {
      final bytes = await f.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final jpg = img.encodeJpg(decoded, quality: 85);
      await f.writeAsBytes(jpg, flush: true);
      return f;
    } catch (e) {
      return null;
    }
  }

  Future<void> _pickThumbnailManually() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) setState(() => _thumbnailFile = File(picked.path));
    } catch (_) {}
  }

  Widget _safeImagePreview(
    File file, {
    BoxFit fit = BoxFit.cover,
    double? maxWidth,
    double? maxHeight,
  }) {
    try {
      if (!file.existsSync()) {
        return Container(
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image),
        );
      }
      final length = file.lengthSync();
      if (length < 200) {
        return Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[100],
          child: const Text('Preview not available'),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          fit: fit,
          width: maxWidth,
          height: maxHeight,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image),
          ),
        ),
      );
    } catch (_) {
      return Container(
        padding: const EdgeInsets.all(8),
        color: Colors.grey[100],
        child: const Text('Preview not available'),
      );
    }
  }

  void _onCategoryTap() async {
    final selected = await showDialog<bool?>(
      context: context,
      builder: (c) {
        final controller = TextEditingController();
        List<dynamic> filtered = List.from(_categories);
        return StatefulBuilder(
          builder: (ctx, setSt) {
            void updateFilter(String q) {
              final ql = q.toLowerCase();
              filtered = _categories.where((cat) {
                try {
                  final name = (cat is Map && cat['name'] != null)
                      ? cat['name'].toString().toLowerCase()
                      : cat.toString().toLowerCase();
                  return name.contains(ql);
                } catch (_) {
                  return false;
                }
              }).toList();
              setSt(() {});
            }

            return AlertDialog(
              title: const Text('Select category'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Search categories',
                      ),
                      onChanged: updateFilter,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (filtered.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('No categories found'),
                            ),
                          ...filtered.map((cat) {
                            final id = (cat is Map && cat['id'] != null)
                                ? cat['id'] as int
                                : null;
                            final name = (cat is Map && cat['name'] != null)
                                ? cat['name'].toString()
                                : cat.toString();
                            final image =
                                (cat is Map && cat['image_url'] != null)
                                ? cat['image_url'] as String?
                                : null;
                            return ListTile(
                              leading: image != null
                                  ? ClipOval(
                                      child: Image.network(
                                        image,
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 36,
                                          height: 36,
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.broken_image,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const CircleAvatar(
                                      radius: 18,
                                      child: Icon(Icons.category),
                                    ),
                              title: Text(name),
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId = id;
                                  _otherCategoryName = null;
                                });
                                Navigator.of(ctx).pop(true);
                              },
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected == true) setState(() {});
  }

  Future<void> _upload() async {
    if (_uploading) return;
    if (_selectedType != 'text' && _pickedFile == null) {
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showWarning('Please choose a file');
      return;
    }

    if (_selectedType == 'text' && _captionController.text.trim().isEmpty) {
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showWarning('Please enter text or upload a .txt file');
      return;
    }

    if (_selectedTopic == null || _selectedTopic!.isEmpty) {
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showWarning('Please select a topic');
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });
    final api = Provider.of<ApiService>(context, listen: false);
    final notifications = Provider.of<NotificationService>(
      context,
      listen: false,
    );

    try {
      final fields = <String, String>{};
      fields['type'] = _selectedType;
      final caption = _captionController.text.trim();
      if (caption.isNotEmpty) fields['caption'] = caption;
      if (_selectedTopic != null) fields['topic'] = _selectedTopic!;
      fields['publish_now'] = _publishSingleNow.toString();

      fields.addAll(
        await _buildPricingFieldsForUpload(
          contentType: _selectedType,
          caption: caption,
          file: _pickedFile,
          durationText: _durationController.text,
          allowCustomPrice: _selectedTopic == 'education' && _canSetCustomPrice,
        ),
      );

      if (_selectedCategoryId != null) {
        fields['category'] = _selectedCategoryId.toString();
      }

      const fileField = 'file';

      if ((_selectedType == 'video' ||
              _selectedType == 'short' ||
              _selectedType == 'story') &&
          _thumbnailFile == null) {
        await _generateThumbnail();
      }

      final res = await api.createContent(
        fields,
        file: _pickedFile,
        fileField: fileField,
        thumbnail: _thumbnailFile,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _uploadProgress = progress);
          }
        },
      );

      final awarded =
          ((res['data'] ?? const {})['reward_points_awarded']) as int?;
      final status =
          ((res['data'] ?? const {})['status'] ??
                  (_publishSingleNow ? 'published' : 'draft'))
              .toString();
      final isDraft = status == 'draft';

      if (isDraft) {
        notifications.showSuccess('Draft saved successfully!');
      } else if (awarded != null && awarded > 0) {
        notifications.showSuccess(
          '+$awarded points earned for your upload! 🎉',
        );
      } else {
        notifications.showSuccess('Content uploaded successfully!');
      }
      if (!mounted) return;
      widget.onUploadSuccess?.call();
      Navigator.of(context).pop(res);
    } catch (e) {
      notifications.showError(
        NotificationService.formatMessage('Failed to upload: $e'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = -1;
        });
      }
    }
  }

  void _addSeriesItem() {
    setState(() {
      _seriesItems.add(
        SeriesItem(type: 'video', order: _seriesItems.length + 1),
      );
    });
  }

  void _removeSeriesItem(int index) {
    if (_isSeriesAudioRecording && _recordingSeriesItemIndex == index) {
      _stopSeriesAudioRecordingIfActive();
    }
    final item = _seriesItems[index];
    _disposeSeriesVideoController(item.id);
    setState(() {
      _seriesItems.removeAt(index);
      for (int i = 0; i < _seriesItems.length; i++) {
        _seriesItems[i].order = i + 1;
      }
    });
  }

  void _updateSeriesItemType(int index, String type) {
    final item = _seriesItems[index];
    final oldType = item.type;
    if (oldType == 'video' && type != 'video') {
      _disposeSeriesVideoController(item.id);
    }

    setState(() {
      _seriesItems[index].type = type;
    });
  }

  Future<void> _pickFileForSeriesItem(
    int index, {
    bool useCameraForVideo = false,
  }) async {
    final item = _seriesItems[index];
    try {
      final picker = ImagePicker();

      if (item.type == 'image') {
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked != null) {
          setState(() {
            item.file = File(picked.path);
            item.fileName = picked.name;
          });
        }
      } else if (item.type == 'video') {
        final picked = await picker.pickVideo(
          source: useCameraForVideo ? ImageSource.camera : ImageSource.gallery,
        );
        if (picked != null) {
          final pickedFile = File(picked.path);
          setState(() {
            item.file = pickedFile;
            item.fileName = picked.name;
          });
          // Auto-generate a thumbnail for the series video item when possible.
          await _generateSeriesItemThumbnail(index, picked.path);
          await _initializeSeriesVideoPreview(index, pickedFile);
        }
      } else if (item.type == 'audio') {
        final res = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
        );
        if (res != null && res.files.isNotEmpty) {
          final p = res.files.first;
          if (p.path != null) {
            setState(() {
              item.file = File(p.path!);
              item.fileName = p.name;
            });
          }
        }
      }
    } catch (e) {
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showError(NotificationService.formatMessage('Failed to pick file: $e'));
    }
  }

  Future<void> _generateSeriesItemThumbnail(int index, String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 75,
      );
      if (thumbPath != null) {
        final f = File(thumbPath);
        final sanitized = await _sanitizeImageFile(f);
        if (sanitized != null) {
          setState(() {
            _seriesItems[index].thumbnail = sanitized;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pickSeriesItemThumbnail(int index) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final sanitized = await _sanitizeImageFile(File(picked.path));
        if (sanitized != null) {
          setState(() {
            _seriesItems[index].thumbnail = sanitized;
          });
        }
      }
    } catch (_) {}
  }

  void _updateSeriesItemCaption(int index, String caption) {
    // Avoid rebuilding the field on every keystroke to prevent cursor jumps.
    _seriesItems[index].caption = caption;
  }

  Future<void> _uploadSeries() async {
    if (_uploading) return;

    if (_seriesTitleController.text.trim().isEmpty) {
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showWarning('Please enter a series title');
      return;
    }

    if (_seriesItems.isEmpty) {
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showWarning('Please add at least one item to the series');
      return;
    }

    for (int i = 0; i < _seriesItems.length; i++) {
      final item = _seriesItems[i];
      if (item.type != 'text' && item.file == null) {
        Provider.of<NotificationService>(
          context,
          listen: false,
        ).showWarning('Please select a file for item ${i + 1}');
        return;
      }
      if (item.type == 'text' && item.caption.trim().isEmpty) {
        Provider.of<NotificationService>(
          context,
          listen: false,
        ).showWarning('Please enter text for item ${i + 1}');
        return;
      }
    }

    if (_selectedTopic == null || _selectedTopic!.isEmpty) {
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).showWarning('Please select a topic');
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });
    final api = Provider.of<ApiService>(context, listen: false);
    final notifications = Provider.of<NotificationService>(
      context,
      listen: false,
    );

    try {
      String currentSeriesId =
          _prefilledSeriesId ??
          'series_${DateTime.now().millisecondsSinceEpoch}';
      String? backendSeriesId;
      final seriesTitle = _seriesTitleController.text.trim();
      final seriesDescription = _seriesDescriptionController.text.trim();

      int totalAwarded = 0;

      for (int i = 0; i < _seriesItems.length; i++) {
        final item = _seriesItems[i];
        final fields = <String, String>{};
        final itemCaption = item.caption.isNotEmpty
            ? item.caption
            : seriesTitle;
        fields['type'] = item.type;
        fields['caption'] = itemCaption;
        fields['topic'] = _selectedTopic!;
        fields['series_id'] = backendSeriesId ?? currentSeriesId;
        fields['series_order'] = (i + 1).toString();
        fields['is_series'] = 'true';
        fields['publish_now'] = _publishSeriesNow.toString();

        fields.addAll(
          await _buildPricingFieldsForUpload(
            contentType: item.type,
            caption: itemCaption,
            file: item.file,
            allowCustomPrice:
                _selectedTopic == 'education' && _canSetCustomPrice,
          ),
        );

        if (seriesTitle.isNotEmpty) fields['series_title'] = seriesTitle;
        if (seriesDescription.isNotEmpty) {
          fields['series_description'] = seriesDescription;
        }

        if (_selectedCategoryId != null) {
          fields['category'] = _selectedCategoryId.toString();
        }

        Map<String, dynamic>? res;
        if (item.type != 'text' && item.file != null) {
          res = await api.createContent(
            fields,
            file: item.file,
            fileField: 'file',
            thumbnail: item.thumbnail,
            onProgress: (progress) {
              if (mounted) {
                setState(() => _uploadProgress = progress);
              }
            },
          );
        } else if (item.type == 'text') {
          res = await api.createContent(fields);
        }

        final awarded =
            ((res?['data'] ?? const {})['reward_points_awarded']) as int?;
        if (awarded != null && awarded > 0) totalAwarded += awarded;

        backendSeriesId ??= _extractSeriesIdFromResponse(res);
        if (backendSeriesId != null) {
          currentSeriesId = backendSeriesId;
        }
      }

      if (_publishSeriesNow && totalAwarded > 0) {
        notifications.showInfo('+$totalAwarded pts for series');
      }
      notifications.showSuccess(
        _publishSeriesNow
            ? 'Series uploaded successfully'
            : 'Series draft saved successfully',
      );
      if (!mounted) return;
      Navigator.of(context).pop({
        'success': true,
        'series_id': backendSeriesId ?? currentSeriesId,
        'status': _publishSeriesNow ? 'published' : 'draft',
        'is_draft': !_publishSeriesNow,
      });
    } catch (e) {
      notifications.showError(
        NotificationService.formatMessage('Failed to upload series: $e'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = -1;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_isSeriesMode ? 'Create Series' : 'Add your content'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _uploading
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DraftsScreen()),
                    );
                  },
            tooltip: 'Drafts',
            icon: const Icon(Icons.drafts_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeToggle(),
            const SizedBox(height: 20),
            if (_isSeriesMode) _buildSeriesUI() else _buildSingleContentUI(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSeriesMode = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isSeriesMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Single Content',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: !_isSeriesMode
                          ? AppTheme.primary
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSeriesMode = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isSeriesMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Series',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _isSeriesMode
                          ? AppTheme.primary
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishOptions({required bool isSeries}) {
    final publishNow = isSeries ? _publishSeriesNow : _publishSingleNow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Visibility', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Draft'),
              selected: !publishNow,
              onSelected: (selected) {
                if (!selected) return;
                setState(() {
                  if (isSeries) {
                    _publishSeriesNow = false;
                  } else {
                    _publishSingleNow = false;
                  }
                });
              },
            ),
            ChoiceChip(
              label: const Text('Publish'),
              selected: publishNow,
              onSelected: (selected) {
                if (!selected) return;
                setState(() {
                  if (isSeries) {
                    _publishSeriesNow = true;
                  } else {
                    _publishSingleNow = true;
                  }
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeriesUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Series Title (required)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _seriesTitleController,
          decoration: const InputDecoration(
            hintText: 'Enter series title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Series Description (optional)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _seriesDescriptionController,
          decoration: const InputDecoration(
            hintText: 'Add a short description for this series',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Series Items (${_seriesItems.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_seriesItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.video_library, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No items added yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Add Item" below to add content to your series',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _seriesItems.length,
            itemBuilder: (context, index) => _buildSeriesItemCard(index),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addSeriesItem,
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppTheme.primary),
              foregroundColor: AppTheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTopicSelector(),
        const SizedBox(height: 16),
        _buildCategorySelector(),
        const SizedBox(height: 16),
        if (_selectedTopic == 'education' || _selectedTopic == 'entertainment')
          _buildPricingSection(),
        const SizedBox(height: 16),
        _buildPublishOptions(isSeries: true),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _uploading ? null : _uploadSeries,
            child: _uploading
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 150,
                        child: LinearProgressIndicator(
                          value: _uploadProgress >= 0 ? _uploadProgress : null,
                          backgroundColor: Colors.white30,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _uploadProgress >= 0
                            ? '${(_uploadProgress * 100).clamp(0, 100).toStringAsFixed(0)}% uploaded'
                            : 'Uploading...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _publishSeriesNow
                        ? 'Publish Series (${_seriesItems.length} items)'
                        : 'Save Series Draft (${_seriesItems.length} items)',
                    style: const TextStyle(fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeriesItemCard(int index) {
    final item = _seriesItems[index];
    final videoController = _seriesVideoControllers[item.id];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Item ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _removeSeriesItem(index),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Content Type'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Video'),
                selected: item.type == 'video',
                onSelected: (s) => _updateSeriesItemType(index, 'video'),
              ),
              ChoiceChip(
                label: const Text('Audio'),
                selected: item.type == 'audio',
                onSelected: (s) => _updateSeriesItemType(index, 'audio'),
              ),
              ChoiceChip(
                label: const Text('Text'),
                selected: item.type == 'text',
                onSelected: (s) => _updateSeriesItemType(index, 'text'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Title / Caption'),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey('series-caption-${item.id}'),
            initialValue: item.caption,
            decoration: const InputDecoration(
              hintText: 'Enter a title or caption for this item',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            maxLines: 2,
            onChanged: (value) => _updateSeriesItemCaption(index, value),
          ),
          const SizedBox(height: 12),
          if (item.type != 'text') ...[
            if (item.type == 'audio') ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickFileForSeriesItem(index),
                    icon: const Icon(Icons.library_music),
                    label: Text(item.fileName ?? 'Select audio'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _toggleSeriesAudioRecording(index),
                    icon: Icon(
                      _isSeriesAudioRecording &&
                              _recordingSeriesItemIndex == index
                          ? Icons.stop
                          : Icons.mic_outlined,
                    ),
                    label: Text(
                      _isSeriesAudioRecording &&
                              _recordingSeriesItemIndex == index
                          ? 'Stop recording'
                          : 'Record audio',
                    ),
                  ),
                ],
              ),
              if (_isSeriesAudioRecording && _recordingSeriesItemIndex == index)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('Recording in progress...'),
                ),
            ] else if (item.type == 'video') ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickFileForSeriesItem(index),
                    icon: const Icon(Icons.video_library_outlined),
                    label: Text(item.fileName ?? 'Select video'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _pickFileForSeriesItem(index, useCameraForVideo: true),
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Record video'),
                  ),
                ],
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: () => _pickFileForSeriesItem(index),
                icon: const Icon(Icons.upload_file),
                label: Text(item.fileName ?? 'Select ${item.type} file'),
              ),
            ],
            if (item.type == 'video') ...[
              const SizedBox(height: 12),
              if (item.file != null)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 240),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child:
                      videoController != null &&
                          videoController.value.isInitialized
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AspectRatio(
                                  aspectRatio:
                                      videoController.value.aspectRatio,
                                  child: VideoPlayer(videoController),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (videoController.value.isPlaying) {
                                      videoController.pause();
                                    } else {
                                      videoController.play();
                                    }
                                    setState(() {});
                                  },
                                  icon: Icon(
                                    videoController.value.isPlaying
                                        ? Icons.pause_circle
                                        : Icons.play_circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.fileName ??
                                        item.file!.path
                                            .split(Platform.pathSeparator)
                                            .last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickSeriesItemThumbnail(index),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Pick thumbnail'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: item.file == null
                        ? null
                        : () => _generateSeriesItemThumbnail(
                            index,
                            item.file!.path,
                          ),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Auto-generate'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (item.thumbnail != null)
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: _safeImagePreview(item.thumbnail!, maxHeight: 140),
                ),
            ],
          ] else ...[
            TextFormField(
              key: ValueKey('series-text-${item.id}'),
              initialValue: item.caption,
              decoration: const InputDecoration(
                hintText: 'Enter text content',
                border: OutlineInputBorder(),
              ),
              maxLines: 6,
              onChanged: (value) => _updateSeriesItemCaption(index, value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopicSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Topic (required)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Entertainment'),
              selected: _selectedTopic == 'entertainment',
              selectedColor: Colors.blue.shade200,
              backgroundColor: Colors.blue.shade50,
              onSelected: (s) => setState(() {
                _selectedTopic = s ? 'entertainment' : null;
                _computePricePreview();
              }),
            ),
            ChoiceChip(
              label: const Text('Education'),
              selected: _selectedTopic == 'education',
              selectedColor: Colors.blue.shade600,
              backgroundColor: Colors.blue.shade100,
              labelStyle: TextStyle(
                color: _selectedTopic == 'education'
                    ? Colors.white
                    : Colors.blue.shade700,
              ),
              onSelected: (s) => setState(() {
                _selectedTopic = s ? 'education' : null;
                _computePricePreview();
              }),
            ),
            ChoiceChip(
              label: const Text('Infotainment'),
              selected: _selectedTopic == 'infotainment',
              selectedColor: Colors.lightBlue.shade300,
              backgroundColor: Colors.lightBlue.shade50,
              onSelected: (s) => setState(() {
                _selectedTopic = s ? 'infotainment' : null;
                _computePricePreview();
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_loadingCategories)
          const Center(child: CircularProgressIndicator())
        else if (_categoriesError != null)
          Text(_categoriesError!, style: const TextStyle(color: Colors.red))
        else if (_categories.isNotEmpty)
          GestureDetector(
            onTap: _onCategoryTap,
            child: InputDecorator(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedCategoryId != null
                          ? (_categories
                                    .firstWhere(
                                      (c) =>
                                          c is Map &&
                                          c['id'] == _selectedCategoryId,
                                      orElse: () => {'name': 'Unknown'},
                                    )['name']
                                    ?.toString() ??
                                'Select category')
                          : 'Select category',
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _getTopicColor() {
    switch (_selectedTopic) {
      case 'entertainment':
        return Colors.blue.shade600;
      case 'education':
        return Colors.indigo.shade600;
      case 'infotainment':
        return Colors.cyan.shade600;
      default:
        return Colors.blue;
    }
  }

  Color _getTopicBackgroundColor() {
    switch (_selectedTopic) {
      case 'entertainment':
        return Colors.blue.shade50;
      case 'education':
        return Colors.indigo.shade50;
      case 'infotainment':
        return Colors.cyan.shade50;
      default:
        return Colors.blue.shade50;
    }
  }

  Widget _buildPricingSection() {
    if (_selectedTopic != 'education' && _selectedTopic != 'entertainment') {
      return const SizedBox.shrink();
    }

    final topicColor = _getTopicColor();
    final topicBgColor = _getTopicBackgroundColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pricing', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_selectedType == 'video' ||
            _selectedType == 'short' ||
            _selectedType == 'story' ||
            _selectedType == 'audio') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: topicBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _isCalculatingDuration ? Icons.hourglass_empty : Icons.timer,
                  color: topicColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _isCalculatingDuration
                      ? Text(
                          'Detecting duration...',
                          style: TextStyle(color: topicColor),
                        )
                      : Text(
                          _durationController.text.isNotEmpty
                              ? 'Duration: ${_formatDuration(int.tryParse(_durationController.text) ?? 0)} (${_durationController.text} seconds)'
                              : 'Duration will be detected automatically',
                          style: TextStyle(color: topicColor),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_selectedType == 'text') ...[
          Builder(
            builder: (context) {
              final wordCount = _captionController.text.trim().isEmpty
                  ? 0
                  : _captionController.text.trim().split(RegExp(r'\s+')).length;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: topicBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.text_fields, color: topicColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Word count: $wordCount words',
                        style: TextStyle(color: topicColor),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: topicBgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.attach_money, size: 18, color: topicColor),
                  const SizedBox(width: 8),
                  Text(
                    _selectedTopic == 'entertainment'
                        ? 'Price: £${_computedPrice?.toStringAsFixed(2) ?? '0.00'}'
                        : 'Computed Price: £${_computedPrice?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: topicColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _selectedTopic == 'entertainment'
                    ? _getEntertainmentPricingTier()
                    : (_computedPrice == 0
                          ? 'Short content: Free with ads'
                          : _computedPrice! <= 2
                          ? 'Standard pricing (£1-£2)'
                          : 'Premium pricing (£3-£5)'),
                style: TextStyle(
                  fontSize: 12,
                  color: topicColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        if (_selectedTopic == 'entertainment') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: topicBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.card_membership, size: 20, color: topicColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Users can subscribe to access all entertainment content',
                    style: TextStyle(fontSize: 12, color: topicColor),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_selectedTopic == 'education' && _canSetCustomPrice) ...[
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Set custom price'),
            subtitle: const Text('Override auto-computed price (£1-£5)'),
            value: _priceController.text.isNotEmpty,
            onChanged: (value) {
              setState(() {
                if (!value) {
                  _priceController.clear();
                }
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          if (_priceController.text.isNotEmpty) ...[
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Custom Price (£)',
                hintText: 'Enter price between £1 and £5',
                border: OutlineInputBorder(),
                prefixText: '£ ',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
        const SizedBox(height: 8),
        Text(
          _selectedTopic == 'entertainment'
              ? 'Entertainment pricing based on duration. Users can subscribe for unlimited access.'
              : (_canSetCustomPrice
                    ? 'As an institute, you can set custom pricing (£1-£5) for your educational content.'
                    : 'Pricing is auto-computed based on content length. Institute users can set custom prices.'),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSingleContentUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Type (required)'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedType,
          items: const [
            DropdownMenuItem(value: 'image', child: Text('image')),
            DropdownMenuItem(value: 'video', child: Text('video')),
            DropdownMenuItem(value: 'short', child: Text('short')),
            DropdownMenuItem(value: 'story', child: Text('story')),
            DropdownMenuItem(value: 'audio', child: Text('audio')),
            DropdownMenuItem(value: 'text', child: Text('text')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              if (_selectedType == 'audio') {
                _stopRecordingIfActive();
              }
              _selectedType = v;
              _pickedFile = null;
              _pickedFileName = null;
              _thumbnailFile = null;
              _durationController.clear();
            });
            _computePricePreview();
          },
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        const Text('Caption'),
        const SizedBox(height: 6),
        TextField(
          controller: _captionController,
          decoration: const InputDecoration(
            hintText: 'Caption (optional)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          maxLines: null,
          onChanged: (_) {
            if (_selectedType == 'text' &&
                (_selectedTopic == 'education' ||
                    _selectedTopic == 'entertainment')) {
              _computePricePreview();
            }
          },
        ),
        const SizedBox(height: 12),
        const Text('Topic (required)'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Entertainment'),
              selected: _selectedTopic == 'entertainment',
              selectedColor: Colors.blue.shade200,
              backgroundColor: Colors.blue.shade50,
              onSelected: (s) => setState(() {
                _selectedTopic = s ? 'entertainment' : null;
                _computePricePreview();
              }),
            ),
            ChoiceChip(
              label: const Text('Education'),
              selected: _selectedTopic == 'education',
              selectedColor: Colors.blue.shade600,
              backgroundColor: Colors.blue.shade100,
              labelStyle: TextStyle(
                color: _selectedTopic == 'education'
                    ? Colors.white
                    : Colors.blue.shade700,
              ),
              onSelected: (s) => setState(() {
                _selectedTopic = s ? 'education' : null;
                _computePricePreview();
              }),
            ),
            ChoiceChip(
              label: const Text('Infotainment'),
              selected: _selectedTopic == 'infotainment',
              selectedColor: Colors.lightBlue.shade300,
              backgroundColor: Colors.lightBlue.shade50,
              onSelected: (s) => setState(() {
                _selectedTopic = s ? 'infotainment' : null;
                _computePricePreview();
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPricingSection(),
        const SizedBox(height: 12),
        if (_selectedType != 'text') ...[
          const Text('File'),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file, size: 36, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  if (_selectedType == 'audio') ...[
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickAudioFromDevice,
                          icon: const Icon(Icons.library_music),
                          label: const Text('Select audio'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _toggleRecording,
                          icon: Icon(
                            _isRecording ? Icons.stop : Icons.mic_outlined,
                          ),
                          label: Text(
                            _isRecording ? 'Stop recording' : 'Record audio',
                          ),
                        ),
                      ],
                    ),
                  ] else if (_selectedType == 'video' ||
                      _selectedType == 'short' ||
                      _selectedType == 'story') ...[
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _chooseFile,
                          icon: const Icon(Icons.video_library_outlined),
                          label: const Text('Select video'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _recordSingleVideo,
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('Record video'),
                        ),
                      ],
                    ),
                  ] else ...[
                    TextButton(
                      onPressed: _chooseFile,
                      child: Text(_pickedFileName ?? 'Choose file'),
                    ),
                  ],
                  if (_pickedFile != null) ...[
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 220,
                        maxHeight: 120,
                      ),
                      child: _selectedType == 'image'
                          ? _safeImagePreview(
                              _pickedFile!,
                              maxWidth: 220,
                              maxHeight: 120,
                            )
                          : (_selectedType == 'audio'
                                ? Text('Selected: ${_pickedFileName ?? ''}')
                                : (_thumbnailFile != null
                                      ? _safeImagePreview(
                                          _thumbnailFile!,
                                          maxWidth: 220,
                                          maxHeight: 120,
                                        )
                                      : Text(
                                          'Selected: ${_pickedFileName ?? ''}',
                                        ))),
                    ),
                  ] else if (_selectedType == 'audio' && _isRecording) ...[
                    const SizedBox(height: 8),
                    const Text('Recording in progress...'),
                  ],
                ],
              ),
            ),
          ),
        ] else ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Type your text or import a .txt file',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickTextFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload .txt file to fill caption'),
          ),
          if (_pickedFileName != null && _selectedType == 'text') ...[
            const SizedBox(height: 6),
            Text(
              'Loaded: $_pickedFileName',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ],
        const SizedBox(height: 12),
        if (_selectedType == 'video' ||
            _selectedType == 'short' ||
            _selectedType == 'story') ...[
          Row(
            children: [
              ElevatedButton(
                onPressed: _generateThumbnail,
                child: const Text('Generate thumbnail'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _pickThumbnailManually,
                child: const Text('Pick thumbnail'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_thumbnailFile != null) ...[
            const Text('Thumbnail (read-only)'),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220, maxHeight: 120),
              child: _safeImagePreview(
                _thumbnailFile!,
                maxWidth: 220,
                maxHeight: 120,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
        const Text('Category (required)'),
        const SizedBox(height: 6),
        if (_loadingCategories) ...[
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(),
            ),
          ),
        ] else if (_categoriesError != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  _categoriesError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: _loadCategories,
                child: const Text('Retry'),
              ),
            ],
          ),
        ] else if (_categories.isNotEmpty) ...[
          GestureDetector(
            onTap: _onCategoryTap,
            child: InputDecorator(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              child: Row(
                children: [
                  if (_selectedCategoryId != null)
                    Builder(
                      builder: (_) {
                        final cat = _categories.firstWhere(
                          (c) => c is Map && c['id'] == _selectedCategoryId,
                          orElse: () => null,
                        );
                        final image = (cat is Map && cat['image_url'] != null)
                            ? cat['image_url'] as String?
                            : null;
                        return image != null
                            ? ClipOval(
                                child: Image.network(
                                  image,
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 24,
                                    height: 24,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedCategoryId != null
                          ? (_categories
                                    .firstWhere(
                                      (c) =>
                                          c is Map &&
                                          c['id'] == _selectedCategoryId,
                                      orElse: () => {'name': 'Unknown'},
                                    )['name']
                                    ?.toString() ??
                                'Unknown')
                          : (_otherCategoryName ?? 'Select category'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ] else ...[
          const Text('No categories available'),
        ],
        const SizedBox(height: 16),
        _buildPublishOptions(isSeries: false),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _uploading ? null : _upload,
            child: _uploading
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 150,
                        child: LinearProgressIndicator(
                          value: _uploadProgress >= 0 ? _uploadProgress : null,
                          backgroundColor: Colors.white30,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _uploadProgress >= 0
                            ? '${(_uploadProgress * 100).clamp(0, 100).toStringAsFixed(0)}% uploaded'
                            : 'Uploading...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _publishSingleNow ? 'Publish' : 'Save as Draft',
                    style: const TextStyle(fontSize: 16),
                  ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
