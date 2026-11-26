import 'package:material_ui/material_ui.dart';

import '../../core/settings/tr.dart';
import 'data/activity_reciters.dart';
import 'quran_audio_controller.dart';
import 'reciter_sheet.dart';

/// Settings: a reciter for each activity that plays a voice.
class RecitersTile extends StatefulWidget {
  const RecitersTile({super.key});

  @override
  State<RecitersTile> createState() => _RecitersTileState();
}

class _RecitersTileState extends State<RecitersTile> {
  @override
  void initState() {
    super.initState();
    ActivityReciters.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    final audio = QuranAudioController.instance;
    final own = ActivityReciters.instance;
    final ar = context.isArabic;
    return ListenableBuilder(
      listenable: Listenable.merge([audio, own]),
      builder: (context, _) {
        return Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Quran player', 'مشغّل القرآن')),
              subtitle: Text(audio.reciter.displayName(ar)),
              trailing: const Icon(Icons.keyboard_arrow_down_rounded),
              onTap: () => showReciterSheet(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Memorisation (Hifz)', 'حفظ القرآن')),
              subtitle: Text(own.hifz.displayName(ar)),
              trailing: const Icon(Icons.keyboard_arrow_down_rounded),
              onTap: () => showReciterSheet(
                context,
                current: own.hifz,
                onPick: (r) => own.set(ActivityReciters.hifzKey, r),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Adhan', 'الأذان')),
              subtitle: Text(context.tr(
                'Has its own voices: see "Adhan voice" in the notifications section',
                'له أصواته الخاصة: انظر «صوت المؤذن» في قسم الإشعارات',
              )),
            ),
          ],
        );
      },
    );
  }
}
