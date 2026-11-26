import 'package:material_ui/material_ui.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';
import 'data/adhan_voices.dart';
import 'data/prayer_notifications.dart';

/// Prayer page: every adhan setting in one card, next to the prayer
/// reminder switches: adhan sound on/off and the adhan voice.
class AdhanSettingsCard extends StatelessWidget {
  const AdhanSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = AppSettings.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final on = settings.notifications;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.border),
          ),
          // list tiles draw their tap ripple on this, above the card's colour
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(Icons.volume_up_rounded, color: p.onPrimarySoft),
                  title: Text(context.tr('Adhan sound', 'صوت الأذان')),
                  subtitle: Text(context.tr(
                      'Turn off to mute prayer notifications',
                      'أوقفه لكتم إشعارات الصلاة')),
                  value: settings.adhanSound,
                  onChanged: on ? settings.setAdhanSound : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: on && settings.adhanSound,
                  leading: Icon(Icons.record_voice_over_rounded,
                      color: p.onPrimarySoft),
                  title: Text(context.tr('Adhan voice', 'صوت المؤذن')),
                  subtitle: Text(
                    AdhanVoice.byId(settings.adhanVoice).label(context.isArabic),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showAdhanVoiceSheet(context),
                ),
                if (!on)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      context.tr(
                        'Notifications are off in Settings.',
                        'الإشعارات متوقفة من الإعدادات.',
                      ),
                      style: TextStyle(fontSize: 12, color: p.muted),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet: pick the adhan voice (separate from the Quran reciter) and
/// listen to it as a real notification.
Future<void> showAdhanVoiceSheet(BuildContext context) {
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
