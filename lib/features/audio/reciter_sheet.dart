import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'data/reciter.dart';
import 'quran_audio_controller.dart';

/// Bottom sheet to choose the reciter. Used by the Listening tab and the
/// full player. Choosing a reciter while listening continues from the same
/// verse in the new voice.
Future<void> showReciterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ReciterSheet(),
  );
}

class _ReciterSheet extends StatelessWidget {
  const _ReciterSheet();

  @override
  Widget build(BuildContext context) {
    final audio = QuranAudioController.instance;
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: ListenableBuilder(
        listenable: audio,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Choose a reciter',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: audio.reciters.length,
                  itemBuilder: (context, i) {
                    final r = audio.reciters[i];
                    final selected = r == audio.reciter;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      selected: selected,
                      selectedTileColor: p.primarySoft,
                      leading: CircleAvatar(
                        backgroundColor:
                            selected ? scheme.primary : p.surfaceAlt,
                        foregroundColor:
                            selected ? scheme.onPrimary : scheme.onSurface,
                        child: Text(
                          r.initials,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        r.englishName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        r.name,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.start,
                      ),
                      trailing: selected
                          ? Icon(Icons.check_circle_rounded,
                              color: scheme.primary)
                          : null,
                      onTap: () {
                        audio.setReciter(r);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Card showing the chosen reciter; tap to change it.
class ReciterCard extends StatefulWidget {
  const ReciterCard({super.key});

  @override
  State<ReciterCard> createState() => _ReciterCardState();
}

class _ReciterCardState extends State<ReciterCard> {
  final _audio = QuranAudioController.instance;

  @override
  void initState() {
    super.initState();
    _audio.loadReciters();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: _audio,
      builder: (context, _) {
        final r = _audio.reciter;
        return Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: p.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showReciterSheet(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    child: Text(r.initials,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reciter',
                            style: TextStyle(fontSize: 12, color: p.muted)),
                        Text(
                          r.englishName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Text('Change',
                      style: TextStyle(
                          color: scheme.primary, fontWeight: FontWeight.w700)),
                  Icon(Icons.keyboard_arrow_down_rounded, color: scheme.primary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
