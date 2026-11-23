import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../companion/data/companion_store.dart';
import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';
import 'data/khatma_repository.dart';
import 'data/khatma_store.dart';

/// ختم القرآن: choose in how many days to finish the Quran, follow the
/// progress, continue reading, update or reset.
class KhatmaScreen extends StatefulWidget {
  const KhatmaScreen({super.key});

  @override
  State<KhatmaScreen> createState() => _KhatmaScreenState();
}

class _KhatmaScreenState extends State<KhatmaScreen> {
  final _store = KhatmaStore.instance;
  final _repo = KhatmaRepository();

  int _days = 30; // choice while setting up
  bool _opening = false;

  static const _presets = [7, 10, 15, 30, 60, 90];

  Future<void> _continueReading() async {
    setState(() => _opening = true);
    try {
      final page = _store.nextPage;
      final surah = await _repo.surahForPage(page);
      if (!mounted) return;
      context.go('/quran/surah/$surah?page=$page&khatma=1');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _setPage(int page) async {
    final finished = await _store.setPage(page);
    if (finished || _store.todayDone) CompanionStore.instance.khatmaDayDone(); // coins + bubble (only if Companion mode is on)
    if (finished && mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('Khatma completed', 'تمت الختمة')),
          content: Text(context.tr(
            'May Allah accept it from you. Start a new khatma whenever you are ready.',
            'تقبل الله منك. ابدأ ختمة جديدة متى شئت.',
          )),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('Amen', 'آمين')),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _confirmReset() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Reset the khatma?', 'إعادة ضبط الختمة؟')),
        content: Text(context.tr(
          'Your progress in this khatma will be deleted.',
          'سيتم حذف تقدمك في هذه الختمة.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Reset', 'إعادة ضبط')),
          ),
        ],
      ),
    );
    if (yes == true) await _store.reset();
  }

  Future<void> _editProgress() async {
    var value = _store.currentPage.toDouble();
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('Pages you have finished', 'الصفحات التي أنهيتها'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('${value.round()} of ${KhatmaStore.totalPages}',
                    '${context.n(value.round())} من ${context.n(KhatmaStore.totalPages)}'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              Slider(
                min: 0,
                max: KhatmaStore.totalPages.toDouble(),
                value: value,
                label: context.n(value.round()),
                onChanged: (v) => setSheet(() => value = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(value.round()),
                  child: Text(context.tr('Save', 'حفظ')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) await _setPage(result);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
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
                      context.tr('Quran Khatma', 'ختم القرآن'),
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
                children: _store.active ? _activeView(context) : _setupView(context),
              ),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------- setup

  List<Widget> _setupView(BuildContext context) {
    final p = context.palette;
    final pagesPerDay = (KhatmaStore.totalPages / _days).ceil();

    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('In how many days do you want to finish the Quran?',
                  'في كم يومًا تريد ختم القرآن؟'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in _presets)
                  ChoiceChip(
                    label: Text(context.tr('$d days', '${context.n(d)} يوم')),
                    selected: _days == d,
                    onSelected: (_) => setState(() => _days = d),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _days > 1 ? () => setState(() => _days--) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    context.tr('$_days days', '${context.n(_days)} يوم'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _days < 365 ? () => setState(() => _days++) : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                context.tr('About $pagesPerDay pages a day',
                    'حوالي ${context.n(pagesPerDay)} صفحة في اليوم'),
                style: TextStyle(fontSize: 14, color: p.muted),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: () => _store.start(_days),
          child: Text(
            context.tr('Start the khatma', 'ابدأ الختمة'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      if (_store.completedCount > 0) ...[
        const SizedBox(height: 16),
        Center(
          child: Text(
            context.tr('Khatmas completed: ${_store.completedCount}',
                'الختمات المكتملة: ${context.n(_store.completedCount)}'),
            style: TextStyle(fontSize: 13, color: p.muted),
          ),
        ),
      ],
    ];
  }

  // ------------------------------------------------------------ active

  List<Widget> _activeView(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final s = _store;
    final percent = (s.progress * 100).floor();

    final String status;
    if (s.todayDone) {
      status = context.tr("Today's goal is done", 'أنجزت ورد اليوم');
    } else {
      status = context.tr('${s.pagesLeftToday} pages left today',
          'متبقٍ ${context.n(s.pagesLeftToday)} صفحة اليوم');
    }

    return [
      // progress card
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: p.hero,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.digits('$percent%'),
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 44,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              context.tr('${s.currentPage} of ${KhatmaStore.totalPages} pages',
                  '${context.n(s.currentPage)} من ${context.n(KhatmaStore.totalPages)} صفحة'),
              style: const TextStyle(color: AppColors.creamSoft, fontSize: 14),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: s.progress,
                minHeight: 10,
                backgroundColor: AppColors.creamFaint,
                valueColor: const AlwaysStoppedAnimation(AppColors.cream),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              s.overdue
                  ? context.tr('The planned time is over — keep going',
                      'انتهت المدة المحددة — واصل القراءة')
                  : context.tr('Day ${s.dayNumber} of ${s.days} · ${s.daysLeft} days left',
                      'اليوم ${context.n(s.dayNumber)} من ${context.n(s.days)} · متبقٍ ${context.n(s.daysLeft)} يوم'),
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // today's portion
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr("Today's portion", 'ورد اليوم'),
                style: TextStyle(fontSize: 12, color: p.muted)),
            const SizedBox(height: 4),
            Text(
              s.overdue
                  ? context.tr('Pages ${s.nextPage}–${KhatmaStore.totalPages}',
                      'الصفحات ${context.n(s.nextPage)}–${context.n(KhatmaStore.totalPages)}')
                  : context.tr('Pages ${s.todayStart}–${s.todayEnd}',
                      'الصفحات ${context.n(s.todayStart)}–${context.n(s.todayEnd)}'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: s.todayDone ? scheme.primary : p.muted,
              ),
            ),
            if (s.behindBy > 0) ...[
              const SizedBox(height: 2),
              Text(
                context.tr('${s.behindBy} pages behind the plan',
                    'متأخر ${context.n(s.behindBy)} صفحة عن الخطة'),
                style: TextStyle(fontSize: 12, color: p.muted),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),

      SizedBox(
        height: 54,
        child: FilledButton.icon(
          onPressed: _opening ? null : _continueReading,
          icon: _opening
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onPrimary,
                  ),
                )
              : const Icon(Icons.menu_book_rounded),
          label: Text(
            context.tr('Continue from page ${s.nextPage}',
                'تابع من صفحة ${context.n(s.nextPage)}'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: s.todayDone ? null : () => _setPage(s.todayEnd),
              icon: const Icon(Icons.check_rounded),
              label: Text(context.tr("Today's goal done", 'أنهيت ورد اليوم')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _editProgress,
              icon: const Icon(Icons.edit_rounded),
              label: Text(context.tr('Update progress', 'تحديث التقدم')),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Center(
        child: TextButton.icon(
          onPressed: _confirmReset,
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          icon: const Icon(Icons.restart_alt_rounded),
          label: Text(context.tr('Reset the khatma', 'إعادة ضبط الختمة')),
        ),
      ),
    ];
  }
}
