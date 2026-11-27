import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/tr.dart';
import '../../prayer_times/data/prayer_models.dart';
import '../companion_bubbles.dart';
import '../companion_widget.dart';

/// Every coin amount in one place. Change the numbers here.
class CompanionRewards {
  CompanionRewards._();

  static const prayerOnTime = 5; //   checked in within [onTimeMinutes] of the adhan
  static const prayerLate = 2; //     checked in later, before the next prayer
  static const onTimeMinutes = 45;

  static const surah = 3; //          finished reading a whole surah
  static const surahPerDay = 3; //    at most this many surahs count each day
  static const khatmaDay = 10; //     finished today's part of the khatma
  static const hifzRemembered = 5; // hifz session: "I remembered it"
  static const hifzTried = 2; //      hifz session: "Needs more work"
  static const hifzPerDay = 3; //     at most this many hifz sessions count each day
  static const azkar = 3; //          finished the morning / evening azkar
  static const tasbeehPerDay = 100; // most coins the Tasbeeh button gives per day

  static const streak7 = 25;
  static const streak30 = 100;
}

/// The companion's wallet: coins, today's check-ins, the streak.
/// Everything here does nothing while Companion mode is off.
class CompanionStore extends ChangeNotifier {
  CompanionStore._();
  static final instance = CompanionStore._();

  static const _key = 'companion_wallet_v1';

  SharedPreferences? _prefs;

  /// Companion mode is on (and allowed to show).
  bool active = false;
  String type = 'sheikh'; // or "sister"
  String name = ''; //        the name the user gave the companion
  bool chosen = false; //     male/female + name already picked (asked only once, and after a reset)

  /// What to call the companion on screen.
  String displayName(bool arabic) => name.trim().isNotEmpty ? name.trim() : (arabic ? 'رفيقي' : 'My companion');
  bool bubbles = true;

  int coins = 0;
  int lifetime = 0;
  int streak = 0;
  int bestStreak = 0;
  String? _lastActive; //  yyyy-mm-dd
  String? since; //        yyyy-mm-dd the day Companion mode was first turned on
  final Set<int> _milestones = {}; // streak bonuses already given in this streak
  final Map<String, Map<String, int>> _daily = {}; // date -> what was earned

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String get _today => ymd(DateTime.now());

  bool get _ar => AppSettings.instance.isArabic;

  String _n(num v) => _ar ? toArabicDigits('$v') : '$v';

  /// Days since Companion mode was first turned on.
  int get daysTogether {
    final s = DateTime.tryParse(since ?? '');
    if (s == null) return 1;
    final t = DateTime.now();
    return DateTime.utc(t.year, t.month, t.day).difference(DateTime.utc(s.year, s.month, s.day)).inDays + 1;
  }

