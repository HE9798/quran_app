import 'package:material_ui/material_ui.dart';

import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';
import 'data/activity_reciters.dart';
import 'data/reciter.dart';
import 'quran_audio_controller.dart';

/// Bottom sheet to choose the reciter. Used by the Listening tab and the
/// full player. Choosing a reciter while listening continues from the same
/// verse in the new voice.
///
/// By default it changes the Quran player's reciter. To choose a reciter for
/// something else (the Hifz, say) pass [current] and [onPick].
Future<void> showReciterSheet(
  BuildContext context, {
  Reciter? current,
  void Function(Reciter)? onPick,
}) async {
  final audio = QuranAudioController.instance;
  audio.loadReciters(); // the list fills in when it arrives
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReciterSheet(current: current, onPick: onPick),
  );
}

class _ReciterSheet extends StatelessWidget {
  const _ReciterSheet({this.current, this.onPick});

  final Reciter? current;
  final void Function(Reciter)? onPick;

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
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  context.tr('Choose a reciter', 'اختر القارئ'),
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
                    final selected = r == (current ?? audio.reciter);
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
                          r.initialsFor(context.isArabic),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        r.displayName(context.isArabic),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: selected
                          ? Icon(Icons.check_circle_rounded,
                              color: scheme.primary)
                          : null,
                      onTap: () {
                        if (onPick != null) {
                          onPick!(r);
                        } else {
                          audio.setReciter(r);
                        }
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

/// For the full player: changes the voice that is reciting now. When the
/// audio was started by an activity (the Khatma, say) it changes that
/// activity's reciter, otherwise the Quran player's.
Future<void> showActiveReciterSheet(BuildContext context) {
  final audio = QuranAudioController.instance;
  final activity = audio.activity;
  if (activity == null) return showReciterSheet(context);
  return showReciterSheet(
    context,
    current: audio.activeReciter,
    onPick: (r) => ActivityReciters.instance.set(activity, r),
  );
}

/// Card showing the chosen reciter; tap to change it.
///
/// Without [activity] it is the Quran player's reciter (Quran page). With an
/// [ActivityReciters] key it is that activity's own reciter (Hifz, Khatma),
/// independent from the player and from the other activities.
class ReciterCard extends StatefulWidget {
  const ReciterCard({super.key, this.activity});

  final String? activity;

  @override
  State<ReciterCard> createState() => _ReciterCardState();
}

class _ReciterCardState extends State<ReciterCard> {
  final _audio = QuranAudioController.instance;
  final _own = ActivityReciters.instance;

  @override
  void initState() {
    super.initState();
    _audio.loadReciters();
    _own.load();
  }

  void _pick() {
    final activity = widget.activity;
    if (activity == null) {
      showReciterSheet(context);
      return;
    }
    showReciterSheet(
      context,
      current: _own.of(activity),
      onPick: (r) => _own.set(activity, r),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([_audio, _own]),
      builder: (context, _) {
        final activity = widget.activity;
        final r = activity == null ? _audio.reciter : _own.of(activity);
        return Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: p.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pick,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    child: Text(r.initialsFor(context.isArabic),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Reciter', 'القارئ'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: p.muted)),
                        Text(
                          r.displayName(context.isArabic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Text(context.tr('Change', 'تغيير'),
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
