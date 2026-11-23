import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';
import 'hijri_calendar.dart';

/// Hijri calendar: a month grid, the occasions, an optional layer of fasting
/// days, and a +/- day adjustment to match the official date.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _kFasting = 'hijri_fasting_marks_v1';
  static const _kAdjust = 'hijri_adjust_v1';

  bool _fasting = false; // fasting marks are off by default
  int _adjust = 0; // days

  late int _year;
  late int _month;
  late DateTime _selected; // a Gregorian day

  static const _weekEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _weekAr = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
  static const _gregEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _gregAr = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day, 12);
    _goToDate(_selected);
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _fasting = p.getBool(_kFasting) ?? false;
        _adjust = (p.getInt(_kAdjust) ?? 0).clamp(-2, 2);
        _goToDate(_selected);
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kFasting, _fasting);
      await p.setInt(_kAdjust, _adjust);
    } catch (_) {}
  }

  void _goToDate(DateTime d) {
    final h = HijriCalendar.fromGregorian(d, adjust: _adjust);
    _year = h.year;
    _month = h.month;
  }

  void _shiftMonth(int by) {
    setState(() {
      var m = _month + by;
      var y = _year;
      while (m > 12) { m -= 12; y += 1; }
      while (m < 1) { m += 12; y -= 1; }
      _year = y;
      _month = m;
    });
  }

  bool get _ar => context.isArabic;
  String _gDay(DateTime d) => '${d.day} ${_ar ? _gregAr[d.month - 1] : _gregEn[d.month - 1]} ${d.year}';
  String _monthName(int m) => _ar ? HijriCalendar.monthsAr[m - 1] : HijriCalendar.monthsEn[m - 1];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final todayH = HijriCalendar.fromGregorian(today, adjust: _adjust);

    final first = HijriCalendar.toGregorian(_year, _month, 1, adjust: _adjust);
    final length = HijriCalendar.daysInMonth(_year, _month);
    final last = HijriCalendar.toGregorian(_year, _month, length, adjust: _adjust);

    // Arabic weeks start on Saturday, English ones on Sunday
    final startShift = _ar ? 6 : 0; // index in Sun..Sat of the first column
    final firstCol = ((first.weekday % 7) - startShift + 7) % 7;
    final order = [for (var i = 0; i < 7; i++) (startShift + i) % 7];

    final selH = HijriCalendar.fromGregorian(_selected, adjust: _adjust);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: context.tr('Back', 'رجوع'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                context.tr('Hijri calendar', 'التقويم الهجري'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _selected = DateTime(today.year, today.month, today.day, 12);
                _goToDate(_selected);
              }),
              child: Text(context.tr('Today', 'اليوم')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _NextOccasionCard(adjust: _adjust, today: today, gDay: _gDay, monthName: _monthName),
        const SizedBox(height: 12),

        // ------------------------------------------------------ month grid
        Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: context.tr('Previous month', 'الشهر السابق'),
                    icon: Icon(_ar ? Icons.chevron_right_rounded : Icons.chevron_left_rounded),
                    onPressed: () => _shiftMonth(-1),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          context.digits('${_monthName(_month)} $_year'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          context.digits(first.month == last.month
                              ? '${_ar ? _gregAr[first.month - 1] : _gregEn[first.month - 1]} ${first.year}'
                              : '${_ar ? _gregAr[first.month - 1] : _gregEn[first.month - 1]} – ${_ar ? _gregAr[last.month - 1] : _gregEn[last.month - 1]} ${last.year}'),
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Next month', 'الشهر التالي'),
                    icon: Icon(_ar ? Icons.chevron_left_rounded : Icons.chevron_right_rounded),
                    onPressed: () => _shiftMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final w in order)
                    Expanded(
                      child: Center(
                        child: Text(
                          _ar ? _weekAr[w] : _weekEn[w],
                          style: TextStyle(fontSize: _ar ? 10 : 11, color: p.muted, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (var row = 0; row < 6; row++)
                if (row * 7 - firstCol < length)
                  Row(
                    children: [
                      for (var col = 0; col < 7; col++)
                        Expanded(child: _cell(context, row * 7 + col - firstCol + 1, length, todayH, scheme)),
                    ],
                  ),
              const SizedBox(height: 10),
              _Legend(showFasting: _fasting),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---------------------------------------------------- selected day
        _DayDetails(
          greg: _selected,
          hijri: selH,
          fasting: _fasting,
          gDay: _gDay,
          monthName: _monthName,
        ),
        const SizedBox(height: 12),

        // -------------------------------------------------------- options
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Show fasting days', 'إظهار أيام الصيام')),
                subtitle: Text(context.tr(
                  'Mondays, Thursdays and the white days (13, 14, 15). Off keeps the calendar clean.',
                  'الاثنين والخميس والأيام البيض (١٣ و١٤ و١٥). إيقافه يُبقي التقويم نظيفًا.',
                )),
                value: _fasting,
                onChanged: (v) {
                  setState(() => _fasting = v);
                  _save();
                },
              ),
              const Divider(height: 16),
              Text(context.tr('Adjust the date', 'تعديل التاريخ'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                context.tr(
                  'The month begins with the moon sighting, so it can differ by a day from the official date. Move it to match yours.',
                  'يبدأ الشهر برؤية الهلال، فقد يختلف يومًا عن التاريخ الرسمي. عدِّله ليطابق تاريخ بلدك.',
                ),
                style: TextStyle(fontSize: 12, color: p.muted, height: 1.4),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: _adjust > -2 ? () { setState(() { _adjust -= 1; _goToDate(_selected); }); _save(); } : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _adjust == 0
                            ? context.tr('No adjustment', 'بدون تعديل')
                            : context.tr(
                                '${_adjust > 0 ? '+' : ''}$_adjust day${_adjust.abs() == 1 ? '' : 's'}',
                                '${_adjust > 0 ? '+' : '-'}${context.n(_adjust.abs())} ${_adjust.abs() == 1 ? 'يوم' : 'أيام'}'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: _adjust < 2 ? () { setState(() { _adjust += 1; _goToDate(_selected); }); _save(); } : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, int day, int length, HijriDate todayH, ColorScheme scheme) {
    if (day < 1 || day > length) return const SizedBox(height: 52);
    final p = context.palette;
    final greg = HijriCalendar.toGregorian(_year, _month, day, adjust: _adjust);
    final h = HijriDate(_year, _month, day);
    final isToday = h.year == todayH.year && h.month == todayH.month && h.day == todayH.day;
    final isSel = greg.year == _selected.year && greg.month == _selected.month && greg.day == _selected.day;
    final occ = HijriCalendar.on(_month, day);
    final hasMajor = occ.any((o) => o.major);
    final fast = _fasting ? HijriCalendar.fastingKind(greg, h) : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = greg),
      child: Container(
        height: 52,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: isToday ? scheme.primary : (isSel ? p.primarySoft : null),
          borderRadius: BorderRadius.circular(12),
          border: isSel && !isToday ? Border.all(color: scheme.primary, width: 1.4) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.n(day),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isToday ? scheme.onPrimary : null,
              ),
            ),
            Text(
              context.n(greg.day),
              style: TextStyle(fontSize: 9.5, color: isToday ? scheme.onPrimary.withValues(alpha: 0.8) : p.muted),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (occ.isNotEmpty)
                    Container(
                      width: hasMajor ? 7 : 5,
                      height: hasMajor ? 7 : 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isToday ? scheme.onPrimary : (hasMajor ? const Color(0xFFD99A2B) : scheme.primary),
                      ),
                    ),
                  if (fast != null) ...[
                    if (occ.isNotEmpty) const SizedBox(width: 3),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isToday ? scheme.onPrimary : p.muted, width: 1.2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.showFasting});

  final bool showFasting;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    Widget item(Widget dot, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [dot, const SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 11, color: p.muted))],
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 4,
      children: [
        item(Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFD99A2B))),
            context.tr('Eid / new year', 'عيد / رأس السنة')),
        item(Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary)),
            context.tr('Occasion', 'مناسبة')),
        if (showFasting)
          item(Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.muted, width: 1.2))),
              context.tr('Fasting day', 'يوم صيام')),
      ],
    );
  }
}

