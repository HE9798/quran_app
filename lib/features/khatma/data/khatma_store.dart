import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Khatma (reading the whole Quran in a chosen number of days).
/// It has its own progress, separate from "Continue reading".
/// It resets when the Quran is finished, or manually.
class KhatmaStore extends ChangeNotifier {
  KhatmaStore._();
  static final instance = KhatmaStore._();

  /// Pages of the Madinah mushaf.
  static const totalPages = 604;

  static const _kActive = 'khatma_active_v1';
  static const _kStart = 'khatma_start_v1'; //     yyyy-mm-dd
  static const _kDays = 'khatma_days_v1';
  static const _kPage = 'khatma_page_v1'; //       pages finished so far
  static const _kDone = 'khatma_completed_v1'; //  khatmas finished before

  SharedPreferences? _prefs;

  bool active = false;
  DateTime _start = DateTime.now();
  int days = 30;

  /// Pages finished so far (0 .. 604).
  int currentPage = 0;

  /// How many khatmas the user finished in total.
  int completedCount = 0;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      active = p.getBool(_kActive) ?? false;
      final start = DateTime.tryParse(p.getString(_kStart) ?? '');
      if (start != null) _start = start;
      days = (p.getInt(_kDays) ?? 30).clamp(1, 365);
      currentPage = (p.getInt(_kPage) ?? 0).clamp(0, totalPages);
      completedCount = p.getInt(_kDone) ?? 0;
      if (start == null) active = false;
    } catch (_) {
      // start empty
    }
  }

  // ------------------------------------------------------------ derived

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Whole days since the start (0 on the first day).
  int get elapsedDays => _day(DateTime.now()).difference(_day(_start)).inDays.clamp(0, 100000);

  /// 1 on the first day ... [days] on the last day (stays at [days] after).
  int get dayNumber => (elapsedDays + 1).clamp(1, days);

  /// Days left including today; 0 when the time is over.
  int get daysLeft => (days - elapsedDays).clamp(0, days);

  bool get overdue => elapsedDays >= days;

  int get pagesPerDay => (totalPages / days).ceil();

  /// Pages that should be finished by the end of [day] (1-based).
  int _target(int day) => (totalPages * day / days).ceil().clamp(0, totalPages);

  /// First and last page of today's portion.
  int get todayStart => _target(dayNumber - 1) + 1;
  int get todayEnd => overdue ? totalPages : _target(dayNumber);

  int get pagesLeftToday => (todayEnd - currentPage).clamp(0, totalPages);
  bool get todayDone => currentPage >= todayEnd;

  /// Pages missing from the previous days (0 when on track).
  int get behindBy => (_target(dayNumber - 1) - currentPage).clamp(0, totalPages);

  double get progress => currentPage / totalPages;

  /// The next page to read (1 .. 604).
  int get nextPage => (currentPage + 1).clamp(1, totalPages);

  // ------------------------------------------------------------ actions

  Future<void> start(int chosenDays) async {
    active = true;
    days = chosenDays.clamp(1, 365);
    _start = _day(DateTime.now());
    currentPage = 0;
    await _save();
    notifyListeners();
  }

  /// Sets how many pages are finished. Returns true when this finished the
  /// whole Quran (the khatma is then closed and reset).
  Future<bool> setPage(int page) async {
    currentPage = page.clamp(0, totalPages);
    if (currentPage >= totalPages) {
      completedCount++;
      _clear();
      await _save();
      notifyListeners();
      return true;
    }
    await _save();
    notifyListeners();
    return false;
  }

  /// Manual reset: the progress goes away.
  Future<void> reset() async {
    _clear();
    await _save();
    notifyListeners();
  }

  void _clear() {
    active = false;
    currentPage = 0;
  }

  Future<void> _save() async {
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await p.setBool(_kActive, active);
      await p.setString(_kStart, _start.toIso8601String());
      await p.setInt(_kDays, days);
      await p.setInt(_kPage, currentPage);
      await p.setInt(_kDone, completedCount);
    } catch (_) {}
  }
}
