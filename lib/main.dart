import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/audio/quran_audio_controller.dart';
import 'features/audio/quran_audio_handler.dart';
import 'features/hifz/data/hifz_store.dart';
import 'features/khatma/data/khatma_store.dart';
import 'features/companion/companion_widget.dart';
import 'features/companion/data/companion_store.dart';
import 'features/tasbeeh/tasbeeh_widget.dart';
import 'features/bookmarks/data/bookmark_store.dart';
import 'features/hadith/data/hadith_bookmark_store.dart';
import 'features/quran/data/reading_sources.dart';
import 'features/prayer_times/data/prayer_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KhatmaStore.instance.load();
  await HifzStore.instance.load();
  TasbeehWidget.restoreOverlay(); // brings the floating button back
  CompanionWidget.restore(); //      brings the companion back
  await AppSettings.instance.load(); // theme, language, font size, ...
  await CompanionStore.instance.load(); // coins and streak (does nothing if Companion mode is off)
  await BookmarkStore.instance.load(); // saved pages + last read position
  await HadithBookmarkStore.instance.load(); // saved ahadeeth
  await ReadingSources.instance.load(); // chosen tafsir / translation (lists refresh in the background)
  try {
    await QuranAudioController.instance.init(); // saved reciter + player
  } catch (_) {}
  try {
    // the player in the phone's notification bar and lock screen
    await initQuranMediaNotification();
  } catch (_) {}
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
    final settings = AppSettings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Quran',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode, // follows the phone by default
          locale: settings.locale, // also flips the layout for Arabic (RTL)
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // font size: scales every text in the app
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(
                  media.textScaler.scale(1) * settings.fontScale,
                ),
              ),
              child: child!,
            );
          },
          routerConfig: appRouter,
        );
      },
    );
  }
}
