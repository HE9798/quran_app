import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_view.dart';
import '../bookmarks/data/bookmark_store.dart';
import 'data/quran_repository.dart';
import 'data/surah.dart';
import 'data/surah_detail.dart';

/// Reader. The surah is shown in mushaf pages (like the printed Quran):
///  - swipe left-to-right  = next page (like turning a page of an Arabic book)
///  - swipe right-to-left  = previous page
///  - swiping past the last / first page opens the next / previous surah
///  - tap a verse to open the Tafseer / Translation panel
///  - the bookmark button saves the page you are on
class SurahScreen extends StatefulWidget {
  const SurahScreen({
    super.key,
    required this.number,
    this.initialPage,
    this.startAtEnd = false,
  });

  final int number;

  /// Mushaf page to open (route: ?page=42). null = first page of the surah.
  final int? initialPage;

  /// Open on the last page of the surah (route: ?end=1). Used when you swipe
  /// back from the next surah.
  final bool startAtEnd;

  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  final _repo = QuranRepository();
  late Future<SurahDetail> _future = _repo.getSurahDetail(widget.number);

  /// surah number -> English name, used on the "next surah" page.
  Map<int, String> _names = const {};

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    try {
      final surahs = await _repo.getSurahs();
      if (!mounted) return;
      setState(() => _names = {for (final s in surahs) s.number: s.englishName});
    } catch (_) {
      // names are only a nicety on the transition page
    }
  }

  void _retry() =>
      setState(() => _future = _repo.getSurahDetail(widget.number));

  void _goToSurah(int number, bool atEnd) {
    context.go(atEnd ? '/quran/surah/$number?end=1' : '/quran/surah/$number');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SurahDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _SimpleShell(
            title: 'Surah ${widget.number}',
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final detail = snapshot.data;
        if (snapshot.hasError || detail == null) {
          return _SimpleShell(
            title: 'Surah ${widget.number}',
            child: ErrorView(
              title: "Couldn't load this surah",
              onRetry: _retry,
            ),
          );
        }
        return _SurahReader(
          detail: detail,
          initialPage: widget.initialPage,
          startAtEnd: widget.startAtEnd,
          names: _names,
          onGoToSurah: _goToSurah,
        );
      },
    );
  }
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/quran');
  }
}

/// Top bar + body, used while loading or on error.
class _SimpleShell extends StatelessWidget {
  const _SimpleShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(
          title: title,
          subtitle: null,
          onBack: () => _goBack(context),
          trailing: const SizedBox(width: 44),
        ),
        Expanded(child: child),
      ],
    );
  }
}

// ---------------------------------------------------------- reader logic

/// The verses of one mushaf page (only the verses of this surah).
class _MushafPage {
  const _MushafPage(this.number, this.ayahs);

  final int number;
  final List<Ayah> ayahs;

  int get juz => ayahs.first.juz;
}

List<_MushafPage> _groupPages(List<Ayah> ayahs) {
  final pages = <_MushafPage>[];
  var current = <Ayah>[];
  var currentPage = ayahs.first.page;
  for (final ayah in ayahs) {
    if (ayah.page != currentPage && current.isNotEmpty) {
      pages.add(_MushafPage(currentPage, current));
      current = <Ayah>[];
      currentPage = ayah.page;
    }
    current.add(ayah);
  }
  if (current.isNotEmpty) pages.add(_MushafPage(currentPage, current));
  return pages;
}

