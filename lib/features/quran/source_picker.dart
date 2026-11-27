import 'package:material_ui/material_ui.dart';

import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';
import 'data/reading_sources.dart';

/// Bottom sheet to choose the tafsir or the translation shown under a verse:
/// a search box and the list grouped by language (Arabic first for tafsir,
/// English first for translations). The choice is remembered.
Future<void> showSourcePicker(BuildContext context, SourceKind kind) {
  ReadingSources.instance.refresh(); // the lists may be newer now
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SourcePicker(kind: kind),
  );
}

class _SourcePicker extends StatefulWidget {
  const _SourcePicker({required this.kind});

  final SourceKind kind;

  @override
  State<_SourcePicker> createState() => _SourcePickerState();
}

class _SourcePickerState extends State<_SourcePicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(TextSource s) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return s.nameEn.toLowerCase().contains(q) ||
        s.nameAr.contains(_query) ||
        s.author.toLowerCase().contains(q) ||
        s.languageEn.toLowerCase().contains(q) ||
        s.languageAr.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    final sources = ReadingSources.instance;
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final ar = context.isArabic;
    final isTafsir = widget.kind == SourceKind.tafsir;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: ListenableBuilder(
        listenable: sources,
        builder: (context, _) {
          final chosen = sources.chosen(widget.kind).key;
          final list = sources.listOf(widget.kind).where(_matches).toList();

          // the list with a header above each language
          final rows = <Widget>[];
          String? lastLanguage;
          for (final s in list) {
            if (s.languageEn != lastLanguage) {
              lastLanguage = s.languageEn;
              rows.add(Padding(
                padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                child: Text(
                  s.language(ar),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: scheme.primary),
                ),
              ));
            }
            final selected = s.key == chosen;
            rows.add(ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              selected: selected,
              selectedTileColor: p.primarySoft,
              title: Text(
                s.name(ar),
                // Arabic names read right to left in the Arabic layout only
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: s.author.isEmpty || s.author == s.nameEn
                  ? null
                  : Text(s.author, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: selected ? Icon(Icons.check_circle_rounded, color: scheme.primary) : null,
              onTap: () {
                sources.select(s);
                Navigator.of(context).pop();
              },
            ));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  isTafsir
                      ? context.tr('Choose a tafsir', 'اختر التفسير')
                      : context.tr('Choose a translation', 'اختر الترجمة'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  context.tr('${list.length} available · from Quran.com and Al-Quran Cloud',
                      '${context.n(list.length)} متاح · من Quran.com و Al-Quran Cloud'),
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: isTafsir
                        ? context.tr('Search by name, author or language', 'ابحث بالاسم أو المؤلف أو اللغة')
                        : context.tr('Search by language, name or translator', 'ابحث باللغة أو الاسم أو المترجم'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(context.tr('Nothing found', 'لا توجد نتائج'),
                            style: TextStyle(color: p.muted)),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        children: rows,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
