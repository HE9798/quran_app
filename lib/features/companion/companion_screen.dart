import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';
import '../prayer_times/data/prayer_models.dart';
import '../prayer_times/prayer_controller.dart';
import 'companion_sprite.dart';
import 'data/companion_store.dart';

/// The companion's own page: coins, today's prayer check-ins, the streak,
/// and (soon) the wardrobe. Nothing about the companion lives anywhere else.
class CompanionScreen extends StatefulWidget {
  const CompanionScreen({super.key});

  @override
  State<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends State<CompanionScreen> {
  final _store = CompanionStore.instance;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _store.refreshState(); // also collects Tasbeeh coins
    PrayerController.instance.start(); // we need today's prayer times
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListenableBuilder(
      listenable: Listenable.merge([_store, PrayerController.instance]),
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.tr('Back', 'رجوع'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.tr('Companion', 'الرفيق'),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _hero(context, p),
                  const SizedBox(height: 14),
                  _prayers(context, p),
                  const SizedBox(height: 14),
                  _streak(context, p),
                  const SizedBox(height: 14),
                  _earn(context, p),
                  const SizedBox(height: 14),
                  _wardrobe(context, p),
                  const SizedBox(height: 14),
                  _settings(context, p),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, AppPalette p, {required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }

  Widget _title(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );

  // ------------------------------------------------------------------ hero
  Widget _hero(BuildContext context, AppPalette p) {
    final scheme = Theme.of(context).colorScheme;
    return _card(
      context,
      p,
      child: Row(
        children: [
          CompanionSprite(type: _store.type, height: 120),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _store.displayName(context.isArabic),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('Together for ${_store.daysTogether} days',
                      'معًا منذ ${context.n(_store.daysTogether)} يوم'),
                  style: TextStyle(fontSize: 13, color: p.muted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.monetization_on_rounded, color: scheme.primary, size: 30),
                    const SizedBox(width: 8),
                    Text(
                      context.n(_store.coins),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                Text(
                  context.tr('${_store.earnedToday} earned today · ${_store.lifetime} in total',
                      'اليوم ${context.n(_store.earnedToday)} · الإجمالي ${context.n(_store.lifetime)}'),
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- prayers
  /// When the check-in for [prayer] closes: the next prayer (Fajr: sunrise).
  DateTime _windowEnd(PrayerDay day, Prayer prayer) {
    final times = day.times;
    switch (prayer) {
      case Prayer.fajr:
        return times[Prayer.sunrise] ?? times[Prayer.fajr]!.add(const Duration(hours: 2));
      case Prayer.dhuhr:
        return times[Prayer.asr]!;
      case Prayer.asr:
        return times[Prayer.maghrib]!;
      case Prayer.maghrib:
        return times[Prayer.isha]!;
      default:
        final days = PrayerController.instance.schedule?.days ?? const [];
        final i = days.indexOf(day);
        final nextFajr = i >= 0 && i + 1 < days.length ? days[i + 1].times[Prayer.fajr] : null;
        return nextFajr ?? times[Prayer.isha]!.add(const Duration(hours: 6));
    }
  }

  Widget _prayers(BuildContext context, AppPalette p) {
    final ctrl = PrayerController.instance;
    final day = ctrl.today;
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (day == null) {
      body = Text(
        ctrl.loading
            ? context.tr('Loading prayer times…', 'جارٍ تحميل مواقيت الصلاة…')
            : context.tr('Open the Prayer page once to load today\'s times.',
                'افتح صفحة الصلاة مرة لتحميل مواقيت اليوم.'),
        style: TextStyle(color: p.muted),
      );
    } else {
      final now = DateTime.now();
      body = Column(
        children: [
          for (final prayer in Prayer.values.where((e) => e.isPrayer))
            Builder(builder: (context) {
              final time = day.times[prayer]!;
              final end = _windowEnd(day, prayer);
              final done = _store.isCheckedIn(day.date, prayer);
              final open = !done && now.isAfter(time) && now.isBefore(end);
              final missed = !done && !now.isBefore(end);
              final onTime = now.difference(time).inMinutes <= CompanionRewards.onTimeMinutes;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prayer.label(context.isArabic),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(context.clock(time), style: TextStyle(fontSize: 12, color: p.muted)),
                        ],
                      ),
                    ),
                    if (done)
                      Row(children: [
                        Icon(Icons.check_circle_rounded, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(context.tr('Done', 'تم'), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                      ])
                    else if (open)
                      FilledButton(
                        onPressed: () => _store.checkIn(prayer, day.date, time),
                        child: Text(context.tr(
                          'I prayed  +${onTime ? CompanionRewards.prayerOnTime : CompanionRewards.prayerLate}',
                          'صليت  +${context.n(onTime ? CompanionRewards.prayerOnTime : CompanionRewards.prayerLate)}',
                        )),
                      )
                    else
                      Text(
                        missed ? '—' : context.tr('Not yet', 'لم يحن بعد'),
                        style: TextStyle(color: p.muted),
                      ),
                  ],
                ),
              );
            }),
        ],
      );
    }

    return _card(
      context,
      p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context, context.tr('Today\'s prayers', 'صلوات اليوم')),
          body,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- streak
  Widget _streak(BuildContext context, AppPalette p) {
    final s = _store.streak;
    final target = s < 7 ? 7 : (s < 30 ? 30 : null);
    final reward = target == 7 ? CompanionRewards.streak7 : CompanionRewards.streak30;
    return _card(
      context,
      p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context, context.tr('Streak', 'الأيام المتتالية')),
          Text(
            context.tr('$s days in a row', '${context.n(s)} أيام متتالية'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr('Best: ${_store.bestStreak} days', 'الأفضل: ${context.n(_store.bestStreak)} يوم'),
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
          if (target != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: s / target, minHeight: 8),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('$target days = +$reward coins', '${context.n(target)} يوم = +${context.n(reward)} عملة'),
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ how to earn
  Widget _earn(BuildContext context, AppPalette p) {
    Widget row(String text, String coins) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(text)),
              Text(coins, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        );
    return _card(
      context,
      p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context, context.tr('How to earn coins', 'كيف تكسب العملات')),
          row(context.tr('Pray on time (check in)', 'صلاة في وقتها (تسجيل)'), '+${context.n(CompanionRewards.prayerOnTime)}'),
          row(context.tr('Pray later in its time', 'صلاة بعد أول وقتها'), '+${context.n(CompanionRewards.prayerLate)}'),
          row(context.tr('Finish a whole surah', 'ختم سورة كاملة'), '+${context.n(CompanionRewards.surah)}'),
          row(context.tr('Finish today\'s khatma part', 'إتمام ورد الختمة اليومي'), '+${context.n(CompanionRewards.khatmaDay)}'),
          row(context.tr('A hifz session', 'جلسة حفظ'),
              '+${context.n(CompanionRewards.hifzTried)} – ${context.n(CompanionRewards.hifzRemembered)}'),
          row(context.tr('Morning or evening azkar', 'أذكار الصباح أو المساء'), '+${context.n(CompanionRewards.azkar)}'),
          row(context.tr('A full Tasbeeh slider', 'اكتمال شريط التسبيح'),
              context.tr('1 per 10', '١ لكل ١٠')),
          row(context.tr('7-day streak', 'سبعة أيام متتالية'), '+${context.n(CompanionRewards.streak7)}'),
          row(context.tr('30-day streak', 'ثلاثون يومًا متتالية'), '+${context.n(CompanionRewards.streak30)}'),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- wardrobe
  Widget _wardrobe(BuildContext context, AppPalette p) {
    return _card(
      context,
      p,
      child: Row(
        children: [
          Icon(Icons.checkroom_rounded, color: p.muted, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('Wardrobe', 'الخزانة'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text(
                  context.tr('Hats, glasses and more to buy with your coins. Coming soon.',
                      'قبعات ونظارات وغيرها لتشتريها بعملاتك. قريبًا.'),
                  style: TextStyle(fontSize: 13, color: p.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- settings
  Widget _settings(BuildContext context, AppPalette p) {
    return _card(
      context,
      p,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SwitchListTile(
        title: Text(context.tr('Speech bubbles', 'فقاعات الكلام')),
        subtitle: Text(context.tr('Prayer times, unfinished azkar and encouragement',
            'مواقيت الصلاة والأذكار غير المكتملة والتشجيع')),
        value: _store.bubbles,
        onChanged: _store.setBubbles,
      ),
    );
  }
}
