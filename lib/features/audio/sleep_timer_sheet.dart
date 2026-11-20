import 'package:flutter/material.dart';

import '../../core/settings/tr.dart';
import 'quran_audio_controller.dart';

/// Text for the sleep-timer button: "Sleep timer", or the time left.
String sleepLabel(BuildContext context, QuranAudioController audio) {
  final left = audio.sleepRemaining;
  if (left != null) {
    final m = left.inMinutes.toString().padLeft(2, '0');
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    return context.digits('$m:$s');
  }
  if (audio.sleepAtSurahEnd) return context.tr('End of surah', 'نهاية السورة');
  return context.tr('Sleep timer', 'مؤقت النوم');
}

/// Choose when the player stops by itself.
Future<void> showSleepTimerSheet(BuildContext context) {
  final audio = QuranAudioController.instance;
  const minutes = [5, 10, 15, 30, 45, 60];

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ListenableBuilder(
          listenable: audio,
          builder: (context, _) {
            Widget option(String label, bool selected, VoidCallback onTap) {
              return ListTile(
                title: Text(label),
                trailing: selected
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  onTap();
                  Navigator.of(sheetContext).pop();
                },
              );
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        context.tr('Sleep timer', 'مؤقت النوم'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  for (final m in minutes)
                    option(
                      context.tr('$m minutes', '${context.n(m)} دقيقة'),
                      false,
                      () => audio.setSleepTimer(Duration(minutes: m)),
                    ),
                  option(
                    context.tr('End of the surah', 'نهاية السورة'),
                    audio.sleepAtSurahEnd,
                    audio.setSleepAtSurahEnd,
                  ),
                  if (audio.sleepActive)
                    option(
                      context.tr('Turn off timer', 'إيقاف المؤقت'),
                      false,
                      audio.cancelSleep,
                    ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
