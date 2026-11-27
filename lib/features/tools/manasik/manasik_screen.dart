import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/tr.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import 'manasik_data.dart';

/// "مناسك الحج والعمرة": step-by-step Umrah, and Hajj Tamattu', Qiran and
/// Ifrad. Each step shows what to do, its supplications (Hisn al-Muslim API)
/// and its evidence (Sahih al-Bukhari / Muslim). Reference cards follow.
class ManasikScreen extends StatefulWidget {
  const ManasikScreen({super.key});

  @override
  State<ManasikScreen> createState() => _ManasikScreenState();
}

class _ManasikScreenState extends State<ManasikScreen> {
  late final Future<ManasikBook> _book = ManasikBook.load();
  int _guide = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FutureBuilder<ManasikBook>(
      future: _book,
      builder: (context, snap) {
        final book = snap.data;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: context.tr('Back', 'رجوع'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.canPop() ? context.pop() : context.go('/tools'),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Hajj & Umrah', 'مناسك الحج والعمرة'),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      ),
                      Text(
                        context.tr('Step by step, with the supplications', 'خطوة بخطوة مع الأذكار'),
                        style: TextStyle(fontSize: 13, color: p.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (book == null)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: snap.hasError
                      ? Text(context.tr('Could not open the guide.', 'تعذّر فتح الدليل.'))
                      : const CircularProgressIndicator(),
                ),
              )
            else
              ..._content(context, book),
          ],
        );
      },
    );
  }

  List<Widget> _content(BuildContext context, ManasikBook book) {
    final p = context.palette;
    final ar = context.isArabic;
    final guide = book.guides[_guide];
    return [
      // Umrah / Tamattu' / Qiran / Ifrad
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < book.guides.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              ChoiceChip(
                label: Text(ar ? book.guides[i].titleAr : book.guides[i].titleEn),
                selected: _guide == i,
                onSelected: (_) => setState(() => _guide = i),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.primarySoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          ar ? guide.introAr : guide.introEn,
          style: TextStyle(fontSize: 14, height: 1.5, color: p.onPrimarySoft),
        ),
      ),
      const SizedBox(height: 16),
      for (var i = 0; i < guide.steps.length; i++) ...[
        _StepCard(
          key: ValueKey('${guide.id}/${guide.steps[i].id}'),
          number: i + 1,
          step: guide.steps[i],
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 14),
      Text(
        context.tr('Good to know', 'أحكام مهمة'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      for (final card in book.info) ...[
        _StepCard(key: ValueKey('info/${card.id}'), step: card),
        const SizedBox(height: 10),
      ],
      _JabirCard(jabir: book.jabir),
      const SizedBox(height: 16),
      Text(
        ar ? book.sourceAr : book.sourceEn,
        style: TextStyle(fontSize: 12, height: 1.5, color: p.muted),
      ),
    ];
  }
}

/// A rite (with a [number]) or a reference card (without one). Tap to open.
class _StepCard extends StatefulWidget {
  const _StepCard({super.key, required this.step, this.number});

  final ManasikStep step;
  final int? number;

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ar = context.isArabic;
    final s = widget.step;
    final when = ar ? s.whenAr : s.whenEn;
    final points = ar ? s.pointsAr : s.pointsEn;

    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.primarySoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: widget.number == null
                        ? Icon(Icons.info_outline_rounded, size: 20, color: p.onPrimarySoft)
                        : Text(
                            context.n(widget.number!),
                            style: TextStyle(fontWeight: FontWeight.w800, color: p.onPrimarySoft),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ar ? s.titleAr : s.titleEn,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        if (when.isNotEmpty)
                          Text(when, style: TextStyle(fontSize: 13, color: p.muted)),
                      ],
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: p.muted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final point in points) _Bullet(point),
                        for (final id in s.duas) _DuaBlock(chapter: id),
                        for (final e in s.evidence) _EvidenceBlock(evidence: e),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: p.onPrimarySoft, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.55))),
        ],
      ),
    );
  }
}

/// Section label inside a card ("الذكر" / "الدليل").
class _Label extends StatelessWidget {
  const _Label(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: p.onPrimarySoft),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: p.onPrimarySoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// The supplications of one Hisn al-Muslim chapter, loaded from its API.
class _DuaBlock extends StatefulWidget {
  const _DuaBlock({required this.chapter});

  final int chapter;

  @override
  State<_DuaBlock> createState() => _DuaBlockState();
}

class _DuaBlockState extends State<_DuaBlock> {
  late Future<HisnChapter> _future = HisnRepository.instance.chapter(widget.chapter);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ar = context.isArabic;
    return FutureBuilder<HisnChapter>(
      future: _future,
      builder: (context, snap) {
        final chapter = snap.data;
        final title = ar ? (hisnTitlesAr[widget.chapter] ?? '') : (chapter?.titleEn ?? '');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Label(Icons.auto_stories_outlined,
                title.isEmpty ? context.tr('Supplication', 'الذكر') : title),
            if (chapter != null)
              for (final d in chapter.duas)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        d.arabic,
                        textDirection: TextDirection.rtl,
                        style: AppTheme.arabic(size: 20, height: 1.8),
                      ),
                      if (!ar && d.translation.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(d.translation, style: TextStyle(fontSize: 14, height: 1.5, color: p.muted)),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          context.tr('Hisn al-Muslim', 'حصن المسلم'),
                          style: TextStyle(fontSize: 11, color: p.muted),
                        ),
                      ),
                    ],
                  ),
                )
            else if (snap.hasError)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Could not load. Check your connection.',
                          'تعذّر التحميل. تحقّق من الاتصال.'),
                      style: TextStyle(fontSize: 13, color: p.muted),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                        () => _future = HisnRepository.instance.chapter(widget.chapter)),
                    child: Text(context.tr('Retry', 'إعادة')),
                  ),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.all(8),
                child: Center(
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EvidenceBlock extends StatelessWidget {
  const _EvidenceBlock({required this.evidence});

  final Evidence evidence;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Label(Icons.menu_book_outlined, context.tr('Evidence', 'الدليل')),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '«${evidence.text}»',
                textDirection: TextDirection.rtl,
                style: AppTheme.arabic(size: 17, height: 1.8),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(evidence.refEn, evidence.refAr),
                style: TextStyle(fontSize: 12, color: p.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Jabir's full description of the Prophet's Hajj, at the end.
class _JabirCard extends StatefulWidget {
  const _JabirCard({required this.jabir});

  final Evidence jabir;

  @override
  State<_JabirCard> createState() => _JabirCardState();
}

class _JabirCardState extends State<_JabirCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p.primarySoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.menu_book_outlined, size: 20, color: p.onPrimarySoft),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr("The Prophet's ﷺ Hajj", 'صفة حجة النبي ﷺ'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          context.tr("Jabir's hadith · ${widget.jabir.refEn}",
                              'حديث جابر · ${widget.jabir.refAr}'),
                          style: TextStyle(fontSize: 13, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: p.muted),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                widget.jabir.text,
                textDirection: TextDirection.rtl,
                style: AppTheme.arabic(size: 18, height: 1.9),
              ),
            ),
        ],
      ),
    );
  }
}
