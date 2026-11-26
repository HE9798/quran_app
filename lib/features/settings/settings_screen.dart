import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../companion/companion_tile.dart';
import '../tasbeeh/overlay_tile.dart';
import '../tasbeeh/target_tile.dart';
import '../tasbeeh/tasbeeh_widget.dart';
import '../prayer_times/data/prayer_notifications.dart';

/// Settings: appearance, notifications (incl. azkar alarms), tasbeeh button,
/// companion mode. Adhan settings live on the Prayer page, reciters on the
/// page of each activity (Quran, Hifz, Khatma).
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

  /// Azkar alarms need the notification permission too. One switch turns on
  /// all three: morning, evening and the unfinished-azkar reminder.
  Future<void> _setAzkar(BuildContext context, bool on) async {
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
    settings.setAzkarAlarms(on);
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
                      title: Text(context.tr('Azkar alarms', 'تنبيهات الأذكار')),
                      subtitle: Text(context.tr(
                          'Morning azkar after Fajr, evening azkar after Asr, '
                              'and a reminder if you have not finished them',
                          'أذكار الصباح بعد الفجر، وأذكار المساء بعد العصر، '
                              'وتذكير إن لم تُكملها')),
                      value: settings.azkarAlarms,
                      onChanged: settings.notifications
                          ? (v) => _setAzkar(context, v)
                          : null,
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _Section(context.tr('Tasbeeh button', 'زر التسبيح')),
                  _Card(children: [
                    const OverlayTile(),
                    const TargetTile(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('Reset the counter', 'تصفير العداد')),
                      subtitle: Text(context.tr(
                          'Sets the count and the combo back to zero',
                          'يعيد العدّ والكومبو إلى الصفر')),
                      trailing: const Icon(Icons.restart_alt_rounded),
                      onTap: () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(context.tr('Reset the counter?', 'تصفير العداد؟')),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: Text(context.tr('Cancel', 'إلغاء')),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: Text(context.tr('Reset', 'تصفير')),
                              ),
                            ],
                          ),
                        );
                        if (yes == true) await TasbeehWidget.reset();
                      },
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _Section(context.tr('Companion mode', 'وضع الرفيق')),
                  const _Card(children: [CompanionTile()]),
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