String _arabicDigits(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
    .join();

class _SurahReader extends StatefulWidget {
  const _SurahReader({
    required this.detail,
    required this.initialPage,
    required this.startAtEnd,
    required this.names,
    required this.onGoToSurah,
  });

  final SurahDetail detail;
  final int? initialPage;
  final bool startAtEnd;
  final Map<int, String> names;
  final void Function(int surah, bool atEnd) onGoToSurah;

  @override
  State<_SurahReader> createState() => _SurahReaderState();
}

class _SurahReaderState extends State<_SurahReader> {
  late final List<_MushafPage> _pages = _groupPages(widget.detail.ayahs);
  late final bool _hasPrev = widget.detail.surah.number > 1;
  late final bool _hasNext = widget.detail.surah.number < 114;
  late final PageController _controller;

  /// Index inside the PageView. Page 0 is the "previous surah" page when
  /// there is one, and the last page is the "next surah" page.
  late int _index;

  final _recognizers = <int, TapGestureRecognizer>{};
  final _fitCache = <String, double>{}; // font size found for each page
  int? _selected; //      verse that is highlighted (panel open)
  int? _lastSelected; //   keeps the panel content while it slides away
  bool _tafseerTab = true;
  bool _leaving = false; // already opening another surah

  int get _offset => _hasPrev ? 1 : 0;
  int get _total => _pages.length + _offset + (_hasNext ? 1 : 0);
  bool _isContent(int i) => i >= _offset && i < _offset + _pages.length;
  _MushafPage get _current =>
      _pages[(_index - _offset).clamp(0, _pages.length - 1)];

  @override
  void initState() {
    super.initState();
    var content = 0;
    final start = widget.initialPage;
    if (widget.startAtEnd) {
      content = _pages.length - 1;
    } else if (start != null) {
      final found = _pages.indexWhere((p) => p.number == start);
      if (found != -1) content = found;
    }
    _index = content + _offset;
    _controller = PageController(initialPage: _index);

    // remember where we are (after the first frame, not during build)
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveLastRead());

    // Amiri is downloaded the first time it is used. Sizes measured before it
    // arrived used a fallback font, so measure again once it has loaded.
    GoogleFonts.pendingFonts().then((_) {
      if (!mounted) return;
      setState(_fitCache.clear);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final r in _recognizers.values) {
      r.dispose();
    }
    super.dispose();
  }

  SavedPage _savedPage() {
    final surah = widget.detail.surah;
    final page = _current;
    return SavedPage(
      surahNumber: surah.number,
      surahName: surah.englishName,
      arabicName: surah.arabicName,
      page: page.number,
      juz: page.juz,
      savedAt: DateTime.now(),
    );
  }

  void _saveLastRead() {
    if (!mounted) return;
    BookmarkStore.instance.setLastRead(_savedPage());
  }

  Future<void> _toggleBookmark() async {
    final saved = await BookmarkStore.instance.toggle(_savedPage());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(saved ? 'Page ${_current.number} saved' : 'Bookmark removed'),
      ));
  }

  TapGestureRecognizer _recognizerFor(int verse) {
    return _recognizers.putIfAbsent(
      verse,
      () => TapGestureRecognizer()..onTap = () => _selectVerse(verse),
    );
  }

  void _selectVerse(int verse) {
    setState(() {
      if (_selected == verse) {
        _selected = null; // tap the same verse again to close
      } else {
        _selected = verse;
        _lastSelected = verse;
      }
    });
  }

  void _closePanel() => setState(() => _selected = null);

  void _copy(Ayah ayah) {
    final surah = widget.detail.surah;
    Clipboard.setData(ClipboardData(
      text: '${ayah.arabic}\n\n${ayah.translation}\n\n'
          '— ${surah.englishName} ${surah.number}:${ayah.numberInSurah}',
    ));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Verse copied')));
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
      _selected = null;
    });
    if (_isContent(index)) _saveLastRead();
  }

  /// When a swipe ends on the "next/previous surah" page, open that surah.
  void _onScrollEnd() {
    if (_leaving || !_controller.hasClients) return;
    final page = _controller.page;
    if (page == null) return;
    final i = page.round();
    if ((page - i).abs() > 0.02) return;

    final number = widget.detail.surah.number;
    if (_hasPrev && i == 0) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onGoToSurah(number - 1, true),
      );
    } else if (_hasNext && i == _total - 1) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onGoToSurah(number + 1, false),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final surah = detail.surah;
    final current = _current;
    final panelOpen = _selected != null;

    Ayah? panelAyah;
    if (_lastSelected != null) {
      for (final a in detail.ayahs) {
        if (a.numberInSurah == _lastSelected) panelAyah = a;
      }
    }

    return Column(
      children: [
        ListenableBuilder(
          listenable: BookmarkStore.instance,
          builder: (context, _) {
            final saved =
                BookmarkStore.instance.isSaved(surah.number, current.number);
            final scheme = Theme.of(context).colorScheme;
            return _TopBar(
              title: surah.englishName,
              subtitle: 'Page ${current.number} · Juz ${current.juz}',
              onBack: () => _goBack(context),
              trailing: _BarButton(
                icon: saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                tooltip: saved ? 'Remove bookmark' : 'Save this page',
                color: saved ? scheme.primary : null,
                onPressed: _toggleBookmark,
              ),
            );
          },
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: NotificationListener<ScrollEndNotification>(
                  onNotification: (notification) {
                    if (notification.depth == 0) _onScrollEnd();
                    return false;
                  },
                  // right-to-left, like an Arabic book: the next page is
                  // revealed by swiping from left to right
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: PageView.builder(
                      controller: _controller,
                      onPageChanged: _onPageChanged,
                      itemCount: _total,
                      itemBuilder: (context, i) {
                        if (_hasPrev && i == 0) {
                          return _TransitionPage(
                            label: 'Previous surah',
                            name: widget.names[surah.number - 1] ??
                                'Surah ${surah.number - 1}',
                          );
                        }
                        if (_hasNext && i == _total - 1) {
                          return _TransitionPage(
                            label: 'Next surah',
                            name: widget.names[surah.number + 1] ??
                                'Surah ${surah.number + 1}',
                          );
                        }
                        final contentIndex = i - _offset;
                        return _MushafPageView(
                          page: _pages[contentIndex],
                          detail: detail,
                          showHeader: contentIndex == 0,
                          selected: _selected,
                          recognizerFor: _recognizerFor,
                          onSelect: _selectVerse,
                          // The font is sized so the page fits without scrolling.
                          // Extra room only while the panel is open.
                          bottomPadding: panelOpen ? 320 : 0,
                          fitCache: _fitCache,
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (panelAyah != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !panelOpen,
                    child: AnimatedSlide(
                      offset: panelOpen ? Offset.zero : const Offset(0, 1.05),
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: _VersePanel(
                        surah: surah,
                        ayah: panelAyah,
                        tafseerTab: _tafseerTab,
                        onTab: (tafseer) =>
                            setState(() => _tafseerTab = tafseer),
                        onCopy: () => _copy(panelAyah!),
                        onClose: _closePanel,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- top bar

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          _BarButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: onBack,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

/// Round 44px icon button. The icon colour is set explicitly so it is always
/// visible (in light and dark mode).
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: p.surface,
        foregroundColor: color ?? scheme.onSurface,
        fixedSize: const Size(44, 44),
        side: BorderSide(color: p.border),
      ),
      icon: Icon(icon, size: 22),
    );
  }
}

// ---------------------------------------------------------------- header

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({required this.detail});

  final SurahDetail detail;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final primary = Theme.of(context).colorScheme.primary;
    final surah = detail.surah;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: p.border, height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        surah.arabicName,
                        style: AppTheme.arabic(
                          size: 30,
                          height: 1.4,
                          color: primary,
                        ),
                      ),
                    ),
                    Text(
                      '${surah.revelationType} · ${surah.ayahCount} verses',
                      style: TextStyle(fontSize: 12, color: p.muted),
                    ),
                  ],
                ),
              ),
              Expanded(child: Divider(color: p.border, height: 1)),
            ],
          ),
          if (detail.showBismillah) ...[
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                textAlign: TextAlign.center,
                style: AppTheme.arabic(size: 28, height: 1.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- a mushaf page

// The font is sized per page so the whole page fits on the screen without
// scrolling: pages with little text get big letters, dense pages get smaller
// ones (like the printed Quran, where every page has about the same area).
const _lineHeight = 2.0;
const _minFont = 14.0;
const _maxFont = 26.0;

/// The verses of one page as inline spans (text + circled number).
/// When [onSelect] is null the spans are only used to measure the page.
List<InlineSpan> _verseSpans(
  _MushafPage page,
  double fontSize, {
  int? selected,
  Color? highlight,
  TapGestureRecognizer Function(int verse)? recognizerFor,
  void Function(int verse)? onSelect,
}) {
  final measuring = onSelect == null;
  final markerSize = fontSize * 1.3;
  final spans = <InlineSpan>[];
  for (final ayah in page.ayahs) {
    final isSelected = selected == ayah.numberInSurah;
    spans.add(TextSpan(
      text: ayah.arabic,
      recognizer: measuring ? null : recognizerFor!(ayah.numberInSurah),
      style: TextStyle(backgroundColor: isSelected ? highlight : null),
    ));
    spans.add(const TextSpan(text: ' '));
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: measuring
          ? const SizedBox.shrink()
          : _VerseMarker(
              number: ayah.numberInSurah,
              selected: isSelected,
              size: markerSize,
              onTap: () => onSelect!(ayah.numberInSurah),
            ),
    ));
    spans.add(const TextSpan(text: ' '));
  }
  return spans;
}

