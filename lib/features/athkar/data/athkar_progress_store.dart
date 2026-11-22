import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../prayer_times/data/prayer_notifications.dart';

import '../../companion/companion_bubbles.dart';
import '../../companion/data/companion_store.dart';
import 'athkar_models.dart';

/// How many times you said each dhikr today. Starts again every new day.
class AthkarProgressStore extends ChangeNotifier {
  AthkarProgressStore._();
  static final instance = AthkarProgressStore._();

  static const _key = 'athkar_progress_v1';
  static const _doneKey = 'athkar_done_v1'; // {"morning": "2026-11-17", ...}

  SharedPreferences? _prefs;
  String _date = '';
  final Map<AthkarSet, List<int>> _counts = {
    for (final set in AthkarSet.values) set: <int>[],
  };

  /// The day each list was last finished: {"morning": "2026-11-17"}.
  final Map<String, String> _doneOn = {};

  /// True when every dhikr of [set] was finished today.
  bool isDoneToday(AthkarSet set) => _doneOn[set.name] == _today();

  /// Called when the last dhikr of [set] is finished.
  void markDone(AthkarSet set) {
    _doneOn[set.name] = _today();
    _saveDone();
    // no need to remind about this list any more
    PrayerNotifications.instance.cancelMissedReminder(set).catchError((_) {});
    // Companion mode: coins + a bubble, and no "unfinished" bubble any more
    CompanionStore.instance.azkarDone(set == AthkarSet.morning);
    CompanionBubbles.resync().catchError((_) {});
  }

  Future<void> _saveDone() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_doneKey, jsonEncode(_doneOn));
    } catch (_) {}
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final doneRaw = prefs.getString(_doneKey);
      if (doneRaw != null) {
        final done = jsonDecode(doneRaw) as Map<String, dynamic>;
        _doneOn.addAll(done.map((k, v) => MapEntry(k, v as String)));
      }
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['date'] != _today()) return; // old day: start fresh
      _date = json['date'] as String;
      for (final set in AthkarSet.values) {
        final list = json[set.name];
        if (list is List) {
          _counts[set] = [for (final v in list) (v as num).toInt()];
        }
      }
    } catch (_) {}
  }

  void _newDayIfNeeded() {
    final today = _today();
    if (_date == today) return;
    _date = today;
    for (final set in AthkarSet.values) {
      _counts[set] = <int>[];
    }
  }

  /// Counts for [set], always exactly [length] long.
  List<int> countsFor(AthkarSet set, int length) {
    _newDayIfNeeded();
    final list = _counts[set]!;
    if (list.length != length) {
      _counts[set] = [
        for (var i = 0; i < length; i++) i < list.length ? list[i] : 0,
      ];
    }
    return _counts[set]!;
  }

  /// Adds one to dhikr [index]. Returns the new count.
  int increment(AthkarSet set, int index, int length) {
    final counts = countsFor(set, length);
    counts[index] += 1;
    notifyListeners();
    _persist();
    return counts[index];
  }

  void reset(AthkarSet set) {
    _newDayIfNeeded();
    if (_doneOn.remove(set.name) != null) _saveDone();
    _counts[set] = <int>[];
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    try {
      await _prefs?.setString(
        _key,
        jsonEncode({
          'date': _date,
          for (final set in AthkarSet.values) set.name: _counts[set],
        }),
      );
    } catch (_) {}
  }
}
