import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import 'quran_audio_controller.dart';

/// Small bar above the bottom navigation while a surah is loaded.
/// Tap it to open the full player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = QuranAudioController.instance;
    final p = context.palette;

    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final surah = audio.surah;
        if (surah == null) return const SizedBox.shrink();
        final progress = surah.ayahCount == 0 ? 0.0 : audio.ayah / surah.ayahCount;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Material(
            color: p.hero,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go('/quran/player'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 6, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                surah.englishName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${audio.reciter.englishName} · Verse ${audio.ayah}/${surah.ayahCount}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (audio.loading && !audio.playing)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                          )
                        else
                          IconButton(
                            tooltip: audio.playing ? 'Pause' : 'Play',
                            color: Colors.white,
                            iconSize: 30,
                            onPressed: audio.togglePlay,
                            icon: Icon(audio.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                          ),
                        IconButton(
                          tooltip: 'Stop',
                          color: Colors.white70,
                          onPressed: audio.stop,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
