import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../home_screen.dart';
import '../../theme.dart';

class SignUpStep3 extends StatefulWidget {
  const SignUpStep3({super.key});

  @override
  State<SignUpStep3> createState() => _SignUpStep3State();
}

class _SignUpStep3State extends State<SignUpStep3> {
  final List<String> _categories = [
    'Web design',
    'Illustration',
    'UI UX Design',
    'Graphics design',
    'Marketing',
    'Article writing',
  ];
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    // If the user is already authenticated, keep the guard (no-op here)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        // nothing special required here — allow user to finish selecting
      }
    });

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.black))),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final isWide = kIsWeb || constraints.maxWidth >= 900;
          final crossAxisCount = constraints.maxWidth >= 1100
              ? 4
              : (constraints.maxWidth >= 700 ? 3 : 2);

          return Center(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: isWide ? 980 : double.infinity),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Center(
                          child: Text('Choose Categories',
                              style: TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.w800))),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'Discover a wide range of content across different categories to suit your interests and preferences.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
                          padding: const EdgeInsets.only(top: 8, bottom: 12),
                          childAspectRatio: 1.25,
                          children: _categories.map((c) {
                            final selected = _selected.contains(c);
                            const Color accent = AppTheme.primary;
                            IconData icon;
                            switch (c) {
                              case 'Web design':
                                icon = Icons.web;
                                break;
                              case 'Illustration':
                                icon = Icons.brush;
                                break;
                              case 'UI UX Design':
                                icon = Icons.design_services;
                                break;
                              case 'Graphics design':
                                icon = Icons.auto_awesome;
                                break;
                              case 'Marketing':
                                icon = Icons.campaign;
                                break;
                              default:
                                icon = Icons.article;
                            }

                            return GestureDetector(
                              onTap: () => setState(() => selected
                                  ? _selected.remove(c)
                                  : _selected.add(c)),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySoft,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                      color: selected
                                          ? accent
                                          : AppTheme.primaryMuted,
                                      width: 2),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? accent.withValues(alpha: 0.12)
                                            : Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(icon,
                                          size: 36,
                                          color: selected
                                              ? accent
                                              : AppTheme.primaryDark),
                                    ),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: Text(c,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        child: Column(children: [
                          SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  onPressed: () async {
                                    final auth = Provider.of<AuthProvider>(
                                        context,
                                        listen: false);
                                    try {
                                      await auth.refreshProfile();
                                    } catch (_) {}
                                    Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                            builder: (_) => const HomeScreen()),
                                        (route) => false);
                                  },
                                  child: const Text('Finish'))),
                          const SizedBox(height: 8),
                          Center(
                              child: TextButton(
                                  onPressed: () async {
                                    final auth = Provider.of<AuthProvider>(
                                        context,
                                        listen: false);
                                    try {
                                      await auth.refreshProfile();
                                    } catch (_) {}
                                    Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                            builder: (_) => const HomeScreen()),
                                        (route) => false);
                                  },
                                  child: const Text('Skip',
                                      style:
                                          TextStyle(color: Colors.lightBlue)))),
                        ]),
                      ),
                    ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}
