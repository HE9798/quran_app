import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../bookmarks/data/bookmark_store.dart';

/// Home screen. All data here is sample data: replace it with real values
/// (prayer times from Aladhan, last-read from local storage, etc.).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: const [
        _Header(),
        SizedBox(height: 20),
        _NextPrayerCard(),
        SizedBox(height: 20),
        _ContinueReadingCard(),
        SizedBox(height: 20),
        _QuickActions(),
        SizedBox(height: 20),
        _HadithOfTheDay(),
      ],
    );
  }
}

// ---------------------------------------------------------------- header

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text('السلام عليكم',
                    style: AppTheme.arabic(size: 24, height: 1.3)),
              ),
              const SizedBox(height: 2),
              Text(
                'Cairo · 14 Jumada I 1448',
                style: TextStyle(fontSize: 13, color: p.muted),
              ),
            ],
          ),
        ),
        _SquareIconButton(
          icon: Icons.bookmark_border_rounded,
          label: 'Saved',
          onTap: () => context.go('/bookmarks'),
        ),
        const SizedBox(width: 8),
        _SquareIconButton(
          icon: Icons.tune_rounded,
          label: 'Settings',
          onTap: () {},
        ),
      ],
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: p.border),
    );
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: p.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------- next prayer card

class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard();

  static const _times = [
    ('Fajr', '4:57'),
    ('Dhuhr', '11:47'),
    ('Asr', '2:50'),
    ('Maghrib', '5:10'),
    ('Isha', '6:31'),
  ];
  static const _nextIndex = 2;

  static const _onHeroSoft = Color(0xEBFFFFFF); // white 92%
  static const _heroGreenText = Color(0xFF0B6B49);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -44,
            top: -44,
            child: SizedBox(
              width: 190,
              height: 190,
              child: CustomPaint(painter: StarPatternPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Next prayer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _onHeroSoft,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                const Text(
                                  'Asr',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Text(
                                    'العصر',
                                    style: AppTheme.arabic(
                                      size: 22,
                                      height: 1.2,
                                      color: _onHeroSoft,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              '2:50 PM',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'in 1h 24m',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _heroGreenText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x47FFFFFF))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < _times.length; i++)
                          _PrayerChip(
                            label: _times[i].$1,
                            time: _times[i].$2,
                            highlighted: i == _nextIndex,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerChip extends StatelessWidget {
  const _PrayerChip({
    required this.label,
    required this.time,
    required this.highlighted,
  });

  final String label;
  final String time;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final textColor =
        highlighted ? _NextPrayerCard._heroGreenText : _NextPrayerCard._onHeroSoft;
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? Colors.white : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlighted ? FontWeight.w800 : FontWeight.w700,
              color: highlighted ? _NextPrayerCard._heroGreenText : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft geometric (eight-point star) pattern drawn on the green card.
class StarPatternPainter extends CustomPainter {
  const StarPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color.fromRGBO(255, 255, 255, 0.14);

    final c = Offset(size.width / 2, size.height / 2);
    final s = size.width * 0.52;

    canvas.drawRect(Rect.fromCenter(center: c, width: s, height: s), paint);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(0.7853981633974483); // 45 degrees
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: s, height: s),
      paint,
    );
    canvas.restore();

    canvas.drawCircle(c, size.width * 0.2, paint);
    canvas.drawCircle(c, size.width * 0.06, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ------------------------------------------------- continue reading card

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    // Listens to the saved reading position, so the card updates by itself
    // when you come back from the reader.
    return ListenableBuilder(
      listenable: BookmarkStore.instance,
      builder: (context, _) {
        final last = BookmarkStore.instance.lastRead;
        final label = last == null ? 'Start reading' : 'Continue reading';
        final title =
            last == null ? 'Al-Fatihah' : '${last.surahName} · Page ${last.page}';
        final subtitle = last == null ? 'Surah 1 · 7 verses' : 'Juz ${last.juz}';
        final target = last == null
            ? '/quran/surah/1'
            : '/quran/surah/${last.surahNumber}?page=${last.page}';

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.go(target),
                  child: Row(
                    children: [
                      const _IconTile(icon: Icons.menu_book_outlined, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: p.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              subtitle,
                              style: TextStyle(fontSize: 13, color: p.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => context.go('/quran/player'),
                tooltip: 'Listen',
                style: IconButton.styleFrom(fixedSize: const Size(44, 44)),
                icon: const Icon(Icons.play_arrow_rounded, size: 26),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: p.onPrimarySoft, size: 24),
    );
  }
}

// ----------------------------------------------------------- quick actions

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.explore_outlined,
            label: 'Qibla',
            onTap: () => context.go('/prayer/qibla'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.wb_sunny_outlined,
            label: 'Athkar',
            onTap: () => context.go('/athkar'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.article_outlined,
            label: 'Hadith',
            onTap: () => context.go('/hadith'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.bookmark_border_rounded,
            label: 'Saved',
            onTap: () => context.go('/bookmarks'),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: p.border),
    );
    return Material(
      color: p.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: p.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: p.onPrimarySoft),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------- hadith of the day

class _HadithOfTheDay extends StatelessWidget {
  const _HadithOfTheDay();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Hadith of the day',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            TextButton(
              onPressed: () => context.go('/hadith'),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text(
                'See all',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
                    style: AppTheme.arabic(size: 22, height: 1.9),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Actions are judged by intentions.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Sahih',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.onPrimarySoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sahih al-Bukhari 1',
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