class _DayDetails extends StatelessWidget {
  const _DayDetails({
    required this.greg,
    required this.hijri,
    required this.fasting,
    required this.gDay,
    required this.monthName,
  });

  final DateTime greg;
  final HijriDate hijri;
  final bool fasting;
  final String Function(DateTime) gDay;
  final String Function(int) monthName;

  static const _weekEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _weekAr = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ar = context.isArabic;
    final occ = HijriCalendar.on(hijri.month, hijri.day);
    final fast = fasting ? HijriCalendar.fastingKind(greg, hijri) : null;
    final lines = <String>[
      for (final o in occ) ar ? o.ar : o.en,
      if (fast == 'white') context.tr('A white day: a day of voluntary fasting', 'من الأيام البيض: يُستحب صيامه'),
      if (fast == 'weekly')
        greg.weekday == DateTime.monday
            ? context.tr('Monday: a day of voluntary fasting', 'الاثنين: يُستحب صيامه')
            : context.tr('Thursday: a day of voluntary fasting', 'الخميس: يُستحب صيامه'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.digits('${ar ? _weekAr[greg.weekday - 1] : _weekEn[greg.weekday - 1]} · ${hijri.day} ${monthName(hijri.month)} ${hijri.year}'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(context.digits(gDay(greg)), style: TextStyle(fontSize: 13, color: p.muted)),
          const SizedBox(height: 8),
          if (lines.isEmpty)
            Text(context.tr('No occasion on this day.', 'لا توجد مناسبة في هذا اليوم.'),
                style: TextStyle(fontSize: 13, color: p.muted))
          else
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8, left: 8),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    Expanded(child: Text(l, style: const TextStyle(fontSize: 14, height: 1.4))),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// "Next: Arafah in 12 days": looks forward for the first headline occasion.
class _NextOccasionCard extends StatelessWidget {
  const _NextOccasionCard({
    required this.adjust,
    required this.today,
    required this.gDay,
    required this.monthName,
  });

  final int adjust;
  final DateTime today;
  final String Function(DateTime) gDay;
  final String Function(int) monthName;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ar = context.isArabic;
    final now = DateTime(today.year, today.month, today.day, 12);
    Occasion? found;
    DateTime? foundDate;
    HijriDate? foundH;
    for (var i = 0; i < 400 && found == null; i++) {
      final d = now.add(Duration(days: i));
      final h = HijriCalendar.fromGregorian(d, adjust: adjust);
      for (final o in HijriCalendar.on(h.month, h.day)) {
        if (o.headline) {
          found = o;
          foundDate = d;
          foundH = h;
          break;
        }
      }
    }
    if (found == null || foundDate == null || foundH == null) return const SizedBox.shrink();
    final days = HijriCalendar.daysBetween(now, foundDate);
    final when = days == 0
        ? context.tr('Today', 'اليوم')
        : days == 1
            ? context.tr('Tomorrow', 'غدًا')
            : context.tr('In $days days', 'بعد ${context.n(days)} يوم');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Next occasion', 'المناسبة القادمة'),
              style: const TextStyle(fontSize: 12, color: Color(0xCCF7EBD4))),
          const SizedBox(height: 2),
          Text(ar ? found.ar : found.en,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFFF7EBD4), height: 1.3)),
          const SizedBox(height: 4),
          Text(
            context.digits('$when · ${foundH.day} ${monthName(foundH.month)} · ${gDay(foundDate)}'),
            style: const TextStyle(fontSize: 12.5, color: Color(0xCCF7EBD4)),
          ),
        ],
      ),
    );
  }
}
