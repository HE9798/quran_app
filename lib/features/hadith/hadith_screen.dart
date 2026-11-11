import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'data/hadith_bookmark_store.dart';
import 'data/hadith_models.dart';
import 'data/hadith_repository.dart';

/// Ahadeeth: two tabs.
///  1. الأربعين النووية
///  2. الأحاديث النبوية الصحيحة (من صحيحي البخاري ومسلم)
class HadithScreen extends StatefulWidget {
  const HadithScreen({super.key});

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ahadeeth',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Authentic collections in Arabic',
                style: TextStyle(fontSize: 13, color: p.muted),
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
            tabs: const [
              _TabLabel('الأربعين النووية'),
              _TabLabel('الأحاديث النبوية الصحيحة'),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [_NawawiTab(), _SahihTab()],
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
            textDirection: TextDirection.rtl,
            style: AppTheme.arabic(size: 17, height: 1.3).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// =================================================================== tab 1

class _NawawiTab extends StatefulWidget {
  const _NawawiTab();

  @override
  State<_NawawiTab> createState() => _NawawiTabState();
}

class _NawawiTabState extends State<_NawawiTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _CollectionLoader(
      book: HadithBook.nawawi,
      builder: (context, collection) => _NawawiBody(collection: collection),
    );
  }
}

class _NawawiBody extends StatefulWidget {
  const _NawawiBody({required this.collection});

  final HadithCollection collection;

  @override
  State<_NawawiBody> createState() => _NawawiBodyState();
}

class _NawawiBodyState extends State<_NawawiBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = widget.collection;
    final searching = _query.trim().isNotEmpty;
    final items = searching ? c.search(_query) : c.hadiths;

    return Column(
      children: [
        _SearchField(onChanged: (value) => setState(() => _query = value)),
        Expanded(
          child: _HadithList(
            hadiths: items,
            emptyText: searching ? 'لا توجد نتائج' : 'لا توجد أحاديث',
            header: searching ? '${items.length} نتيجة' : null,
          ),
        ),
      ],
    );
  }
}

// =================================================================== tab 2

class _SahihTab extends StatefulWidget {
  const _SahihTab();

  @override
  State<_SahihTab> createState() => _SahihTabState();
}

class _SahihTabState extends State<_SahihTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  HadithBook _book = HadithBook.bukhari;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              _BookChip(
                label: HadithBook.bukhari.title,
                selected: _book == HadithBook.bukhari,
                onTap: () => setState(() => _book = HadithBook.bukhari),
              ),
              const SizedBox(width: 8),
              _BookChip(
                label: HadithBook.muslim.title,
                selected: _book == HadithBook.muslim,
                onTap: () => setState(() => _book = HadithBook.muslim),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'من صحيحي البخاري ومسلم',
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.arabic(size: 14, height: 1.3, color: p.muted),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _CollectionLoader(
            key: ValueKey(_book), // new book = fresh state
            book: _book,
            builder: (context, collection) => _SahihBody(
              key: ValueKey(_book),
              collection: collection,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookChip extends StatelessWidget {
  const _BookChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : p.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? scheme.primary : p.border),
          ),
          child: Text(
            label,
            textDirection: TextDirection.rtl,
            style: AppTheme.arabic(
              size: 16,
              height: 1.2,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _SahihBody extends StatefulWidget {
  const _SahihBody({super.key, required this.collection});

  final HadithCollection collection;

  @override
  State<_SahihBody> createState() => _SahihBodyState();
}

class _SahihBodyState extends State<_SahihBody> {
  String _query = '';
  late int _section;

  @override
  void initState() {
    super.initState();
    final sections = widget.collection.sections;
    _section = sections.isEmpty ? 0 : sections.first.number;
  }

  HadithSection? get _current {
    for (final s in widget.collection.sections) {
      if (s.number == _section) return s;
    }
    return null;
  }

  Future<void> _pickSection() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SectionSheet(
        sections: widget.collection.sections,
        selected: _section,
      ),
    );
    if (chosen != null && mounted) setState(() => _section = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.collection;
    final searching = _query.trim().isNotEmpty;
    final hasSections = c.sections.isNotEmpty;

    final List<Hadith> items;
    if (searching) {
      items = c.search(_query);
    } else if (hasSections) {
      items = c.inSection(_section);
    } else {
      items = c.hadiths;
    }

    return Column(
      children: [
        _SearchField(onChanged: (value) => setState(() => _query = value)),
        if (!searching && hasSections)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _SectionButton(
              section: _current,
              onTap: _pickSection,
            ),
          ),
        Expanded(
          child: _HadithList(
            hadiths: items,
            emptyText: searching ? 'لا توجد نتائج' : 'لا توجد أحاديث',
            header: searching
                ? (items.length >= 100
                    ? 'أول ١٠٠ نتيجة'
                    : '${items.length} نتيجة')
                : null,
          ),
        ),
      ],
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({required this.section, required this.onTap});

  final HadithSection? section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: p.border),
    );
    return Material(
      color: p.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.expand_more_rounded, color: p.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section == null
                      ? 'اختر الكتاب'
                      : '${section!.name} (${section!.count})',
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.arabic(size: 17, height: 1.4).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionSheet extends StatelessWidget {
  const _SectionSheet({required this.sections, required this.selected});

  final List<HadithSection> sections;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.7;

    return SizedBox(
      height: height,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final s = sections[index];
          final isSelected = s.number == selected;
          return ListTile(
            onTap: () => Navigator.of(context).pop(s.number),
            selected: isSelected,
            selectedTileColor: p.primarySoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            leading: isSelected
                ? Icon(Icons.check_rounded, color: scheme.primary)
                : null,
            title: Text(
              s.name,
              textDirection: TextDirection.rtl,
              style: AppTheme.arabic(
                size: 17,
                height: 1.4,
                color: isSelected ? p.onPrimarySoft : scheme.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            trailing: Text(
              '${s.count}',
              style: TextStyle(color: p.muted, fontSize: 13),
            ),
          );
        },
      ),
    );
  }
}

// ================================================================== shared

/// Downloads (or reads from the phone) one book, with loading and error views.
class _CollectionLoader extends StatefulWidget {
  const _CollectionLoader({
    super.key,
    required this.book,
    required this.builder,
  });

  final HadithBook book;
  final Widget Function(BuildContext context, HadithCollection collection)
      builder;

  @override
  State<_CollectionLoader> createState() => _CollectionLoaderState();
}

class _CollectionLoaderState extends State<_CollectionLoader> {
  late Future<HadithCollection> _future =
      HadithRepository.instance.load(widget.book);

  void _retry() {
    setState(() => _future = HadithRepository.instance.load(widget.book));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FutureBuilder<HadithCollection>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) return widget.builder(context, snapshot.data!);

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 44, color: p.muted),
                  const SizedBox(height: 12),
                  const Text(
                    "Couldn't load the ahadeeth",
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check your internet connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: p.muted),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _retry,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                widget.book == HadithBook.nawawi
                    ? 'Loading…'
                    : 'Downloading ${widget.book.title}…\nOnly the first time.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        height: 48,
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
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 250),
                    () => widget.onChanged(value),
                  );
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search hadith',
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
      ),
    );
  }
}

