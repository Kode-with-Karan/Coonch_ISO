import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'login/login_screen.dart';
import 'home_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/coonch_logo.dart';
import 'profile/profile_screen.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _deepLinkUserId;
  AppLinks? _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLink();
    _startNavTimer();
  }

  Future<void> _initDeepLink() async {
    try {
      _appLinks = AppLinks(onAppLink: (uri, _) {
        _handleIncomingLink(uri);
      });

      final uri = await _appLinks!.getInitialAppLink();
      _handleIncomingLink(uri);
    } on PlatformException catch (_) {
      // ignore
    } on FormatException catch (_) {
      // ignore malformed uri
    }
  }

  void _handleIncomingLink(Uri? uri) {
    if (!mounted || uri == null) return;
    final id = _extractUserId(uri);
    if (id != null) {
      setState(() => _deepLinkUserId = id);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)),
        );
      }
    }
  }

  String? _extractUserId(Uri uri) {
    if (uri.scheme == 'coonch' && uri.host == 'profile') {
      if (uri.pathSegments.isNotEmpty) return uri.pathSegments.last;
    }
    final idx = uri.pathSegments.indexOf('profile');
    if (idx != -1 && idx < uri.pathSegments.length - 1) {
      return uri.pathSegments[idx + 1];
    }
    return null;
  }

  void _startNavTimer() {
    Timer(const Duration(seconds: 2), () async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      const timeout = Duration(seconds: 5);
      final end = DateTime.now().add(timeout);
      while (auth.loading && DateTime.now().isBefore(end)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!mounted) return;

      if (auth.isAuthenticated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        if (_deepLinkUserId != null) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: _deepLinkUserId!)));
          });
        }
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _appLinks = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF7DB7F8);

    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: CoonchLogo(
                    iconDiameter: 170,
                    ringStroke: 22,
                    textSize: 32,
                    fontWeight: FontWeight.w700,
                    spacing: 18,
                    textColor: brandColor,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'SOUND OF YOUR VIRTUOSITY',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: brandColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
