import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../settings/tr.dart';

/// Back arrow for the main pages (Quran, Prayer, Athkar, Hadith): goes home.
class HomeBackButton extends StatelessWidget {
  const HomeBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('Back to home', 'الرجوع للرئيسية'),
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => context.go('/'),
    );
  }
}
