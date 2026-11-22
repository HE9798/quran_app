import '../../core/settings/tr.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/lang_text.dart';
import '../audio/quran_audio_controller.dart';
import '../companion/companion_sprite.dart';
import '../companion/data/companion_store.dart';
import '../hifz/data/hifz_store.dart';
import '../khatma/data/khatma_store.dart';
import '../bookmarks/data/bookmark_store.dart';
import '../hadith/data/hadith_models.dart';
import '../hadith/data/hadith_repository.dart';
import '../prayer_times/data/prayer_models.dart';
import '../prayer_times/azkar_countdown.dart';
import '../prayer_times/prayer_controller.dart';
import '../quran/data/quran_repository.dart';

/// Home screen. Prayer times, last-read and the Hadith of the day are real.
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
        SizedBox(height: 12),
        _KhatmaCard(),
        SizedBox(height: 12),
        _HifzCard(),
        _CompanionCard(), // only appears when Companion mode is on
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
              context.isArabic
                  ? Text('السلام عليكم',
                      style: AppTheme.arabic(size: 26, height: 1.3))
                  : const Text(
                      'Assalamu Alaykum',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
              const SizedBox(height: 2),
              // real city + Hijri date, the same source as the Prayer tab
              ListenableBuilder(
                listenable: PrayerController.instance,
                builder: (context, _) {
                  final c = PrayerController.instance;
                  final parts = [
                    if (c.location != null)
                      c.location!.city == 'Your location'
                          ? context.tr('Your location', 'موقعك')
                          : c.location!.city,
                    if (c.today != null &&
                        c.today!.hijriFor(context.isArabic).isNotEmpty)
                      context.digits(c.today!.hijriFor(context.isArabic)),
                  ];
                  return Text(
                    parts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: p.muted),
                  );
                },
              ),
            ],
          ),
        ),
        _SquareIconButton(
          icon: Icons.bookmark_border_rounded,
          label: context.tr('Saved', 'المحفوظات'),
          onTap: () => context.go('/bookmarks'),
        ),
        const SizedBox(width: 8),
        _SquareIconButton(
          icon: Icons.tune_rounded,
          label: context.tr('Settings', 'الإعدادات'),
          onTap: () => context.go('/settings'),
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

class _NextPrayerCard extends StatefulWidget {
  const _NextPrayerCard();

  static const _onHeroSoft = Color(0xEBF7EBD4); // white 92%
  static const _heroGreenText = AppColors.teal;

  @override
  State<_NextPrayerCard> createState() => _NextPrayerCardState();
}

class _NextPrayerCardState extends State<_NextPrayerCard> {
  final _controller = PrayerController.instance;

  @override
  void initState() {
    super.initState();
    _controller.start(); // loads location + times (once) and ticks the countdown
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const onHeroSoft = _NextPrayerCard._onHeroSoft;
    const heroGreenText = _NextPrayerCard._heroGreenText;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        final nextOrNull = c.next;
        final today = c.today;
        final hasData = c.schedule != null && nextOrNull != null;

        final String title;
        final String? clock;
        final String badge;
        if (c.schedule != null && nextOrNull != null) {
          final next = nextOrNull;
          title = next.prayer.label(context.isArabic);
          clock = context.clock(next.time);
          badge = context.countdown(next.time.difference(DateTime.now()));
        } else if (c.locationProblem != null) {
          title = context.tr('Allow location', 'اسمح بالموقع');
          clock = context.tr('Tap to set up prayer times', 'اضغط لإعداد مواقيت الصلاة');
          badge = context.tr('Set up', 'إعداد');
        } else if (c.schedule == null && !c.loading) {
          title = context.tr("Couldn't load", 'تعذّر التحميل');
          clock = context.tr('Tap to try again', 'اضغط للمحاولة مرة أخرى');
          badge = context.tr('Retry', 'إعادة');
        } else {
          title = context.tr('Loading…', 'جارٍ التحميل…');
          clock = null;
          badge = '';
        }

        return Material(
          color: p.hero,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (c.schedule == null && !c.loading) {
                c.load(refreshLocation: c.locationProblem != null);
              }
              context.go('/prayer');
            },
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
                    style: const TextStyle(color: AppColors.cream),
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
                                  Text(
                                    context.tr('Next prayer', 'الصلاة القادمة'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: onHeroSoft,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (clock != null)
                                    Text(
                                      clock,
                                      style: TextStyle(
                                        fontSize: hasData ? 18 : 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (badge.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.cream,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: heroGreenText,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.only(top: 12),
                          decoration: const BoxDecoration(
                            border: Border(
                                top: BorderSide(color: Color(0x47F7EBD4))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final prayer in Prayer.values)
                                if (prayer.isPrayer)
                                  _PrayerChip(
                                    label: prayer.label(context.isArabic),
                                    time: today == null
                                        ? '--:--'
                                        : context.clock(today.times[prayer]!,
                                            withPeriod: false),
                                    highlighted: nextOrNull != null &&
                                        today != null &&
                                        nextOrNull.prayer == prayer &&
                                        nextOrNull.time == today.times[prayer],
                                  ),
                            ],
                          ),
                        ),
                        AzkarCountdown(controller: c),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        color: highlighted ? AppColors.cream : null,
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
              color: highlighted ? _NextPrayerCard._heroGreenText : AppColors.cream,
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

  /// Play button: listen from the first verse of the page you will continue
  /// reading (or Al-Fatihah if nothing was read yet). Pauses if playing.
  Future<void> _listenFromLastRead(SavedPage? last) async {
    final audio = QuranAudioController.instance;
    if (audio.playing) {
      await audio.togglePlay();
      return;
    }
    try {
      final detail =
          await QuranRepository().getSurahDetail(last?.surahNumber ?? 1);
      var start = 1;
      if (last != null) {
        final match = detail.ayahs.where((a) => a.page == last.page);
        if (match.isNotEmpty) start = match.first.numberInSurah;
      }
      await audio.playSurah(detail.surah, startAyah: start);
    } catch (e) {
      audio.reportError(e); // the shell shows the "couldn't play" message
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    // Listens to the saved reading position, so the card updates by itself
    // when you come back from the reader.
    return ListenableBuilder(
      listenable: BookmarkStore.instance,
      builder: (context, _) {
        final last = BookmarkStore.instance.lastRead;
        final label = last == null
            ? context.tr('Start reading', 'ابدأ القراءة')
            : context.tr('Continue reading', 'تابع القراءة');
        final ar = context.isArabic;
        final title = last == null
            ? context.tr('Al-Fatihah', 'الفاتحة')
            : (ar
                ? 'سورة ${last.arabicName} · صفحة ${context.n(last.page)}'
                : '${last.surahName} · Page ${last.page}');
        final subtitle = last == null
            ? context.tr('Surah 1 · 7 verses', 'السورة ١ · ٧ آيات')
            : (ar ? 'الجزء ${context.n(last.juz)}' : 'Juz ${last.juz}');
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
              ListenableBuilder(
                listenable: QuranAudioController.instance,
                builder: (context, _) {
                  final audio = QuranAudioController.instance;
                  final playing = audio.playing;
                  final busy = audio.loading && !audio.playing;
                  return IconButton.filled(
                    onPressed: () => _listenFromLastRead(last),
                    tooltip: playing
                        ? context.tr('Pause', 'إيقاف مؤقت')
                        : context.tr('Listen from where you stopped',
                            'استمع من حيث توقفت'),
                    style: IconButton.styleFrom(fixedSize: const Size(44, 44)),
                    icon: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.cream,
                            ),
                          )
                        : Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 26,
                          ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "ختم القرآن": its own progress, separate from "Continue reading".
class _KhatmaCard extends StatelessWidget {
  const _KhatmaCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: KhatmaStore.instance,
      builder: (context, _) {
        final k = KhatmaStore.instance;
        final String subtitle;
        if (!k.active) {
          subtitle = context.tr('Set a timeline and finish the Quran',
              'حدد مدة لختم القرآن الكريم');
        } else if (k.todayDone) {
          subtitle = context.tr("Today's goal is done", 'أنجزت ورد اليوم');
        } else {
          subtitle = context.tr(
            'Today: pages ${k.todayStart}–${k.todayEnd} · ${k.daysLeft} days left',
            'اليوم: صفحات ${context.n(k.todayStart)}–${context.n(k.todayEnd)} · متبقٍ ${context.n(k.daysLeft)} يوم',
          );
        }

        return Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: p.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.go('/khatma'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _IconTile(icon: Icons.auto_stories_outlined, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Quran Khatma', 'ختم القرآن'),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: p.muted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: p.muted),
                    ],
                  ),
                  if (k.active) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: k.progress,
                        minHeight: 8,
                        backgroundColor: p.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation(scheme.primary),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        '${k.currentPage} / ${KhatmaStore.totalPages} pages',
                        '${context.n(k.currentPage)} / ${context.n(KhatmaStore.totalPages)} صفحة',
                      ),
                      style: TextStyle(fontSize: 12, color: p.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Memorisation (hifz): repeat, hide the text, revise on schedule.
class _HifzCard extends StatelessWidget {
  const _HifzCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ListenableBuilder(
      listenable: HifzStore.instance,
      builder: (context, _) {
        final h = HifzStore.instance;
        final String subtitle;
        if (h.isEmpty) {
          subtitle = context.tr('Repeat, hide the text and test yourself',
              'كرّر، أخفِ النص، واختبر نفسك');
        } else if (h.dueCount > 0) {
          subtitle = context.tr('${h.dueCount} due for revision today',
              '${context.n(h.dueCount)} للمراجعة اليوم');
        } else {
          subtitle = context.tr('All revised for today', 'راجعت كل شيء اليوم');
        }

        return Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: p.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.go('/hifz'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const _IconTile(icon: Icons.school_outlined, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Memorisation (Hifz)', 'حفظ القرآن'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.muted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Companion mode: only shown when the companion is turned on in the settings.
class _CompanionCard extends StatefulWidget {
  const _CompanionCard();

  @override
  State<_CompanionCard> createState() => _CompanionCardState();
}

class _CompanionCardState extends State<_CompanionCard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CompanionStore.instance.refreshState(); // also collects Tasbeeh coins
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) CompanionStore.instance.refreshState();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListenableBuilder(
      listenable: CompanionStore.instance,
      builder: (context, _) {
        final c = CompanionStore.instance;
        if (!c.active) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Material(
            color: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: p.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.go('/companion'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    SizedBox(width: 48, child: Center(child: CompanionSprite(type: c.type, height: 64))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.displayName(context.isArabic),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            context.tr('${c.coins} coins · ${c.streak} day streak',
                                '${context.n(c.coins)} عملة · ${context.n(c.streak)} يوم متتالي'),
                            style: TextStyle(fontSize: 13, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.muted),
                  ],
                ),
              ),
            ),
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
            label: context.tr('Qibla', 'القبلة'),
            onTap: () => context.go('/prayer/qibla'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.wb_sunny_outlined,
            label: context.tr('Athkar', 'الأذكار'),
            onTap: () => context.go('/athkar'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.article_outlined,
            label: context.tr('Hadith', 'الحديث'),
            onTap: () => context.go('/hadith'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.bookmark_border_rounded,
            label: context.tr('Saved', 'المحفوظات'),
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

class _HadithOfTheDay extends StatefulWidget {
  const _HadithOfTheDay();

  @override
  State<_HadithOfTheDay> createState() => _HadithOfTheDayState();
}

class _HadithOfTheDayState extends State<_HadithOfTheDay> {
  late Future<HadithCollection> _future;
  bool? _arabic;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arabic = context.isArabic;
    if (_arabic != arabic) {
      _arabic = arabic;
      _future = HadithRepository.instance.load(HadithBook.nawawi, arabic: arabic);
    }
  }

  /// One hadith of the Forty Nawawi per day, the same all day long.
  Hadith _today(HadithCollection collection) {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    return collection.hadiths[dayOfYear % collection.hadiths.length];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr('Hadith of the day', 'حديث اليوم'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            TextButton(
              onPressed: () => context.go('/hadith'),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: Text(
                context.tr('See all', 'عرض الكل'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: p.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.go('/hadith'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: FutureBuilder<HadithCollection>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('Tap to open the ahadeeth', 'اضغط لفتح الأحاديث'),
                            style: TextStyle(color: p.muted),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _future =
                              HadithRepository.instance.load(HadithBook.nawawi,
                                  arabic: context.isArabic)),
                          child: Text(context.tr('Retry', 'إعادة')),
                        ),
                      ],
                    );
                  }
                  if (!snapshot.hasData) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: p.muted,
                          ),
                        ),
                      ),
                    );
                  }

                  final hadith = _today(snapshot.data!);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          hadith.text,
                          textDirection: dirFor(hadith.text),
                          // no line limit: the card grows to fit the whole hadith
                          style: contentStyle(hadith.text, size: 21, height: 1.9),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (hadith.grade != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: p.primarySoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                hadith.grade!,
                                style: contentStyle(
                                  hadith.grade!,
                                  size: 14,
                                  height: 1.3,
                                  color: p.onPrimarySoft,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              hadith.label,
                              textDirection: dirFor(hadith.label),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: contentStyle(
                                hadith.label,
                                size: 15,
                                height: 1.3,
                                color: p.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