class _HadithList extends StatelessWidget {
  const _HadithList({
    required this.hadiths,
    required this.emptyText,
    this.header,
  });

  final List<Hadith> hadiths;
  final String emptyText;
  final String? header;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (hadiths.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          textDirection: TextDirection.rtl,
          style: AppTheme.arabic(size: 18, height: 1.4, color: p.muted),
        ),
      );
    }

    final headerCount = header == null ? 0 : 1;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: hadiths.length + headerCount,
      itemBuilder: (context, index) {
        if (header != null && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              header!,
              textDirection: TextDirection.rtl,
              style: AppTheme.arabic(size: 15, height: 1.3, color: p.muted),
            ),
          );
        }
        final hadith = hadiths[index - headerCount];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: HadithCard(key: ValueKey(hadith.id), hadith: hadith),
        );
      },
    );
  }
}

/// One hadith: source + grade, Arabic text, copy and bookmark.
class HadithCard extends StatefulWidget {
  const HadithCard({super.key, required this.hadith});

  final Hadith hadith;

  @override
  State<HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends State<HadithCard> {
  static const _collapsedChars = 420;
  bool _expanded = false;

  Future<void> _copy() async {
    final h = widget.hadith;
    await Clipboard.setData(ClipboardData(text: '${h.text}\n\n— ${h.label}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Hadith copied')));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final h = widget.hadith;
    final long = h.text.length > _collapsedChars;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  h.label,
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.arabic(size: 15, height: 1.3, color: p.muted)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (h.grade != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    h.grade!,
                    style: AppTheme.arabic(
                      size: 14,
                      height: 1.3,
                      color: p.onPrimarySoft,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: Text(
              h.text,
              textDirection: TextDirection.rtl,
              maxLines: (long && !_expanded) ? 8 : null,
              overflow: (long && !_expanded)
                  ? TextOverflow.ellipsis
                  : TextOverflow.visible,
              style: AppTheme.arabic(size: 21, height: 1.9),
            ),
          ),
          if (long)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: Text(
                  _expanded ? 'عرض أقل' : 'عرض المزيد',
                  textDirection: TextDirection.rtl,
                  style: AppTheme.arabic(
                    size: 16,
                    height: 1.3,
                    color: scheme.primary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Copy hadith',
                  onPressed: _copy,
                  style: IconButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    fixedSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 21),
                ),
                const Spacer(),
                ListenableBuilder(
                  listenable: HadithBookmarkStore.instance,
                  builder: (context, _) {
                    final saved = HadithBookmarkStore.instance.isSaved(h.id);
                    return IconButton(
                      tooltip: saved ? 'Remove bookmark' : 'Bookmark hadith',
                      onPressed: () => HadithBookmarkStore.instance.toggle(h),
                      style: IconButton.styleFrom(
                        foregroundColor:
                            saved ? scheme.primary : scheme.onSurface,
                        fixedSize: const Size(44, 44),
                      ),
                      icon: Icon(
                        saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 22,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
