import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One range of verses the user is memorising, with its revision schedule.
class HifzItem {
  HifzItem({
    required this.id,
    required this.surah,
    required this.surahEn,
    required this.surahAr,
    required this.from,
    required this.to,
    required this.nextDue,
    this.stage = 0,
    this.revisions = 0,
    this.lastRevised,
  });

  final String id;
  final int surah;
  final String surahEn;
  final String surahAr;
  final int from;
  final int to;

  /// How many times in a row it was remembered (0 = new or forgotten).
  int stage;

  /// Total number of revision sessions.
  int revisions;

  /// yyyy-mm-dd
  String nextDue;
  String? lastRevised;

  /// Strong = remembered 5 times in a row.
  bool get isStrong => stage >= 5;

  String title(bool arabic, String Function(Object) n) {
    final name = arabic ? surahAr : surahEn;
    final range = from == to
        ? (arabic ? 'آية ${n(from)}' : 'verse $from')
        : '${n(from)}–${n(to)}';
    return '$name · $range';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'surah': surah,
        'en': surahEn,
        'ar': surahAr,
        'from': from,
        'to': to,
        'stage': stage,
        'revisions': revisions,
        'due': nextDue,
        'last': lastRevised,
      };

  factory HifzItem.fromJson(Map<String, dynamic> j) => HifzItem(
        id: j['id'] as String,
        surah: (j['surah'] as num).toInt(),
        surahEn: (j['en'] ?? '') as String,
        surahAr: (j['ar'] ?? '') as String,
        from: (j['from'] as num).toInt(),
        to: (j['to'] as num).toInt(),
        stage: (j['stage'] as num?)?.toInt() ?? 0,
        revisions: (j['revisions'] as num?)?.toInt() ?? 0,
        nextDue: (j['due'] ?? HifzStore.ymd(DateTime.now())) as String,
        lastRevised: j['last'] as String?,
      );
}

/// Memorisation (hifz): the ranges, and when each one is due for revision.
/// Revision gaps grow after every success: 1, 3, 7, 14, 30, 60 days.
/// Forgetting a range sends it back to the start (revise tomorrow).
class HifzStore extends ChangeNotifier {
  HifzStore._();
  static final instance = HifzStore._();

  static const _key = 'hifz_items_v1';
  static const gaps = [1, 3, 7, 14, 30, 60];

  final List<HifzItem> _items = [];

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _utcDay(String s) {
    final p = s.split('-');
    return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime.utc(n.year, n.month, n.day);
  }

  /// Days until it is due (0 = today, negative = late).
  int daysUntilDue(HifzItem i) {
    try {
      return _utcDay(i.nextDue).difference(_today).inDays;
    } catch (_) {
      return 0;
    }
  }

  bool isDue(HifzItem i) => daysUntilDue(i) <= 0;

  /// Due ones first (the latest first), then the rest by date.
  List<HifzItem> get items {
    final list = [..._items];
    list.sort((a, b) => daysUntilDue(a).compareTo(daysUntilDue(b)));
    return list;
  }

  int get dueCount => _items.where(isDue).length;
  bool get isEmpty => _items.isEmpty;
  int get total => _items.length;

  HifzItem? byId(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      _items
        ..clear()
        ..addAll(list.map((e) => HifzItem.fromJson(e as Map<String, dynamic>)));
    } catch (_) {
      // start empty
    }
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  Future<HifzItem> add({
    required int surah,
    required String surahEn,
    required String surahAr,
    required int from,
    required int to,
  }) async {
    final item = HifzItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      surah: surah,
      surahEn: surahEn,
      surahAr: surahAr,
      from: from,
      to: to,
      nextDue: ymd(DateTime.now()), // new: start today
    );
    _items.add(item);
    notifyListeners();
    await _save();
    return item;
  }

  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save();
  }

  /// End of a revision session. Remembered = the gap grows; not remembered =
  /// back to the start, revise again tomorrow. Returns the days until the
  /// next revision.
  Future<int> markRevised(String id, {required bool remembered}) async {
    final i = byId(id);
    if (i == null) return 0;
    final today = DateTime.now();
    final int days;
    if (remembered) {
      days = gaps[i.stage.clamp(0, gaps.length - 1)];
      i.stage += 1;
    } else {
      days = 1;
      i.stage = 0;
    }
    i.revisions += 1;
    i.lastRevised = ymd(today);
    i.nextDue = ymd(DateTime(today.year, today.month, today.day + days));
    notifyListeners();
    await _save();
    return days;
  }
}
