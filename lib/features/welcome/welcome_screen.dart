import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';

/// Shown every time the app opens. Uses the current theme (the phone's
/// light/dark mode by default) and the app's colours.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _arabic =
      'هذا التطبيق صدقة جارية، لا تنسونا من صالح دعائكم';
  static const _english =
      'This app is an ongoing charity (sadaqah jariyah). Please keep us in your prayers.';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/logo/logo.png',
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.menu_book_rounded,
                        size: 96,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Arabic
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      _arabic,
                      textAlign: TextAlign.center,
                      style: AppTheme.arabic(size: 26, height: 1.9),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 48,
                    height: 3,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // English
                  Text(
                    _english,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.6, color: p.muted),
                  ),
                  const SizedBox(height: 40),

                  // button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: () => context.go('/'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        context.tr('Amen', 'آمين'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
