import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Temporary screen so every tab works while you build the real ones.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Coming soon',
            style: TextStyle(color: context.palette.muted),
          ),
        ],
      ),
    );
  }
}
