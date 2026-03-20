import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/signup/signup_step1.dart';
import 'screens/signup/signup_step2.dart';
import 'screens/signup/signup_step3.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/usage_monitor.dart';
import 'widgets/notification_overlay.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';

/// The app expects a pre-initialized [ApiService] (so tokens are already loaded).
class CoonchApp extends StatelessWidget {
  const CoonchApp({super.key, required this.apiService});

  final ApiService apiService;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Avoid calling GoogleFonts at app startup because it may trigger
    // asynchronous asset loads that throw if AssetManifest.json is missing
    // in some environments (causes unhandled exceptions). Use the default
    // textTheme for startup and apply GoogleFonts selectively inside
    // widgets where safe.
    final theme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      textTheme: ThemeData.light().textTheme,
    );

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(apiService)),
        ChangeNotifierProvider<NotificationService>(
            create: (_) => NotificationService()),
        ChangeNotifierProvider<UsageMonitor>(
            create: (_) => UsageMonitor(navigatorKey)),
      ],
      child: MaterialApp(
        title: 'Coonch',
        debugShowCheckedModeBanner: false,
        theme: theme.copyWith(),
        navigatorKey: navigatorKey,
        home: const SplashScreen(),
        routes: {
          '/signup/1': (_) => const SignUpStep1(),
          '/signup/2': (_) => const SignUpStep2(),
          '/signup/3': (_) => const SignUpStep3(),
        },
        builder: (context, child) {
          return DefaultTextStyle.merge(
            // Emoji fallback applied at text-render level for SDK compatibility.
            style: const TextStyle(
              fontFamilyFallback: [
                'Noto Color Emoji',
                'Segoe UI Emoji',
                'Apple Color Emoji',
                'Noto Emoji',
              ],
            ),
            child: NotificationOverlay(child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}
