import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'athkar_models.dart';

/// How many times you said each dhikr today. Starts again every new day.
class AthkarProgressStore extends ChangeNotifier {
  AthkarProgressStore._();
  static final instance = AthkarProgressStore._();

  static const _key = 'athkar_progress_v1';

  SharedPreferences? _prefs;
  String _date = '';
  final Map<AthkarSet, List<int>> _counts = {
    for (final set in AthkarSet.values) set: <int>[],
  };

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
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