/// Height the page text needs at [fontSize] when it is [width] wide.
double _measureHeight(
  _MushafPage page,
  double fontSize,
  double width,
  TextScaler scaler,
) {
  final markerSize = fontSize * 1.3;
  final painter = TextPainter(
    text: TextSpan(
      style: AppTheme.arabic(size: fontSize, height: _lineHeight),
      children: _verseSpans(page, fontSize),
    ),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.justify,
    textScaler: scaler,
  );
  painter.setPlaceholderDimensions(
    List.filled(
      page.ayahs.length,
      PlaceholderDimensions(
        size: Size(markerSize + 4, markerSize), // circle + its 2px margins
        alignment: PlaceholderAlignment.middle,
      ),
    ),
  );
  painter.layout(maxWidth: width);
  final height = painter.height;
  painter.dispose();
  return height;
}

/// Largest font size (between [_minFont] and [_maxFont]) at which the page
/// text fits in [height]. If even the smallest size does not fit, the page
/// is allowed to scroll a little.
double _fitFontSize(
  _MushafPage page,
  double width,
  double height,
  TextScaler scaler,
) {
  if (_measureHeight(page, _maxFont, width, scaler) <= height) return _maxFont;
  if (_measureHeight(page, _minFont, width, scaler) > height) return _minFont;

  var low = _minFont; //  fits
  var high = _maxFont; // does not fit
  for (var i = 0; i < 7; i++) {
    final mid = (low + high) / 2;
    if (_measureHeight(page, mid, width, scaler) <= height) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return (low * 10).floorToDouble() / 10; // round down to 0.1
}

/// One page of the Quran: header (first page only), the verses as justified
/// text with circled numbers, and the page number at the bottom.
class _MushafPageView extends StatelessWidget {
  const _MushafPageView({
    required this.page,
    required this.detail,
    required this.showHeader,
    required this.selected,
    required this.recognizerFor,
    required this.onSelect,
    required this.bottomPadding,
    required this.fitCache,
  });

  final _MushafPage page;
  final SurahDetail detail;
  final bool showHeader;
  final int? selected;
  final TapGestureRecognizer Function(int verse) recognizerFor;
  final void Function(int verse) onSelect;

  /// Extra space under the text. Only used while the bottom panel is open
  /// (so the page can be scrolled to uncover the text behind the panel).
  final double bottomPadding;

  /// Remembers the font size found for each page.
  final Map<String, double> fitCache;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scaler = MediaQuery.textScalerOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) _SurahHeader(detail: detail),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth - 40; // 20px each side
              final height = constraints.maxHeight - 16; // small safety margin
              final key =
                  '${page.number}-${width.round()}-${height.round()}-${scaler.scale(10).round()}';
              final fontSize = fitCache.putIfAbsent(
                key,
                () => _fitFontSize(page, width, height, scaler),
              );

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPadding),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text.rich(
                    TextSpan(
                      style: AppTheme.arabic(
                        size: fontSize,
                        height: _lineHeight,
                      ),
                      children: _verseSpans(
                        page,
                        fontSize,
                        selected: selected,
                        highlight: p.primarySoft,
                        recognizerFor: recognizerFor,
                        onSelect: onSelect,
                      ),
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(
          height: 36,
          child: Center(
            child: Text(
              _arabicDigits(page.number),
              style: AppTheme.arabic(size: 16, height: 1.2, color: p.muted),
            ),
          ),
        ),
      ],
    );
  }
}

