import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_view.dart';
import '../quran/data/quran_repository.dart';
import '../quran/data/surah_detail.dart';
import '../companion/data/companion_store.dart';
import 'data/hifz_store.dart';
import '../audio/data/activity_reciters.dart';
import '../audio/reciter_sheet.dart';
import 'hifz_player.dart';

/// Practice one range: listen on repeat, hide the text, test yourself, then
/// say if you remembered it (that sets the next revision day).
class HifzSessionScreen extends StatefulWidget {
  const HifzSessionScreen({super.key, required this.id});

  final String id;

  @override
  State<HifzSessionScreen> createState() => _HifzSessionScreenState();
}

class _HifzSessionScreenState extends State<HifzSessionScreen> {
  final _store = HifzStore.instance;
  final _player = HifzPlayer();
  late Future<SurahDetail> _detail;

  static const _roundChoices = [1, 3, 5, 10, 20];
  static const _verseChoices = [1, 2, 3];

  int _rounds = 5;
  int _verseRepeats = 1;
  int _mode = 0; // 0 = show, 1 = first word, 2 = hidden
  final _revealed = <int>{};

  @override
  void initState() {
    super.initState();
    final item = _store.byId(widget.id);
    if (item != null) {
      _detail = QuranRepository().getSurahDetail(item.surah);
      // revising something already learned: start with the text hidden
      _mode = item.revisions > 0 ? 2 : 0;
    }
    _player.addListener(_onPlayer);
    ActivityReciters.instance.load();
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayer);
    _player.dispose();
    super.dispose();
  }

  void _onPlayer() {
    if (_player.error != null && mounted) {
      _player.clearError();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(context.tr(
            "Couldn't play the recitation. Check your internet connection and try again.",
            'تعذّر تشغيل التلاوة. تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
          )),
        ));
    }
    if (mounted) setState(() {});
  }

  void _togglePlay(HifzItem item) {
    if (_player.started && !_player.finished) {
      _player.togglePlay();
    } else {
      _player.start(
        surah: item.surah,
        from: item.from,
        to: item.to,
        rounds: _rounds,
        verseRepeats: _verseRepeats,
      );
    }
  }

  Future<void> _finish(HifzItem item, bool remembered) async {
    await _player.stop();
    final days = await _store.markRevised(item.id, remembered: remembered);
    CompanionStore.instance.hifzSession(remembered); // coins + bubble (only if Companion mode is on)
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(remembered
            ? context.tr('Well done. Next revision in $days days.',
                'أحسنت. المراجعة القادمة بعد ${context.n(days)} يوم.')
            : context.tr('No problem, revise again tomorrow.',
                'لا بأس، راجعها مرة أخرى غدًا.')),
      ));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/hifz');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _store.byId(widget.id);
    if (item == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('This range was removed.', 'تم حذف هذا الجزء.')),
            TextButton(
              onPressed: () => context.go('/hifz'),
              child: Text(context.tr('Back', 'رجوع')),
            ),
          ],
        ),
      );
    }
    final p = context.palette;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 20, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: context.tr('Back', 'رجوع'),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/hifz'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.title(context.isArabic, context.n),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<SurahDetail>(
            future: _detail,
            builder: (context, snap) {
              if (snap.hasError) {
                return ErrorView(
                  onRetry: () => setState(
                      () => _detail = QuranRepository().getSurahDetail(item.surah)),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final verses = snap.data!.ayahs
                  .where((a) => a.numberInSurah >= item.from && a.numberInSurah <= item.to)
                  .toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _settings(context, p),
                  const SizedBox(height: 12),
                  for (final a in verses) _verse(context, a),
                ],
              );
            },
          ),
        ),
        _bottomBar(context, item, p),
      ],
    );
  }

  Widget _settings(BuildContext context, AppPalette p) {
    Widget chips(String label, List<int> values, int selected, void Function(int) pick) {
      return Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: TextStyle(fontSize: 13, color: p.muted)),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              children: [
                for (final v in values)
                  ChoiceChip(
                    label: Text(context.n(v)),
                    selected: selected == v,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      _player.stop();
                      setState(() => pick(v));
                    },
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          _reciterRow(context, p),
          const SizedBox(height: 8),
          chips(context.tr('Repeat range', 'تكرار المقطع'), _roundChoices, _rounds,
              (v) => _rounds = v),
          const SizedBox(height: 4),
          chips(context.tr('Each verse', 'كل آية'), _verseChoices, _verseRepeats,
              (v) => _verseRepeats = v),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, label: Text(context.tr('Show', 'إظهار'))),
                ButtonSegment(value: 1, label: Text(context.tr('Hint', 'تلميح'))),
                ButtonSegment(value: 2, label: Text(context.tr('Hide', 'إخفاء'))),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _revealed.clear();
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// The reciter used here only (the Quran player keeps its own).
  Widget _reciterRow(BuildContext context, AppPalette p) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: ActivityReciters.instance,
      builder: (context, _) {
        final r = ActivityReciters.instance.hifz;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showReciterSheet(
            context,
            current: r,
            onPick: (picked) {
              _player.stop(); // the next play uses the new voice
              ActivityReciters.instance.set(ActivityReciters.hifzKey, picked);
            },
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(context.tr('Reciter', 'القارئ'),
                      style: TextStyle(fontSize: 13, color: p.muted)),
                ),
                Expanded(
                  child: Text(
                    r.displayName(context.isArabic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(context.tr('Change', 'تغيير'),
                    style: TextStyle(fontSize: 13, color: scheme.primary, fontWeight: FontWeight.w700)),
                Icon(Icons.keyboard_arrow_down_rounded, color: scheme.primary),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _verse(BuildContext context, Ayah a) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final current = _player.started && _player.ayah == a.numberInSurah;
    final revealed = _revealed.contains(a.numberInSurah);
    final style = AppTheme.arabic(size: 26, height: 1.9);

    Widget text;
    if (_mode == 0 || revealed) {
      text = Text(a.arabic, textDirection: TextDirection.rtl, style: style);
    } else if (_mode == 1) {
      text = Text('${a.arabic.split(' ').first} …',
          textDirection: TextDirection.rtl, style: style);
    } else {
      text = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: Text(a.arabic, textDirection: TextDirection.rtl, style: style),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: current ? p.primarySoft : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: current ? scheme.primary : p.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _mode == 0
              ? null
              : () => setState(() {
                    if (!_revealed.remove(a.numberInSurah)) {
                      _revealed.add(a.numberInSurah);
                    }
                  }),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.n(a.numberInSurah),
                    style: TextStyle(
                        fontSize: 12, color: p.muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                SizedBox(width: double.infinity, child: text),
                if (_mode != 0 && !revealed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(context.tr('Tap to reveal', 'اضغط لإظهار الآية'),
                        style: TextStyle(fontSize: 12, color: p.muted)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, HifzItem item, AppPalette p) {
    final scheme = Theme.of(context).colorScheme;
    final status = _player.finished
        ? context.tr('Finished', 'انتهى')
        : _player.started
            ? context.tr(
                'Round ${_player.round} of ${_player.rounds} · verse ${_player.ayah}',
                'الجولة ${context.n(_player.round)} من ${context.n(_player.rounds)} · الآية ${context.n(_player.ayah)}')
            : context.tr('Press play to listen on repeat', 'اضغط تشغيل للاستماع بالتكرار');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: IconButton.filled(
                    tooltip: _player.playing
                        ? context.tr('Pause', 'إيقاف مؤقت')
                        : context.tr('Play', 'تشغيل'),
                    onPressed: () => _togglePlay(item),
                    icon: _player.loading && !_player.playing
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 3, color: scheme.onPrimary),
                          )
                        : Icon(
                            _player.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 32),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(status,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _finish(item, false),
                    child: Text(context.tr('Needs more work', 'أحتاج مراجعة')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _finish(item, true),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(context.tr('I remembered it', 'حفظتها')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
