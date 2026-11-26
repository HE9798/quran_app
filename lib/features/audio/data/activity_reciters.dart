import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../quran_audio_controller.dart';
import 'reciter.dart';

/// A reciter of its own for each activity that plays a voice, so the
/// memorisation (Hifz) and the Khatma can each use a different reciter from
/// the Quran player. Each one is chosen on that activity's own page.
///
/// Each choice is fully independent: changing the Quran player's reciter
/// never changes an activity's, and the other way round. Until the user picks
/// one for an activity, it uses the app's default reciter ([Reciter.alafasy]).
///
/// The Quran player keeps its own choice in QuranAudioController. The adhan
/// has its own voice list on the Prayer page.
class ActivityReciters extends ChangeNotifier {
  ActivityReciters._();
  static final instance = ActivityReciters._();

  static const hifzKey = 'hifz';
  static const khatmaKey = 'khatma';
  static const _key = 'activity_reciters_v1';

  final Map<String, Reciter> _own = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        map.forEach((activity, json) {
          _own[activity] = Reciter.fromJson(json as Map<String, dynamic>);
        });
        notifyListeners();
      }
    } catch (_) {}
  }

  /// True once the user has chosen a reciter just for this activity.
  bool hasOwn(String activity) => _own.containsKey(activity);

  /// The reciter to use for [activity].
  Reciter of(String activity) => _own[activity] ?? Reciter.alafasy;

  Reciter get hifz => of(hifzKey);
  Reciter get khatma => of(khatmaKey);

  Future<void> set(String activity, Reciter reciter) async {
    _own[activity] = reciter;
    notifyListeners();
    // that activity may be playing through the shared player right now
    QuranAudioController.instance.setActivityVoice(activity, reciter);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({for (final e in _own.entries) e.key: e.value.toJson()}),
      );
    } catch (_) {}
  }
}