/// Circled verse number, written with Arabic-Indic digits (١ ٢ ٣).
class _VerseMarker extends StatelessWidget {
  const _VerseMarker({
    required this.number,
    required this.selected,
    required this.size,
    required this.onTap,
  });

  final int number;
  final bool selected;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Verse $number',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: EdgeInsets.all(size * 0.1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? scheme.primary : null,
            border: Border.all(color: scheme.primary, width: 1.5),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _arabicDigits(number),
              style: AppTheme.arabic(
                size: size * 0.5,
                height: 1.3,
                color: selected ? scheme.onPrimary : scheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while swiping past the first / last page of a surah.
class _TransitionPage extends StatelessWidget {
  const _TransitionPage({required this.label, required this.name});

  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 18),
          Text(label, style: TextStyle(fontSize: 13, color: p.muted)),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------- bottom panel

/// Panel pinned to the bottom of the page: verse info, copy / close buttons
/// and two tabs, Tafseer and Translation.
class _VersePanel extends StatelessWidget {
  const _VersePanel({
    required this.surah,
    required this.ayah,
    required this.tafseerTab,
    required this.onTab,
    required this.onCopy,
    required this.onClose,
  });

  final Surah surah;
  final Ayah ayah;
  final bool tafseerTab;
  final void Function(bool tafseer) onTab;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: p.border)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24061812),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle: swipe down to close
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 150) onClose();
            },
            child: SizedBox(
              height: 26,
              width: double.infinity,
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.muted.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verse ${ayah.numberInSurah}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${surah.englishName} ${surah.number}:${ayah.numberInSurah}',
                      style: TextStyle(fontSize: 12, color: p.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy verse',
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _PanelTab(
                  label: 'Tafseer',
                  selected: tafseerTab,
                  onTap: () => onTab(true),
                ),
                _PanelTab(
                  label: 'Translation',
                  selected: !tafseerTab,
                  onTap: () => onTab(false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: p.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tafseerTab ? 'Al-Muyassar' : 'Saheeh International',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.onPrimarySoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // long tafseer scrolls inside the panel
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 190),
            child: SingleChildScrollView(
              child: SizedBox(
                width: double.infinity,
                child: tafseerTab ? _tafseer(p) : _translation(p),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tafseer(AppPalette p) {
    if (ayah.tafseer.isEmpty) {
      return Text(
        'Tafseer is not available for this verse right now.',
        style: TextStyle(fontSize: 14, color: p.muted),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(ayah.tafseer, style: AppTheme.arabic(size: 20, height: 1.9)),
    );
  }

  Widget _translation(AppPalette p) {
    if (ayah.translation.isEmpty) {
      return Text(
        'Translation is not available for this verse.',
        style: TextStyle(fontSize: 14, color: p.muted),
      );
    }
    return Text(
      ayah.translation,
      style: const TextStyle(fontSize: 15, height: 1.55),
    );
  }
}

class _PanelTab extends StatelessWidget {
  const _PanelTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = context.palette;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? scheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? scheme.onSurface : p.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
