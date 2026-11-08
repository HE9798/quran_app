import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'data/bookmark_store.dart';

/// "Saved": the page you stopped on, and every page you bookmarked.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${_months[d.month - 1]} ${d.day}';
  }

  static void _open(BuildContext context, SavedPage page) {
    context.go('/quran/surah/${page.surahNumber}?page=${page.page}');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ListenableBuilder(
      listenable: BookmarkStore.instance,
      builder: (context, _) {
        final store = BookmarkStore.instance;
        final items = store.bookmarks;
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
                      tooltip: 'Back',
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
                      const Text(
                        'Saved',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        items.length == 1
                            ? '1 bookmark'
                            : '${items.length} bookmarks',
                        style: TextStyle(fontSize: 13, color: p.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: (items.isEmpty && last == null)
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
                            dateLabel: _dateLabel(b.savedAt),
                            onTap: () => _open(context, b),
                            onRemove: () => store.remove(b),
                          ),
                          const SizedBox(height: 10),
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
                      'Last read',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.onPrimarySoft,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${page.surahName} · Page ${page.page}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: p.onPrimarySoft,
                      ),
                    ),
                    Text(
                      'Juz ${page.juz}',
                      style: TextStyle(fontSize: 13, color: p.onPrimarySoft),
                    ),
                  ],
                ),
              ),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  page.arabicName,
                  style: AppTheme.arabic(
                    size: 20,
                    height: 1.4,
                    color: p.onPrimarySoft,
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
                      '${page.surahName} · Page ${page.page}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Juz ${page.juz} · $dateLabel',
                      style: TextStyle(fontSize: 13, color: p.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove bookmark',
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
            const Text(
              'No saved pages yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'While reading, tap the bookmark icon to save the page you are on.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}
