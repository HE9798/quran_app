import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/lang_text.dart';
import '../hadith/data/hadith_models.dart' show normalizeArabic;
import 'dua_data.dart';

/// الأدعية: two tabs, like the Hadith page. Duas from the Quran only, and
/// duas from Sahih al-Bukhari and Sahih Muslim.
class DuaScreen extends StatefulWidget {
  const DuaScreen({super.key});

  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late final Future<DuaBook> _book = DuaBook.load();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
          child: Row(
            children: [
              IconButton(
                tooltip: context.tr('Back', 'رجوع'),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.canPop() ? context.pop() : context.go('/'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Dua', 'الأدعية'),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('From the Quran and the Sunnah', 'من القرآن والسنة'),
                      style: TextStyle(fontSize: 13, color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabs,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: scheme.onPrimary,
            unselectedLabelColor: scheme.onSurface,
            splashBorderRadius: BorderRadius.circular(12),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            tabs: [
              _TabLabel(context.tr('From the Quran', 'أدعية من القرآن')),
              _TabLabel(context.tr('From the Hadith', 'أدعية من السنة')),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: FutureBuilder<DuaBook>(
            future: _book,
            builder: (context, snap) {
              final book = snap.data;
              if (book == null) {
                return Center(
                  child: snap.hasError
                      ? Text(context.tr('Could not open the duas.', 'تعذّر فتح الأدعية.'))
                      : const CircularProgressIndicator(),
                );
              }
              return TabBarView(
                controller: _tabs,
                children: [
                  _DuaList<QuranDua>(
                    note: context.tr('Duas in the words of the Quran', 'أدعية بنص آيات القرآن الكريم'),
                    items: book.quran,
                    topicOf: (d) => d.topic,
                    searchKeyOf: (d) => d.searchKey,
                    source: context.isArabic ? book.sourceAr : book.sourceEn,
                    card: (d) => _QuranCard(dua: d),
                  ),
                  _DuaList<HadithDua>(
                    note: context.tr('From Sahih al-Bukhari and Sahih Muslim', 'من صحيحي البخاري ومسلم'),
                    items: book.hadith,
                    topicOf: (d) => d.topic,
                    searchKeyOf: (d) => d.searchKey,
                    source: context.isArabic ? book.sourceAr : book.sourceEn,
                    card: (d) => _HadithCard(dua: d),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textDirection: dirFor(text),
            style: contentStyle(text, size: 17, height: 1.3, weight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// Topic names for the chips.
String topicLabel(BuildContext context, String topic) => switch (topic) {
      'forgiveness' => context.tr('Forgiveness', 'المغفرة والتوبة'),
      'guidance' => context.tr('Guidance', 'الهداية والثبات'),
      'protection' => context.tr('Protection', 'الاستعاذة'),
      'hardship' => context.tr('Hardship', 'الكرب والشدة'),
      'family' => context.tr('Family', 'الوالدين والذرية'),
      'goodness' => context.tr('Good of both worlds', 'خير الدنيا والآخرة'),
      'praise' => context.tr('Praise', 'الثناء والتوكل'),
      'occasions' => context.tr('Daily occasions', 'أدعية المواقف'),
      _ => topic,
    };

/// One tab: a search box, topic chips, a note with the count, the cards,
/// and the source at the bottom.
class _DuaList<T> extends StatefulWidget {
  const _DuaList({
    super.key,
    required this.note,
    required this.items,
    required this.topicOf,
    required this.searchKeyOf,
    required this.source,
    required this.card,
  });

  final String note;
  final List<T> items;
  final String Function(T) topicOf;
  final String Function(T) searchKeyOf;
  final String source;
  final Widget Function(T) card;

  @override
  State<_DuaList<T>> createState() => _DuaListState<T>();
}

class _DuaListState<T> extends State<_DuaList<T>> with AutomaticKeepAliveClientMixin {
  String? _topic; // null = all
  String _query = '';

  @override
  bool get wantKeepAlive => true; // keep the search and chip when switching tabs

  List<T> get _shown {
    final words = normalizeArabic(_query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return [
      for (final d in widget.items)
        if ((_topic == null || widget.topicOf(d) == _topic) &&
            words.every(widget.searchKeyOf(d).contains))
          d,
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final shown = _shown;
    final topics = [
      for (final t in duaTopics)
        if (widget.items.any((d) => widget.topicOf(d) == t)) t,
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: shown.length + 4,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Container(
            height: 48,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: p.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: context.tr('Search duas', 'ابحث في الأدعية'),
                      hintStyle: TextStyle(color: p.muted),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isCollapsed: true,
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
          );
        }
        if (i == 1) {
          return SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final t in [null, ...topics]) ...[
                  ChoiceChip(
                    label: Text(t == null ? context.tr('All', 'الكل') : topicLabel(context, t)),
                    selected: _topic == t,
                    onSelected: (_) => setState(() => _topic = t),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          );
        }
        if (i == 2) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 10),
            child: Text(
              '${widget.note} · ${context.n(shown.length)}',
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
          );
        }
        if (i == shown.length + 3) {
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: shown.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text(context.tr('No duas found', 'لا توجد أدعية مطابقة'),
                          style: TextStyle(color: p.muted)),
                    ),
                  )
                : Text(widget.source, style: TextStyle(fontSize: 12, height: 1.5, color: p.muted)),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: widget.card(shown[i - 3]),
        );
      },
    );
  }
}

class _QuranCard extends StatelessWidget {
  const _QuranCard({required this.dua});
  final QuranDua dua;

  @override
  Widget build(BuildContext context) {
    final ref = context.tr(
      '${dua.surahEn} ${dua.surah}:${dua.verses}',
      'سورة ${dua.surahAr}: ${context.n(dua.verses)}',
    );
    return _DuaCard(arabic: dua.arabic, english: dua.english, reference: ref);
  }
}

class _HadithCard extends StatelessWidget {
  const _HadithCard({required this.dua});
  final HadithDua dua;

  @override
  Widget build(BuildContext context) {
    final ref = dua.isBukhari
        ? context.tr('Sahih al-Bukhari ${dua.number}', 'رواه البخاري (${context.n(dua.number)})')
        : context.tr('Sahih Muslim ${dua.number}', 'رواه مسلم (${context.n(dua.number)})');
    final title = context.isArabic ? dua.titleAr : dua.titleEn;
    return _DuaCard(
      title: title.isEmpty ? null : title,
      arabic: dua.arabic,
      english: dua.english,
      reference: ref,
    );
  }
}

/// Arabic text (always right to left), the English when the app is in
/// English, and the source. Long-press copies the dua.
class _DuaCard extends StatelessWidget {
  const _DuaCard({required this.arabic, required this.english, required this.reference, this.title});

  final String arabic, english, reference;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final ar = context.isArabic;
    return Material(
      color: p.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: '$arabic\n\n$reference'));
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(context.tr('Dua copied', 'تم نسخ الدعاء'))));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.primary),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                arabic,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: AppTheme.arabic(size: 20, height: 1.9),
              ),
              if (!ar) ...[
                const SizedBox(height: 8),
                Text(english, style: TextStyle(fontSize: 14, height: 1.5, color: p.muted)),
              ],
              const SizedBox(height: 8),
              Text(reference, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
