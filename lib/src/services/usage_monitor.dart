import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks foreground usage time and prompts the user to take a break
/// after sustained usage.
class UsageMonitor extends ChangeNotifier with WidgetsBindingObserver {
  UsageMonitor(this.navigatorKey) {
    _init();
  }

  static const _prefsKeyEnabled = 'rest_alert_enabled';
  static const Duration _threshold = Duration(hours: 2);
  static const Duration _tick = Duration(minutes: 1);

  final GlobalKey<NavigatorState> navigatorKey;

  bool _enabled = true;
  bool _dialogShowing = false;
  Timer? _timer;
  DateTime? _sessionStart;

  bool get enabled => _enabled;

  Future<void> _init() async {
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefsKeyEnabled) ?? true;
    _sessionStart = DateTime.now();
    _startTimer();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyEnabled, value);
    if (value) {
      _resetSession();
      _startTimer();
    } else {
      _cancelTimer();
    }
    notifyListeners();
  }

  void _resetSession() {
    _sessionStart = DateTime.now();
  }

  void _startTimer() {
    _cancelTimer();
    if (!_enabled) return;
    _timer = Timer.periodic(_tick, (_) => _check());
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _check() {
    if (!_enabled || _dialogShowing) return;
    if (_sessionStart == null) {
      _sessionStart = DateTime.now();
      return;
    }
    final elapsed = DateTime.now().difference(_sessionStart!);
    if (elapsed >= _threshold) {
      _showRestDialog();
    }
  }

  Future<void> _showRestDialog() async {
    final ctx = navigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;
    _dialogShowing = true;
    final result = await showDialog<String>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Take a break'),
        content: const Text(
            'You have been using the app for 2 hours. Please take a short rest.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop('dismiss'),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(c).pop('exit'),
            child: const Text('Exit app'),
          ),
        ],
      ),
    );
    _dialogShowing = false;
    if (result == 'exit') {
      await SystemNavigator.pop();
      return;
    }
    _resetSession();
    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resetSession();
      _startTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _cancelTimer();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimer();
    super.dispose();
  }
}
