import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../widgets/main_shell.dart';
import '../widgets/placeholder_screen.dart';

/// One branch per bottom-bar tab. Sub-routes (bookmarks, player, qibla)
/// live inside their parent tab so the bottom bar stays visible.
///
/// Replace each PlaceholderScreen with the real screen as you build it.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        // 0 - Home
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
            routes: [
              GoRoute(
                path: 'bookmarks',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Saved'),
              ),
            ],
          ),
        ]),
        // 1 - Quran
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/quran',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Quran'),
            routes: [
              GoRoute(
                path: 'player',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Player'),
              ),
            ],
          ),
        ]),
        // 2 - Prayer times
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/prayer',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Prayer times'),
            routes: [
              GoRoute(
                path: 'qibla',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Qibla'),
              ),
            ],
          ),
        ]),
        // 3 - Athkar
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/athkar',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Athkar'),
          ),
        ]),
        // 4 - Hadith
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/hadith',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Ahadeeth'),
          ),
        ]),
      ],
    ),
  ],
);
