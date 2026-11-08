import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/bookmarks/bookmarks_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/quran/quran_list_screen.dart';
import '../../features/quran/surah_screen.dart';
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
                builder: (context, state) => const BookmarksScreen(),
              ),
            ],
          ),
        ]),
        // 1 - Quran
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/quran',
            builder: (context, state) => const QuranListScreen(),
            routes: [
              GoRoute(
                path: 'surah/:number',
                builder: (context, state) {
                  final number =
                      int.tryParse(state.pathParameters['number'] ?? '') ?? 1;
                  // ?page=5  opens a saved page, ?end=1 opens the last page
                  final page =
                      int.tryParse(state.uri.queryParameters['page'] ?? '');
                  final end = state.uri.queryParameters['end'] == '1';
                  return SurahScreen(
                    key: ValueKey('$number-$page-$end'),
                    number: number,
                    initialPage: page,
                    startAtEnd: end,
                  );
                },
              ),
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
