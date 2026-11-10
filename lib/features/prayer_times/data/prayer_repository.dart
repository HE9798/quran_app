import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'location_service.dart';
import 'prayer_models.dart';

/// Prayer times from the free Aladhan API (https://aladhan.com/prayer-times-api).
///
/// We download whole months with `/v1/calendar/{year}/{month}`: one request
/// gives about 30 days, which is enough for the countdown, tomorrow's Fajr
/// and for scheduling reminders. Every month is saved on the phone, so the
/// screen also works offline.
class PrayerRepository {
  PrayerRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://api.aladhan.com/v1';

  /// Aladhan calculation method for each country (the official authority of
  /// that country). Anything not listed uses 3 = Muslim World League.
  /// All ids: https://aladhan.com/calculation-methods
  static const _methodByCountry = {
    'EG': 5, //  Egyptian General Authority of Survey
    'SA': 4, //  Umm al-Qura, Makkah
    'AE': 16, // Dubai
    'KW': 9, //  Kuwait
    'QA': 10, // Qatar
    'BH': 8, //  Gulf
    'OM': 8,
    'PK': 1, //  University of Islamic Sciences, Karachi
    'IN': 1,
    'BD': 1,
    'AF': 1,
    'US': 2, //  ISNA
    'CA': 2,
    'TR': 13, // Diyanet
    'FR': 12,
    'RU': 14,
    'SG': 11,
    'MY': 17,
    'ID': 20,
    'TN': 18,
    'DZ': 19,
    'MA': 21,
    'PT': 22,
    'JO': 23,
  };

  static int methodFor(UserLocation location) =>
      _methodByCountry[location.countryCode] ?? 3;

  /// Today's month and the next one (so tomorrow's Fajr and the reminders
  /// always exist), plus the previous month on the 1st (for the progress bar).
  Future<PrayerSchedule> load(UserLocation location) async {
    final now = DateTime.now();
    final months = <(int, int)>[];
    if (now.day == 1) {
      final prev = DateTime(now.year, now.month - 1);
      months.add((prev.year, prev.month));
    }
    months.add((now.year, now.month));
    final next = DateTime(now.year, now.month + 1);
    months.add((next.year, next.month));

    final days = <PrayerDay>[];
    tz.Location? zone;
    Object? firstError;

    for (final (year, month) in months) {
      try {
        final body = await _month(location, year, month);
        final parsed = _parse(body);
        zone ??= parsed.$1;
        days.addAll(parsed.$2);
      } catch (e) {
        // The next month is a bonus: only fail when we have nothing at all.
        firstError ??= e;
      }
    }

    if (days.isEmpty || zone == null) {
      throw firstError ?? Exception('No prayer times');
    }
    days.sort((a, b) => a.date.compareTo(b.date));
    return PrayerSchedule(days: days, location: zone);
  }

  Future<String> _month(UserLocation loc, int year, int month) async {
    final method = methodFor(loc);
    final key = 'prayer_${year}_${month}_'
        '${loc.lat.toStringAsFixed(1)}_${loc.lng.toStringAsFixed(1)}_$method';
    final prefs = await SharedPreferences.getInstance();

    final cached = prefs.getString(key);
    if (cached != null) {
      try {
        _parse(cached); // make sure the saved copy is not damaged
        return cached;
      } catch (_) {
        await prefs.remove(key);
      }
    }

    final uri = Uri.parse('$_base/calendar/$year/$month').replace(
      queryParameters: {
        'latitude': loc.lat.toStringAsFixed(4),
        'longitude': loc.lng.toStringAsFixed(4),
        'method': '$method',
      },
    );
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Server error (${response.statusCode})');
    }
    final body = utf8.decode(response.bodyBytes);
    _parse(body); // throws if the answer is not what we expect
    await prefs.setString(key, body);
    return body;
  }

  /// Returns the time zone of the place and its days.
  (tz.Location, List<PrayerDay>) _parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final data = (json['data'] as List<dynamic>).cast<Map<String, dynamic>>();
    if (data.isEmpty) throw const FormatException('Empty calendar');

    final zoneName =
        ((data.first['meta'] as Map<String, dynamic>?)?['timezone'] ?? '')
            as String;
    tz.Location zone;
    try {
      zone = tz.getLocation(zoneName);
    } catch (_) {
      zone = tz.local; // unknown name: use the phone's zone
    }

    final days = <PrayerDay>[];
    for (final entry in data) {
      final date = entry['date'] as Map<String, dynamic>;
      final gregorian = (date['gregorian'] as Map<String, dynamic>)['date']
          as String; // DD-MM-YYYY
      final parts = gregorian.split('-').map(int.parse).toList();
      final (day, month, year) = (parts[0], parts[1], parts[2]);

      final timings = entry['timings'] as Map<String, dynamic>;
      final times = <Prayer, tz.TZDateTime>{};
      for (final prayer in Prayer.values) {
        // values look like "04:57 (EET)": take the HH:mm part
        final match =
            RegExp(r'(\d{1,2}):(\d{2})').firstMatch('${timings[prayer.apiKey]}');
        if (match == null) throw FormatException('Missing ${prayer.apiKey}');
        times[prayer] = tz.TZDateTime(
          zone,
          year,
          month,
          day,
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
        );
      }

      days.add(PrayerDay(
        date: DateTime(year, month, day),
        times: times,
        hijri: _hijri(date['hijri'] as Map<String, dynamic>?),
      ));
    }
    return (zone, days);
  }

  static const _hijriMonths = [
    'Muharram', 'Safar', 'Rabi I', 'Rabi II', 'Jumada I', 'Jumada II',
    'Rajab', 'Shaban', 'Ramadan', 'Shawwal', 'Dhul Qadah', 'Dhul Hijjah',
  ];

  /// "28 Jumada I 1448". Month names are our own short spellings, because
  /// the API's names carry accents that are hard to read.
  static String _hijri(Map<String, dynamic>? hijri) {
    if (hijri == null) return '';
    final day = int.tryParse('${hijri['day']}') ?? hijri['day'];
    final month = hijri['month'] as Map<String, dynamic>?;
    final number = int.tryParse('${month?['number']}');
    final name = (number != null && number >= 1 && number <= 12)
        ? _hijriMonths[number - 1]
        : '${month?['en'] ?? ''}';
    return '$day $name ${hijri['year']}'.trim();
  }
}