  // ------------------------------------------------------------ loading

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        coins = (j['coins'] as num?)?.toInt() ?? 0;
        lifetime = (j['lifetime'] as num?)?.toInt() ?? 0;
        streak = (j['streak'] as num?)?.toInt() ?? 0;
        bestStreak = (j['best'] as num?)?.toInt() ?? 0;
        _lastActive = j['last'] as String?;
        since = j['since'] as String?;
        name = (j['name'] as String?) ?? '';
        chosen = (j['chosen'] as bool?) ?? false;
        if (chosen) type = (j['type'] as String?) ?? type;
        _milestones
          ..clear()
          ..addAll(((j['milestones'] as List<dynamic>?) ?? []).map((e) => (e as num).toInt()));
        _daily.clear();
        ((j['daily'] as Map<String, dynamic>?) ?? {}).forEach((date, v) {
          _daily[date] = (v as Map<String, dynamic>).map((k, n) => MapEntry(k, (n as num).toInt()));
        });
      }
    } catch (_) {}
    await refreshState();
  }

  /// Asks the phone side: is the companion on? Also collects Tasbeeh coins.
  Future<void> refreshState() async {
    final s = await CompanionWidget.state();
    active = s.enabled && s.permission;
    if (active) since ??= _today;
    if (!chosen) type = s.type;
    bubbles = s.bubbles;
    if (active) await claimTasbeeh();
    notifyListeners();
  }

  /// The settings switch turned the companion on or off.
  Future<void> setActive(bool on, {String? companion}) async {
    active = on;
    if (companion != null) type = companion;
    if (on) {
      since ??= _today;
      await _save();
      await pushStrings();
    }
    notifyListeners();
    await CompanionBubbles.resync();
  }

  /// First-time (or after a reset) choice: male/female and the name.
  Future<void> setIdentity(String companion, String newName) async {
    type = companion;
    name = newName.trim();
    chosen = true;
    await _save();
    notifyListeners();
  }

  /// Settings > reset: forget the choice, the name and ALL progress
  /// (coins, streak, days together).
  Future<void> resetIdentity() async {
    await CompanionWidget.claimTasbeehCoins(); // throw away coins waiting from the Tasbeeh button
    chosen = false;
    name = '';
    active = false;
    coins = 0;
    lifetime = 0;
    streak = 0;
    bestStreak = 0;
    _lastActive = null;
    since = null;
    _milestones.clear();
    _daily.clear();
    await _save();
    notifyListeners();
    await CompanionBubbles.resync();
  }

  Future<void> setBubbles(bool on) async {
    bubbles = on;
    notifyListeners();
    await CompanionWidget.setBubbles(on);
  }

  /// Phrases for the bubbles the phone side makes by itself.
  Future<void> pushStrings() => CompanionWidget.setStrings({
        'tasbeeh': _ar ? 'ما شاء الله' : 'Mashaa Allah',
        // the companion full screen over the lock screen
        'lock_title': displayName(_ar),
        'lock_dismiss': _ar ? 'إغلاق' : 'Dismiss',
        'lock_open': _ar ? 'فتح التطبيق' : 'Open app',
        // dropped on the X
        'x_title': _ar ? 'إخفاء ${displayName(true)}؟' : 'Hide ${displayName(false)}?',
        'x_body': _ar
            ? 'هل تريد إيقاف تذكيراته أيضًا؟ إن أبقيتها سيظهر على شاشة القفل في أوقات الصلاة.'
            : 'Also stop its reminders? If you keep them, it will still appear on the lock screen at prayer times.',
        'x_keep': _ar ? 'إبقاء التذكيرات' : 'Keep reminders',
        'x_stop': _ar ? 'إيقاف التذكيرات أيضًا' : 'Stop reminders too',
        'x_cancel': _ar ? 'إلغاء' : 'Cancel',
        // reminders as a notification while the character is hidden
        'reminder_channel': _ar ? 'تذكيرات الرفيق' : 'Companion reminders',
      });

  // ----------------------------------------------------------- daily counts

  int _count(String key) => _daily[_today]?[key] ?? 0;

  void _add(String key, [int n = 1]) {
    final day = _daily.putIfAbsent(_today, () => {});
    day[key] = (day[key] ?? 0) + n;
  }

  /// Coins earned today (all sources).
  int get earnedToday => _count('coins');

  bool isCheckedIn(DateTime day, Prayer prayer) =>
      (_daily[ymd(day)]?['prayer:${prayer.apiKey}'] ?? 0) > 0;

  // ------------------------------------------------------------- earning

  /// Gives [amount] coins, updates the streak and says [line] in a bubble.
  Future<void> _grant(int amount, String line, {int bubbleMs = 1000, bool speak = true}) async {
    var bonus = 0;
    var bonusDays = 0;

    // ---- the streak: every day with any activity counts
    final today = _today;
    if (_lastActive != today) {
      final y = DateTime.now().subtract(const Duration(days: 1));
      if (_lastActive == ymd(y)) {
        streak += 1;
      } else {
        streak = 1;
        _milestones.clear();
      }
      _lastActive = today;
      if (streak > bestStreak) bestStreak = streak;
      if (streak >= 7 && !_milestones.contains(7)) {
        _milestones.add(7);
        bonus += CompanionRewards.streak7;
        bonusDays = 7;
      }
      if (streak >= 30 && !_milestones.contains(30)) {
        _milestones.add(30);
        bonus += CompanionRewards.streak30;
        bonusDays = 30;
      }
    }

    final total = amount + bonus;
    coins += total;
    lifetime += total;
    _add('coins', total);
    await _save();
    notifyListeners();

    if (!speak && bonus == 0) return;
    // only words in the bubble: the coins are listed on the Companion page
    final streakLine = _ar ? '${_n(bonusDays)} أيام متتالية' : '${_n(bonusDays)}-day streak';
    var text = speak ? line : '';
    if (bonus > 0) text = text.isEmpty ? streakLine : '$text\n$streakLine';
    await CompanionWidget.say(text, ms: bonus > 0 ? 1500 : bubbleMs);
  }

  /// "I prayed" on the Companion page. [adhan] is the prayer's time.
  /// Returns false if it was already checked in.
  Future<bool> checkIn(Prayer prayer, DateTime day, DateTime adhan) async {
    if (!active) return false;
    final key = 'prayer:${prayer.apiKey}';
    final date = ymd(day);
    if ((_daily[date]?[key] ?? 0) > 0) return false;
    final onTime = DateTime.now().difference(adhan).inMinutes <= CompanionRewards.onTimeMinutes;
    final bucket = _daily.putIfAbsent(date, () => {});
    bucket[key] = 1;
    await _grant(
      onTime ? CompanionRewards.prayerOnTime : CompanionRewards.prayerLate,
      _ar ? 'تقبل الله' : 'Taqabbal Allah',
    );
    return true;
  }

  /// The reader reached the end of a whole surah.
  Future<void> surahFinished(int surah) async {
    if (!active) return;
    final key = 'surah:$surah';
    if (_count(key) > 0 || _count('surahs') >= CompanionRewards.surahPerDay) return;
    _add(key);
    _add('surahs');
    await _grant(CompanionRewards.surah, _ar ? 'ما شاء الله' : 'Mashaa Allah');
  }

  /// Today's part of the khatma is finished.
  Future<void> khatmaDayDone() async {
    if (!active || _count('khatma') > 0) return;
    _add('khatma');
    await _grant(
      CompanionRewards.khatmaDay,
      _ar ? 'ما شاء الله، أتممت ورد اليوم' : 'Mashaa Allah, you finished today\'s part',
    );
  }

  /// A hifz session ended. [remembered] = the user said "I remembered it".
  Future<void> hifzSession(bool remembered) async {
    if (!active || _count('hifz') >= CompanionRewards.hifzPerDay) return;
    _add('hifz');
    await _grant(
      remembered ? CompanionRewards.hifzRemembered : CompanionRewards.hifzTried,
      remembered
          ? (_ar ? 'بارك الله فيك' : 'Barakallahu feek')
          : (_ar ? 'أحسنت المحاولة' : 'Well tried'),
    );
  }

  /// The morning or evening azkar were finished.
  Future<void> azkarDone(bool morning) async {
    if (!active) return;
    final key = morning ? 'azkar:morning' : 'azkar:evening';
    if (_count(key) > 0) return;
    _add(key);
    await _grant(
      CompanionRewards.azkar,
      morning
          ? (_ar ? 'ما شاء الله، أذكار الصباح' : 'Mashaa Allah, morning azkar done')
          : (_ar ? 'ما شاء الله، أذكار المساء' : 'Mashaa Allah, evening azkar done'),
    );
  }

  /// Collects the coins the floating Tasbeeh button earned (the bubble was
  /// already shown by the phone side).
  Future<void> claimTasbeeh() async {
    if (!active) return;
    final pending = await CompanionWidget.claimTasbeehCoins();
    if (pending <= 0) return;
    final room = (CompanionRewards.tasbeehPerDay - _count('tasbeeh')).clamp(0, pending);
    if (room <= 0) return;
    _add('tasbeeh', room);
    // no bubble here: the phone side already said it
    final today = _today;
    if (_lastActive != today) {
      await _grant(room, '', speak: false);
    } else {
      coins += room;
      lifetime += room;
      _add('coins', room);
      await _save();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      // keep only the last 14 days of notes
      final keep = _daily.keys.toList()..sort();
      while (keep.length > 14) {
        _daily.remove(keep.removeAt(0));
      }
      await p.setString(
        _key,
        jsonEncode({
          'coins': coins,
          'lifetime': lifetime,
          'streak': streak,
          'best': bestStreak,
          'last': _lastActive,
          'since': since,
          'name': name,
          'chosen': chosen,
          'type': type,
          'milestones': _milestones.toList(),
          'daily': _daily,
        }),
      );
    } catch (_) {}
  }
}
