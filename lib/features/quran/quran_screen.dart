import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'listening_tab.dart';
import 'quran_list_screen.dart';

/// Quran tab: two sub-tabs, "Reading" (the surah list that opens the
/// reader) and "Listening" (reciter + play a whole surah).
class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quran',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text('114 surahs', style: TextStyle(fontSize: 13, color: p.muted)),
            ],
          ),
        ),
        Container(
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabs,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: scheme.onPrimary,
            unselectedLabelColor: scheme.onSurface,
            splashBorderRadius: BorderRadius.circular(12),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(height: 44, text: 'Reading'),
              Tab(height: 44, text: 'Listening'),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [QuranListScreen(), ListeningTab()],
          ),
        ),
      ],
    );
  }
}
