import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../prayer_times/data/adhan_voices.dart';
import '../prayer_times/data/prayer_notifications.dart';

/// Settings: language, font size, theme, notifications, vibration, azkar.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _setNotifications(BuildContext context, bool on) async {
    final settings = AppSettings.instance;
    if (on) {
      final allowed = await PrayerNotifications.instance.requestPermission();
      if (!allowed) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(context.tr(
                'Notifications are blocked. Allow them in the phone settings.',
                'الإشعارات محظورة. اسمح بها من إعدادات الهاتف.',
              )),
            ));
        }
        return;
      }
    }
    settings.setNotifications(on);
  }

  /// Azkar alarms need the notification permission too.
  Future<void> _setAzkar(BuildContext context, bool morning, bool on) async {
    final settings = AppSettings.instance;
    if (on) {
      final allowed = await PrayerNotifications.instance.requestPermission();
      if (!allowed) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(context.tr(
                'Notifications are blocked. Allow them in the phone settings.',
                'الإشعارات محظورة. اسمح بها من إعدادات الهاتف.',
              )),
            ));
        }
        return;
      }
    }
    morning ? settings.setAzkarMorning(on) : settings.setAzkarEvening(on);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final p = context.palette;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.tr('Back', 'رجوع'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                  ),
                  Expanded(
                    child: Text(
                      context.tr('Settings', 'الإعدادات'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  // ------------------------------------------- appearance
                  _Section(context.tr('Appearance', 'المظهر')),
                  _Card(children: [
                    _Label(context.tr('Language', 'اللغة')),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('English')),
                        ButtonSegment(value: 'ar', label: Text('العربية')),
                      ],
                      selected: {settings.languageCode},
                      onSelectionChanged: (v) => settings.setLanguage(v.first),
                    ),
                    const _Gap(),
                    _Label(context.tr('Font size', 'حجم الخط')),
                    Row(
                      children: [
                        Text('A', style: TextStyle(fontSize: 14, color: p.muted)),
                        Expanded(
                          child: Slider(
                            min: AppSettings.minFontScale,
                            max: AppSettings.maxFontScale,
                            divisions: 11,
                            value: settings.fontScale,
                            label: '${(settings.fontScale * 100).round()}%',
                            onChanged: settings.setFontScale,
                          ),
                        ),
                        Text('A', style: TextStyle(fontSize: 24, color: p.muted)),
                      ],
                    ),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                        style: AppTheme.arabic(size: 22, height: 1.6),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: settings.fontScale == 1.0
                            ? null
                            : () => settings.setFontScale(1.0),
                        child: Text(context.tr('Reset', 'إعادة الضبط')),
                      ),
                    ),
                    const _Gap(),
                    _Label(context.tr('Theme', 'المظهر')),
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: const Icon(Icons.brightness_auto_rounded),
                          label: Text(context.tr('Device', 'الجهاز')),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: const Icon(Icons.light_mode_rounded),
                          label: Text(context.tr('Light', 'فاتح')),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: const Icon(Icons.dark_mode_rounded),
                          label: Text(context.tr('Dark', 'داكن')),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (v) {
                        final mode = v.first;
                        if (mode == ThemeMode.system) {
                          settings.setFollowDevice(true);
                        } else {
                          settings.setDarkMode(mode == ThemeMode.dark);
                          settings.setFollowDevice(false);
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('Device follows your phone\'s light or dark mode.',
                          'خيار الجهاز يتبع الوضع الفاتح أو الداكن في هاتفك.'),
                      style: TextStyle(fontSize: 12, color: context.palette.muted),
                    ),
                  ]),

                  // ----------------------------------------- notifications
                  const SizedBox(height: 20),
                  _Section(context.tr('Notifications', 'الإشعارات')),
                  _Card(children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Notifications', 'الإشعارات')),
                      subtitle: Text(context.tr(
                          'Prayer times and azkar reminders',
                          'تنبيهات الصلاة والأذكار')),
                      value: settings.notifications,
                      onChanged: (v) => _setNotifications(context, v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Vibration', 'الاهتزاز')),
                      subtitle: Text(context.tr('Vibrate when a reminder rings',
                          'اهتزاز عند وصول التنبيه')),
                      value: settings.vibration,
                      onChanged:
                          settings.notifications ? settings.setVibration : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Prayer countdown in the status bar',
                          'العد التنازلي للصلاة في شريط الإشعارات')),
                      subtitle: Text(context.tr(
                          'A fixed notification with the time left for the next prayer',
                          'إشعار ثابت بالوقت المتبقي للصلاة القادمة')),
                      value: settings.statusCountdown,
                      onChanged: settings.notifications
                          ? settings.setStatusCountdown
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Adhan sound', 'صوت الأذان')),
                      subtitle: Text(context.tr(
                          'Turn off to mute prayer notifications',
                          'أوقفه لكتم إشعارات الصلاة')),
                      value: settings.adhanSound,
                      onChanged:
                          settings.notifications ? settings.setAdhanSound : null,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: settings.notifications && settings.adhanSound,
                      title: Text(context.tr('Adhan voice', 'صوت المؤذن')),
                      subtitle: Text(
                        AdhanVoice.byId(settings.adhanVoice)
                            .label(context.isArabic),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _chooseAdhan(context),
                    ),
                  ]),

                  // ----------------------------------------------- azkar
                  const SizedBox(height: 20),
                  _Section(context.tr('Azkar alarms', 'تنبيهات الأذكار')),
                  _Card(children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Morning azkar', 'أذكار الصباح')),
                      subtitle: Text(context.tr(
                          'After Fajr, until sunrise', 'بعد الفجر حتى الشروق')),
                      value: settings.azkarMorning,
                      onChanged: settings.notifications
                          ? (v) => _setAzkar(context, true, v)
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Evening azkar', 'أذكار المساء')),
                      subtitle: Text(context.tr(
                          'After Asr, until Maghrib', 'بعد العصر حتى المغرب')),
                      value: settings.azkarEvening,
                      onChanged: settings.notifications
                          ? (v) => _setAzkar(context, false, v)
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Unfinished morning azkar',
                          'أذكار الصباح غير المكتملة')),
                      subtitle: Text(context.tr(
                          'A reminder 30 minutes before the evening azkar if you have not finished the morning ones',
                          'تذكير قبل أذكار المساء بـ ٣٠ دقيقة إن لم تُكمل أذكار الصباح')),
                      value: settings.morningMissed,
                      onChanged: settings.notifications
                          ? settings.setMorningMissed
                          : null,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      'Times come from Aladhan, based on your location. The '
                      'azkar countdown appears on the prayer card.',
                      'المواقيت من خدمة الأذان حسب موقعك. يظهر العد التنازلي '
                          'للأذكار في بطاقة الصلاة.',
                    ),
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bottom sheet: pick the adhan voice (separate from the Quran reciter) and
/// listen to it as a real notification.
Future<void> _chooseAdhan(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final s = AppSettings.instance;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Adhan voice', 'صوت المؤذن'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'Used for prayer notifications only. It does not change the Quran reciter.',
                    'للإشعارات فقط، ولا يغيّر قارئ القرآن.',
                  ),
                  style: TextStyle(fontSize: 12, color: context.palette.muted),
                ),
                const SizedBox(height: 8),
                for (final v in AdhanVoice.all)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      s.adhanVoice == v.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: s.adhanVoice == v.id
                          ? Theme.of(context).colorScheme.primary
                          : context.palette.muted,
                    ),
                    title: Text(v.label(context.isArabic)),
                    onTap: () => s.setAdhanVoice(v.id),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _testAdhan(context, v.id, true),
                          child: Text(context.tr('Fajr', 'الفجر')),
                        ),
                        IconButton(
                          tooltip: context.tr('Listen', 'استمع'),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          onPressed: () => _testAdhan(context, v.id, false),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _testAdhan(BuildContext context, String id, bool fajr) async {
  final ok = await PrayerNotifications.instance.testAdhan(id, fajr: fajr);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.tr('Allow notifications to hear the adhan.',
          'اسمح بالإشعارات لتسمع الأذان.')),
    ));
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      );
}

class _Gap extends StatelessWidget {
  const _Gap();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 12);
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
