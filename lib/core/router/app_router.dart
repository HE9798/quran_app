import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/athkar/athkar_screen.dart';
import '../../features/bookmarks/bookmarks_screen.dart';
import '../../features/hadith/hadith_screen.dart';
import '../../features/companion/companion_screen.dart';
import '../../features/hifz/hifz_screen.dart';
import '../../features/hifz/hifz_session_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/dua/dua_screen.dart';
import '../../features/khatma/khatma_dua_screen.dart';
import '../../features/khatma/khatma_screen.dart';
import '../../features/prayer_times/prayer_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/tools/calendar_screen.dart';
import '../../features/tools/manasik/manasik_screen.dart';
import '../../features/tools/tools_screen.dart';
import '../../features/tools/zakat_screen.dart';
import '../../features/qibla/qibla_screen.dart';
import '../../features/audio/player_screen.dart';
import '../../features/quran/quran_list_screen.dart';
import '../../features/quran/surah_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../widgets/main_shell.dart';

/// One branch per bottom-bar tab. Sub-routes (bookmarks, player, qibla)
/// live inside their parent tab so the bottom bar stays visible.
///
/// Replace each PlaceholderScreen with the real screen as you build it.
/// The reader. ?page=5 opens a saved page, ?end=1 opens the last page.
/// [fromKhatma]: reading here moves the Khatma's place, not "Continue reading".
Widget _surah(GoRouterState state, {required bool fromKhatma}) {
  final number = int.tryParse(state.pathParameters['number'] ?? '') ?? 1;
  final page = int.tryParse(state.uri.queryParameters['page'] ?? '');
  final end = state.uri.queryParameters['end'] == '1';
  return SurahScreen(
    key: ValueKey('$number-$page-$end-$fromKhatma'),
    number: number,
    initialPage: page,
    startAtEnd: end,
    fromKhatma: fromKhatma,
  );
}

final appRouter = GoRouter(
  initialLocation: '/welcome', // shown every time the app opens
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
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
                path: 'khatma',
                builder: (context, state) => const KhatmaScreen(),
                routes: [
                  // The Khatma's own reader: it sits on top of the Khatma page
                  // (Home tab), so "back" returns to the Khatma, and the
                  // Quran tab keeps its own place untouched.
                  GoRoute(
                    path: 'surah/:number',
                    builder: (context, state) =>
                        _surah(state, fromKhatma: true),
                  ),
                  // دعاء ختم القرآن (?done=1: a khatma was just completed)
                  GoRoute(
                    path: 'dua',
                    builder: (context, state) => KhatmaDuaScreen(
                      justCompleted: state.uri.queryParameters['done'] == '1',
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'dua',
                builder: (context, state) => const DuaScreen(),
              ),
              GoRoute(
                path: 'companion',
                builder: (context, state) => const CompanionScreen(),
              ),
              GoRoute(
                path: 'hifz',
                builder: (context, state) => const HifzScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => HifzSessionScreen(
                      key: ValueKey(state.pathParameters['id']),
                      id: state.pathParameters['id'] ?? '',
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'tools',
                builder: (context, state) => const ToolsScreen(),
                routes: [
                  GoRoute(
                    path: 'qibla',
                    builder: (context, state) => const QiblaScreen(),
                  ),
                  GoRoute(
                    path: 'calendar',
                    builder: (context, state) => const CalendarScreen(),
                  ),
                  GoRoute(
                    path: 'zakat',
                    builder: (context, state) => const ZakatScreen(),
                  ),
                  GoRoute(
                    path: 'manasik',
                    builder: (context, state) => const ManasikScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
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
                // ?khatma=1: opened from the Khatma (older links; the Khatma
                // now uses /khatma/surah/:number)
                builder: (context, state) => _surah(
                  state,
                  fromKhatma: state.uri.queryParameters['khatma'] == '1',
                ),
              ),
              GoRoute(
                path: 'player',
                builder: (context, state) => const PlayerScreen(),
              ),
            ],
          ),
        ]),
        // 2 - Prayer times
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/prayer',
            builder: (context, state) => const PrayerScreen(),
            routes: [
              GoRoute(
                path: 'qibla',
                builder: (context, state) => const QiblaScreen(),
              ),
            ],
          ),
        ]),
        // 3 - Athkar
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/athkar',
            builder: (context, state) => const AthkarScreen(),
          ),
        ]),
        // 4 - Hadith
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/hadith',
            builder: (context, state) => const HadithScreen(),
          ),
        ]),
      ],
    ),
  ],
);
