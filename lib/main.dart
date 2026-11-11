import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/bookmarks/data/bookmark_store.dart';
import 'features/hadith/data/hadith_bookmark_store.dart';
import 'features/prayer_times/data/prayer_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BookmarkStore.instance.load(); // saved pages + last read position
  await HadithBookmarkStore.instance.load(); // saved ahadeeth
  tz_data.initializeTimeZones(); // time zone database for prayer reminders
  try {
    await PrayerNotifications.instance.init();
  } catch (_) {
    // reminders are optional: the app must still start without them
  }
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Quran',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system, // follows the phone's light/dark setting
      routerConfig: appRouter,
    );
  }
}
