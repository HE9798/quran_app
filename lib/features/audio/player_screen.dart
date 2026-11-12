import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'quran_audio_controller.dart';
import 'reciter_sheet.dart';

/// Full player: what is playing, verse slider, controls, reciter.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = QuranAudioController.instance;
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final surah = audio.surah;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/quran'),
                  ),
                  const Expanded(
                    child: Text(
                      'Now playing',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: surah == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.headphones_rounded, size: 48, color: p.muted),
                            const SizedBox(height: 12),
                            const Text('Nothing is playing',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              'Choose a surah in the Listening tab.',
                              style: TextStyle(color: p.muted),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => context.go('/quran'),
                              child: const Text('Open Quran'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Column(
                        children: [
                          // hero card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 28, horizontal: 20),
                            decoration: BoxDecoration(
                              color: p.hero,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              children: [
                                Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Text(
                                    'سورة ${surah.arabicName}',
                                    style: AppTheme.arabic(
                                      size: 38,
                                      height: 1.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${surah.englishName} · ${surah.translation}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    audio.reciter.englishName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // verse slider
                          Slider(
                            min: 1,
                            max: surah.ayahCount.toDouble().clamp(2, 100000),
                            divisions: surah.ayahCount > 1
                                ? surah.ayahCount - 1
                                : null,
                            value: audio.ayah
                                .clamp(1, surah.ayahCount < 2 ? 2 : surah.ayahCount)
                                .toDouble(),
                            label: '${audio.ayah}',
                            onChanged: surah.ayahCount > 1
                                ? (v) => audio.seekToAyah(v.round())
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Verse ${audio.ayah}',
                                    style: TextStyle(color: p.muted)),
                                Text('${surah.ayahCount}',
                                    style: TextStyle(color: p.muted)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: audio.cycleSpeed,
                                child: Text(
                                  '${audio.speed}x',
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Previous verse',
                                iconSize: 34,
                                onPressed: audio.previousAyah,
                                icon: const Icon(Icons.skip_previous_rounded),
                              ),
                              SizedBox(
                                width: 68,
                                height: 68,
                                child: IconButton.filled(
                                  tooltip: audio.playing ? 'Pause' : 'Play',
                                  onPressed: audio.togglePlay,
                                  icon: audio.loading && !audio.playing
                                      ? SizedBox(
                                          width: 26,
                                          height: 26,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: scheme.onPrimary,
                                          ),
                                        )
                                      : Icon(
                                          audio.playing
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          size: 38,
                                        ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Next verse',
                                iconSize: 34,
                                onPressed: audio.nextAyah,
                                icon: const Icon(Icons.skip_next_rounded),
                              ),
                              IconButton(
                                tooltip: 'Repeat verse',
                                onPressed: audio.toggleRepeatAyah,
                                color: audio.repeatAyah ? scheme.primary : null,
                                icon: Icon(audio.repeatAyah
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: surah.number > 1 ? audio.previousSurah : null,
                                icon: const Icon(Icons.chevron_left_rounded),
                                label: const Text('Previous surah'),
                              ),
                              TextButton.icon(
                                onPressed: surah.number < 114 ? audio.nextSurah : null,
                                iconAlignment: IconAlignment.end,
                                icon: const Icon(Icons.chevron_right_rounded),
                                label: const Text('Next surah'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => showReciterSheet(context),
                            icon: const Icon(Icons.record_voice_over_rounded),
                            label: const Text('Change reciter'),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () =>
                                context.go('/quran/surah/${surah.number}'),
                            icon: const Icon(Icons.menu_book_rounded),
                            label: const Text('Read along'),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
