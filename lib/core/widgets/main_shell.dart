import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/audio/mini_player.dart';
import '../../features/audio/quran_audio_controller.dart';

/// App frame: current tab on top, bottom navigation bar below.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _audio = QuranAudioController.instance;

  @override
  void initState() {
    super.initState();
    _audio.addListener(_onAudio);
  }

  @override
  void dispose() {
    _audio.removeListener(_onAudio);
    super.dispose();
  }

  /// One place that tells the user when audio failed.
  void _onAudio() {
    if (_audio.error == null || !mounted) return;
    _audio.clearError();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text("Couldn't play the recitation. Check your internet connection and try again."),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    // The mini player is hidden where it would be in the way
    final location = GoRouterState.of(context).uri.path;
    final hideMini = location.startsWith('/quran/player') ||
        location.startsWith('/quran/surah/');

    return Scaffold(
      body: SafeArea(bottom: false, child: navigationShell),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hideMini) const MiniPlayer(),
          _nav(navigationShell),
        ],
      ),
    );
  }

  Widget _nav(StatefulNavigationShell navigationShell) {
    return NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // tapping the current tab returns to its first screen
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Quran',
          ),
          NavigationDestination(
            icon: Icon(Icons.access_time_rounded),
            selectedIcon: Icon(Icons.access_time_filled_rounded),
            label: 'Prayer',
          ),
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny_rounded),
            label: 'Athkar',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article_rounded),
            label: 'Hadith',
          ),
        ],
    );
  }
}
