import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import 'data/location_service.dart';
import 'data/prayer_alert_store.dart';
import 'data/prayer_models.dart';
import 'data/prayer_notifications.dart';
import 'data/prayer_repository.dart';

/// The next prayer, and the one before it (for the progress bar).
class NextPrayer {
  const NextPrayer({required this.prayer, required this.time, this.previous});

  final Prayer prayer;
  final tz.TZDateTime time;
  final ({Prayer prayer, tz.TZDateTime time})? previous;
}

/// Holds everything the Prayer and Qibla screens show. One shared instance,
/// so the data is kept while you switch tabs.
class PrayerController extends ChangeNotifier {
  PrayerController._();
  static final instance = PrayerController._();

  final _locations = LocationService.instance;
  final _repository = PrayerRepository();
  final _alerts = PrayerAlertStore.instance;

  UserLocation? location;
  PrayerSchedule? schedule;
  LocationProblem? locationProblem; // why we have no location
  bool networkError = false; //        location is known but no times
  bool loading = false;
  bool _started = false;
  Timer? _ticker;

  // ------------------------------------------------------------- loading

  /// Call when the screen opens. Safe to call many times.
  Future<void> start() async {
    _ticker ??= Timer.periodic(const Duration(seconds: 20), (_) {
      if (schedule != null) notifyListeners(); // refresh the countdown
    });
    if (_started) return;
    _started = true;
    await _alerts.load();
    await load();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// [refreshLocation] asks the phone where it is now (the city button).
  Future<void> load({bool refreshLocation = false}) async {
    if (loading) return;
    loading = true;
    locationProblem = null;
    networkError = false;
    notifyListeners();

    try {
      var current = refreshLocation ? null : await _locations.cached();
      final fromCache = current != null;
      current ??= await _locations.detect();

      await _apply(current);
      if (fromCache) unawaited(_checkForMove(current));
    } on LocationException catch (e) {
      if (schedule == null) locationProblem = e.problem;
    } catch (_) {
      if (schedule == null) networkError = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// In the background: did the phone move to another city since last time?
  Future<void> _checkForMove(UserLocation old) async {
    try {
      final fresh = await _locations.detect();
      if (fresh.distanceKmTo(old) > 10) {
        await _apply(fresh);
        notifyListeners();
      }
    } catch (_) {
      // keep showing the saved place
    }
  }

  Future<void> _apply(UserLocation place) async {
    final loaded = await _repository.load(place);
    location = place;
    schedule = loaded;
    _scheduleReminders();
  }

  void _scheduleReminders() {
    final current = schedule;
    if (current == null) return;
    PrayerNotifications.instance
        .reschedule(current, _alerts.enabled)
        .catchError((_) {}); // reminders are a bonus, never break the screen
  }

  // -------------------------------------------------------------- alerts

  bool isAlertOn(Prayer prayer) => _alerts.isOn(prayer);

  /// Returns false when the user blocked notifications (the switch stays off).
  Future<bool> setAlert(Prayer prayer, bool on) async {
    if (on) {
      final allowed = await PrayerNotifications.instance.requestPermission();
      if (!allowed) return false;
    }
    await _alerts.set(prayer, on);
    _scheduleReminders();
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------- derived

  /// "Now" in the time zone of the user's place.
  tz.TZDateTime? get now =>
      schedule == null ? null : tz.TZDateTime.now(schedule!.location);

  PrayerDay? get today {
    final current = now;
    if (schedule == null || current == null) return null;
    for (final day in schedule!.days) {
      if (day.date.year == current.year &&
          day.date.month == current.month &&
          day.date.day == current.day) {
        return day;
      }
    }
    return null;
  }

  NextPrayer? get next {
    final current = schedule;
    if (current == null) return null;
    final moment = DateTime.now();

    ({Prayer prayer, tz.TZDateTime time})? previous;
    for (final day in current.days) {
      for (final prayer in Prayer.values) {
        if (!prayer.isPrayer) continue;
        final time = day.times[prayer]!;
        if (time.isAfter(moment)) {
          return NextPrayer(prayer: prayer, time: time, previous: previous);
        }
        previous = (prayer: prayer, time: time);
      }
    }
    return null; // ran past the downloaded days, reload on resume
  }

  /// 0..1 between the previous prayer and the next one.
  double progressOf(NextPrayer next) {
    final prev = next.previous;
    if (prev == null) return 0;
    final total = next.time.difference(prev.time).inSeconds;
    if (total <= 0) return 0;
    final passed = DateTime.now().difference(prev.time).inSeconds;
    return (passed / total).clamp(0.0, 1.0);
  }

  /// True when the downloaded days no longer cover tomorrow.
  bool get needsRefresh => schedule != null && next == null;
}
