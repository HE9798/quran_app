import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/settings/tr.dart';
import '../../core/theme/lang_text.dart';
import '../hadith/data/hadith_models.dart';
import '../hadith/data/hadith_repository.dart';
import '../hadith/data/hadith_bookmark_store.dart';
import 'data/bookmark_store.dart';

/// "Saved": the page you stopped on, and every page you bookmarked.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  static String _dateLabel(BuildContext context, DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return context.tr('Today', 'اليوم');
    if (diff == 1) return context.tr('Yesterday', 'أمس');
    return context.shortDate(d);
  }

  static void _open(BuildContext context, SavedPage page) {
    context.go('/quran/surah/${page.surahNumber}?page=${page.page}');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ListenableBuilder(
      listenable: Listenable.merge([
        BookmarkStore.instance,
        HadithBookmarkStore.instance,
      ]),
      builder: (context, _) {
        final store = BookmarkStore.instance;
        final items = store.bookmarks;
        final hadiths = HadithBookmarkStore.instance.items;
        final total = items.length + hadiths.length;
        final last = store.lastRead;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
              child: Row(
                children: [
                  if (context.canPop())
                    IconButton(
                      tooltip: context.tr('Back', 'رجوع'),
                      onPressed: () => context.pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: p.surface,
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        fixedSize: const Size(44, 44),
                        side: BorderSide(color: p.border),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 22),
                    )
                  else
                    const SizedBox(width: 8),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Saved', 'المحفوظات'),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        context.isArabic
                            ? '${context.n(total)} إشارة'
                            : (total == 1 ? '1 bookmark' : '$total bookmarks'),
                        style: TextStyle(fontSize: 13, color: p.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: (items.isEmpty && last == null && hadiths.isEmpty)
                  ? const _EmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        if (last != null) ...[
                          _LastReadCard(
                            page: last,
                            onTap: () => _open(context, last),
                          ),
                          const SizedBox(height: 10),
                        ],
                        for (final b in items) ...[
                          _BookmarkTile(
                            page: b,
                            dateLabel: _dateLabel(context, b.savedAt),
                            onTap: () => _open(context, b),
                            onRemove: () => store.remove(b),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (hadiths.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 8, 0, 8),
                            child: Text(
                              context.tr('Ahadeeth', 'الأحاديث'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: p.muted,
                              ),
                            ),
                          ),
                          for (final h in hadiths) ...[
                            _SavedHadithTile(
                              hadith: h,
                              onRemove: () =>
                                  HadithBookmarkStore.instance.removeById(h.id),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _LastReadCard extends StatelessWidget {
  const _LastReadCard({required this.page, required this.onTap});

  final SavedPage page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: p.border),
    );
    return Material(
      color: p.primarySoft,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.menu_book_outlined, color: scheme.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Last read', 'آخر قراءة'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.onPrimarySoft,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      context.isArabic
                          ? 'سورة ${page.arabicName} · صفحة ${context.n(page.page)}'
                          : '${page.surahName} · Page ${page.page}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: p.onPrimarySoft,
                      ),
                    ),
                    Text(
                      context.isArabic
                          ? 'الجزء ${context.n(page.juz)}'
                          : 'Juz ${page.juz}',
                      style: TextStyle(fontSize: 13, color: p.onPrimarySoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  const _BookmarkTile({
    required this.page,
    required this.dateLabel,
    required this.onTap,
    required this.onRemove,
  });

  final SavedPage page;
  final String dateLabel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: p.border),
    );
    return Material(
      color: p.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.menu_book_outlined, color: p.onPrimarySoft),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.isArabic
                          ? 'سورة ${page.arabicName} · صفحة ${context.n(page.page)}'
                          : '${page.surahName} · Page ${page.page}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.isArabic
                          ? 'الجزء ${context.n(page.juz)} · $dateLabel'
                          : 'Juz ${page.juz} · $dateLabel',
                      style: TextStyle(fontSize: 13, color: p.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('Remove bookmark', 'إزالة الإشارة'),
                onPressed: onRemove,
                style: IconButton.styleFrom(
                  foregroundColor: scheme.primary,
                  fixedSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.bookmark_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A saved hadith. Tap to read all of it, tap again to fold it.
class _SavedHadithTile extends StatefulWidget {
  const _SavedHadithTile({required this.hadith, required this.onRemove});

  final SavedHadith hadith;
  final VoidCallback onRemove;

  @override
  State<_SavedHadithTile> createState() => _SavedHadithTileState();
}

class _SavedHadithTileState extends State<_SavedHadithTile> {
  bool _open = false;
  bool? _arabic;
  String? _text; //  text in the chosen language (null = use the saved one)
  String? _label;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arabic = context.isArabic;
    if (_arabic == arabic) return;
    _arabic = arabic;
    _resolve(arabic);
  }

  /// The hadith was saved in one language; show it in the current one.
  Future<void> _resolve(bool arabic) async {
    _text = null;
    _label = null;
    try {
      final parts = widget.hadith.id.split(':');
      final book = HadithBook.values.byName(parts[0]);
      final collection =
          await HadithRepository.instance.load(book, arabic: arabic);
      for (final h in collection.hadiths) {
        if (h.number == parts[1]) {
          if (!mounted || _arabic != arabic) return;
          setState(() {
            _text = h.text;
            _label = h.label;
          });
          return;
        }
      }
    } catch (_) {
      // keep the saved copy
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final label = _label ?? widget.hadith.label;
    final text = _text ?? widget.hadith.text;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: p.border),
    );
    return Material(
      color: p.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      textDirection: dirFor(label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: contentStyle(
                        label,
                        size: 15,
                        height: 1.3,
                        color: p.muted,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Remove bookmark', 'إزالة الإشارة'),
                    onPressed: widget.onRemove,
                    style: IconButton.styleFrom(
                      foregroundColor: scheme.primary,
                      fixedSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.bookmark_rounded),
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12, bottom: 10),
                  child: Text(
                    text,
                    textDirection: dirFor(text),
                    maxLines: _open ? null : 3,
                    overflow:
                        _open ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: contentStyle(text, size: 19, height: 1.8),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_rounded, size: 48, color: p.muted),
            const SizedBox(height: 12),
            Text(
              context.tr('Nothing saved yet', 'لا يوجد شيء محفوظ بعد'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'Tap the bookmark icon while reading the Quran or the ahadeeth to save it here.',
                'اضغط على أيقونة الإشارة أثناء قراءة القرآن أو الأحاديث لحفظها هنا.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}
